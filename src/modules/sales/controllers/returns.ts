import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyStockChange } from '@/shared/services/stock.service.js';
import { ensureDefaultCashAccount, postCashEntry, postPartyLedger } from '@/shared/services/ledger.service.js';
import z from 'zod';

export const ValidationSchema = {
  createReturn: {
    body: z.object({
      branch_id: z.uuid(),
      sales_invoice_id: z.uuid().optional().nullable(),
      customer_id: z.uuid().optional().nullable(),
      return_type: z.enum(['refund', 'exchange']).default('refund'),
      reason: z.string().optional().nullable(),
      refund_method: z.enum(['cash', 'upi', 'card', 'credit_note']).default('cash'),
      items: z
        .array(
          z.object({
            variant_id: z.uuid(),
            product_name: z.string().min(1),
            quantity: z.number().positive(),
            unit_price: z.number().nonnegative(),
            tax_amount: z.number().nonnegative().optional(),
            restock: z.boolean().optional(),
          }),
        )
        .min(1),
    }),
  },
};

export async function listReturns(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT r.*, c.name AS customer_name
     FROM sales_returns r
     LEFT JOIN customers c ON c.id = r.customer_id
     WHERE r.tenant_id = $1
     ORDER BY r.return_date DESC
     LIMIT 200`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createReturn(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.createReturn.body>;
  await db.begin();
  try {
    const count = await db.queryOne<{ c: string }>(
      `SELECT COUNT(*)::text AS c FROM sales_returns WHERE tenant_id = $1`,
      [req.user!.tenant_id],
    );
    const returnNumber = `SRET-${String(Number(count?.c || 0) + 1).padStart(5, '0')}`;

    let subtotal = 0;
    let taxTotal = 0;
    for (const item of body.items) {
      subtotal += item.quantity * item.unit_price;
      taxTotal += item.tax_amount || 0;
    }
    const grand = Math.round((subtotal + taxTotal + Number.EPSILON) * 100) / 100;

    const ret = await db.queryOne(
      `INSERT INTO sales_returns
        (tenant_id, branch_id, sales_invoice_id, customer_id, return_number, return_type,
         reason, subtotal, tax_total, grand_total, refund_method, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
      [
        req.user!.tenant_id,
        body.branch_id,
        body.sales_invoice_id ?? null,
        body.customer_id ?? null,
        returnNumber,
        body.return_type,
        body.reason ?? null,
        subtotal,
        taxTotal,
        grand,
        body.refund_method,
        req.user!.id,
      ],
    );

    for (const item of body.items) {
      const lineTotal = item.quantity * item.unit_price + (item.tax_amount || 0);
      await db.query(
        `INSERT INTO sales_return_items
          (tenant_id, sales_return_id, variant_id, product_name, quantity, unit_price, tax_amount, line_total, restock)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [
          req.user!.tenant_id,
          ret!.id,
          item.variant_id,
          item.product_name,
          item.quantity,
          item.unit_price,
          item.tax_amount || 0,
          lineTotal,
          item.restock !== false,
        ],
      );

      if (item.restock !== false) {
        await applyStockChange(db, {
          tenantId: req.user!.tenant_id!,
          branchId: body.branch_id,
          variantId: item.variant_id,
          qtyDelta: item.quantity,
          movementType: 'sales_return',
          refType: 'sales_return',
          refId: ret!.id,
          userId: req.user!.id,
          reason: body.reason,
        });
      }
    }

    if (body.customer_id && body.refund_method === 'credit_note') {
      await db.query(
        `UPDATE customers SET outstanding = outstanding - $2 WHERE id = $1 AND tenant_id = $3`,
        [body.customer_id, grand, req.user!.tenant_id],
      );
      await postPartyLedger(db, {
        tenantId: req.user!.tenant_id!,
        partyType: 'customer',
        partyId: body.customer_id,
        direction: 'credit',
        amount: grand,
        description: `Sales return ${returnNumber}`,
        refType: 'sales_return',
        refId: ret!.id,
        userId: req.user!.id,
      });
    } else if (body.refund_method === 'cash' || body.refund_method === 'upi' || body.refund_method === 'card') {
      const accounts = await ensureDefaultCashAccount(db, req.user!.tenant_id!);
      await postCashEntry(db, {
        tenantId: req.user!.tenant_id!,
        accountId: body.refund_method === 'card' ? accounts.bankId : accounts.cashId,
        direction: 'out',
        amount: grand,
        description: `Refund ${returnNumber}`,
        refType: 'sales_return',
        refId: ret!.id,
        userId: req.user!.id,
      });
    }

    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: ret });
  } catch (e: any) {
    await db.rollback();
    if (e?.code === 'insufficient_stock') {
      return res.status(STATUS_CODES.BAD_REQUEST).json({ message: e.message });
    }
    throw e;
  }
}

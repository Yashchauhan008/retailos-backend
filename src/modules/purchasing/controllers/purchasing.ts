import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyStockChange } from '@/shared/services/stock.service.js';
import z from 'zod';

async function nextNumber(db: DatabaseClient, tenantId: string, prefixKey: string, fallback: string) {
  const setting = await db.queryOne<{ value: string }>(
    `SELECT value #>> '{}' AS value FROM tenant_settings WHERE tenant_id = $1 AND key = $2`,
    [tenantId, prefixKey],
  );
  const prefix = (setting?.value || fallback).replace(/"/g, '');
  const count = await db.queryOne<{ c: string }>(
    `SELECT COUNT(*)::text AS c FROM purchase_orders WHERE tenant_id = $1`,
    [tenantId],
  );
  const n = Number(count?.c || 0) + 1;
  return `${prefix}-${String(n).padStart(5, '0')}`;
}

export const ValidationSchema = {
  supplier: {
    body: z.object({
      name: z.string().trim().min(1),
      contact_person: z.string().optional().nullable(),
      phone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      gstin: z.string().optional().nullable(),
      address: z.string().optional().nullable(),
    }),
  },
  po: {
    body: z.object({
      branch_id: z.uuid(),
      supplier_id: z.uuid(),
      notes: z.string().optional().nullable(),
      items: z
        .array(
          z.object({
            variant_id: z.uuid(),
            quantity: z.number().positive(),
            unit_cost: z.number().nonnegative(),
            tax_amount: z.number().nonnegative().optional(),
          }),
        )
        .min(1),
    }),
  },
  receive: {
    body: z.object({
      items: z
        .array(
          z.object({
            variant_id: z.uuid(),
            quantity: z.number().positive(),
            unit_cost: z.number().nonnegative().optional(),
          }),
        )
        .min(1),
      notes: z.string().optional().nullable(),
      create_invoice: z.boolean().optional(),
    }),
  },
  purchaseReturn: {
    body: z.object({
      branch_id: z.uuid(),
      supplier_id: z.uuid(),
      purchase_invoice_id: z.uuid().optional().nullable(),
      reason: z.string().optional().nullable(),
      items: z
        .array(
          z.object({
            variant_id: z.uuid(),
            quantity: z.number().positive(),
            unit_cost: z.number().nonnegative(),
          }),
        )
        .min(1),
    }),
  },
};

export async function listSuppliers(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT * FROM suppliers WHERE tenant_id = $1 ORDER BY name`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createSupplier(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.supplier.body>;
  const row = await db.queryOne(
    `INSERT INTO suppliers (tenant_id, name, contact_person, phone, email, gstin, address)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [
      req.user!.tenant_id,
      body.name,
      body.contact_person ?? null,
      body.phone ?? null,
      body.email ?? null,
      body.gstin ?? null,
      body.address ?? null,
    ],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function listPOs(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT po.*, s.name AS supplier_name,
      (SELECT json_agg(i.*) FROM purchase_order_items i WHERE i.purchase_order_id = po.id) AS items
     FROM purchase_orders po
     JOIN suppliers s ON s.id = po.supplier_id
     WHERE po.tenant_id = $1
     ORDER BY po.created_at DESC`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createPO(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.po.body>;
  await db.begin();
  try {
    const poNumber = await nextNumber(db, req.user!.tenant_id!, 'po_prefix', 'PO');
    let subtotal = 0;
    let taxTotal = 0;
    for (const item of body.items) {
      subtotal += item.quantity * item.unit_cost;
      taxTotal += item.tax_amount || 0;
    }
    const po = await db.queryOne(
      `INSERT INTO purchase_orders
        (tenant_id, branch_id, supplier_id, po_number, status, notes, subtotal, tax_total, grand_total, created_by)
       VALUES ($1,$2,$3,$4,'ordered',$5,$6,$7,$8,$9) RETURNING *`,
      [
        req.user!.tenant_id,
        body.branch_id,
        body.supplier_id,
        poNumber,
        body.notes ?? null,
        subtotal,
        taxTotal,
        subtotal + taxTotal,
        req.user!.id,
      ],
    );
    for (const item of body.items) {
      const lineTotal = item.quantity * item.unit_cost + (item.tax_amount || 0);
      await db.query(
        `INSERT INTO purchase_order_items
          (tenant_id, purchase_order_id, variant_id, quantity, unit_cost, tax_amount, line_total)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [
          req.user!.tenant_id,
          po!.id,
          item.variant_id,
          item.quantity,
          item.unit_cost,
          item.tax_amount || 0,
          lineTotal,
        ],
      );
    }
    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: po });
  } catch (error) {
    await db.rollback();
    throw error;
  }
}

export async function receivePO(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.receive.body>;
  const po = await db.queryOne(
    `SELECT * FROM purchase_orders WHERE id = $1 AND tenant_id = $2`,
    [req.params.id, req.user!.tenant_id],
  );
  if (!po) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'PO not found' });

  await db.begin();
  try {
    const grnCount = await db.queryOne<{ c: string }>(
      `SELECT COUNT(*)::text AS c FROM grns WHERE tenant_id = $1`,
      [req.user!.tenant_id],
    );
    const grnNumber = `GRN-${String(Number(grnCount?.c || 0) + 1).padStart(5, '0')}`;

    const grn = await db.queryOne(
      `INSERT INTO grns (tenant_id, branch_id, purchase_order_id, supplier_id, grn_number, notes, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [
        req.user!.tenant_id,
        po.branch_id,
        po.id,
        po.supplier_id,
        grnNumber,
        body.notes ?? null,
        req.user!.id,
      ],
    );

    let invoiceTotal = 0;
    for (const item of body.items) {
      await db.query(
        `INSERT INTO grn_items (tenant_id, grn_id, variant_id, quantity, unit_cost)
         VALUES ($1,$2,$3,$4,$5)`,
        [
          req.user!.tenant_id,
          grn!.id,
          item.variant_id,
          item.quantity,
          item.unit_cost ?? 0,
        ],
      );
      await applyStockChange(db, {
        tenantId: req.user!.tenant_id!,
        branchId: po.branch_id,
        variantId: item.variant_id,
        qtyDelta: item.quantity,
        movementType: 'grn',
        refType: 'grn',
        refId: grn!.id,
        userId: req.user!.id,
      });
      await db.query(
        `UPDATE purchase_order_items SET received_qty = received_qty + $3
         WHERE purchase_order_id = $1 AND variant_id = $2`,
        [po.id, item.variant_id, item.quantity],
      );
      invoiceTotal += item.quantity * (item.unit_cost ?? 0);
    }

    await db.query(`UPDATE purchase_orders SET status = 'received', updated_at = now() WHERE id = $1`, [
      po.id,
    ]);

    let invoice = null;
    if (body.create_invoice !== false) {
      const invCount = await db.queryOne<{ c: string }>(
        `SELECT COUNT(*)::text AS c FROM purchase_invoices WHERE tenant_id = $1`,
        [req.user!.tenant_id],
      );
      const invoiceNumber = `PINV-${String(Number(invCount?.c || 0) + 1).padStart(5, '0')}`;
      invoice = await db.queryOne(
        `INSERT INTO purchase_invoices
          (tenant_id, branch_id, supplier_id, grn_id, invoice_number, subtotal, grand_total, status)
         VALUES ($1,$2,$3,$4,$5,$6,$6,'unpaid') RETURNING *`,
        [req.user!.tenant_id, po.branch_id, po.supplier_id, grn!.id, invoiceNumber, invoiceTotal],
      );
    }

    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: { grn, invoice } });
  } catch (error) {
    await db.rollback();
    throw error;
  }
}

export async function listGRNs(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT g.*, s.name AS supplier_name FROM grns g
     JOIN suppliers s ON s.id = g.supplier_id
     WHERE g.tenant_id = $1 ORDER BY g.created_at DESC`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function listPurchaseInvoices(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT pi.*, s.name AS supplier_name FROM purchase_invoices pi
     JOIN suppliers s ON s.id = pi.supplier_id
     WHERE pi.tenant_id = $1 ORDER BY pi.created_at DESC`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createPurchaseReturn(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.purchaseReturn.body>;
  await db.begin();
  try {
    const count = await db.queryOne<{ c: string }>(
      `SELECT COUNT(*)::text AS c FROM purchase_returns WHERE tenant_id = $1`,
      [req.user!.tenant_id],
    );
    const returnNumber = `PRET-${String(Number(count?.c || 0) + 1).padStart(5, '0')}`;
    let grand = 0;
    for (const item of body.items) grand += item.quantity * item.unit_cost;

    const ret = await db.queryOne(
      `INSERT INTO purchase_returns
        (tenant_id, branch_id, supplier_id, purchase_invoice_id, return_number, reason, grand_total, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [
        req.user!.tenant_id,
        body.branch_id,
        body.supplier_id,
        body.purchase_invoice_id ?? null,
        returnNumber,
        body.reason ?? null,
        grand,
        req.user!.id,
      ],
    );

    for (const item of body.items) {
      await db.query(
        `INSERT INTO purchase_return_items
          (tenant_id, purchase_return_id, variant_id, quantity, unit_cost, line_total)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [
          req.user!.tenant_id,
          ret!.id,
          item.variant_id,
          item.quantity,
          item.unit_cost,
          item.quantity * item.unit_cost,
        ],
      );
      await applyStockChange(db, {
        tenantId: req.user!.tenant_id!,
        branchId: body.branch_id,
        variantId: item.variant_id,
        qtyDelta: -item.quantity,
        movementType: 'purchase_return',
        refType: 'purchase_return',
        refId: ret!.id,
        userId: req.user!.id,
        reason: body.reason,
      });
    }
    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: ret });
  } catch (error: any) {
    await db.rollback();
    if (error?.code === 'insufficient_stock') {
      return res.status(STATUS_CODES.BAD_REQUEST).json({ message: error.message });
    }
    throw error;
  }
}

import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyStockChange } from '@/shared/services/stock.service.js';
import { calculateLineTax } from '@/shared/services/tax.service.js';
import z from 'zod';

export const ValidationSchema = {
  checkout: {
    body: z.object({
      branch_id: z.uuid(),
      customer_id: z.uuid().optional().nullable(),
      notes: z.string().optional().nullable(),
      bill_discount: z.number().nonnegative().optional(),
      inter_state: z.boolean().optional(),
      items: z
        .array(
          z.object({
            variant_id: z.uuid(),
            quantity: z.number().positive(),
            unit_price: z.number().nonnegative(),
            discount_amount: z.number().nonnegative().optional(),
          }),
        )
        .min(1),
      payments: z
        .array(
          z.object({
            method: z.enum(['cash', 'upi', 'card', 'credit', 'other']),
            amount: z.number().nonnegative().optional(),
            reference: z.string().optional().nullable(),
          }),
        )
        .min(1),
      settle_full: z.boolean().optional(),
    }),
  },
  heldCart: {
    body: z.object({
      branch_id: z.uuid(),
      label: z.string().optional().nullable(),
      cart_data: z.any(),
    }),
  },
};

export async function checkout(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.checkout.body>;
  const taxInclusiveSetting = await db.queryOne<{ value: unknown }>(
    `SELECT value FROM tenant_settings WHERE tenant_id = $1 AND key = 'tax_inclusive'`,
    [req.user!.tenant_id],
  );
  const taxInclusive = Boolean(taxInclusiveSetting?.value === true || taxInclusiveSetting?.value === 'true');

  await db.begin();
  try {
    const count = await db.queryOne<{ c: string }>(
      `SELECT COUNT(*)::text AS c FROM sales_invoices WHERE tenant_id = $1`,
      [req.user!.tenant_id],
    );
    const prefixRow = await db.queryOne<{ value: unknown }>(
      `SELECT value FROM tenant_settings WHERE tenant_id = $1 AND key = 'invoice_prefix'`,
      [req.user!.tenant_id],
    );
    const prefix = String(prefixRow?.value ?? 'INV').replace(/"/g, '');
    const invoiceNumber = `${prefix}-${String(Number(count?.c || 0) + 1).padStart(5, '0')}`;

    let subtotal = 0;
    let discountTotal = body.bill_discount || 0;
    let cgstTotal = 0;
    let sgstTotal = 0;
    let igstTotal = 0;
    const lineResults: Array<{
      item: (typeof body.items)[number];
      variant: any;
      product: any;
      tax: ReturnType<typeof calculateLineTax>;
      taxRate: number;
    }> = [];

    for (const item of body.items) {
      const variant = await db.queryOne(
        `SELECT v.*, p.name AS product_name, p.track_inventory, p.tax_rate_id
         FROM product_variants v
         JOIN products p ON p.id = v.product_id
         WHERE v.id = $1 AND v.tenant_id = $2`,
        [item.variant_id, req.user!.tenant_id],
      );
      if (!variant) throw Object.assign(new Error('Variant not found'), { status: 400 });

      const taxRate = variant.tax_rate_id
        ? await db.queryOne(
            `SELECT * FROM tax_rates WHERE id = $1 AND tenant_id = $2`,
            [variant.tax_rate_id, req.user!.tenant_id],
          )
        : { cgst_rate: 0, sgst_rate: 0, igst_rate: 0 };

      const tax = calculateLineTax({
        quantity: item.quantity,
        unitPrice: item.unit_price,
        discountAmount: item.discount_amount || 0,
        cgstRate: Number(taxRate?.cgst_rate || 0),
        sgstRate: Number(taxRate?.sgst_rate || 0),
        igstRate: Number(taxRate?.igst_rate || 0),
        interState: body.inter_state,
        taxInclusive,
      });

      discountTotal += item.discount_amount || 0;
      subtotal += tax.taxable;
      cgstTotal += Number(tax.cgst);
      sgstTotal += Number(tax.sgst);
      igstTotal += Number(tax.igst);

      lineResults.push({
        item,
        variant,
        product: variant,
        tax,
        taxRate: body.inter_state
          ? Number(taxRate?.igst_rate || 0)
          : Number(taxRate?.cgst_rate || 0) + Number(taxRate?.sgst_rate || 0),
      });
    }

    // Apply bill discount proportionally to taxable conceptually as reduction on grand
    const taxTotal = cgstTotal + sgstTotal + igstTotal;
    let grandTotal = subtotal + taxTotal - (body.bill_discount || 0);
    if (grandTotal < 0) grandTotal = 0;
    grandTotal = Math.round((grandTotal + Number.EPSILON) * 100) / 100;

    let tenderLines = body.payments.map((p) => ({
      ...p,
      amount: p.amount ?? 0,
    }));
    const explicitPaid = tenderLines.reduce((s, p) => s + (p.amount || 0), 0);
    if (body.settle_full !== false && (explicitPaid <= 0 || Math.abs(explicitPaid - grandTotal) > 0.05)) {
      // POS convenience: settle full bill on first tender when amounts omitted/mismatched
      tenderLines = [
        {
          method: tenderLines[0]!.method,
          amount: grandTotal,
          reference: tenderLines[0]!.reference ?? null,
        },
      ];
    }
    const paid = tenderLines.reduce((s, p) => s + p.amount, 0);
    const amountDue = Math.round((grandTotal - paid + Number.EPSILON) * 100) / 100;

    const invoice = await db.queryOne(
      `INSERT INTO sales_invoices
        (tenant_id, branch_id, customer_id, invoice_number, status,
         subtotal, discount_total, tax_total, cgst_total, sgst_total, igst_total,
         grand_total, amount_paid, amount_due, notes, created_by)
       VALUES ($1,$2,$3,$4,'completed',$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       RETURNING *`,
      [
        req.user!.tenant_id,
        body.branch_id,
        body.customer_id ?? null,
        invoiceNumber,
        subtotal,
        discountTotal,
        taxTotal,
        cgstTotal,
        sgstTotal,
        igstTotal,
        grandTotal,
        paid,
        Math.max(0, amountDue),
        body.notes ?? null,
        req.user!.id,
      ],
    );

    for (const line of lineResults) {
      await db.query(
        `INSERT INTO sales_invoice_items
          (tenant_id, sales_invoice_id, variant_id, product_name, sku, quantity, unit_price,
           discount_amount, tax_rate, cgst_amount, sgst_amount, igst_amount, line_total)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
        [
          req.user!.tenant_id,
          invoice!.id,
          line.item.variant_id,
          line.variant.product_name,
          line.variant.sku,
          line.item.quantity,
          line.item.unit_price,
          line.item.discount_amount || 0,
          line.taxRate,
          line.tax.cgst,
          line.tax.sgst,
          line.tax.igst,
          line.tax.lineTotal,
        ],
      );

      if (line.variant.track_inventory) {
        await applyStockChange(db, {
          tenantId: req.user!.tenant_id!,
          branchId: body.branch_id,
          variantId: line.item.variant_id,
          qtyDelta: -line.item.quantity,
          movementType: 'sale',
          refType: 'sales_invoice',
          refId: invoice!.id,
          userId: req.user!.id,
        });
      }
    }

    for (const payment of tenderLines) {
      await db.query(
        `INSERT INTO sales_payments (tenant_id, sales_invoice_id, method, amount, reference)
         VALUES ($1,$2,$3,$4,$5)`,
        [
          req.user!.tenant_id,
          invoice!.id,
          payment.method,
          payment.amount,
          payment.reference ?? null,
        ],
      );
    }

    if (body.customer_id && amountDue > 0) {
      await db.query(
        `UPDATE customers SET outstanding = outstanding + $2 WHERE id = $1 AND tenant_id = $3`,
        [body.customer_id, amountDue, req.user!.tenant_id],
      );
    }

    await db.commit();

    const full = await db.queryOne(`SELECT * FROM sales_invoices WHERE id = $1`, [invoice!.id]);
    const items = await db.queryAll(
      `SELECT * FROM sales_invoice_items WHERE sales_invoice_id = $1`,
      [invoice!.id],
    );
    const payments = await db.queryAll(
      `SELECT * FROM sales_payments WHERE sales_invoice_id = $1`,
      [invoice!.id],
    );

    return res.status(STATUS_CODES.CREATED).json({ data: { ...full, items, payments } });
  } catch (error: any) {
    await db.rollback();
    if (error?.code === 'insufficient_stock') {
      return res.status(STATUS_CODES.BAD_REQUEST).json({ message: error.message });
    }
    throw error;
  }
}

export async function listInvoices(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT si.*, c.name AS customer_name
     FROM sales_invoices si
     LEFT JOIN customers c ON c.id = si.customer_id
     WHERE si.tenant_id = $1
     ORDER BY si.invoice_date DESC
     LIMIT 200`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function getInvoice(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const invoice = await db.queryOne(
    `SELECT si.*, c.name AS customer_name, c.phone AS customer_phone, t.name AS business_name,
            t.gstin, t.address_line1, t.city, t.state, t.pincode
     FROM sales_invoices si
     LEFT JOIN customers c ON c.id = si.customer_id
     JOIN tenants t ON t.id = si.tenant_id
     WHERE si.id = $1 AND si.tenant_id = $2`,
    [req.params.id, req.user!.tenant_id],
  );
  if (!invoice) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Invoice not found' });
  const items = await db.queryAll(
    `SELECT * FROM sales_invoice_items WHERE sales_invoice_id = $1`,
    [invoice.id],
  );
  const payments = await db.queryAll(
    `SELECT * FROM sales_payments WHERE sales_invoice_id = $1`,
    [invoice.id],
  );
  return res.status(STATUS_CODES.OK).json({ data: { ...invoice, items, payments } });
}

export async function listHeldCarts(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT * FROM held_carts WHERE tenant_id = $1 AND user_id = $2 ORDER BY updated_at DESC NULLS LAST, created_at DESC`,
    [req.user!.tenant_id, req.user!.id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function saveHeldCart(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.heldCart.body>;
  const row = await db.queryOne(
    `INSERT INTO held_carts (tenant_id, branch_id, user_id, label, cart_data, updated_at)
     VALUES ($1,$2,$3,$4,$5::jsonb, now()) RETURNING *`,
    [
      req.user!.tenant_id,
      body.branch_id,
      req.user!.id,
      body.label ?? 'Held cart',
      JSON.stringify(body.cart_data),
    ],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function deleteHeldCart(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await db.query(
    `DELETE FROM held_carts WHERE id = $1 AND tenant_id = $2 AND user_id = $3`,
    [req.params.id, req.user!.tenant_id, req.user!.id],
  );
  return res.status(STATUS_CODES.OK).json({ message: 'Deleted' });
}

import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyStockChange } from '@/shared/services/stock.service.js';
import { syncNewPermissionsToTenantOwners } from '@/shared/services/ledger.service.js';
import z from 'zod';

export const ValidationSchema = {
  transfer: {
    body: z.object({
      from_branch_id: z.uuid(),
      to_branch_id: z.uuid(),
      notes: z.string().optional().nullable(),
      items: z
        .array(z.object({ variant_id: z.uuid(), quantity: z.number().positive() }))
        .min(1),
    }),
  },
  shift: {
    body: z.object({
      name: z.string().min(1),
      start_time: z.string(),
      end_time: z.string(),
    }),
  },
  attendance: {
    body: z.object({
      user_id: z.uuid(),
      branch_id: z.uuid().optional().nullable(),
      shift_id: z.uuid().optional().nullable(),
      attendance_date: z.string().optional(),
      check_in: z.string().optional().nullable(),
      check_out: z.string().optional().nullable(),
      status: z.enum(['present', 'absent', 'leave', 'half_day']).default('present'),
      notes: z.string().optional().nullable(),
    }),
  },
  customerGroup: {
    body: z.object({
      name: z.string().min(1),
      discount_percent: z.number().min(0).max(100).default(0),
    }),
  },
  loyaltySettings: {
    body: z.object({
      points_per_currency: z.number().positive(),
      currency_per_point: z.number().positive(),
      min_redeem_points: z.number().nonnegative(),
      is_active: z.boolean().optional(),
    }),
  },
  loyaltyAdjust: {
    body: z.object({
      customer_id: z.uuid(),
      points: z.number(),
      direction: z.enum(['earn', 'redeem', 'adjust']),
      notes: z.string().optional().nullable(),
    }),
  },
  coupon: {
    body: z.object({
      code: z.string().trim().min(1),
      name: z.string().min(1),
      discount_type: z.enum(['percent', 'flat']).default('percent'),
      discount_value: z.number().positive(),
      min_order_amount: z.number().nonnegative().optional(),
      max_discount: z.number().positive().optional().nullable(),
      usage_limit: z.number().int().positive().optional().nullable(),
      starts_at: z.string().optional().nullable(),
      ends_at: z.string().optional().nullable(),
    }),
  },
  validateCoupon: {
    body: z.object({
      code: z.string().trim().min(1),
      order_amount: z.number().nonnegative(),
    }),
  },
  promotion: {
    body: z.object({
      name: z.string().min(1),
      promo_type: z.string().default('percent_off'),
      config: z.record(z.string(), z.any()).optional(),
      starts_at: z.string().optional().nullable(),
      ends_at: z.string().optional().nullable(),
    }),
  },
  batch: {
    body: z.object({
      branch_id: z.uuid(),
      variant_id: z.uuid(),
      batch_number: z.string().min(1),
      quantity: z.number(),
      expiry_date: z.string().optional().nullable(),
      manufactured_date: z.string().optional().nullable(),
    }),
  },
  serial: {
    body: z.object({
      branch_id: z.uuid().optional().nullable(),
      variant_id: z.uuid(),
      serial_value: z.string().min(1),
      serial_type: z.enum(['serial', 'imei']).default('serial'),
      warranty_months: z.number().int().positive().optional().nullable(),
    }),
  },
  warranty: {
    body: z.object({
      serial_id: z.uuid().optional().nullable(),
      customer_id: z.uuid().optional().nullable(),
      issue_description: z.string().min(1),
    }),
  },
};

export async function listTransfers(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  await syncNewPermissionsToTenantOwners(db, req.user!.tenant_id!);
  const rows = await db.queryAll(
    `SELECT t.*, fb.name AS from_branch, tb.name AS to_branch,
      (SELECT json_agg(i.*) FROM stock_transfer_items i WHERE i.stock_transfer_id = t.id) AS items
     FROM stock_transfers t
     JOIN branches fb ON fb.id = t.from_branch_id
     JOIN branches tb ON tb.id = t.to_branch_id
     WHERE t.tenant_id = $1
     ORDER BY t.created_at DESC`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createTransfer(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.transfer.body>;
  if (body.from_branch_id === body.to_branch_id) {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Branches must differ' });
  }
  const count = await db.queryOne<{ c: string }>(
    `SELECT COUNT(*)::text AS c FROM stock_transfers WHERE tenant_id = $1`,
    [req.user!.tenant_id],
  );
  const transferNumber = `TR-${String(Number(count?.c || 0) + 1).padStart(5, '0')}`;
  await db.begin();
  try {
    const transfer = await db.queryOne(
      `INSERT INTO stock_transfers
        (tenant_id, transfer_number, from_branch_id, to_branch_id, status, notes, created_by)
       VALUES ($1,$2,$3,$4,'draft',$5,$6) RETURNING *`,
      [
        req.user!.tenant_id,
        transferNumber,
        body.from_branch_id,
        body.to_branch_id,
        body.notes ?? null,
        req.user!.id,
      ],
    );
    for (const item of body.items) {
      await db.query(
        `INSERT INTO stock_transfer_items (tenant_id, stock_transfer_id, variant_id, quantity)
         VALUES ($1,$2,$3,$4)`,
        [req.user!.tenant_id, transfer!.id, item.variant_id, item.quantity],
      );
    }
    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: transfer });
  } catch (e) {
    await db.rollback();
    throw e;
  }
}

export async function dispatchTransfer(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const transfer = await db.queryOne(
    `SELECT * FROM stock_transfers WHERE id = $1 AND tenant_id = $2`,
    [req.params.id, req.user!.tenant_id],
  );
  if (!transfer) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Transfer not found' });
  if (transfer.status !== 'draft') {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Only draft transfers can be dispatched' });
  }

  const items = await db.queryAll(
    `SELECT * FROM stock_transfer_items WHERE stock_transfer_id = $1`,
    [transfer.id],
  );
  await db.begin();
  try {
    for (const item of items) {
      await applyStockChange(db, {
        tenantId: req.user!.tenant_id!,
        branchId: transfer.from_branch_id,
        variantId: item.variant_id,
        qtyDelta: -Number(item.quantity),
        movementType: 'transfer_out',
        refType: 'stock_transfer',
        refId: transfer.id,
        userId: req.user!.id,
      });
    }
    const updated = await db.queryOne(
      `UPDATE stock_transfers SET status = 'in_transit', transferred_at = now() WHERE id = $1 RETURNING *`,
      [transfer.id],
    );
    await db.commit();
    return res.status(STATUS_CODES.OK).json({ data: updated });
  } catch (e: any) {
    await db.rollback();
    if (e?.code === 'insufficient_stock') {
      return res.status(STATUS_CODES.BAD_REQUEST).json({ message: e.message });
    }
    throw e;
  }
}

export async function receiveTransfer(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const transfer = await db.queryOne(
    `SELECT * FROM stock_transfers WHERE id = $1 AND tenant_id = $2`,
    [req.params.id, req.user!.tenant_id],
  );
  if (!transfer) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Transfer not found' });
  if (transfer.status !== 'in_transit') {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Transfer not in transit' });
  }
  const items = await db.queryAll(
    `SELECT * FROM stock_transfer_items WHERE stock_transfer_id = $1`,
    [transfer.id],
  );
  await db.begin();
  try {
    for (const item of items) {
      await applyStockChange(db, {
        tenantId: req.user!.tenant_id!,
        branchId: transfer.to_branch_id,
        variantId: item.variant_id,
        qtyDelta: Number(item.quantity),
        movementType: 'transfer_in',
        refType: 'stock_transfer',
        refId: transfer.id,
        userId: req.user!.id,
      });
      await db.query(
        `UPDATE stock_transfer_items SET received_qty = quantity WHERE id = $1`,
        [item.id],
      );
    }
    const updated = await db.queryOne(
      `UPDATE stock_transfers SET status = 'received', received_at = now(), received_by = $2 WHERE id = $1 RETURNING *`,
      [transfer.id, req.user!.id],
    );
    await db.commit();
    return res.status(STATUS_CODES.OK).json({ data: updated });
  } catch (e) {
    await db.rollback();
    throw e;
  }
}

export async function listShifts(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(`SELECT * FROM shifts WHERE tenant_id = $1 ORDER BY start_time`, [
    req.user!.tenant_id,
  ]);
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createShift(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.shift.body>;
  const row = await db.queryOne(
    `INSERT INTO shifts (tenant_id, name, start_time, end_time) VALUES ($1,$2,$3::time,$4::time) RETURNING *`,
    [req.user!.tenant_id, body.name, body.start_time, body.end_time],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function listAttendance(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT a.*, u.name AS user_name, s.name AS shift_name
     FROM attendance_records a
     JOIN users u ON u.id = a.user_id
     LEFT JOIN shifts s ON s.id = a.shift_id
     WHERE a.tenant_id = $1
     ORDER BY a.attendance_date DESC
     LIMIT 200`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function upsertAttendance(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.attendance.body>;
  const date = body.attendance_date || new Date().toISOString().slice(0, 10);
  const row = await db.queryOne(
    `INSERT INTO attendance_records
      (tenant_id, user_id, branch_id, shift_id, attendance_date, check_in, check_out, status, notes)
     VALUES ($1,$2,$3,$4,$5::date,$6::timestamptz,$7::timestamptz,$8,$9)
     ON CONFLICT (tenant_id, user_id, attendance_date) DO UPDATE SET
       branch_id = EXCLUDED.branch_id,
       shift_id = EXCLUDED.shift_id,
       check_in = EXCLUDED.check_in,
       check_out = EXCLUDED.check_out,
       status = EXCLUDED.status,
       notes = EXCLUDED.notes
     RETURNING *`,
    [
      req.user!.tenant_id,
      body.user_id,
      body.branch_id ?? req.user!.branch_id ?? null,
      body.shift_id ?? null,
      date,
      body.check_in ?? null,
      body.check_out ?? null,
      body.status,
      body.notes ?? null,
    ],
  );
  return res.status(STATUS_CODES.OK).json({ data: row });
}

export async function listCustomerGroups(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT * FROM customer_groups WHERE tenant_id = $1 ORDER BY name`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createCustomerGroup(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.customerGroup.body>;
  const row = await db.queryOne(
    `INSERT INTO customer_groups (tenant_id, name, discount_percent) VALUES ($1,$2,$3) RETURNING *`,
    [req.user!.tenant_id, body.name, body.discount_percent],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function getLoyaltySettings(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  let row = await db.queryOne(`SELECT * FROM loyalty_settings WHERE tenant_id = $1`, [req.user!.tenant_id]);
  if (!row) {
    row = await db.queryOne(
      `INSERT INTO loyalty_settings (tenant_id) VALUES ($1) RETURNING *`,
      [req.user!.tenant_id],
    );
  }
  return res.status(STATUS_CODES.OK).json({ data: row });
}

export async function upsertLoyaltySettings(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.loyaltySettings.body>;
  const row = await db.queryOne(
    `INSERT INTO loyalty_settings (tenant_id, points_per_currency, currency_per_point, min_redeem_points, is_active)
     VALUES ($1,$2,$3,$4,COALESCE($5,true))
     ON CONFLICT (tenant_id) DO UPDATE SET
       points_per_currency = EXCLUDED.points_per_currency,
       currency_per_point = EXCLUDED.currency_per_point,
       min_redeem_points = EXCLUDED.min_redeem_points,
       is_active = EXCLUDED.is_active
     RETURNING *`,
    [
      req.user!.tenant_id,
      body.points_per_currency,
      body.currency_per_point,
      body.min_redeem_points,
      body.is_active ?? true,
    ],
  );
  return res.status(STATUS_CODES.OK).json({ data: row });
}

export async function adjustLoyalty(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.loyaltyAdjust.body>;
  const customer = await db.queryOne<{ id: string; loyalty_points: string }>(
    `SELECT id, loyalty_points FROM customers WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
    [body.customer_id, req.user!.tenant_id],
  );
  if (!customer) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Customer not found' });

  const current = Number(customer.loyalty_points);
  const delta =
    body.direction === 'redeem' ? -Math.abs(body.points) : body.direction === 'earn' ? Math.abs(body.points) : body.points;
  const balanceAfter = current + delta;
  if (balanceAfter < 0) {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Insufficient loyalty points' });
  }

  await db.query(`UPDATE customers SET loyalty_points = $2 WHERE id = $1`, [customer.id, balanceAfter]);
  const tx = await db.queryOne(
    `INSERT INTO loyalty_transactions
      (tenant_id, customer_id, points, direction, balance_after, notes)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [req.user!.tenant_id, customer.id, Math.abs(body.points), body.direction, balanceAfter, body.notes ?? null],
  );
  return res.status(STATUS_CODES.OK).json({ data: tx });
}

export async function listCoupons(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(`SELECT * FROM coupons WHERE tenant_id = $1 ORDER BY created_at DESC`, [
    req.user!.tenant_id,
  ]);
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createCoupon(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.coupon.body>;
  const row = await db.queryOne(
    `INSERT INTO coupons
      (tenant_id, code, name, discount_type, discount_value, min_order_amount, max_discount, usage_limit, starts_at, ends_at)
     VALUES ($1, UPPER($2), $3, $4, $5, $6, $7, $8, $9::timestamptz, $10::timestamptz) RETURNING *`,
    [
      req.user!.tenant_id,
      body.code,
      body.name,
      body.discount_type,
      body.discount_value,
      body.min_order_amount ?? 0,
      body.max_discount ?? null,
      body.usage_limit ?? null,
      body.starts_at ?? null,
      body.ends_at ?? null,
    ],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function validateCoupon(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.validateCoupon.body>;
  const coupon = await db.queryOne(
    `SELECT * FROM coupons WHERE tenant_id = $1 AND code = UPPER($2) AND is_active = true`,
    [req.user!.tenant_id, body.code],
  );
  if (!coupon) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Coupon not found' });
  if (coupon.starts_at && new Date(coupon.starts_at) > new Date()) {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Coupon not started' });
  }
  if (coupon.ends_at && new Date(coupon.ends_at) < new Date()) {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Coupon expired' });
  }
  if (coupon.usage_limit != null && coupon.used_count >= coupon.usage_limit) {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Coupon usage limit reached' });
  }
  if (body.order_amount < Number(coupon.min_order_amount)) {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Order below minimum amount' });
  }

  let discount =
    coupon.discount_type === 'percent'
      ? (body.order_amount * Number(coupon.discount_value)) / 100
      : Number(coupon.discount_value);
  if (coupon.max_discount != null) discount = Math.min(discount, Number(coupon.max_discount));
  discount = Math.round((discount + Number.EPSILON) * 100) / 100;

  return res.status(STATUS_CODES.OK).json({
    data: { coupon, discount_amount: discount },
  });
}

export async function listPromotions(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(`SELECT * FROM promotions WHERE tenant_id = $1 ORDER BY created_at DESC`, [
    req.user!.tenant_id,
  ]);
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createPromotion(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.promotion.body>;
  const row = await db.queryOne(
    `INSERT INTO promotions (tenant_id, name, promo_type, config, starts_at, ends_at)
     VALUES ($1,$2,$3,$4::jsonb,$5::timestamptz,$6::timestamptz) RETURNING *`,
    [
      req.user!.tenant_id,
      body.name,
      body.promo_type,
      JSON.stringify(body.config ?? {}),
      body.starts_at ?? null,
      body.ends_at ?? null,
    ],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function listBatches(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT b.*, v.sku, p.name AS product_name
     FROM inventory_batches b
     JOIN product_variants v ON v.id = b.variant_id
     JOIN products p ON p.id = v.product_id
     WHERE b.tenant_id = $1
     ORDER BY b.expiry_date NULLS LAST, b.created_at DESC`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function upsertBatch(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.batch.body>;
  const row = await db.queryOne(
    `INSERT INTO inventory_batches
      (tenant_id, branch_id, variant_id, batch_number, quantity, expiry_date, manufactured_date)
     VALUES ($1,$2,$3,$4,$5,$6::date,$7::date)
     ON CONFLICT (tenant_id, branch_id, variant_id, batch_number) DO UPDATE SET
       quantity = EXCLUDED.quantity,
       expiry_date = EXCLUDED.expiry_date,
       manufactured_date = EXCLUDED.manufactured_date
     RETURNING *`,
    [
      req.user!.tenant_id,
      body.branch_id,
      body.variant_id,
      body.batch_number,
      body.quantity,
      body.expiry_date ?? null,
      body.manufactured_date ?? null,
    ],
  );
  return res.status(STATUS_CODES.OK).json({ data: row });
}

export async function listSerials(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT s.*, v.sku, p.name AS product_name
     FROM serial_numbers s
     JOIN product_variants v ON v.id = s.variant_id
     JOIN products p ON p.id = v.product_id
     WHERE s.tenant_id = $1
     ORDER BY s.created_at DESC
     LIMIT 300`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createSerial(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.serial.body>;
  const warrantyExpires = body.warranty_months
    ? new Date(Date.now() + body.warranty_months * 30 * 86400000).toISOString().slice(0, 10)
    : null;
  const row = await db.queryOne(
    `INSERT INTO serial_numbers
      (tenant_id, branch_id, variant_id, serial_value, serial_type, warranty_months, warranty_expires_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7::date) RETURNING *`,
    [
      req.user!.tenant_id,
      body.branch_id ?? req.user!.branch_id ?? null,
      body.variant_id,
      body.serial_value,
      body.serial_type,
      body.warranty_months ?? null,
      warrantyExpires,
    ],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function listWarranties(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT w.*, c.name AS customer_name, s.serial_value
     FROM warranty_claims w
     LEFT JOIN customers c ON c.id = w.customer_id
     LEFT JOIN serial_numbers s ON s.id = w.serial_id
     WHERE w.tenant_id = $1
     ORDER BY w.created_at DESC`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createWarrantyClaim(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.warranty.body>;
  const count = await db.queryOne<{ c: string }>(
    `SELECT COUNT(*)::text AS c FROM warranty_claims WHERE tenant_id = $1`,
    [req.user!.tenant_id],
  );
  const claimNumber = `WRN-${String(Number(count?.c || 0) + 1).padStart(5, '0')}`;
  const row = await db.queryOne(
    `INSERT INTO warranty_claims
      (tenant_id, serial_id, customer_id, claim_number, issue_description, created_by)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [
      req.user!.tenant_id,
      body.serial_id ?? null,
      body.customer_id ?? null,
      claimNumber,
      body.issue_description,
      req.user!.id,
    ],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function listForecasts(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT f.*, v.sku, p.name AS product_name
     FROM inventory_forecasts f
     JOIN product_variants v ON v.id = f.variant_id
     JOIN products p ON p.id = v.product_id
     WHERE f.tenant_id = $1
     ORDER BY f.suggested_reorder_qty DESC
     LIMIT 100`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function generateForecasts(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  // Simple 30-day moving average forecast
  const rows = await db.queryAll<{
    variant_id: string;
    branch_id: string;
    qty_sold: string;
    stock: string;
  }>(
    `SELECT sii.variant_id,
            si.branch_id,
            COALESCE(SUM(sii.quantity),0)::text AS qty_sold,
            COALESCE((
              SELECT quantity FROM stock_levels sl
              WHERE sl.variant_id = sii.variant_id AND sl.branch_id = si.branch_id AND sl.tenant_id = si.tenant_id
            ),0)::text AS stock
     FROM sales_invoice_items sii
     JOIN sales_invoices si ON si.id = sii.sales_invoice_id
     WHERE si.tenant_id = $1 AND si.invoice_date >= now() - interval '30 days'
     GROUP BY sii.variant_id, si.branch_id, si.tenant_id`,
    [req.user!.tenant_id],
  );

  await db.query(`DELETE FROM inventory_forecasts WHERE tenant_id = $1`, [req.user!.tenant_id]);
  const created = [];
  for (const row of rows) {
    const avgDaily = Number(row.qty_sold) / 30;
    const stock = Number(row.stock);
    const daysCover = avgDaily > 0 ? stock / avgDaily : 999;
    const suggested = Math.max(0, Math.ceil(avgDaily * 14 - stock));
    const forecast = await db.queryOne(
      `INSERT INTO inventory_forecasts
        (tenant_id, variant_id, branch_id, avg_daily_sales, suggested_reorder_qty, days_of_cover, metadata)
       VALUES ($1,$2,$3,$4,$5,$6,$7::jsonb) RETURNING *`,
      [
        req.user!.tenant_id,
        row.variant_id,
        row.branch_id,
        avgDaily,
        suggested,
        Math.round(daysCover * 100) / 100,
        JSON.stringify({ window_days: 30, qty_sold: Number(row.qty_sold) }),
      ],
    );
    created.push(forecast);
  }
  return res.status(STATUS_CODES.OK).json({ data: created });
}

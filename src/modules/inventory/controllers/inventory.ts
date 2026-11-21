import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyStockChange } from '@/shared/services/stock.service.js';
import z from 'zod';

export const ValidationSchema = {
  adjust: {
    body: z.object({
      branch_id: z.uuid(),
      variant_id: z.uuid(),
      quantity: z.number(),
      reason: z.string().trim().min(1),
      mode: z.enum(['set', 'delta']).default('delta'),
    }),
  },
};

export async function listStock(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const branchId = String(req.query.branch_id || req.user!.branch_id || '');
  const rows = await db.queryAll(
    `SELECT sl.*, v.sku, v.barcode, v.selling_price, p.name AS product_name, p.low_stock_threshold,
            b.name AS branch_name
     FROM stock_levels sl
     JOIN product_variants v ON v.id = sl.variant_id
     JOIN products p ON p.id = v.product_id
     JOIN branches b ON b.id = sl.branch_id
     WHERE sl.tenant_id = $1
       AND ($2 = '' OR sl.branch_id = $2::uuid)
     ORDER BY p.name`,
    [req.user!.tenant_id, branchId],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function adjustStock(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.adjust.body>;
  await db.begin();
  try {
    let qtyDelta = body.quantity;
    if (body.mode === 'set') {
      const existing = await db.queryOne<{ quantity: string }>(
        `SELECT quantity FROM stock_levels
         WHERE tenant_id = $1 AND branch_id = $2 AND variant_id = $3`,
        [req.user!.tenant_id, body.branch_id, body.variant_id],
      );
      const current = existing ? Number(existing.quantity) : 0;
      qtyDelta = body.quantity - current;
    }

    const result = await applyStockChange(db, {
      tenantId: req.user!.tenant_id!,
      branchId: body.branch_id,
      variantId: body.variant_id,
      qtyDelta,
      movementType: 'adjustment',
      reason: body.reason,
      userId: req.user!.id,
    });
    await db.commit();
    return res.status(STATUS_CODES.OK).json({ data: result });
  } catch (error: any) {
    await db.rollback();
    if (error?.code === 'insufficient_stock') {
      return res.status(STATUS_CODES.BAD_REQUEST).json({ message: error.message });
    }
    throw error;
  }
}

export async function listMovements(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT m.*, v.sku, p.name AS product_name
     FROM stock_movements m
     JOIN product_variants v ON v.id = m.variant_id
     JOIN products p ON p.id = v.product_id
     WHERE m.tenant_id = $1
     ORDER BY m.created_at DESC
     LIMIT 200`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

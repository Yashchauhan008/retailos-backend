import type { DatabaseClient } from '@/shared/helpers/database.helper.js';

export async function applyStockChange(
  db: DatabaseClient,
  input: {
    tenantId: string;
    branchId: string;
    variantId: string;
    qtyDelta: number;
    movementType: string;
    reason?: string | null;
    refType?: string | null;
    refId?: string | null;
    userId?: string | null;
  },
) {
  const existing = await db.queryOne<{ id: string; quantity: string }>(
    `SELECT id, quantity FROM stock_levels
     WHERE tenant_id = $1 AND branch_id = $2 AND variant_id = $3
     FOR UPDATE`,
    [input.tenantId, input.branchId, input.variantId],
  );

  const current = existing ? Number(existing.quantity) : 0;
  const next = current + input.qtyDelta;
  if (next < -0.0001) {
    throw Object.assign(new Error('Insufficient stock'), { status: 400, code: 'insufficient_stock' });
  }

  let stockId = existing?.id;
  if (existing) {
    await db.query(
      `UPDATE stock_levels SET quantity = $2, updated_at = now() WHERE id = $1`,
      [existing.id, next],
    );
  } else {
    const created = await db.queryOne<{ id: string }>(
      `INSERT INTO stock_levels (tenant_id, branch_id, variant_id, quantity)
       VALUES ($1,$2,$3,$4) RETURNING id`,
      [input.tenantId, input.branchId, input.variantId, next],
    );
    stockId = created?.id;
  }

  await db.query(
    `INSERT INTO stock_movements
      (tenant_id, branch_id, variant_id, movement_type, qty_delta, qty_after, reason, ref_type, ref_id, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
    [
      input.tenantId,
      input.branchId,
      input.variantId,
      input.movementType,
      input.qtyDelta,
      next,
      input.reason ?? null,
      input.refType ?? null,
      input.refId ?? null,
      input.userId ?? null,
    ],
  );

  return { stockId, quantity: next };
}

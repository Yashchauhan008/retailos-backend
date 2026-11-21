import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyTenantRls } from '@/shared/middlewares/tenant-context.js';
import z from 'zod';

export const ValidationSchema = {
  update: {
    body: z.object({
      status: z.enum(['active', 'suspended']).optional(),
      plan_id: z.uuid().optional(),
    }),
  },
};

export async function listRetailers(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await applyTenantRls(db, { isSuperAdmin: true });
  const q = String(req.query.q || '').trim();
  const rows = await db.queryAll(
    `SELECT t.*, i.name AS industry_name, p.name AS plan_name, p.code AS plan_code,
            s.status AS subscription_status, s.trial_ends_at, s.current_period_end
     FROM tenants t
     LEFT JOIN industries i ON i.id = t.industry_id
     LEFT JOIN tenant_subscriptions s ON s.tenant_id = t.id
     LEFT JOIN plans p ON p.id = s.plan_id
     WHERE ($1 = '' OR t.name ILIKE '%' || $1 || '%' OR t.email ILIKE '%' || $1 || '%')
     ORDER BY t.created_at DESC`,
    [q],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function updateRetailer(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await applyTenantRls(db, { isSuperAdmin: true });
  const body = req.body as z.infer<typeof ValidationSchema.update.body>;

  if (body.status) {
    await db.query(`UPDATE tenants SET status = $2, updated_at = now() WHERE id = $1`, [
      req.params.id,
      body.status,
    ]);
  }
  if (body.plan_id) {
    await db.query(
      `UPDATE tenant_subscriptions SET plan_id = $2, status = 'active', updated_at = now()
       WHERE tenant_id = $1`,
      [req.params.id, body.plan_id],
    );
  }

  const row = await db.queryOne(`SELECT * FROM tenants WHERE id = $1`, [req.params.id]);
  return res.status(STATUS_CODES.OK).json({ data: row });
}

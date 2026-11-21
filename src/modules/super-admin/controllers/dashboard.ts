import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyTenantRls } from '@/shared/middlewares/tenant-context.js';

export async function dashboard(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await applyTenantRls(db, { isSuperAdmin: true });

  const totals = await db.queryOne<{
    tenants: string;
    active_tenants: string;
    trialing: string;
    suspended: string;
  }>(
    `SELECT
       COUNT(*)::text AS tenants,
       COUNT(*) FILTER (WHERE status = 'active')::text AS active_tenants,
       COUNT(*) FILTER (WHERE status = 'suspended')::text AS suspended,
       (SELECT COUNT(*)::text FROM tenant_subscriptions WHERE status = 'trialing') AS trialing
     FROM tenants`,
  );

  const recent = await db.queryAll(
    `SELECT t.id, t.name, t.status, t.created_at, i.name AS industry_name,
            p.name AS plan_name, s.status AS subscription_status
     FROM tenants t
     LEFT JOIN industries i ON i.id = t.industry_id
     LEFT JOIN tenant_subscriptions s ON s.tenant_id = t.id
     LEFT JOIN plans p ON p.id = s.plan_id
     ORDER BY t.created_at DESC
     LIMIT 10`,
  );

  return res.status(STATUS_CODES.OK).json({ data: { totals, recent } });
}

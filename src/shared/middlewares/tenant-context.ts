import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';

/** Set Postgres session vars for RLS. Call inside a request that already has a DB client. */
export async function applyTenantRls(
  db: DatabaseClient,
  options: { tenantId?: string | null; isSuperAdmin?: boolean },
) {
  if (options.isSuperAdmin) {
    await db.query(`SELECT set_config('app.is_super_admin', 'true', true)`);
    await db.query(`SELECT set_config('app.tenant_id', '', true)`);
    return;
  }

  await db.query(`SELECT set_config('app.is_super_admin', 'false', true)`);
  if (options.tenantId) {
    await db.query(`SELECT set_config('app.tenant_id', $1, true)`, [options.tenantId]);
  } else {
    await db.query(`SELECT set_config('app.tenant_id', '', true)`);
  }
}

/**
 * Wraps a controller so RLS context is applied from the authenticated request.
 * Must be used with withDatabase.
 */
export function withTenantContext(
  controller: (
    req: Request,
    res: Response,
    next: NextFunction,
    db: DatabaseClient,
  ) => Promise<unknown>,
) {
  return async (req: Request, res: Response, next: NextFunction, db: DatabaseClient) => {
    await applyTenantRls(db, {
      tenantId: req.user?.tenant_id,
      isSuperAdmin: Boolean(req.superAdmin?.id),
    });
    return controller(req, res, next, db);
  };
}

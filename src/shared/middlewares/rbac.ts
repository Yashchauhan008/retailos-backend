import type { NextFunction, Request, Response } from 'express';
import Database from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyTenantRls } from './tenant-context.js';

export function requirePermission(...permissionKeys: string[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (req.superAdmin?.id) return next();

    const roleId = req.user?.role_id;
    const tenantId = req.user?.tenant_id;
    if (!roleId || !tenantId) {
      return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'Insufficient permissions' });
    }

    const db = await Database.getConnection();
    try {
      await applyTenantRls(db, { tenantId });
      const rows = await db.queryAll<{ key: string }>(
        `SELECT p.key
         FROM tenant_role_permissions trp
         JOIN permissions p ON p.id = trp.permission_id
         WHERE trp.tenant_role_id = $1 AND p.key = ANY($2::text[])`,
        [roleId, permissionKeys],
      );

      // Require ANY of the listed permissions
      if (rows.length === 0) {
        return res.status(STATUS_CODES.FORBIDDEN).json({
          message: 'Insufficient permissions',
          required_any: permissionKeys,
        });
      }
      return next();
    } catch (error) {
      return next(error);
    } finally {
      db.release();
    }
  };
}

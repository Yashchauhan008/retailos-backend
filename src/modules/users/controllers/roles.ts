import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import z from 'zod';

export const ValidationSchema = {
  updatePermissions: {
    body: z.object({
      permission_ids: z.array(z.uuid()),
    }),
  },
};

export async function listRoles(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const roles = await db.queryAll(
    `SELECT r.*,
      COALESCE(json_agg(p.key) FILTER (WHERE p.id IS NOT NULL), '[]') AS permissions
     FROM tenant_roles r
     LEFT JOIN tenant_role_permissions trp ON trp.tenant_role_id = r.id
     LEFT JOIN permissions p ON p.id = trp.permission_id
     WHERE r.tenant_id = $1
     GROUP BY r.id
     ORDER BY r.name`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: roles });
}

export async function updateRolePermissions(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const role = await db.queryOne(
    `SELECT * FROM tenant_roles WHERE id = $1 AND tenant_id = $2`,
    [req.params.id, req.user!.tenant_id],
  );
  if (!role) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Role not found' });
  if (role.code === 'owner') {
    return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'Owner role permissions are locked' });
  }

  const { permission_ids } = req.body as z.infer<typeof ValidationSchema.updatePermissions.body>;
  await db.begin();
  try {
    await db.query(`DELETE FROM tenant_role_permissions WHERE tenant_role_id = $1`, [role.id]);
    for (const permissionId of permission_ids) {
      await db.query(
        `INSERT INTO tenant_role_permissions (tenant_role_id, permission_id) VALUES ($1, $2)`,
        [role.id, permissionId],
      );
    }
    await db.commit();
  } catch (error) {
    await db.rollback();
    throw error;
  }

  return listRoles(req, res, next, db);
}

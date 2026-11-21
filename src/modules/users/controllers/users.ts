import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import bcrypt from 'bcryptjs';
import z from 'zod';

export const ValidationSchema = {
  invite: {
    body: z.object({
      name: z.string().trim().min(1).max(255),
      email: z.email().trim().toLowerCase(),
      password: z.string().trim().min(6).max(255),
      role_id: z.uuid(),
      branch_id: z.uuid().optional().nullable(),
      phone: z.string().optional().nullable(),
    }),
  },
  update: {
    body: z.object({
      role_id: z.uuid().optional(),
      branch_id: z.uuid().optional().nullable(),
      status: z.enum(['active', 'inactive']).optional(),
    }),
  },
};

export async function listUsers(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const rows = await db.queryAll(
    `SELECT tu.id, tu.status, tu.role_id, tu.branch_id, tu.created_at,
            u.id AS user_id, u.name, u.email, u.phone, u.last_login_at,
            r.name AS role_name, r.code AS role_code,
            b.name AS branch_name
     FROM tenant_users tu
     JOIN users u ON u.id = tu.user_id
     JOIN tenant_roles r ON r.id = tu.role_id
     LEFT JOIN branches b ON b.id = tu.branch_id
     WHERE tu.tenant_id = $1
     ORDER BY tu.created_at`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function inviteUser(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.invite.body>;

  const role = await db.queryOne(
    `SELECT id FROM tenant_roles WHERE id = $1 AND tenant_id = $2`,
    [body.role_id, req.user!.tenant_id],
  );
  if (!role) return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Invalid role' });

  await db.begin();
  try {
    let user = await db.queryOne<{ id: string }>('SELECT id FROM users WHERE email = $1', [
      body.email,
    ]);
    if (!user) {
      const passwordHash = await bcrypt.hash(body.password, 10);
      user = await db.queryOne<{ id: string }>(
        `INSERT INTO users (name, email, password_hash, phone, status, email_verified)
         VALUES ($1,$2,$3,$4,'active', true) RETURNING id`,
        [body.name, body.email, passwordHash, body.phone ?? null],
      );
    }

    const existing = await db.queryOne(
      `SELECT id FROM tenant_users WHERE tenant_id = $1 AND user_id = $2`,
      [req.user!.tenant_id, user!.id],
    );
    if (existing) {
      await db.rollback();
      return res.status(STATUS_CODES.CONFLICT).json({ message: 'User already in this business' });
    }

    const membership = await db.queryOne(
      `INSERT INTO tenant_users (tenant_id, user_id, role_id, branch_id, status)
       VALUES ($1,$2,$3,$4,'active') RETURNING *`,
      [req.user!.tenant_id, user!.id, body.role_id, body.branch_id ?? null],
    );
    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: membership });
  } catch (error) {
    await db.rollback();
    throw error;
  }
}

export async function updateUser(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.update.body>;
  const row = await db.queryOne(
    `UPDATE tenant_users SET
       role_id = COALESCE($3, role_id),
       branch_id = COALESCE($4, branch_id),
       status = COALESCE($5, status)
     WHERE id = $1 AND tenant_id = $2
     RETURNING *`,
    [
      req.params.id,
      req.user!.tenant_id,
      body.role_id ?? null,
      body.branch_id ?? null,
      body.status ?? null,
    ],
  );
  if (!row) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'User not found' });
  return res.status(STATUS_CODES.OK).json({ data: row });
}

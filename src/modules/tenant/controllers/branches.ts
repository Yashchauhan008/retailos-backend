import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import z from 'zod';

export const ValidationSchema = {
  create: {
    body: z.object({
      name: z.string().trim().min(1).max(255),
      code: z.string().trim().max(64).optional(),
      phone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      address_line1: z.string().optional().nullable(),
      city: z.string().optional().nullable(),
      state: z.string().optional().nullable(),
      pincode: z.string().optional().nullable(),
    }),
  },
  update: {
    body: z.object({
      name: z.string().trim().min(1).max(255).optional(),
      phone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      address_line1: z.string().optional().nullable(),
      city: z.string().optional().nullable(),
      state: z.string().optional().nullable(),
      pincode: z.string().optional().nullable(),
      is_active: z.boolean().optional(),
    }),
  },
};

export async function listBranches(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT * FROM branches WHERE tenant_id = $1 ORDER BY is_default DESC, name`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createBranch(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.create.body>;
  const row = await db.queryOne(
    `INSERT INTO branches (tenant_id, name, code, phone, email, address_line1, city, state, pincode)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
    [
      req.user!.tenant_id,
      body.name,
      body.code ?? null,
      body.phone ?? null,
      body.email ?? null,
      body.address_line1 ?? null,
      body.city ?? null,
      body.state ?? null,
      body.pincode ?? null,
    ],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function updateBranch(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.update.body>;
  const row = await db.queryOne(
    `UPDATE branches SET
       name = COALESCE($3, name),
       phone = COALESCE($4, phone),
       email = COALESCE($5, email),
       address_line1 = COALESCE($6, address_line1),
       city = COALESCE($7, city),
       state = COALESCE($8, state),
       pincode = COALESCE($9, pincode),
       is_active = COALESCE($10, is_active),
       updated_at = now()
     WHERE id = $1 AND tenant_id = $2
     RETURNING *`,
    [
      req.params.id,
      req.user!.tenant_id,
      body.name ?? null,
      body.phone ?? null,
      body.email ?? null,
      body.address_line1 ?? null,
      body.city ?? null,
      body.state ?? null,
      body.pincode ?? null,
      body.is_active ?? null,
    ],
  );
  if (!row) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Branch not found' });
  return res.status(STATUS_CODES.OK).json({ data: row });
}

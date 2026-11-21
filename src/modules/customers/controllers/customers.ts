import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import z from 'zod';

export const ValidationSchema = {
  create: {
    body: z.object({
      name: z.string().trim().min(1),
      phone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      gstin: z.string().optional().nullable(),
      address: z.string().optional().nullable(),
      credit_limit: z.number().nonnegative().optional(),
    }),
  },
  update: {
    body: z.object({
      name: z.string().trim().min(1).optional(),
      phone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      gstin: z.string().optional().nullable(),
      address: z.string().optional().nullable(),
      credit_limit: z.number().nonnegative().optional(),
      is_active: z.boolean().optional(),
    }),
  },
};

export async function listCustomers(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const q = String(req.query.q || '').trim();
  const rows = await db.queryAll(
    `SELECT * FROM customers
     WHERE tenant_id = $1
       AND ($2 = '' OR name ILIKE '%' || $2 || '%' OR phone ILIKE '%' || $2 || '%')
     ORDER BY name`,
    [req.user!.tenant_id, q],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createCustomer(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.create.body>;
  const row = await db.queryOne(
    `INSERT INTO customers (tenant_id, name, phone, email, gstin, address, credit_limit)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [
      req.user!.tenant_id,
      body.name,
      body.phone ?? null,
      body.email ?? null,
      body.gstin ?? null,
      body.address ?? null,
      body.credit_limit ?? 0,
    ],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function updateCustomer(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.update.body>;
  const row = await db.queryOne(
    `UPDATE customers SET
       name = COALESCE($3, name),
       phone = COALESCE($4, phone),
       email = COALESCE($5, email),
       gstin = COALESCE($6, gstin),
       address = COALESCE($7, address),
       credit_limit = COALESCE($8, credit_limit),
       is_active = COALESCE($9, is_active)
     WHERE id = $1 AND tenant_id = $2
     RETURNING *`,
    [
      req.params.id,
      req.user!.tenant_id,
      body.name ?? null,
      body.phone ?? null,
      body.email ?? null,
      body.gstin ?? null,
      body.address ?? null,
      body.credit_limit ?? null,
      body.is_active ?? null,
    ],
  );
  if (!row) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Customer not found' });
  return res.status(STATUS_CODES.OK).json({ data: row });
}

export async function customerHistory(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT id, invoice_number, invoice_date, grand_total, amount_paid, amount_due, status
     FROM sales_invoices
     WHERE tenant_id = $1 AND customer_id = $2
     ORDER BY invoice_date DESC
     LIMIT 100`,
    [req.user!.tenant_id, req.params.id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

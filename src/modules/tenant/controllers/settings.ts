import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import z from 'zod';

export const ValidationSchema = {
  upsert: {
    body: z.object({
      settings: z.record(z.string(), z.any()),
    }),
  },
};

export async function getSettings(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll<{ key: string; value: unknown }>(
    `SELECT key, value FROM tenant_settings WHERE tenant_id = $1`,
    [req.user!.tenant_id],
  );
  const settings = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return res.status(STATUS_CODES.OK).json({ data: settings });
}

export async function upsertSettings(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const { settings } = req.body as z.infer<typeof ValidationSchema.upsert.body>;
  for (const [key, value] of Object.entries(settings)) {
    await db.query(
      `INSERT INTO tenant_settings (tenant_id, key, value)
       VALUES ($1, $2, $3::jsonb)
       ON CONFLICT (tenant_id, key) DO UPDATE SET value = EXCLUDED.value`,
      [req.user!.tenant_id, key, JSON.stringify(value)],
    );
  }
  return getSettings(req, res, next, db);
}

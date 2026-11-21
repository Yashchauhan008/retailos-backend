import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';

export async function listPermissions(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(`SELECT * FROM permissions ORDER BY module, key`);
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

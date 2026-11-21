import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { revokeRefreshToken } from '@/shared/services/token.service.js';
import z from 'zod';

export const ValidationSchema = {
  body: z.object({
    refresh_token: z.string().min(10),
  }),
};

export async function Controller(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const { refresh_token } = req.body as z.infer<typeof ValidationSchema.body>;
  await revokeRefreshToken(db, refresh_token);
  return res.status(STATUS_CODES.OK).json({ message: 'Logged out' });
}

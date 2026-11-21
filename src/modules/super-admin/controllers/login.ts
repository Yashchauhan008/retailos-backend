import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import bcrypt from 'bcryptjs';
import z from 'zod';
import { issueSuperAdminTokens } from '@/shared/services/token.service.js';

export const ValidationSchema = {
  body: z.object({
    email: z.email().trim().toLowerCase(),
    password: z.string().min(5),
  }),
};

export async function loginSuperAdmin(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const { email, password } = req.body as z.infer<typeof ValidationSchema.body>;
  const admin = await db.queryOne<{
    id: string;
    name: string;
    email: string;
    password_hash: string;
    status: string;
  }>('SELECT * FROM super_admins WHERE email = $1', [email]);

  if (!admin || admin.status !== 'active') {
    return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Invalid credentials' });
  }

  const ok = await bcrypt.compare(password, admin.password_hash);
  if (!ok) {
    return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Invalid credentials' });
  }

  const tokens = await issueSuperAdminTokens(db, admin.id);
  return res.status(STATUS_CODES.OK).json({
    access_token: tokens.accessToken,
    refresh_token: tokens.refreshToken,
    admin: { id: admin.id, name: admin.name, email: admin.email },
  });
}

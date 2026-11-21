import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { TOKEN_TYPES } from '../auth.constant.js';
import z from 'zod';
import bcrypt from 'bcryptjs';
import { issueUserTokens } from '@/shared/services/token.service.js';
import { applyTenantRls } from '@/shared/middlewares/tenant-context.js';

export const ValidationSchema = {
  body: z.object({
    email: z.string().trim().min(1).max(255),
    password: z.string().trim().min(5).max(255),
    tenant_id: z.uuid().optional(),
  }),
};

export async function Controller(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const { email, password, tenant_id } = req.body as z.infer<typeof ValidationSchema.body>;

  const user = await db.queryOne<{
    id: string;
    name: string;
    email: string;
    password_hash: string;
    status: string;
  }>('SELECT * FROM users WHERE email = $1', [email.toLowerCase()]);

  if (!user) {
    return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Invalid email or password' });
  }

  if (user.status !== 'active') {
    return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'User account is not active' });
  }

  const isPasswordValid = await bcrypt.compare(password, user.password_hash);
  if (!isPasswordValid) {
    return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Invalid email or password' });
  }

  await applyTenantRls(db, { isSuperAdmin: true });

  let membership = await db.queryOne<{
    id: string;
    tenant_id: string;
    role_id: string;
    branch_id: string | null;
    tenant_status: string;
    tenant_name: string;
    onboarding_completed: boolean;
    onboarding_step: string;
  }>(
    `SELECT tu.id, tu.tenant_id, tu.role_id, tu.branch_id,
            t.status AS tenant_status, t.name AS tenant_name,
            t.onboarding_completed, t.onboarding_step
     FROM tenant_users tu
     JOIN tenants t ON t.id = tu.tenant_id
     WHERE tu.user_id = $1 AND tu.status = 'active'
       AND ($2::uuid IS NULL OR tu.tenant_id = $2)
     ORDER BY tu.created_at ASC
     LIMIT 1`,
    [user.id, tenant_id ?? null],
  );

  if (!membership) {
    return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'No active tenant membership' });
  }

  if (membership.tenant_status !== 'active') {
    return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'Business account is suspended' });
  }

  const tokens = await issueUserTokens(db, {
    user_id: user.id,
    tenant_id: membership.tenant_id,
    tenant_user_id: membership.id,
    role_id: membership.role_id,
    branch_id: membership.branch_id,
  });

  await db.query(`UPDATE users SET last_login_at = now() WHERE id = $1`, [user.id]);

  return res.status(STATUS_CODES.OK).json({
    access_token: tokens.accessToken,
    refresh_token: tokens.refreshToken,
    token: tokens.accessToken,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
    },
    tenant: {
      id: membership.tenant_id,
      name: membership.tenant_name,
      onboarding_completed: membership.onboarding_completed,
      onboarding_step: membership.onboarding_step,
    },
    branch_id: membership.branch_id,
    role_id: membership.role_id,
    token_type: TOKEN_TYPES.USER_ACCESS_TOKEN,
  });
}

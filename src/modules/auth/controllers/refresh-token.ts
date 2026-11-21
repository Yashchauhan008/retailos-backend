import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { decodeJWTToken } from '@/shared/utilities/token.js';
import { TOKEN_TYPES } from '../auth.constant.js';
import {
  findValidRefreshToken,
  issueSuperAdminTokens,
  issueUserTokens,
  revokeRefreshToken,
} from '@/shared/services/token.service.js';
import { applyTenantRls } from '@/shared/middlewares/tenant-context.js';
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
  const payload = await decodeJWTToken<{
    type: string;
    user_id?: string;
    tenant_id?: string;
    super_admin_id?: string;
  }>(refresh_token);

  if (!payload) {
    return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Invalid refresh token' });
  }

  const stored = await findValidRefreshToken(db, refresh_token);
  if (!stored) {
    return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Refresh token revoked or expired' });
  }

  await revokeRefreshToken(db, refresh_token);

  if (payload.type === TOKEN_TYPES.USER_REFRESH_TOKEN && payload.user_id && payload.tenant_id) {
    await applyTenantRls(db, { isSuperAdmin: true });
    const membership = await db.queryOne<{
      id: string;
      role_id: string;
      branch_id: string | null;
    }>(
      `SELECT id, role_id, branch_id FROM tenant_users
       WHERE user_id = $1 AND tenant_id = $2 AND status = 'active'`,
      [payload.user_id, payload.tenant_id],
    );
    if (!membership) {
      return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Membership not found' });
    }

    const tokens = await issueUserTokens(db, {
      user_id: payload.user_id,
      tenant_id: payload.tenant_id,
      tenant_user_id: membership.id,
      role_id: membership.role_id,
      branch_id: membership.branch_id,
    });

    return res.status(STATUS_CODES.OK).json({
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
    });
  }

  if (payload.type === TOKEN_TYPES.SUPER_ADMIN_REFRESH_TOKEN && payload.super_admin_id) {
    const tokens = await issueSuperAdminTokens(db, payload.super_admin_id);
    return res.status(STATUS_CODES.OK).json({
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
    });
  }

  return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Invalid refresh token type' });
}

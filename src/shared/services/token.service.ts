import crypto from 'node:crypto';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { createJWTToken } from '@/shared/utilities/token.js';
import { TOKEN_TYPES } from '@/modules/auth/auth.constant.js';

function hashToken(token: string) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export async function issueUserTokens(
  db: DatabaseClient,
  payload: {
    user_id: string;
    tenant_id: string;
    tenant_user_id: string;
    role_id: string;
    branch_id?: string | null;
  },
) {
  const accessToken = await createJWTToken(
    {
      type: TOKEN_TYPES.USER_ACCESS_TOKEN,
      ...payload,
    },
    '15m',
  );

  const refreshToken = await createJWTToken(
    {
      type: TOKEN_TYPES.USER_REFRESH_TOKEN,
      user_id: payload.user_id,
      tenant_id: payload.tenant_id,
    },
    '30d',
  );

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30);

  await db.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [payload.user_id, hashToken(refreshToken), expiresAt.toISOString()],
  );

  return { accessToken, refreshToken };
}

export async function issueSuperAdminTokens(db: DatabaseClient, superAdminId: string) {
  const accessToken = await createJWTToken(
    {
      type: TOKEN_TYPES.SUPER_ADMIN_ACCESS_TOKEN,
      super_admin_id: superAdminId,
    },
    '15m',
  );

  const refreshToken = await createJWTToken(
    {
      type: TOKEN_TYPES.SUPER_ADMIN_REFRESH_TOKEN,
      super_admin_id: superAdminId,
    },
    '30d',
  );

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30);

  await db.query(
    `INSERT INTO refresh_tokens (super_admin_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [superAdminId, hashToken(refreshToken), expiresAt.toISOString()],
  );

  return { accessToken, refreshToken };
}

export async function revokeRefreshToken(db: DatabaseClient, refreshToken: string) {
  await db.query(
    `UPDATE refresh_tokens SET revoked_at = now()
     WHERE token_hash = $1 AND revoked_at IS NULL`,
    [hashToken(refreshToken)],
  );
}

export async function findValidRefreshToken(db: DatabaseClient, refreshToken: string) {
  return db.queryOne<{
    id: string;
    user_id: string | null;
    super_admin_id: string | null;
  }>(
    `SELECT id, user_id, super_admin_id FROM refresh_tokens
     WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now()`,
    [hashToken(refreshToken)],
  );
}

export { hashToken };

import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import bcrypt from 'bcryptjs';
import z from 'zod';
import { createTenantForOwner } from '@/shared/services/tenant-bootstrap.service.js';
import { issueUserTokens } from '@/shared/services/token.service.js';

export const ValidationSchema = {
  body: z.object({
    name: z.string().trim().min(1).max(255),
    email: z.email().trim().toLowerCase(),
    password: z.string().trim().min(6).max(255),
    business_name: z.string().trim().min(1).max(255),
    industry_id: z.uuid(),
    phone: z.string().trim().max(32).optional(),
  }),
};

export async function Controller(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.body>;

  const industry = await db.queryOne('SELECT id FROM industries WHERE id = $1 AND is_active = true', [
    body.industry_id,
  ]);
  if (!industry) {
    return res.status(STATUS_CODES.BAD_REQUEST).json({ message: 'Invalid industry' });
  }

  const existing = await db.queryOne('SELECT id FROM users WHERE email = $1', [body.email]);
  if (existing) {
    return res.status(STATUS_CODES.CONFLICT).json({ message: 'Email already registered' });
  }

  await db.begin();
  try {
    const passwordHash = await bcrypt.hash(body.password, 10);
    const user = await db.queryOne<{ id: string; name: string; email: string }>(
      `INSERT INTO users (name, email, password_hash, phone, status, email_verified)
       VALUES ($1, $2, $3, $4, 'active', true)
       RETURNING id, name, email`,
      [body.name, body.email, passwordHash, body.phone ?? null],
    );
    if (!user) throw new Error('Failed to create user');

    const tenantCtx = await createTenantForOwner(db, {
      userId: user.id,
      businessName: body.business_name,
      industryId: body.industry_id,
      email: body.email,
    });

    const tokens = await issueUserTokens(db, {
      user_id: user.id,
      tenant_id: tenantCtx.tenant_id,
      tenant_user_id: tenantCtx.tenant_user_id!,
      role_id: tenantCtx.role_id,
      branch_id: tenantCtx.branch_id,
    });

    await db.query(
      `INSERT INTO audit_logs (tenant_id, actor_user_id, action, entity_type, entity_id, metadata)
       VALUES ($1, $2, 'tenant.registered', 'tenant', $1, $3::jsonb)`,
      [tenantCtx.tenant_id, user.id, JSON.stringify({ business_name: body.business_name })],
    );

    await db.commit();

    return res.status(STATUS_CODES.CREATED).json({
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
      },
      tenant_id: tenantCtx.tenant_id,
      branch_id: tenantCtx.branch_id,
      onboarding_step: 'business_profile',
      onboarding_completed: false,
    });
  } catch (error) {
    await db.rollback();
    throw error;
  }
}

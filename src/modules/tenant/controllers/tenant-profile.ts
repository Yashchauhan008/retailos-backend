import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { syncNewPermissionsToTenantOwners } from '@/shared/services/ledger.service.js';
import z from 'zod';

export const ValidationSchema = {
  patch: {
    body: z.object({
      name: z.string().trim().min(1).max(255).optional(),
      gstin: z.string().trim().max(32).optional().nullable(),
      phone: z.string().trim().max(32).optional().nullable(),
      email: z.string().trim().email().optional().nullable(),
      address_line1: z.string().optional().nullable(),
      address_line2: z.string().optional().nullable(),
      city: z.string().optional().nullable(),
      state: z.string().optional().nullable(),
      pincode: z.string().optional().nullable(),
      onboarding_step: z.string().optional(),
    }),
  },
};

export async function getMe(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  await syncNewPermissionsToTenantOwners(db, req.user!.tenant_id!);
  const tenant = await db.queryOne(
    `SELECT t.*, i.code AS industry_code, i.name AS industry_name,
            s.status AS subscription_status, s.trial_ends_at, s.current_period_end,
            p.code AS plan_code, p.name AS plan_name
     FROM tenants t
     LEFT JOIN industries i ON i.id = t.industry_id
     LEFT JOIN tenant_subscriptions s ON s.tenant_id = t.id
     LEFT JOIN plans p ON p.id = s.plan_id
     WHERE t.id = $1`,
    [req.user!.tenant_id],
  );

  const features = await db.queryAll(
    `SELECT feature_key, enabled FROM plan_features
     WHERE plan_id = (SELECT plan_id FROM tenant_subscriptions WHERE tenant_id = $1)`,
    [req.user!.tenant_id],
  );
  const limits = await db.queryAll(
    `SELECT limit_key, limit_value FROM plan_limits
     WHERE plan_id = (SELECT plan_id FROM tenant_subscriptions WHERE tenant_id = $1)`,
    [req.user!.tenant_id],
  );

  const permissions = await db.queryAll<{ key: string }>(
    `SELECT p.key FROM tenant_role_permissions trp
     JOIN permissions p ON p.id = trp.permission_id
     WHERE trp.tenant_role_id = $1`,
    [req.user!.role_id],
  );

  return res.status(STATUS_CODES.OK).json({
    data: tenant,
    entitlements: { features, limits },
    permissions: permissions.map((p) => p.key),
  });
}

export async function patchMe(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  const body = req.body as z.infer<typeof ValidationSchema.patch.body>;
  const tenant = await db.queryOne(
    `UPDATE tenants SET
       name = COALESCE($2, name),
       gstin = COALESCE($3, gstin),
       phone = COALESCE($4, phone),
       email = COALESCE($5, email),
       address_line1 = COALESCE($6, address_line1),
       address_line2 = COALESCE($7, address_line2),
       city = COALESCE($8, city),
       state = COALESCE($9, state),
       pincode = COALESCE($10, pincode),
       onboarding_step = COALESCE($11, onboarding_step),
       updated_at = now()
     WHERE id = $1
     RETURNING *`,
    [
      req.user!.tenant_id,
      body.name ?? null,
      body.gstin ?? null,
      body.phone ?? null,
      body.email ?? null,
      body.address_line1 ?? null,
      body.address_line2 ?? null,
      body.city ?? null,
      body.state ?? null,
      body.pincode ?? null,
      body.onboarding_step ?? null,
    ],
  );
  return res.status(STATUS_CODES.OK).json({ data: tenant });
}

export async function completeOnboarding(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const tenant = await db.queryOne(
    `UPDATE tenants SET onboarding_completed = true, onboarding_step = 'done', updated_at = now()
     WHERE id = $1 RETURNING *`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: tenant });
}

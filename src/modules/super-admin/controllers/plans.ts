import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyTenantRls } from '@/shared/middlewares/tenant-context.js';
import z from 'zod';

export const ValidationSchema = {
  upsert: {
    body: z.object({
      code: z.string().trim().min(1).max(64).optional(),
      name: z.string().trim().min(1).max(255),
      description: z.string().optional().nullable(),
      price_monthly: z.number().nonnegative().optional(),
      price_yearly: z.number().nonnegative().optional(),
      trial_days: z.number().int().nonnegative().optional(),
      is_active: z.boolean().optional(),
      features: z
        .array(z.object({ feature_key: z.string(), enabled: z.boolean() }))
        .optional(),
      limits: z
        .array(z.object({ limit_key: z.string(), limit_value: z.number().int() }))
        .optional(),
    }),
  },
};

export async function listPlans(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await applyTenantRls(db, { isSuperAdmin: true });
  const plans = await db.queryAll(`SELECT * FROM plans ORDER BY sort_order, name`);
  const features = await db.queryAll(`SELECT * FROM plan_features`);
  const limits = await db.queryAll(`SELECT * FROM plan_limits`);
  const data = plans.map((p) => ({
    ...p,
    features: features.filter((f) => f.plan_id === p.id),
    limits: limits.filter((l) => l.plan_id === p.id),
  }));
  return res.status(STATUS_CODES.OK).json({ data });
}

export async function upsertPlan(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await applyTenantRls(db, { isSuperAdmin: true });
  const body = req.body as z.infer<typeof ValidationSchema.upsert.body>;
  const id = req.params.id;

  await db.begin();
  try {
    let plan;
    if (id) {
      plan = await db.queryOne(
        `UPDATE plans SET
           name = $2,
           description = COALESCE($3, description),
           price_monthly = COALESCE($4, price_monthly),
           price_yearly = COALESCE($5, price_yearly),
           trial_days = COALESCE($6, trial_days),
           is_active = COALESCE($7, is_active)
         WHERE id = $1 RETURNING *`,
        [
          id,
          body.name,
          body.description ?? null,
          body.price_monthly ?? null,
          body.price_yearly ?? null,
          body.trial_days ?? null,
          body.is_active ?? null,
        ],
      );
    } else {
      plan = await db.queryOne(
        `INSERT INTO plans (code, name, description, price_monthly, price_yearly, trial_days, is_active)
         VALUES ($1,$2,$3,$4,$5,$6,COALESCE($7,true)) RETURNING *`,
        [
          body.code || body.name.toLowerCase().replace(/\s+/g, '_'),
          body.name,
          body.description ?? null,
          body.price_monthly ?? 0,
          body.price_yearly ?? 0,
          body.trial_days ?? 0,
          body.is_active ?? true,
        ],
      );
    }

    if (!plan) throw new Error('Plan save failed');

    if (body.features) {
      await db.query(`DELETE FROM plan_features WHERE plan_id = $1`, [plan.id]);
      for (const f of body.features) {
        await db.query(
          `INSERT INTO plan_features (plan_id, feature_key, enabled) VALUES ($1,$2,$3)`,
          [plan.id, f.feature_key, f.enabled],
        );
      }
    }
    if (body.limits) {
      await db.query(`DELETE FROM plan_limits WHERE plan_id = $1`, [plan.id]);
      for (const l of body.limits) {
        await db.query(
          `INSERT INTO plan_limits (plan_id, limit_key, limit_value) VALUES ($1,$2,$3)`,
          [plan.id, l.limit_key, l.limit_value],
        );
      }
    }

    await db.commit();
    return res.status(STATUS_CODES.OK).json({ data: plan });
  } catch (error) {
    await db.rollback();
    throw error;
  }
}

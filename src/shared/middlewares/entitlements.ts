import type { NextFunction, Request, Response } from 'express';
import Database from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { applyTenantRls } from './tenant-context.js';

function isSubscriptionActive(sub: {
  status: string;
  trial_ends_at: string | null;
  current_period_end: string | null;
}) {
  if (['canceled', 'expired', 'suspended'].includes(sub.status)) return false;
  if (sub.status === 'trialing' && sub.trial_ends_at && new Date(sub.trial_ends_at) < new Date()) {
    return false;
  }
  if (
    sub.status !== 'trialing' &&
    sub.current_period_end &&
    new Date(sub.current_period_end) < new Date()
  ) {
    return false;
  }
  return true;
}

export function requireFeature(featureKey: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (req.superAdmin?.id) return next();
    const tenantId = req.user?.tenant_id;
    if (!tenantId) {
      return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'Tenant context required' });
    }

    const db = await Database.getConnection();
    try {
      await applyTenantRls(db, { tenantId });
      const sub = await db.queryOne<{
        plan_id: string;
        status: string;
        trial_ends_at: string | null;
        current_period_end: string | null;
      }>(
        `SELECT plan_id, status, trial_ends_at, current_period_end
         FROM tenant_subscriptions WHERE tenant_id = $1`,
        [tenantId],
      );
      if (!sub || !isSubscriptionActive(sub)) {
        return res.status(STATUS_CODES.PAYMENT_REQUIRED).json({
          message: 'Subscription inactive or expired',
          code: 'subscription_inactive',
        });
      }

      const feature = await db.queryOne<{ enabled: boolean }>(
        `SELECT enabled FROM plan_features WHERE plan_id = $1 AND feature_key = $2`,
        [sub.plan_id, featureKey],
      );

      if (!feature?.enabled) {
        return res.status(STATUS_CODES.FORBIDDEN).json({
          message: `Feature '${featureKey}' is not available on your plan`,
          code: 'feature_not_entitled',
          feature_key: featureKey,
        });
      }
      return next();
    } catch (error) {
      return next(error);
    } finally {
      db.release();
    }
  };
}

export function requireLimit(limitKey: string, countQuery: (tenantId: string) => Promise<number>) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (req.superAdmin?.id) return next();
    const tenantId = req.user?.tenant_id;
    if (!tenantId) {
      return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'Tenant context required' });
    }

    const db = await Database.getConnection();
    try {
      await applyTenantRls(db, { tenantId });
      const sub = await db.queryOne<{ plan_id: string }>(
        `SELECT plan_id FROM tenant_subscriptions WHERE tenant_id = $1`,
        [tenantId],
      );
      if (!sub) {
        return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'No subscription found' });
      }

      const limit = await db.queryOne<{ limit_value: number }>(
        `SELECT limit_value FROM plan_limits WHERE plan_id = $1 AND limit_key = $2`,
        [sub.plan_id, limitKey],
      );
      if (!limit) return next();

      const current = await countQuery(tenantId);
      if (current >= limit.limit_value) {
        return res.status(STATUS_CODES.FORBIDDEN).json({
          message: `Limit reached for ${limitKey}`,
          code: 'limit_exceeded',
          limit_key: limitKey,
          limit: limit.limit_value,
          current,
        });
      }
      return next();
    } catch (error) {
      return next(error);
    } finally {
      db.release();
    }
  };
}

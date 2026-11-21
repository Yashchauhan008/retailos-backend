import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';

export async function listIndustries(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const industries = await db.queryAll(
    `SELECT i.id, i.code, i.name, i.description,
            COALESCE(json_agg(json_build_object(
              'feature_key', f.feature_key,
              'enabled', f.enabled,
              'config', f.config
            )) FILTER (WHERE f.id IS NOT NULL), '[]') AS features
     FROM industries i
     LEFT JOIN industry_feature_flags f ON f.industry_id = i.id
     WHERE i.is_active = true
     GROUP BY i.id
     ORDER BY i.name`,
  );
  return res.status(STATUS_CODES.OK).json({ data: industries });
}

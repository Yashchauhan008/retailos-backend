import type { NextFunction, Request, Response } from 'express';
import withDatabase from '@/shared/utilities/with-database.js';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { withTenantContext } from '@/shared/middlewares/tenant-context.js';

export default function withTenantDb(
  controller: (
    req: Request,
    res: Response,
    next: NextFunction,
    db: DatabaseClient,
  ) => Promise<unknown>,
) {
  return withDatabase(withTenantContext(controller));
}

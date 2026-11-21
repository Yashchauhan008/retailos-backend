import type { NextFunction, Request, Response } from 'express';
import Database from '@/shared/helpers/database.helper.js';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';

function WithDatabase(
  controller: (
    req: Request,
    res: Response,
    next: NextFunction,
    db: DatabaseClient,
  ) => Promise<unknown>,
) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const db = await Database.getConnection();
    try {
      await controller(req, res, next, db);
    } catch (error) {
      next(error);
    } finally {
      try {
        await db.query(`SELECT set_config('app.tenant_id', '', false)`);
        await db.query(`SELECT set_config('app.is_super_admin', 'false', false)`);
      } catch {
        // ignore reset errors
      }
      db.release();
    }
  };
}

export default WithDatabase;

import type { NextFunction, Request, Response } from 'express';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import { decodeJWTToken } from '@/shared/utilities/token.js';
import { TOKEN_TYPES } from '@/modules/auth/auth.constant.js';

export type AuthPayload = {
  type: string;
  user_id?: string;
  super_admin_id?: string;
  tenant_id?: string;
  tenant_user_id?: string;
  role_id?: string;
  branch_id?: string;
};

export async function authenticate(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Unauthorized' });
  }

  const token = header.slice(7);
  const payload = await decodeJWTToken<AuthPayload>(token);
  if (!payload) {
    return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Invalid or expired token' });
  }

  if (payload.type === TOKEN_TYPES.USER_ACCESS_TOKEN && payload.user_id) {
    req.user = {
      id: payload.user_id,
      tenant_id: payload.tenant_id,
      tenant_user_id: payload.tenant_user_id,
      role_id: payload.role_id,
      branch_id: payload.branch_id,
    };
    return next();
  }

  if (payload.type === TOKEN_TYPES.SUPER_ADMIN_ACCESS_TOKEN && payload.super_admin_id) {
    req.superAdmin = { id: payload.super_admin_id };
    return next();
  }

  return res.status(STATUS_CODES.UNAUTHORIZED).json({ message: 'Invalid token type' });
}

export function requireTenant(req: Request, res: Response, next: NextFunction) {
  if (!req.user?.tenant_id) {
    return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'Tenant context required' });
  }
  return next();
}

export function requireSuperAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.superAdmin?.id) {
    return res.status(STATUS_CODES.FORBIDDEN).json({ message: 'Super admin access required' });
  }
  return next();
}

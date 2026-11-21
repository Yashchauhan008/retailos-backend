import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import {
  listUsers,
  inviteUser,
  updateUser,
  ValidationSchema as usersSchema,
} from './controllers/users.js';
import {
  listRoles,
  updateRolePermissions,
  ValidationSchema as rolesSchema,
} from './controllers/roles.js';
import { listPermissions } from './controllers/permissions.js';

const router = Router();
router.use(authenticate, requireTenant);

router.get('/permissions', requirePermission('roles.manage', 'users.manage'), withTenantDb(listPermissions));

router.get('/roles', requirePermission('roles.manage', 'users.manage'), withTenantDb(listRoles));
router.put(
  '/roles/:id/permissions',
  requirePermission('roles.manage'),
  validate(rolesSchema.updatePermissions),
  withTenantDb(updateRolePermissions),
);

router.get('/', requirePermission('users.manage'), withTenantDb(listUsers));
router.post('/', requirePermission('users.manage'), validate(usersSchema.invite), withTenantDb(inviteUser));
router.patch(
  '/:id',
  requirePermission('users.manage'),
  validate(usersSchema.update),
  withTenantDb(updateUser),
);

export default router;

import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import { requireFeature } from '@/shared/middlewares/entitlements.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import * as ctrl from './controllers/customers.js';

const router = Router();
router.use(authenticate, requireTenant, requireFeature('customers'));

router.get('/', requirePermission('customers.read'), withTenantDb(ctrl.listCustomers));
router.post(
  '/',
  requirePermission('customers.write'),
  validate(ctrl.ValidationSchema.create),
  withTenantDb(ctrl.createCustomer),
);
router.patch(
  '/:id',
  requirePermission('customers.write'),
  validate(ctrl.ValidationSchema.update),
  withTenantDb(ctrl.updateCustomer),
);
router.get('/:id/history', requirePermission('customers.read', 'sales.read'), withTenantDb(ctrl.customerHistory));

export default router;

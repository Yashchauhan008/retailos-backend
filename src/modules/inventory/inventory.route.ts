import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import { requireFeature } from '@/shared/middlewares/entitlements.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import * as ctrl from './controllers/inventory.js';

const router = Router();
router.use(authenticate, requireTenant, requireFeature('inventory'));

router.get('/stock', requirePermission('inventory.read'), withTenantDb(ctrl.listStock));
router.post(
  '/adjustments',
  requirePermission('inventory.write'),
  validate(ctrl.ValidationSchema.adjust),
  withTenantDb(ctrl.adjustStock),
);
router.get('/movements', requirePermission('inventory.read'), withTenantDb(ctrl.listMovements));

export default router;

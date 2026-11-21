import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import { requireFeature } from '@/shared/middlewares/entitlements.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import * as ctrl from './controllers/sales.js';
import * as returnsCtrl from './controllers/returns.js';

const router = Router();
router.use(authenticate, requireTenant);

router.post(
  '/pos/checkout',
  requireFeature('pos'),
  requirePermission('pos.sell'),
  validate(ctrl.ValidationSchema.checkout),
  withTenantDb(ctrl.checkout),
);
router.get('/invoices', requirePermission('sales.read'), withTenantDb(ctrl.listInvoices));
router.get('/invoices/:id', requirePermission('sales.read', 'pos.sell'), withTenantDb(ctrl.getInvoice));

router.get('/returns', requirePermission('sales.read', 'returns.write'), withTenantDb(returnsCtrl.listReturns));
router.post(
  '/returns',
  requirePermission('returns.write'),
  validate(returnsCtrl.ValidationSchema.createReturn),
  withTenantDb(returnsCtrl.createReturn),
);

router.get('/held-carts', requirePermission('pos.sell'), withTenantDb(ctrl.listHeldCarts));
router.post(
  '/held-carts',
  requirePermission('pos.sell'),
  validate(ctrl.ValidationSchema.heldCart),
  withTenantDb(ctrl.saveHeldCart),
);
router.delete('/held-carts/:id', requirePermission('pos.sell'), withTenantDb(ctrl.deleteHeldCart));

export default router;

import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import { requireFeature } from '@/shared/middlewares/entitlements.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import * as ctrl from './controllers/purchasing.js';

const router = Router();
router.use(authenticate, requireTenant, requireFeature('purchases'));

router.get('/suppliers', requirePermission('suppliers.read'), withTenantDb(ctrl.listSuppliers));
router.post(
  '/suppliers',
  requirePermission('suppliers.write'),
  validate(ctrl.ValidationSchema.supplier),
  withTenantDb(ctrl.createSupplier),
);

router.get('/purchase-orders', requirePermission('purchases.read'), withTenantDb(ctrl.listPOs));
router.post(
  '/purchase-orders',
  requirePermission('purchases.write'),
  validate(ctrl.ValidationSchema.po),
  withTenantDb(ctrl.createPO),
);
router.post(
  '/purchase-orders/:id/receive',
  requirePermission('purchases.write'),
  validate(ctrl.ValidationSchema.receive),
  withTenantDb(ctrl.receivePO),
);

router.get('/grns', requirePermission('purchases.read'), withTenantDb(ctrl.listGRNs));
router.get('/purchase-invoices', requirePermission('purchases.read'), withTenantDb(ctrl.listPurchaseInvoices));
router.post(
  '/purchase-returns',
  requirePermission('purchases.write'),
  validate(ctrl.ValidationSchema.purchaseReturn),
  withTenantDb(ctrl.createPurchaseReturn),
);

export default router;

import { Router } from 'express';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import { requireFeature } from '@/shared/middlewares/entitlements.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import * as ctrl from './controllers/reports.js';

const router = Router();
router.use(authenticate, requireTenant);

router.get('/sales', requirePermission('reports.read', 'sales.read'), withTenantDb(ctrl.salesReport));
router.get('/purchases', requirePermission('reports.read', 'purchases.read'), withTenantDb(ctrl.purchaseReport));
router.get(
  '/inventory-valuation',
  requirePermission('reports.read', 'inventory.read'),
  withTenantDb(ctrl.inventoryValuation),
);
router.get(
  '/profit-loss',
  requireFeature('reports_finance'),
  requirePermission('reports.finance', 'finance.read'),
  withTenantDb(ctrl.profitAndLoss),
);
router.get(
  '/gst',
  requireFeature('reports_finance'),
  requirePermission('reports.finance'),
  withTenantDb(ctrl.gstReport),
);
router.get(
  '/daily-closing',
  requirePermission('reports.finance', 'finance.read'),
  withTenantDb(ctrl.dailyClosingReport),
);

export default router;

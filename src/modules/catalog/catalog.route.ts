import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import { requireFeature } from '@/shared/middlewares/entitlements.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import * as ctrl from './controllers/catalog.js';

const router = Router();
router.use(authenticate, requireTenant, requireFeature('products'));

router.get('/categories', requirePermission('products.read'), withTenantDb(ctrl.listCategories));
router.post(
  '/categories',
  requirePermission('products.write'),
  validate(ctrl.ValidationSchema.category),
  withTenantDb(ctrl.createCategory),
);

router.get('/brands', requirePermission('products.read'), withTenantDb(ctrl.listBrands));
router.post(
  '/brands',
  requirePermission('products.write'),
  validate(ctrl.ValidationSchema.brand),
  withTenantDb(ctrl.createBrand),
);

router.get('/units', requirePermission('products.read'), withTenantDb(ctrl.listUnits));
router.get('/tax-rates', requirePermission('products.read'), withTenantDb(ctrl.listTaxRates));

router.get('/products', requirePermission('products.read'), withTenantDb(ctrl.listProducts));
router.get('/products/:id', requirePermission('products.read'), withTenantDb(ctrl.getProduct));
router.post(
  '/products',
  requirePermission('products.write'),
  validate(ctrl.ValidationSchema.product),
  withTenantDb(ctrl.createProduct),
);
router.patch(
  '/products/:id',
  requirePermission('products.write'),
  validate(ctrl.ValidationSchema.productUpdate),
  withTenantDb(ctrl.updateProduct),
);

router.get('/search', requirePermission('products.read', 'pos.sell'), withTenantDb(ctrl.searchCatalog));

export default router;

import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import { requireFeature } from '@/shared/middlewares/entitlements.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import * as ctrl from './controllers/advanced.js';

const router = Router();
router.use(authenticate, requireTenant);

// Transfers
router.get('/transfers', requirePermission('transfers.write', 'inventory.read'), withTenantDb(ctrl.listTransfers));
router.post(
  '/transfers',
  requireFeature('stock_transfers'),
  requirePermission('transfers.write'),
  validate(ctrl.ValidationSchema.transfer),
  withTenantDb(ctrl.createTransfer),
);
router.post(
  '/transfers/:id/dispatch',
  requireFeature('stock_transfers'),
  requirePermission('transfers.write'),
  withTenantDb(ctrl.dispatchTransfer),
);
router.post(
  '/transfers/:id/receive',
  requireFeature('stock_transfers'),
  requirePermission('transfers.write'),
  withTenantDb(ctrl.receiveTransfer),
);

// Attendance
router.get('/shifts', requirePermission('attendance.manage', 'users.manage'), withTenantDb(ctrl.listShifts));
router.post(
  '/shifts',
  requireFeature('attendance'),
  requirePermission('attendance.manage'),
  validate(ctrl.ValidationSchema.shift),
  withTenantDb(ctrl.createShift),
);
router.get('/attendance', requirePermission('attendance.manage'), withTenantDb(ctrl.listAttendance));
router.post(
  '/attendance',
  requireFeature('attendance'),
  requirePermission('attendance.manage'),
  validate(ctrl.ValidationSchema.attendance),
  withTenantDb(ctrl.upsertAttendance),
);

// Loyalty & groups
router.get('/customer-groups', requirePermission('customers.read'), withTenantDb(ctrl.listCustomerGroups));
router.post(
  '/customer-groups',
  requirePermission('customers.write'),
  validate(ctrl.ValidationSchema.customerGroup),
  withTenantDb(ctrl.createCustomerGroup),
);
router.get('/loyalty/settings', requirePermission('loyalty.manage', 'customers.read'), withTenantDb(ctrl.getLoyaltySettings));
router.put(
  '/loyalty/settings',
  requireFeature('loyalty'),
  requirePermission('loyalty.manage'),
  validate(ctrl.ValidationSchema.loyaltySettings),
  withTenantDb(ctrl.upsertLoyaltySettings),
);
router.post(
  '/loyalty/adjust',
  requireFeature('loyalty'),
  requirePermission('loyalty.manage'),
  validate(ctrl.ValidationSchema.loyaltyAdjust),
  withTenantDb(ctrl.adjustLoyalty),
);

// Coupons / promotions
router.get('/coupons', requirePermission('promotions.manage', 'pos.sell'), withTenantDb(ctrl.listCoupons));
router.post(
  '/coupons',
  requireFeature('loyalty'),
  requirePermission('promotions.manage'),
  validate(ctrl.ValidationSchema.coupon),
  withTenantDb(ctrl.createCoupon),
);
router.post('/coupons/validate', requirePermission('pos.sell'), validate(ctrl.ValidationSchema.validateCoupon), withTenantDb(ctrl.validateCoupon));
router.get('/promotions', requirePermission('promotions.manage'), withTenantDb(ctrl.listPromotions));
router.post(
  '/promotions',
  requireFeature('loyalty'),
  requirePermission('promotions.manage'),
  validate(ctrl.ValidationSchema.promotion),
  withTenantDb(ctrl.createPromotion),
);

// Batch / serial / warranty / forecast
router.get('/batches', requirePermission('inventory.read'), withTenantDb(ctrl.listBatches));
router.post(
  '/batches',
  requireFeature('batch_expiry'),
  requirePermission('inventory.write'),
  validate(ctrl.ValidationSchema.batch),
  withTenantDb(ctrl.upsertBatch),
);
router.get('/serials', requirePermission('serials.manage', 'inventory.read'), withTenantDb(ctrl.listSerials));
router.post(
  '/serials',
  requireFeature('serial_tracking'),
  requirePermission('serials.manage'),
  validate(ctrl.ValidationSchema.serial),
  withTenantDb(ctrl.createSerial),
);
router.get('/warranties', requirePermission('serials.manage'), withTenantDb(ctrl.listWarranties));
router.post(
  '/warranties',
  requireFeature('serial_tracking'),
  requirePermission('serials.manage'),
  validate(ctrl.ValidationSchema.warranty),
  withTenantDb(ctrl.createWarrantyClaim),
);
router.get('/forecasts', requirePermission('inventory.read'), withTenantDb(ctrl.listForecasts));
router.post('/forecasts/generate', requirePermission('inventory.write'), withTenantDb(ctrl.generateForecasts));

export default router;

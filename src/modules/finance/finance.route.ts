import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import { requireFeature } from '@/shared/middlewares/entitlements.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import * as ctrl from './controllers/finance.js';

const router = Router();
router.use(authenticate, requireTenant, requireFeature('finance'));

router.get('/expenses', requirePermission('finance.read'), withTenantDb(ctrl.listExpenses));
router.post(
  '/expenses',
  requirePermission('finance.write'),
  validate(ctrl.ValidationSchema.expense),
  withTenantDb(ctrl.createExpense),
);
router.get(
  '/expense-categories',
  requirePermission('finance.read'),
  withTenantDb(ctrl.listExpenseCategories),
);
router.post(
  '/expense-categories',
  requirePermission('finance.write'),
  validate(ctrl.ValidationSchema.expenseCategory),
  withTenantDb(ctrl.createExpenseCategory),
);

router.get('/cash-accounts', requirePermission('finance.read'), withTenantDb(ctrl.listCashAccounts));
router.get('/cashbook', requirePermission('finance.read'), withTenantDb(ctrl.cashbook));
router.get('/bankbook', requirePermission('finance.read'), withTenantDb(ctrl.bankbook));

router.post(
  '/customer-payments',
  requirePermission('finance.write'),
  validate(ctrl.ValidationSchema.customerPayment),
  withTenantDb(ctrl.recordCustomerPayment),
);
router.post(
  '/supplier-payments',
  requirePermission('finance.write'),
  validate(ctrl.ValidationSchema.supplierPayment),
  withTenantDb(ctrl.recordSupplierPayment),
);

router.get('/customer-ledger/:customerId', requirePermission('finance.read'), withTenantDb(ctrl.customerLedger));
router.get('/supplier-ledger/:supplierId', requirePermission('finance.read'), withTenantDb(ctrl.supplierLedger));
router.get('/receivables', requirePermission('finance.read'), withTenantDb(ctrl.receivables));
router.get('/payables', requirePermission('finance.read'), withTenantDb(ctrl.payables));

router.post(
  '/daily-closing',
  requirePermission('finance.write'),
  validate(ctrl.ValidationSchema.dailyClosing),
  withTenantDb(ctrl.dailyClosing),
);
router.get('/daily-closing', requirePermission('finance.read'), withTenantDb(ctrl.listDailyClosings));

export default router;

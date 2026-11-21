import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import {
  getMe,
  patchMe,
  completeOnboarding,
  ValidationSchema as tenantSchema,
} from './controllers/tenant-profile.js';
import {
  listBranches,
  createBranch,
  updateBranch,
  ValidationSchema as branchSchema,
} from './controllers/branches.js';
import {
  getSettings,
  upsertSettings,
  ValidationSchema as settingsSchema,
} from './controllers/settings.js';
import { listIndustries } from './controllers/industries.js';
import withDatabase from '@/shared/utilities/with-database.js';

const router = Router();

router.get('/industries', withDatabase(listIndustries));

router.use(authenticate, requireTenant);

router.get('/me', requirePermission('settings.manage', 'dashboard.read'), withTenantDb(getMe));
router.patch(
  '/me',
  requirePermission('settings.manage'),
  validate(tenantSchema.patch),
  withTenantDb(patchMe),
);
router.post(
  '/me/complete-onboarding',
  requirePermission('settings.manage'),
  withTenantDb(completeOnboarding),
);

router.get('/branches', requirePermission('settings.manage', 'dashboard.read'), withTenantDb(listBranches));
router.post(
  '/branches',
  requirePermission('settings.manage'),
  validate(branchSchema.create),
  withTenantDb(createBranch),
);
router.patch(
  '/branches/:id',
  requirePermission('settings.manage'),
  validate(branchSchema.update),
  withTenantDb(updateBranch),
);

router.get('/settings', requirePermission('settings.manage'), withTenantDb(getSettings));
router.put(
  '/settings',
  requirePermission('settings.manage'),
  validate(settingsSchema.upsert),
  withTenantDb(upsertSettings),
);

export default router;

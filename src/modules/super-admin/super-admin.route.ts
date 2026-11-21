import { Router } from 'express';
import validate from '@/shared/middlewares/request-validator.js';
import withDatabase from '@/shared/utilities/with-database.js';
import { authenticate, requireSuperAdmin } from '@/shared/middlewares/authenticate.js';
import {
  loginSuperAdmin,
  ValidationSchema as loginSchema,
} from './controllers/login.js';
import { dashboard } from './controllers/dashboard.js';
import {
  listRetailers,
  updateRetailer,
  ValidationSchema as retailersSchema,
} from './controllers/retailers.js';
import {
  listPlans,
  upsertPlan,
  ValidationSchema as plansSchema,
} from './controllers/plans.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';

const router = Router();

router.post('/auth/login', validate(loginSchema), withDatabase(loginSuperAdmin));

router.use(authenticate, requireSuperAdmin);

router.get('/dashboard', withTenantDb(dashboard));
router.get('/retailers', withTenantDb(listRetailers));
router.patch(
  '/retailers/:id',
  validate(retailersSchema.update),
  withTenantDb(updateRetailer),
);
router.get('/plans', withTenantDb(listPlans));
router.post('/plans', validate(plansSchema.upsert), withTenantDb(upsertPlan));
router.put('/plans/:id', validate(plansSchema.upsert), withTenantDb(upsertPlan));

export default router;

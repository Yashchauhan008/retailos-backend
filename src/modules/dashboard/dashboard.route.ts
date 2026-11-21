import { Router } from 'express';
import { authenticate, requireTenant } from '@/shared/middlewares/authenticate.js';
import { requirePermission } from '@/shared/middlewares/rbac.js';
import withTenantDb from '@/shared/utilities/with-tenant-db.js';
import { summary } from './controllers/summary.js';

const router = Router();
router.use(authenticate, requireTenant);
router.get('/summary', requirePermission('dashboard.read'), withTenantDb(summary));

export default router;

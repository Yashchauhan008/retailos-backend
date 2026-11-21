import { Router } from 'express';
import authRoutes from '@/modules/auth/auth.route.js';
import fileRoutes from '@/modules/file/file.route.js';
import tenantRoutes from '@/modules/tenant/tenant.route.js';
import usersRoutes from '@/modules/users/users.route.js';
import superAdminRoutes from '@/modules/super-admin/super-admin.route.js';
import catalogRoutes from '@/modules/catalog/catalog.route.js';
import inventoryRoutes from '@/modules/inventory/inventory.route.js';
import purchasingRoutes from '@/modules/purchasing/purchasing.route.js';
import salesRoutes from '@/modules/sales/sales.route.js';
import customersRoutes from '@/modules/customers/customers.route.js';
import dashboardRoutes from '@/modules/dashboard/dashboard.route.js';
import financeRoutes from '@/modules/finance/finance.route.js';
import reportsRoutes from '@/modules/reports/reports.route.js';
import advancedRoutes from '@/modules/advanced/advanced.route.js';

const router = Router();

router.use('/auth', authRoutes);
router.use('/files', fileRoutes);
router.use('/tenants', tenantRoutes);
router.use('/users', usersRoutes);
router.use('/super-admin', superAdminRoutes);
router.use('/catalog', catalogRoutes);
router.use('/inventory', inventoryRoutes);
router.use('/purchasing', purchasingRoutes);
router.use('/sales', salesRoutes);
router.use('/customers', customersRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/finance', financeRoutes);
router.use('/reports', reportsRoutes);
router.use('/advanced', advancedRoutes);

export default router;

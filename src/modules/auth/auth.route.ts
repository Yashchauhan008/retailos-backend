import { Router } from 'express';
import withDatabase from '@/shared/utilities/with-database.js';
import validate from '@/shared/middlewares/request-validator.js';

import {
  Controller as registerUser,
  ValidationSchema as registerUserValidationSchema,
} from '@/modules/auth/controllers/register-user.js';
import {
  Controller as verifyRegistration,
  ValidationSchema as verifyRegistrationValidationSchema,
} from '@/modules/auth/controllers/verify-registration.js';
import {
  Controller as loginUser,
  ValidationSchema as loginUserValidationSchema,
} from '@/modules/auth/controllers/login-user.js';
import {
  Controller as registerRetailer,
  ValidationSchema as registerRetailerValidationSchema,
} from '@/modules/auth/controllers/register-retailer.js';
import {
  Controller as refreshToken,
  ValidationSchema as refreshTokenValidationSchema,
} from '@/modules/auth/controllers/refresh-token.js';
import {
  Controller as logout,
  ValidationSchema as logoutValidationSchema,
} from '@/modules/auth/controllers/logout.js';

const router = Router();

router.route('/register').post(validate(registerUserValidationSchema), withDatabase(registerUser));
router
  .route('/verify-registration')
  .post(validate(verifyRegistrationValidationSchema), withDatabase(verifyRegistration));
router.route('/login').post(validate(loginUserValidationSchema), withDatabase(loginUser));
router
  .route('/register-retailer')
  .post(validate(registerRetailerValidationSchema), withDatabase(registerRetailer));
router.route('/refresh').post(validate(refreshTokenValidationSchema), withDatabase(refreshToken));
router.route('/logout').post(validate(logoutValidationSchema), withDatabase(logout));

export default router;

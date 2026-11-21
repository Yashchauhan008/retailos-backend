-- migrate:up

-- Extend users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone varchar(32),
  ADD COLUMN IF NOT EXISTS status varchar(32) NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS email_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_login_at timestamptz;

-- Super admins
CREATE TABLE super_admins (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_super_admins_id PRIMARY KEY,
  name varchar(255) NOT NULL,
  email varchar(255) NOT NULL CONSTRAINT uk_super_admins_email UNIQUE,
  password_hash text NOT NULL,
  status varchar(32) NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);

-- Industries
CREATE TABLE industries (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_industries_id PRIMARY KEY,
  code varchar(64) NOT NULL CONSTRAINT uk_industries_code UNIQUE,
  name varchar(255) NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE industry_feature_flags (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_industry_feature_flags_id PRIMARY KEY,
  industry_id uuid NOT NULL REFERENCES industries(id) ON DELETE CASCADE,
  feature_key varchar(100) NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT uk_industry_feature UNIQUE (industry_id, feature_key)
);

-- Plans & entitlements
CREATE TABLE plans (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_plans_id PRIMARY KEY,
  code varchar(64) NOT NULL CONSTRAINT uk_plans_code UNIQUE,
  name varchar(255) NOT NULL,
  description text,
  price_monthly numeric(14,2) NOT NULL DEFAULT 0,
  price_yearly numeric(14,2) NOT NULL DEFAULT 0,
  trial_days int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE plan_features (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_plan_features_id PRIMARY KEY,
  plan_id uuid NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  feature_key varchar(100) NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  CONSTRAINT uk_plan_feature UNIQUE (plan_id, feature_key)
);

CREATE TABLE plan_limits (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_plan_limits_id PRIMARY KEY,
  plan_id uuid NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  limit_key varchar(100) NOT NULL,
  limit_value int NOT NULL DEFAULT 0,
  CONSTRAINT uk_plan_limit UNIQUE (plan_id, limit_key)
);

-- Permissions & system role templates
CREATE TABLE permissions (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_permissions_id PRIMARY KEY,
  key varchar(100) NOT NULL CONSTRAINT uk_permissions_key UNIQUE,
  name varchar(255) NOT NULL,
  module varchar(100) NOT NULL,
  description text
);

CREATE TABLE role_templates (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_role_templates_id PRIMARY KEY,
  code varchar(64) NOT NULL CONSTRAINT uk_role_templates_code UNIQUE,
  name varchar(255) NOT NULL,
  description text,
  is_system boolean NOT NULL DEFAULT true
);

CREATE TABLE role_template_permissions (
  role_template_id uuid NOT NULL REFERENCES role_templates(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  CONSTRAINT pk_role_template_permissions PRIMARY KEY (role_template_id, permission_id)
);

-- Tenants
CREATE TABLE tenants (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_tenants_id PRIMARY KEY,
  name varchar(255) NOT NULL,
  slug varchar(100) NOT NULL CONSTRAINT uk_tenants_slug UNIQUE,
  industry_id uuid REFERENCES industries(id),
  status varchar(32) NOT NULL DEFAULT 'active',
  onboarding_step varchar(64) NOT NULL DEFAULT 'industry',
  onboarding_completed boolean NOT NULL DEFAULT false,
  gstin varchar(32),
  phone varchar(32),
  email varchar(255),
  address_line1 text,
  address_line2 text,
  city varchar(100),
  state varchar(100),
  pincode varchar(20),
  country varchar(100) NOT NULL DEFAULT 'India',
  logo_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);

CREATE TABLE tenant_subscriptions (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_tenant_subscriptions_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES plans(id),
  status varchar(32) NOT NULL DEFAULT 'trialing',
  trial_ends_at timestamptz,
  current_period_start timestamptz NOT NULL DEFAULT now(),
  current_period_end timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz,
  CONSTRAINT uk_tenant_subscriptions_tenant UNIQUE (tenant_id)
);

CREATE TABLE branches (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_branches_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  code varchar(64),
  phone varchar(32),
  email varchar(255),
  address_line1 text,
  city varchar(100),
  state varchar(100),
  pincode varchar(20),
  is_default boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);

CREATE INDEX idx_branches_tenant ON branches(tenant_id);

CREATE TABLE tenant_roles (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_tenant_roles_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  code varchar(64) NOT NULL,
  name varchar(255) NOT NULL,
  description text,
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_tenant_roles UNIQUE (tenant_id, code)
);

CREATE TABLE tenant_role_permissions (
  tenant_role_id uuid NOT NULL REFERENCES tenant_roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  CONSTRAINT pk_tenant_role_permissions PRIMARY KEY (tenant_role_id, permission_id)
);

CREATE TABLE tenant_users (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_tenant_users_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES tenant_roles(id),
  branch_id uuid REFERENCES branches(id),
  status varchar(32) NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_tenant_users UNIQUE (tenant_id, user_id)
);

CREATE INDEX idx_tenant_users_user ON tenant_users(user_id);

CREATE TABLE tenant_settings (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_tenant_settings_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  key varchar(100) NOT NULL,
  value jsonb NOT NULL DEFAULT 'null'::jsonb,
  CONSTRAINT uk_tenant_settings UNIQUE (tenant_id, key)
);

CREATE TABLE refresh_tokens (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_refresh_tokens_id PRIMARY KEY,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  super_admin_id uuid REFERENCES super_admins(id) ON DELETE CASCADE,
  token_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_refresh_tokens_owner CHECK (
    (user_id IS NOT NULL AND super_admin_id IS NULL) OR
    (user_id IS NULL AND super_admin_id IS NOT NULL)
  )
);

CREATE TABLE audit_logs (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_audit_logs_id PRIMARY KEY,
  tenant_id uuid REFERENCES tenants(id) ON DELETE SET NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  actor_super_admin_id uuid REFERENCES super_admins(id) ON DELETE SET NULL,
  action varchar(100) NOT NULL,
  entity_type varchar(100),
  entity_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ip_address varchar(64),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_tenant ON audit_logs(tenant_id, created_at DESC);

-- RLS helpers
CREATE OR REPLACE FUNCTION app_current_tenant_id() RETURNS uuid AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION app_is_super_admin() RETURNS boolean AS $$
  SELECT COALESCE(current_setting('app.is_super_admin', true), 'false') = 'true';
$$ LANGUAGE sql STABLE;

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_subscriptions FORCE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_roles FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_role_permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_users FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_settings FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;

CREATE POLICY tenants_isolation ON tenants
  USING (app_is_super_admin() OR id = app_current_tenant_id())
  WITH CHECK (app_is_super_admin() OR id = app_current_tenant_id());

CREATE POLICY tenant_subscriptions_isolation ON tenant_subscriptions
  USING (app_is_super_admin() OR tenant_id = app_current_tenant_id())
  WITH CHECK (app_is_super_admin() OR tenant_id = app_current_tenant_id());

CREATE POLICY branches_isolation ON branches
  USING (app_is_super_admin() OR tenant_id = app_current_tenant_id())
  WITH CHECK (app_is_super_admin() OR tenant_id = app_current_tenant_id());

CREATE POLICY tenant_roles_isolation ON tenant_roles
  USING (app_is_super_admin() OR tenant_id = app_current_tenant_id())
  WITH CHECK (app_is_super_admin() OR tenant_id = app_current_tenant_id());

CREATE POLICY tenant_role_permissions_isolation ON tenant_role_permissions
  USING (
    app_is_super_admin() OR EXISTS (
      SELECT 1 FROM tenant_roles tr
      WHERE tr.id = tenant_role_id AND tr.tenant_id = app_current_tenant_id()
    )
  )
  WITH CHECK (
    app_is_super_admin() OR EXISTS (
      SELECT 1 FROM tenant_roles tr
      WHERE tr.id = tenant_role_id AND tr.tenant_id = app_current_tenant_id()
    )
  );

CREATE POLICY tenant_users_isolation ON tenant_users
  USING (app_is_super_admin() OR tenant_id = app_current_tenant_id())
  WITH CHECK (app_is_super_admin() OR tenant_id = app_current_tenant_id());

CREATE POLICY tenant_settings_isolation ON tenant_settings
  USING (app_is_super_admin() OR tenant_id = app_current_tenant_id())
  WITH CHECK (app_is_super_admin() OR tenant_id = app_current_tenant_id());

CREATE POLICY audit_logs_isolation ON audit_logs
  USING (app_is_super_admin() OR tenant_id = app_current_tenant_id())
  WITH CHECK (app_is_super_admin() OR tenant_id = app_current_tenant_id());

-- Seed industries
INSERT INTO industries (code, name, description) VALUES
  ('grocery', 'Grocery', 'Weight-based billing, expiry, batch tracking'),
  ('clothing', 'Clothing Store', 'Size, color, fabric, variants'),
  ('electronics', 'Electronics', 'IMEI, serial numbers, warranty'),
  ('pharmacy', 'Pharmacy', 'Batch, expiry, prescription records'),
  ('footwear', 'Footwear', 'Size and color matrix'),
  ('hardware', 'Hardware', 'Measurement units, bulk pricing'),
  ('cosmetics', 'Cosmetics', 'Shades, batch, expiry'),
  ('furniture', 'Furniture', 'Dimensions, custom orders, delivery');

INSERT INTO industry_feature_flags (industry_id, feature_key, enabled, config)
SELECT i.id, f.feature_key, f.enabled, f.config::jsonb
FROM industries i
JOIN (
  VALUES
    ('grocery', 'weight_billing', true, '{}'),
    ('grocery', 'batch_expiry', true, '{}'),
    ('clothing', 'variants', true, '{"attributes":["size","color","fabric"]}'),
    ('clothing', 'size_color_matrix', true, '{}'),
    ('electronics', 'imei', true, '{}'),
    ('electronics', 'serial_numbers', true, '{}'),
    ('electronics', 'warranty', true, '{}'),
    ('pharmacy', 'batch_expiry', true, '{}'),
    ('pharmacy', 'prescription', true, '{}'),
    ('footwear', 'variants', true, '{"attributes":["size","color"]}'),
    ('footwear', 'size_color_matrix', true, '{}'),
    ('hardware', 'bulk_pricing', true, '{}'),
    ('hardware', 'measurement_units', true, '{}'),
    ('cosmetics', 'variants', true, '{"attributes":["shade"]}'),
    ('cosmetics', 'batch_expiry', true, '{}'),
    ('furniture', 'dimensions', true, '{}'),
    ('furniture', 'custom_orders', true, '{}')
) AS f(industry_code, feature_key, enabled, config)
  ON i.code = f.industry_code;

-- Seed plans
INSERT INTO plans (code, name, description, price_monthly, price_yearly, trial_days, sort_order) VALUES
  ('trial', 'Free Trial', '14-day trial with core features', 0, 0, 14, 1),
  ('starter', 'Starter', 'For single-branch shops', 999, 9990, 0, 2),
  ('growth', 'Growth', 'Growing multi-user businesses', 2499, 24990, 0, 3),
  ('pro', 'Pro', 'Advanced features and higher limits', 4999, 49990, 0, 4);

INSERT INTO plan_features (plan_id, feature_key, enabled)
SELECT p.id, f.feature_key, f.enabled
FROM plans p
JOIN (
  VALUES
    ('trial', 'pos', true),
    ('trial', 'products', true),
    ('trial', 'inventory', true),
    ('trial', 'purchases', true),
    ('trial', 'customers', true),
    ('trial', 'reports_basic', true),
    ('trial', 'multi_branch', false),
    ('trial', 'loyalty', false),
    ('starter', 'pos', true),
    ('starter', 'products', true),
    ('starter', 'inventory', true),
    ('starter', 'purchases', true),
    ('starter', 'customers', true),
    ('starter', 'reports_basic', true),
    ('starter', 'multi_branch', false),
    ('starter', 'loyalty', false),
    ('growth', 'pos', true),
    ('growth', 'products', true),
    ('growth', 'inventory', true),
    ('growth', 'purchases', true),
    ('growth', 'customers', true),
    ('growth', 'reports_basic', true),
    ('growth', 'multi_branch', true),
    ('growth', 'loyalty', false),
    ('pro', 'pos', true),
    ('pro', 'products', true),
    ('pro', 'inventory', true),
    ('pro', 'purchases', true),
    ('pro', 'customers', true),
    ('pro', 'reports_basic', true),
    ('pro', 'multi_branch', true),
    ('pro', 'loyalty', true)
) AS f(plan_code, feature_key, enabled) ON p.code = f.plan_code;

INSERT INTO plan_limits (plan_id, limit_key, limit_value)
SELECT p.id, l.limit_key, l.limit_value
FROM plans p
JOIN (
  VALUES
    ('trial', 'max_users', 3),
    ('trial', 'max_branches', 1),
    ('trial', 'max_products', 500),
    ('starter', 'max_users', 5),
    ('starter', 'max_branches', 1),
    ('starter', 'max_products', 2000),
    ('growth', 'max_users', 15),
    ('growth', 'max_branches', 3),
    ('growth', 'max_products', 10000),
    ('pro', 'max_users', 50),
    ('pro', 'max_branches', 10),
    ('pro', 'max_products', 100000)
) AS l(plan_code, limit_key, limit_value) ON p.code = l.plan_code;

-- Seed permissions
INSERT INTO permissions (key, name, module, description) VALUES
  ('dashboard.read', 'View Dashboard', 'dashboard', 'View sales dashboard'),
  ('products.read', 'View Products', 'products', 'View product catalog'),
  ('products.write', 'Manage Products', 'products', 'Create and edit products'),
  ('inventory.read', 'View Inventory', 'inventory', 'View stock levels'),
  ('inventory.write', 'Adjust Inventory', 'inventory', 'Adjust stock levels'),
  ('purchases.read', 'View Purchases', 'purchases', 'View purchase orders'),
  ('purchases.write', 'Manage Purchases', 'purchases', 'Create POs and GRNs'),
  ('purchases.approve', 'Approve Purchases', 'purchases', 'Approve purchase orders'),
  ('pos.sell', 'POS Billing', 'pos', 'Create sales invoices'),
  ('sales.read', 'View Sales', 'sales', 'View sales history'),
  ('customers.read', 'View Customers', 'customers', 'View customers'),
  ('customers.write', 'Manage Customers', 'customers', 'Create and edit customers'),
  ('suppliers.read', 'View Suppliers', 'suppliers', 'View suppliers'),
  ('suppliers.write', 'Manage Suppliers', 'suppliers', 'Create and edit suppliers'),
  ('users.manage', 'Manage Users', 'users', 'Invite and manage staff'),
  ('roles.manage', 'Manage Roles', 'users', 'Manage roles and permissions'),
  ('settings.manage', 'Manage Settings', 'settings', 'Manage business settings'),
  ('subscription.read', 'View Subscription', 'subscription', 'View plan and billing'),
  ('reports.read', 'View Reports', 'reports', 'View reports');

INSERT INTO role_templates (code, name, description) VALUES
  ('owner', 'Owner', 'Full access to all features'),
  ('manager', 'Manager', 'Manage operations except billing settings'),
  ('cashier', 'Cashier', 'POS and basic customer access'),
  ('inventory', 'Inventory Staff', 'Products and inventory only');

INSERT INTO role_template_permissions (role_template_id, permission_id)
SELECT rt.id, p.id
FROM role_templates rt
CROSS JOIN permissions p
WHERE rt.code = 'owner';

INSERT INTO role_template_permissions (role_template_id, permission_id)
SELECT rt.id, p.id
FROM role_templates rt
JOIN permissions p ON p.key IN (
  'dashboard.read','products.read','products.write','inventory.read','inventory.write',
  'purchases.read','purchases.write','pos.sell','sales.read','customers.read','customers.write',
  'suppliers.read','suppliers.write','users.manage','reports.read','subscription.read'
)
WHERE rt.code = 'manager';

INSERT INTO role_template_permissions (role_template_id, permission_id)
SELECT rt.id, p.id
FROM role_templates rt
JOIN permissions p ON p.key IN (
  'dashboard.read','pos.sell','sales.read','customers.read','customers.write','products.read'
)
WHERE rt.code = 'cashier';

INSERT INTO role_template_permissions (role_template_id, permission_id)
SELECT rt.id, p.id
FROM role_templates rt
JOIN permissions p ON p.key IN (
  'products.read','products.write','inventory.read','inventory.write','suppliers.read','purchases.read'
)
WHERE rt.code = 'inventory';

-- Default super admin: admin@retailos.com / Admin@123
INSERT INTO super_admins (name, email, password_hash)
VALUES (
  'Super Admin',
  'admin@retailos.com',
  '$2b$10$75d6Fk47iRh/fLFI572P0efyrMY7r8/xBIexDQCmqyNKAmSg5UU7u'
);

-- migrate:down

DROP POLICY IF EXISTS audit_logs_isolation ON audit_logs;
DROP POLICY IF EXISTS tenant_settings_isolation ON tenant_settings;
DROP POLICY IF EXISTS tenant_users_isolation ON tenant_users;
DROP POLICY IF EXISTS tenant_role_permissions_isolation ON tenant_role_permissions;
DROP POLICY IF EXISTS tenant_roles_isolation ON tenant_roles;
DROP POLICY IF EXISTS branches_isolation ON branches;
DROP POLICY IF EXISTS tenant_subscriptions_isolation ON tenant_subscriptions;
DROP POLICY IF EXISTS tenants_isolation ON tenants;

DROP FUNCTION IF EXISTS app_is_super_admin();
DROP FUNCTION IF EXISTS app_current_tenant_id();

DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS tenant_settings;
DROP TABLE IF EXISTS tenant_users;
DROP TABLE IF EXISTS tenant_role_permissions;
DROP TABLE IF EXISTS tenant_roles;
DROP TABLE IF EXISTS branches;
DROP TABLE IF EXISTS tenant_subscriptions;
DROP TABLE IF EXISTS tenants;
DROP TABLE IF EXISTS role_template_permissions;
DROP TABLE IF EXISTS role_templates;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS plan_limits;
DROP TABLE IF EXISTS plan_features;
DROP TABLE IF EXISTS plans;
DROP TABLE IF EXISTS industry_feature_flags;
DROP TABLE IF EXISTS industries;
DROP TABLE IF EXISTS super_admins;

ALTER TABLE users
  DROP COLUMN IF EXISTS phone,
  DROP COLUMN IF EXISTS status,
  DROP COLUMN IF EXISTS email_verified,
  DROP COLUMN IF EXISTS last_login_at;

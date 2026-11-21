-- migrate:up

-- Stock transfers between branches
CREATE TABLE stock_transfers (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_stock_transfers_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  transfer_number varchar(64) NOT NULL,
  from_branch_id uuid NOT NULL REFERENCES branches(id),
  to_branch_id uuid NOT NULL REFERENCES branches(id),
  status varchar(32) NOT NULL DEFAULT 'draft', -- draft | in_transit | received | cancelled
  notes text,
  created_by uuid REFERENCES users(id),
  received_by uuid REFERENCES users(id),
  transferred_at timestamptz,
  received_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_stock_transfers_number UNIQUE (tenant_id, transfer_number)
);

CREATE TABLE stock_transfer_items (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_stock_transfer_items_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  stock_transfer_id uuid NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  quantity numeric(14,3) NOT NULL,
  received_qty numeric(14,3) NOT NULL DEFAULT 0
);

-- Attendance & shifts
CREATE TABLE shifts (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_shifts_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(100) NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE attendance_records (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_attendance_records_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id),
  branch_id uuid REFERENCES branches(id),
  shift_id uuid REFERENCES shifts(id),
  attendance_date date NOT NULL,
  check_in timestamptz,
  check_out timestamptz,
  status varchar(32) NOT NULL DEFAULT 'present', -- present | absent | leave | half_day
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_attendance UNIQUE (tenant_id, user_id, attendance_date)
);

-- Customer groups & pricing
CREATE TABLE customer_groups (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_customer_groups_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(100) NOT NULL,
  discount_percent numeric(5,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customers
  ADD COLUMN IF NOT EXISTS customer_group_id uuid REFERENCES customer_groups(id),
  ADD COLUMN IF NOT EXISTS loyalty_points numeric(14,2) NOT NULL DEFAULT 0;

-- Loyalty
CREATE TABLE loyalty_settings (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_loyalty_settings_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  points_per_currency numeric(10,4) NOT NULL DEFAULT 1,
  currency_per_point numeric(10,4) NOT NULL DEFAULT 0.25,
  min_redeem_points numeric(14,2) NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT uk_loyalty_settings_tenant UNIQUE (tenant_id)
);

CREATE TABLE loyalty_transactions (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_loyalty_transactions_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id),
  points numeric(14,2) NOT NULL,
  direction varchar(16) NOT NULL, -- earn | redeem | adjust
  balance_after numeric(14,2) NOT NULL,
  ref_type varchar(64),
  ref_id uuid,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Coupons & promotions
CREATE TABLE coupons (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_coupons_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  code varchar(64) NOT NULL,
  name varchar(255) NOT NULL,
  discount_type varchar(32) NOT NULL DEFAULT 'percent', -- percent | flat
  discount_value numeric(14,2) NOT NULL,
  min_order_amount numeric(14,2) NOT NULL DEFAULT 0,
  max_discount numeric(14,2),
  usage_limit int,
  used_count int NOT NULL DEFAULT 0,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_coupons_code UNIQUE (tenant_id, code)
);

CREATE TABLE promotions (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_promotions_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  promo_type varchar(64) NOT NULL DEFAULT 'bogo', -- bogo | percent_off | flat_off
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Batch / expiry
CREATE TABLE inventory_batches (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_inventory_batches_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  batch_number varchar(100) NOT NULL,
  expiry_date date,
  manufactured_date date,
  quantity numeric(14,3) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_inventory_batches UNIQUE (tenant_id, branch_id, variant_id, batch_number)
);

-- Serial / IMEI tracking
CREATE TABLE serial_numbers (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_serial_numbers_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid REFERENCES branches(id),
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  serial_value varchar(255) NOT NULL,
  serial_type varchar(32) NOT NULL DEFAULT 'serial', -- serial | imei
  status varchar(32) NOT NULL DEFAULT 'in_stock', -- in_stock | sold | returned | warranty
  sales_invoice_id uuid REFERENCES sales_invoices(id),
  warranty_months int,
  warranty_expires_at date,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_serial_numbers UNIQUE (tenant_id, serial_value)
);

-- Warranty claims
CREATE TABLE warranty_claims (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_warranty_claims_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  serial_id uuid REFERENCES serial_numbers(id),
  customer_id uuid REFERENCES customers(id),
  claim_number varchar(64) NOT NULL,
  claim_date date NOT NULL DEFAULT CURRENT_DATE,
  issue_description text,
  status varchar(32) NOT NULL DEFAULT 'open', -- open | in_progress | resolved | rejected
  resolution_notes text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_warranty_claims_number UNIQUE (tenant_id, claim_number)
);

-- Custom product attributes already partially exist; ensure definitions usable
-- Forecasting snapshots (simple moving average storage)
CREATE TABLE inventory_forecasts (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_inventory_forecasts_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  branch_id uuid REFERENCES branches(id),
  forecast_date date NOT NULL DEFAULT CURRENT_DATE,
  avg_daily_sales numeric(14,4) NOT NULL DEFAULT 0,
  suggested_reorder_qty numeric(14,3) NOT NULL DEFAULT 0,
  days_of_cover numeric(10,2) NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Permissions + plan features
INSERT INTO permissions (key, name, module, description) VALUES
  ('branches.manage', 'Manage Branches', 'branches', 'Create and manage branches'),
  ('transfers.write', 'Stock Transfers', 'inventory', 'Transfer stock between branches'),
  ('attendance.manage', 'Manage Attendance', 'hr', 'Shifts and attendance'),
  ('loyalty.manage', 'Manage Loyalty', 'promotions', 'Loyalty and rewards'),
  ('promotions.manage', 'Manage Promotions', 'promotions', 'Coupons and promotions'),
  ('serials.manage', 'Serial/IMEI Tracking', 'inventory', 'Track serials and warranties')
ON CONFLICT (key) DO NOTHING;

INSERT INTO role_template_permissions (role_template_id, permission_id)
SELECT rt.id, p.id FROM role_templates rt
CROSS JOIN permissions p
WHERE rt.code = 'owner'
  AND p.key IN ('branches.manage','transfers.write','attendance.manage','loyalty.manage','promotions.manage','serials.manage')
ON CONFLICT DO NOTHING;

INSERT INTO role_template_permissions (role_template_id, permission_id)
SELECT rt.id, p.id FROM role_templates rt
JOIN permissions p ON p.key IN ('transfers.write','attendance.manage','loyalty.manage','promotions.manage','serials.manage')
WHERE rt.code = 'manager'
ON CONFLICT DO NOTHING;

INSERT INTO plan_features (plan_id, feature_key, enabled)
SELECT p.id, f.feature_key, f.enabled
FROM plans p
JOIN (VALUES
  ('trial', 'loyalty', false),
  ('trial', 'stock_transfers', false),
  ('trial', 'batch_expiry', true),
  ('trial', 'serial_tracking', false),
  ('starter', 'loyalty', false),
  ('starter', 'stock_transfers', false),
  ('starter', 'batch_expiry', true),
  ('starter', 'serial_tracking', false),
  ('growth', 'loyalty', true),
  ('growth', 'stock_transfers', true),
  ('growth', 'batch_expiry', true),
  ('growth', 'serial_tracking', true),
  ('growth', 'multi_branch', true),
  ('pro', 'loyalty', true),
  ('pro', 'stock_transfers', true),
  ('pro', 'batch_expiry', true),
  ('pro', 'serial_tracking', true),
  ('pro', 'multi_branch', true),
  ('pro', 'attendance', true),
  ('growth', 'attendance', true)
) AS f(plan_code, feature_key, enabled) ON p.code = f.plan_code
ON CONFLICT DO NOTHING;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'stock_transfers','stock_transfer_items','shifts','attendance_records',
    'customer_groups','loyalty_settings','loyalty_transactions','coupons','promotions',
    'inventory_batches','serial_numbers','warranty_claims','inventory_forecasts'
  ]
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I USING (app_is_super_admin() OR tenant_id = app_current_tenant_id()) WITH CHECK (app_is_super_admin() OR tenant_id = app_current_tenant_id())',
      t || '_isolation', t
    );
  END LOOP;
END $$;

-- migrate:down

ALTER TABLE customers DROP COLUMN IF EXISTS customer_group_id;
ALTER TABLE customers DROP COLUMN IF EXISTS loyalty_points;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'inventory_forecasts','warranty_claims','serial_numbers','inventory_batches',
    'promotions','coupons','loyalty_transactions','loyalty_settings','customer_groups',
    'attendance_records','shifts','stock_transfer_items','stock_transfers'
  ]
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', t);
  END LOOP;
END $$;

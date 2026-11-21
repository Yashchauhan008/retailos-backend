-- migrate:up

-- Sales returns / exchanges
CREATE TABLE sales_returns (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_sales_returns_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  sales_invoice_id uuid REFERENCES sales_invoices(id),
  customer_id uuid REFERENCES customers(id),
  return_number varchar(64) NOT NULL,
  return_date timestamptz NOT NULL DEFAULT now(),
  return_type varchar(32) NOT NULL DEFAULT 'refund', -- refund | exchange
  reason text,
  subtotal numeric(14,2) NOT NULL DEFAULT 0,
  tax_total numeric(14,2) NOT NULL DEFAULT 0,
  grand_total numeric(14,2) NOT NULL DEFAULT 0,
  refund_method varchar(32), -- cash | upi | card | credit_note
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_sales_returns_number UNIQUE (tenant_id, return_number)
);

CREATE TABLE sales_return_items (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_sales_return_items_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  sales_return_id uuid NOT NULL REFERENCES sales_returns(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  product_name varchar(255) NOT NULL,
  quantity numeric(14,3) NOT NULL,
  unit_price numeric(14,2) NOT NULL,
  tax_amount numeric(14,2) NOT NULL DEFAULT 0,
  line_total numeric(14,2) NOT NULL,
  restock boolean NOT NULL DEFAULT true
);

-- Customer payments / credit
CREATE TABLE customer_payments (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_customer_payments_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id),
  branch_id uuid REFERENCES branches(id),
  amount numeric(14,2) NOT NULL,
  method varchar(32) NOT NULL DEFAULT 'cash',
  reference varchar(255),
  notes text,
  sales_invoice_id uuid REFERENCES sales_invoices(id),
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Supplier payments
CREATE TABLE supplier_payments (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_supplier_payments_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  supplier_id uuid NOT NULL REFERENCES suppliers(id),
  branch_id uuid REFERENCES branches(id),
  amount numeric(14,2) NOT NULL,
  method varchar(32) NOT NULL DEFAULT 'cash',
  reference varchar(255),
  notes text,
  purchase_invoice_id uuid REFERENCES purchase_invoices(id),
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Expenses
CREATE TABLE expense_categories (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_expense_categories_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE expenses (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_expenses_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid REFERENCES branches(id),
  category_id uuid REFERENCES expense_categories(id),
  title varchar(255) NOT NULL,
  amount numeric(14,2) NOT NULL,
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  payment_method varchar(32) NOT NULL DEFAULT 'cash',
  notes text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Cashbook / Bankbook ledger entries
CREATE TABLE cash_accounts (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_cash_accounts_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  account_type varchar(32) NOT NULL DEFAULT 'cash', -- cash | bank
  opening_balance numeric(14,2) NOT NULL DEFAULT 0,
  current_balance numeric(14,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cash_ledger_entries (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_cash_ledger_entries_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES cash_accounts(id) ON DELETE CASCADE,
  entry_date timestamptz NOT NULL DEFAULT now(),
  direction varchar(16) NOT NULL, -- in | out
  amount numeric(14,2) NOT NULL,
  balance_after numeric(14,2) NOT NULL,
  description text,
  ref_type varchar(64),
  ref_id uuid,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Generic party ledger (customer / supplier)
CREATE TABLE party_ledger_entries (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_party_ledger_entries_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  party_type varchar(32) NOT NULL, -- customer | supplier
  party_id uuid NOT NULL,
  entry_date timestamptz NOT NULL DEFAULT now(),
  direction varchar(16) NOT NULL, -- debit | credit
  amount numeric(14,2) NOT NULL,
  balance_after numeric(14,2) NOT NULL DEFAULT 0,
  description text,
  ref_type varchar(64),
  ref_id uuid,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_party_ledger_party ON party_ledger_entries(tenant_id, party_type, party_id, entry_date DESC);

-- Daily closing
CREATE TABLE daily_closings (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_daily_closings_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  closing_date date NOT NULL,
  opening_cash numeric(14,2) NOT NULL DEFAULT 0,
  cash_sales numeric(14,2) NOT NULL DEFAULT 0,
  cash_expenses numeric(14,2) NOT NULL DEFAULT 0,
  expected_cash numeric(14,2) NOT NULL DEFAULT 0,
  counted_cash numeric(14,2) NOT NULL DEFAULT 0,
  variance numeric(14,2) NOT NULL DEFAULT 0,
  total_sales numeric(14,2) NOT NULL DEFAULT 0,
  total_returns numeric(14,2) NOT NULL DEFAULT 0,
  notes text,
  closed_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_daily_closings UNIQUE (tenant_id, branch_id, closing_date)
);

-- New permissions for finance
INSERT INTO permissions (key, name, module, description) VALUES
  ('finance.read', 'View Finance', 'finance', 'View expenses and ledgers'),
  ('finance.write', 'Manage Finance', 'finance', 'Record expenses and payments'),
  ('returns.write', 'Process Returns', 'sales', 'Create sales returns'),
  ('reports.finance', 'Finance Reports', 'reports', 'View P&L and GST reports')
ON CONFLICT (key) DO NOTHING;

-- Grant to owner template
INSERT INTO role_template_permissions (role_template_id, permission_id)
SELECT rt.id, p.id
FROM role_templates rt
CROSS JOIN permissions p
WHERE rt.code = 'owner'
  AND p.key IN ('finance.read','finance.write','returns.write','reports.finance')
ON CONFLICT DO NOTHING;

INSERT INTO role_template_permissions (role_template_id, permission_id)
SELECT rt.id, p.id
FROM role_templates rt
JOIN permissions p ON p.key IN ('finance.read','returns.write','reports.finance','reports.read')
WHERE rt.code = 'manager'
ON CONFLICT DO NOTHING;

-- Plan features for reports
INSERT INTO plan_features (plan_id, feature_key, enabled)
SELECT p.id, f.feature_key, f.enabled
FROM plans p
JOIN (VALUES
  ('trial', 'finance', true),
  ('trial', 'reports_finance', true),
  ('starter', 'finance', true),
  ('starter', 'reports_finance', true),
  ('growth', 'finance', true),
  ('growth', 'reports_finance', true),
  ('pro', 'finance', true),
  ('pro', 'reports_finance', true)
) AS f(plan_code, feature_key, enabled) ON p.code = f.plan_code
ON CONFLICT DO NOTHING;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'sales_returns','sales_return_items','customer_payments','supplier_payments',
    'expense_categories','expenses','cash_accounts','cash_ledger_entries',
    'party_ledger_entries','daily_closings'
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

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'daily_closings','party_ledger_entries','cash_ledger_entries','cash_accounts',
    'expenses','expense_categories','supplier_payments','customer_payments',
    'sales_return_items','sales_returns'
  ]
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', t);
  END LOOP;
END $$;

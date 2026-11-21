-- migrate:up

CREATE TABLE tax_rates (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_tax_rates_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(100) NOT NULL,
  hsn_sac varchar(32),
  cgst_rate numeric(5,2) NOT NULL DEFAULT 0,
  sgst_rate numeric(5,2) NOT NULL DEFAULT 0,
  igst_rate numeric(5,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE categories (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_categories_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  name varchar(255) NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE brands (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_brands_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE units (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_units_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(64) NOT NULL,
  short_name varchar(16) NOT NULL,
  allow_decimal boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_units_tenant_short UNIQUE (tenant_id, short_name)
);

CREATE TABLE attribute_definitions (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_attribute_definitions_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(100) NOT NULL,
  code varchar(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_attribute_definitions UNIQUE (tenant_id, code)
);

CREATE TABLE attribute_values (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_attribute_values_id PRIMARY KEY,
  attribute_id uuid NOT NULL REFERENCES attribute_definitions(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  value varchar(100) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE products (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_products_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  category_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  brand_id uuid REFERENCES brands(id) ON DELETE SET NULL,
  unit_id uuid REFERENCES units(id) ON DELETE SET NULL,
  tax_rate_id uuid REFERENCES tax_rates(id) ON DELETE SET NULL,
  name varchar(255) NOT NULL,
  description text,
  product_type varchar(32) NOT NULL DEFAULT 'simple',
  track_inventory boolean NOT NULL DEFAULT true,
  low_stock_threshold numeric(14,3) NOT NULL DEFAULT 0,
  image_url text,
  attrs jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);

CREATE INDEX idx_products_tenant_name ON products(tenant_id, name);

CREATE TABLE product_variants (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_product_variants_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku varchar(100) NOT NULL,
  barcode varchar(100),
  name varchar(255),
  selling_price numeric(14,2) NOT NULL DEFAULT 0,
  cost_price numeric(14,2) NOT NULL DEFAULT 0,
  mrp numeric(14,2),
  attrs jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz,
  CONSTRAINT uk_product_variants_sku UNIQUE (tenant_id, sku)
);

CREATE UNIQUE INDEX uk_product_variants_barcode ON product_variants(tenant_id, barcode)
  WHERE barcode IS NOT NULL;

CREATE TABLE stock_levels (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_stock_levels_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
  quantity numeric(14,3) NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_stock_levels UNIQUE (tenant_id, branch_id, variant_id)
);

CREATE TABLE stock_movements (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_stock_movements_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
  movement_type varchar(64) NOT NULL,
  qty_delta numeric(14,3) NOT NULL,
  qty_after numeric(14,3) NOT NULL,
  reason text,
  ref_type varchar(64),
  ref_id uuid,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_movements_tenant ON stock_movements(tenant_id, created_at DESC);

CREATE TABLE suppliers (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_suppliers_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  contact_person varchar(255),
  phone varchar(32),
  email varchar(255),
  gstin varchar(32),
  address text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE purchase_orders (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_purchase_orders_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  supplier_id uuid NOT NULL REFERENCES suppliers(id),
  po_number varchar(64) NOT NULL,
  status varchar(32) NOT NULL DEFAULT 'draft',
  order_date date NOT NULL DEFAULT CURRENT_DATE,
  expected_date date,
  notes text,
  subtotal numeric(14,2) NOT NULL DEFAULT 0,
  tax_total numeric(14,2) NOT NULL DEFAULT 0,
  grand_total numeric(14,2) NOT NULL DEFAULT 0,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz,
  CONSTRAINT uk_purchase_orders_number UNIQUE (tenant_id, po_number)
);

CREATE TABLE purchase_order_items (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_purchase_order_items_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  purchase_order_id uuid NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  quantity numeric(14,3) NOT NULL,
  received_qty numeric(14,3) NOT NULL DEFAULT 0,
  unit_cost numeric(14,2) NOT NULL DEFAULT 0,
  tax_amount numeric(14,2) NOT NULL DEFAULT 0,
  line_total numeric(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE grns (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_grns_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  purchase_order_id uuid REFERENCES purchase_orders(id),
  supplier_id uuid NOT NULL REFERENCES suppliers(id),
  grn_number varchar(64) NOT NULL,
  received_date date NOT NULL DEFAULT CURRENT_DATE,
  notes text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_grns_number UNIQUE (tenant_id, grn_number)
);

CREATE TABLE grn_items (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_grn_items_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  grn_id uuid NOT NULL REFERENCES grns(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  quantity numeric(14,3) NOT NULL,
  unit_cost numeric(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE purchase_invoices (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_purchase_invoices_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  supplier_id uuid NOT NULL REFERENCES suppliers(id),
  grn_id uuid REFERENCES grns(id),
  invoice_number varchar(64) NOT NULL,
  invoice_date date NOT NULL DEFAULT CURRENT_DATE,
  subtotal numeric(14,2) NOT NULL DEFAULT 0,
  tax_total numeric(14,2) NOT NULL DEFAULT 0,
  grand_total numeric(14,2) NOT NULL DEFAULT 0,
  amount_paid numeric(14,2) NOT NULL DEFAULT 0,
  status varchar(32) NOT NULL DEFAULT 'unpaid',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_purchase_invoices_number UNIQUE (tenant_id, invoice_number)
);

CREATE TABLE purchase_returns (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_purchase_returns_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  supplier_id uuid NOT NULL REFERENCES suppliers(id),
  purchase_invoice_id uuid REFERENCES purchase_invoices(id),
  return_number varchar(64) NOT NULL,
  return_date date NOT NULL DEFAULT CURRENT_DATE,
  reason text,
  grand_total numeric(14,2) NOT NULL DEFAULT 0,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_purchase_returns_number UNIQUE (tenant_id, return_number)
);

CREATE TABLE purchase_return_items (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_purchase_return_items_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  purchase_return_id uuid NOT NULL REFERENCES purchase_returns(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  quantity numeric(14,3) NOT NULL,
  unit_cost numeric(14,2) NOT NULL DEFAULT 0,
  line_total numeric(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE customers (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_customers_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  phone varchar(32),
  email varchar(255),
  gstin varchar(32),
  address text,
  credit_limit numeric(14,2) NOT NULL DEFAULT 0,
  outstanding numeric(14,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_customers_tenant_phone ON customers(tenant_id, phone);

CREATE TABLE sales_invoices (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_sales_invoices_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  customer_id uuid REFERENCES customers(id),
  invoice_number varchar(64) NOT NULL,
  invoice_date timestamptz NOT NULL DEFAULT now(),
  status varchar(32) NOT NULL DEFAULT 'completed',
  subtotal numeric(14,2) NOT NULL DEFAULT 0,
  discount_total numeric(14,2) NOT NULL DEFAULT 0,
  tax_total numeric(14,2) NOT NULL DEFAULT 0,
  cgst_total numeric(14,2) NOT NULL DEFAULT 0,
  sgst_total numeric(14,2) NOT NULL DEFAULT 0,
  igst_total numeric(14,2) NOT NULL DEFAULT 0,
  grand_total numeric(14,2) NOT NULL DEFAULT 0,
  amount_paid numeric(14,2) NOT NULL DEFAULT 0,
  amount_due numeric(14,2) NOT NULL DEFAULT 0,
  notes text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uk_sales_invoices_number UNIQUE (tenant_id, invoice_number)
);

CREATE INDEX idx_sales_invoices_tenant_date ON sales_invoices(tenant_id, invoice_date DESC);

CREATE TABLE sales_invoice_items (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_sales_invoice_items_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  sales_invoice_id uuid NOT NULL REFERENCES sales_invoices(id) ON DELETE CASCADE,
  variant_id uuid NOT NULL REFERENCES product_variants(id),
  product_name varchar(255) NOT NULL,
  sku varchar(100),
  quantity numeric(14,3) NOT NULL,
  unit_price numeric(14,2) NOT NULL,
  discount_amount numeric(14,2) NOT NULL DEFAULT 0,
  tax_rate numeric(5,2) NOT NULL DEFAULT 0,
  cgst_amount numeric(14,2) NOT NULL DEFAULT 0,
  sgst_amount numeric(14,2) NOT NULL DEFAULT 0,
  igst_amount numeric(14,2) NOT NULL DEFAULT 0,
  line_total numeric(14,2) NOT NULL
);

CREATE TABLE sales_payments (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_sales_payments_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  sales_invoice_id uuid NOT NULL REFERENCES sales_invoices(id) ON DELETE CASCADE,
  method varchar(32) NOT NULL,
  amount numeric(14,2) NOT NULL,
  reference varchar(255),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE held_carts (
  id uuid NOT NULL DEFAULT uuidv7() CONSTRAINT pk_held_carts_id PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES branches(id),
  user_id uuid NOT NULL REFERENCES users(id),
  label varchar(100),
  cart_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);

-- Enable RLS on phase 2 tenant tables
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'tax_rates','categories','brands','units','attribute_definitions','attribute_values',
    'products','product_variants','stock_levels','stock_movements','suppliers',
    'purchase_orders','purchase_order_items','grns','grn_items','purchase_invoices',
    'purchase_returns','purchase_return_items','customers','sales_invoices',
    'sales_invoice_items','sales_payments','held_carts'
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
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'held_carts','sales_payments','sales_invoice_items','sales_invoices','customers',
    'purchase_return_items','purchase_returns','purchase_invoices','grn_items','grns',
    'purchase_order_items','purchase_orders','suppliers','stock_movements','stock_levels',
    'product_variants','products','attribute_values','attribute_definitions','units',
    'brands','categories','tax_rates'
  ]
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', t);
  END LOOP;
END $$;

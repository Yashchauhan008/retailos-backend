\restrict dbmate

-- Dumped from database version 18.6 (Homebrew)
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: app_current_tenant_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_current_tenant_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid;
$$;


--
-- Name: app_is_super_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_is_super_admin() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT COALESCE(current_setting('app.is_super_admin', true), 'false') = 'true';
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attendance_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance_records (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    branch_id uuid,
    shift_id uuid,
    attendance_date date NOT NULL,
    check_in timestamp with time zone,
    check_out timestamp with time zone,
    status character varying(32) DEFAULT 'present'::character varying NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.attendance_records FORCE ROW LEVEL SECURITY;


--
-- Name: attribute_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attribute_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    code character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.attribute_definitions FORCE ROW LEVEL SECURITY;


--
-- Name: attribute_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attribute_values (
    id uuid DEFAULT uuidv7() NOT NULL,
    attribute_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    value character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.attribute_values FORCE ROW LEVEL SECURITY;


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid,
    actor_user_id uuid,
    actor_super_admin_id uuid,
    action character varying(100) NOT NULL,
    entity_type character varying(100),
    entity_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    ip_address character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.audit_logs FORCE ROW LEVEL SECURITY;


--
-- Name: branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branches (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    code character varying(64),
    phone character varying(32),
    email character varying(255),
    address_line1 text,
    city character varying(100),
    state character varying(100),
    pincode character varying(20),
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);

ALTER TABLE ONLY public.branches FORCE ROW LEVEL SECURITY;


--
-- Name: brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brands (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.brands FORCE ROW LEVEL SECURITY;


--
-- Name: cash_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cash_accounts (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    account_type character varying(32) DEFAULT 'cash'::character varying NOT NULL,
    opening_balance numeric(14,2) DEFAULT 0 NOT NULL,
    current_balance numeric(14,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.cash_accounts FORCE ROW LEVEL SECURITY;


--
-- Name: cash_ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cash_ledger_entries (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    account_id uuid NOT NULL,
    entry_date timestamp with time zone DEFAULT now() NOT NULL,
    direction character varying(16) NOT NULL,
    amount numeric(14,2) NOT NULL,
    balance_after numeric(14,2) NOT NULL,
    description text,
    ref_type character varying(64),
    ref_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.cash_ledger_entries FORCE ROW LEVEL SECURITY;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    parent_id uuid,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.categories FORCE ROW LEVEL SECURITY;


--
-- Name: coupons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coupons (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(255) NOT NULL,
    discount_type character varying(32) DEFAULT 'percent'::character varying NOT NULL,
    discount_value numeric(14,2) NOT NULL,
    min_order_amount numeric(14,2) DEFAULT 0 NOT NULL,
    max_discount numeric(14,2),
    usage_limit integer,
    used_count integer DEFAULT 0 NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.coupons FORCE ROW LEVEL SECURITY;


--
-- Name: customer_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_groups (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    discount_percent numeric(5,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.customer_groups FORCE ROW LEVEL SECURITY;


--
-- Name: customer_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_payments (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    branch_id uuid,
    amount numeric(14,2) NOT NULL,
    method character varying(32) DEFAULT 'cash'::character varying NOT NULL,
    reference character varying(255),
    notes text,
    sales_invoice_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.customer_payments FORCE ROW LEVEL SECURITY;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    phone character varying(32),
    email character varying(255),
    gstin character varying(32),
    address text,
    credit_limit numeric(14,2) DEFAULT 0 NOT NULL,
    outstanding numeric(14,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    customer_group_id uuid,
    loyalty_points numeric(14,2) DEFAULT 0 NOT NULL
);

ALTER TABLE ONLY public.customers FORCE ROW LEVEL SECURITY;


--
-- Name: daily_closings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_closings (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    closing_date date NOT NULL,
    opening_cash numeric(14,2) DEFAULT 0 NOT NULL,
    cash_sales numeric(14,2) DEFAULT 0 NOT NULL,
    cash_expenses numeric(14,2) DEFAULT 0 NOT NULL,
    expected_cash numeric(14,2) DEFAULT 0 NOT NULL,
    counted_cash numeric(14,2) DEFAULT 0 NOT NULL,
    variance numeric(14,2) DEFAULT 0 NOT NULL,
    total_sales numeric(14,2) DEFAULT 0 NOT NULL,
    total_returns numeric(14,2) DEFAULT 0 NOT NULL,
    notes text,
    closed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.daily_closings FORCE ROW LEVEL SECURITY;


--
-- Name: expense_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expense_categories (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.expense_categories FORCE ROW LEVEL SECURITY;


--
-- Name: expenses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expenses (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid,
    category_id uuid,
    title character varying(255) NOT NULL,
    amount numeric(14,2) NOT NULL,
    expense_date date DEFAULT CURRENT_DATE NOT NULL,
    payment_method character varying(32) DEFAULT 'cash'::character varying NOT NULL,
    notes text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.expenses FORCE ROW LEVEL SECURITY;


--
-- Name: files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.files (
    id uuid DEFAULT uuidv7() NOT NULL,
    key text NOT NULL,
    endpoint text DEFAULT 'http://localhost:3007/files'::text NOT NULL,
    url text GENERATED ALWAYS AS (((endpoint || '/'::text) || key)) STORED,
    _status character varying(100) DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: grn_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grn_items (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    grn_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    quantity numeric(14,3) NOT NULL,
    unit_cost numeric(14,2) DEFAULT 0 NOT NULL
);

ALTER TABLE ONLY public.grn_items FORCE ROW LEVEL SECURITY;


--
-- Name: grns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grns (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    purchase_order_id uuid,
    supplier_id uuid NOT NULL,
    grn_number character varying(64) NOT NULL,
    received_date date DEFAULT CURRENT_DATE NOT NULL,
    notes text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.grns FORCE ROW LEVEL SECURITY;


--
-- Name: held_carts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.held_carts (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    user_id uuid NOT NULL,
    label character varying(100),
    cart_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);

ALTER TABLE ONLY public.held_carts FORCE ROW LEVEL SECURITY;


--
-- Name: industries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.industries (
    id uuid DEFAULT uuidv7() NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: industry_feature_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.industry_feature_flags (
    id uuid DEFAULT uuidv7() NOT NULL,
    industry_id uuid NOT NULL,
    feature_key character varying(100) NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: inventory_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_batches (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    batch_number character varying(100) NOT NULL,
    expiry_date date,
    manufactured_date date,
    quantity numeric(14,3) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.inventory_batches FORCE ROW LEVEL SECURITY;


--
-- Name: inventory_forecasts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_forecasts (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    branch_id uuid,
    forecast_date date DEFAULT CURRENT_DATE NOT NULL,
    avg_daily_sales numeric(14,4) DEFAULT 0 NOT NULL,
    suggested_reorder_qty numeric(14,3) DEFAULT 0 NOT NULL,
    days_of_cover numeric(10,2) DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.inventory_forecasts FORCE ROW LEVEL SECURITY;


--
-- Name: loyalty_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.loyalty_settings (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    points_per_currency numeric(10,4) DEFAULT 1 NOT NULL,
    currency_per_point numeric(10,4) DEFAULT 0.25 NOT NULL,
    min_redeem_points numeric(14,2) DEFAULT 100 NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);

ALTER TABLE ONLY public.loyalty_settings FORCE ROW LEVEL SECURITY;


--
-- Name: loyalty_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.loyalty_transactions (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    points numeric(14,2) NOT NULL,
    direction character varying(16) NOT NULL,
    balance_after numeric(14,2) NOT NULL,
    ref_type character varying(64),
    ref_id uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.loyalty_transactions FORCE ROW LEVEL SECURITY;


--
-- Name: party_ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party_ledger_entries (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    party_type character varying(32) NOT NULL,
    party_id uuid NOT NULL,
    entry_date timestamp with time zone DEFAULT now() NOT NULL,
    direction character varying(16) NOT NULL,
    amount numeric(14,2) NOT NULL,
    balance_after numeric(14,2) DEFAULT 0 NOT NULL,
    description text,
    ref_type character varying(64),
    ref_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.party_ledger_entries FORCE ROW LEVEL SECURITY;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id uuid DEFAULT uuidv7() NOT NULL,
    key character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    module character varying(100) NOT NULL,
    description text
);


--
-- Name: plan_features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_features (
    id uuid DEFAULT uuidv7() NOT NULL,
    plan_id uuid NOT NULL,
    feature_key character varying(100) NOT NULL,
    enabled boolean DEFAULT true NOT NULL
);


--
-- Name: plan_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_limits (
    id uuid DEFAULT uuidv7() NOT NULL,
    plan_id uuid NOT NULL,
    limit_key character varying(100) NOT NULL,
    limit_value integer DEFAULT 0 NOT NULL
);


--
-- Name: plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plans (
    id uuid DEFAULT uuidv7() NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    price_monthly numeric(14,2) DEFAULT 0 NOT NULL,
    price_yearly numeric(14,2) DEFAULT 0 NOT NULL,
    trial_days integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: product_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_variants (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    product_id uuid NOT NULL,
    sku character varying(100) NOT NULL,
    barcode character varying(100),
    name character varying(255),
    selling_price numeric(14,2) DEFAULT 0 NOT NULL,
    cost_price numeric(14,2) DEFAULT 0 NOT NULL,
    mrp numeric(14,2),
    attrs jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);

ALTER TABLE ONLY public.product_variants FORCE ROW LEVEL SECURITY;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    category_id uuid,
    brand_id uuid,
    unit_id uuid,
    tax_rate_id uuid,
    name character varying(255) NOT NULL,
    description text,
    product_type character varying(32) DEFAULT 'simple'::character varying NOT NULL,
    track_inventory boolean DEFAULT true NOT NULL,
    low_stock_threshold numeric(14,3) DEFAULT 0 NOT NULL,
    image_url text,
    attrs jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);

ALTER TABLE ONLY public.products FORCE ROW LEVEL SECURITY;


--
-- Name: promotions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.promotions (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    promo_type character varying(64) DEFAULT 'bogo'::character varying NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.promotions FORCE ROW LEVEL SECURITY;


--
-- Name: purchase_invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_invoices (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    grn_id uuid,
    invoice_number character varying(64) NOT NULL,
    invoice_date date DEFAULT CURRENT_DATE NOT NULL,
    subtotal numeric(14,2) DEFAULT 0 NOT NULL,
    tax_total numeric(14,2) DEFAULT 0 NOT NULL,
    grand_total numeric(14,2) DEFAULT 0 NOT NULL,
    amount_paid numeric(14,2) DEFAULT 0 NOT NULL,
    status character varying(32) DEFAULT 'unpaid'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.purchase_invoices FORCE ROW LEVEL SECURITY;


--
-- Name: purchase_order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_order_items (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    purchase_order_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    quantity numeric(14,3) NOT NULL,
    received_qty numeric(14,3) DEFAULT 0 NOT NULL,
    unit_cost numeric(14,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(14,2) DEFAULT 0 NOT NULL,
    line_total numeric(14,2) DEFAULT 0 NOT NULL
);

ALTER TABLE ONLY public.purchase_order_items FORCE ROW LEVEL SECURITY;


--
-- Name: purchase_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_orders (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    po_number character varying(64) NOT NULL,
    status character varying(32) DEFAULT 'draft'::character varying NOT NULL,
    order_date date DEFAULT CURRENT_DATE NOT NULL,
    expected_date date,
    notes text,
    subtotal numeric(14,2) DEFAULT 0 NOT NULL,
    tax_total numeric(14,2) DEFAULT 0 NOT NULL,
    grand_total numeric(14,2) DEFAULT 0 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);

ALTER TABLE ONLY public.purchase_orders FORCE ROW LEVEL SECURITY;


--
-- Name: purchase_return_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_return_items (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    purchase_return_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    quantity numeric(14,3) NOT NULL,
    unit_cost numeric(14,2) DEFAULT 0 NOT NULL,
    line_total numeric(14,2) DEFAULT 0 NOT NULL
);

ALTER TABLE ONLY public.purchase_return_items FORCE ROW LEVEL SECURITY;


--
-- Name: purchase_returns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_returns (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    purchase_invoice_id uuid,
    return_number character varying(64) NOT NULL,
    return_date date DEFAULT CURRENT_DATE NOT NULL,
    reason text,
    grand_total numeric(14,2) DEFAULT 0 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.purchase_returns FORCE ROW LEVEL SECURITY;


--
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refresh_tokens (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid,
    super_admin_id uuid,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_refresh_tokens_owner CHECK ((((user_id IS NOT NULL) AND (super_admin_id IS NULL)) OR ((user_id IS NULL) AND (super_admin_id IS NOT NULL))))
);


--
-- Name: role_template_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_template_permissions (
    role_template_id uuid NOT NULL,
    permission_id uuid NOT NULL
);


--
-- Name: role_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_templates (
    id uuid DEFAULT uuidv7() NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_system boolean DEFAULT true NOT NULL
);


--
-- Name: sales_invoice_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_invoice_items (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    sales_invoice_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    product_name character varying(255) NOT NULL,
    sku character varying(100),
    quantity numeric(14,3) NOT NULL,
    unit_price numeric(14,2) NOT NULL,
    discount_amount numeric(14,2) DEFAULT 0 NOT NULL,
    tax_rate numeric(5,2) DEFAULT 0 NOT NULL,
    cgst_amount numeric(14,2) DEFAULT 0 NOT NULL,
    sgst_amount numeric(14,2) DEFAULT 0 NOT NULL,
    igst_amount numeric(14,2) DEFAULT 0 NOT NULL,
    line_total numeric(14,2) NOT NULL
);

ALTER TABLE ONLY public.sales_invoice_items FORCE ROW LEVEL SECURITY;


--
-- Name: sales_invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_invoices (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    customer_id uuid,
    invoice_number character varying(64) NOT NULL,
    invoice_date timestamp with time zone DEFAULT now() NOT NULL,
    status character varying(32) DEFAULT 'completed'::character varying NOT NULL,
    subtotal numeric(14,2) DEFAULT 0 NOT NULL,
    discount_total numeric(14,2) DEFAULT 0 NOT NULL,
    tax_total numeric(14,2) DEFAULT 0 NOT NULL,
    cgst_total numeric(14,2) DEFAULT 0 NOT NULL,
    sgst_total numeric(14,2) DEFAULT 0 NOT NULL,
    igst_total numeric(14,2) DEFAULT 0 NOT NULL,
    grand_total numeric(14,2) DEFAULT 0 NOT NULL,
    amount_paid numeric(14,2) DEFAULT 0 NOT NULL,
    amount_due numeric(14,2) DEFAULT 0 NOT NULL,
    notes text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.sales_invoices FORCE ROW LEVEL SECURITY;


--
-- Name: sales_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_payments (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    sales_invoice_id uuid NOT NULL,
    method character varying(32) NOT NULL,
    amount numeric(14,2) NOT NULL,
    reference character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.sales_payments FORCE ROW LEVEL SECURITY;


--
-- Name: sales_return_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_return_items (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    sales_return_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    product_name character varying(255) NOT NULL,
    quantity numeric(14,3) NOT NULL,
    unit_price numeric(14,2) NOT NULL,
    tax_amount numeric(14,2) DEFAULT 0 NOT NULL,
    line_total numeric(14,2) NOT NULL,
    restock boolean DEFAULT true NOT NULL
);

ALTER TABLE ONLY public.sales_return_items FORCE ROW LEVEL SECURITY;


--
-- Name: sales_returns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_returns (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    sales_invoice_id uuid,
    customer_id uuid,
    return_number character varying(64) NOT NULL,
    return_date timestamp with time zone DEFAULT now() NOT NULL,
    return_type character varying(32) DEFAULT 'refund'::character varying NOT NULL,
    reason text,
    subtotal numeric(14,2) DEFAULT 0 NOT NULL,
    tax_total numeric(14,2) DEFAULT 0 NOT NULL,
    grand_total numeric(14,2) DEFAULT 0 NOT NULL,
    refund_method character varying(32),
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.sales_returns FORCE ROW LEVEL SECURITY;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: serial_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.serial_numbers (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid,
    variant_id uuid NOT NULL,
    serial_value character varying(255) NOT NULL,
    serial_type character varying(32) DEFAULT 'serial'::character varying NOT NULL,
    status character varying(32) DEFAULT 'in_stock'::character varying NOT NULL,
    sales_invoice_id uuid,
    warranty_months integer,
    warranty_expires_at date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.serial_numbers FORCE ROW LEVEL SECURITY;


--
-- Name: shifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shifts (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.shifts FORCE ROW LEVEL SECURITY;


--
-- Name: stock_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_levels (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    quantity numeric(14,3) DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.stock_levels FORCE ROW LEVEL SECURITY;


--
-- Name: stock_movements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_movements (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    movement_type character varying(64) NOT NULL,
    qty_delta numeric(14,3) NOT NULL,
    qty_after numeric(14,3) NOT NULL,
    reason text,
    ref_type character varying(64),
    ref_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.stock_movements FORCE ROW LEVEL SECURITY;


--
-- Name: stock_transfer_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_transfer_items (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    stock_transfer_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    quantity numeric(14,3) NOT NULL,
    received_qty numeric(14,3) DEFAULT 0 NOT NULL
);

ALTER TABLE ONLY public.stock_transfer_items FORCE ROW LEVEL SECURITY;


--
-- Name: stock_transfers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_transfers (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    transfer_number character varying(64) NOT NULL,
    from_branch_id uuid NOT NULL,
    to_branch_id uuid NOT NULL,
    status character varying(32) DEFAULT 'draft'::character varying NOT NULL,
    notes text,
    created_by uuid,
    received_by uuid,
    transferred_at timestamp with time zone,
    received_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.stock_transfers FORCE ROW LEVEL SECURITY;


--
-- Name: super_admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.super_admins (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash text NOT NULL,
    status character varying(32) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);


--
-- Name: supplier_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_payments (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    branch_id uuid,
    amount numeric(14,2) NOT NULL,
    method character varying(32) DEFAULT 'cash'::character varying NOT NULL,
    reference character varying(255),
    notes text,
    purchase_invoice_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.supplier_payments FORCE ROW LEVEL SECURITY;


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    contact_person character varying(255),
    phone character varying(32),
    email character varying(255),
    gstin character varying(32),
    address text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.suppliers FORCE ROW LEVEL SECURITY;


--
-- Name: tax_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tax_rates (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    hsn_sac character varying(32),
    cgst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    sgst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    igst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.tax_rates FORCE ROW LEVEL SECURITY;


--
-- Name: tenant_role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_role_permissions (
    tenant_role_id uuid NOT NULL,
    permission_id uuid NOT NULL
);

ALTER TABLE ONLY public.tenant_role_permissions FORCE ROW LEVEL SECURITY;


--
-- Name: tenant_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_roles (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_system boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.tenant_roles FORCE ROW LEVEL SECURITY;


--
-- Name: tenant_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_settings (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    key character varying(100) NOT NULL,
    value jsonb DEFAULT 'null'::jsonb NOT NULL
);

ALTER TABLE ONLY public.tenant_settings FORCE ROW LEVEL SECURITY;


--
-- Name: tenant_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_subscriptions (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    status character varying(32) DEFAULT 'trialing'::character varying NOT NULL,
    trial_ends_at timestamp with time zone,
    current_period_start timestamp with time zone DEFAULT now() NOT NULL,
    current_period_end timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);

ALTER TABLE ONLY public.tenant_subscriptions FORCE ROW LEVEL SECURITY;


--
-- Name: tenant_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_users (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    branch_id uuid,
    status character varying(32) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.tenant_users FORCE ROW LEVEL SECURITY;


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(100) NOT NULL,
    industry_id uuid,
    status character varying(32) DEFAULT 'active'::character varying NOT NULL,
    onboarding_step character varying(64) DEFAULT 'industry'::character varying NOT NULL,
    onboarding_completed boolean DEFAULT false NOT NULL,
    gstin character varying(32),
    phone character varying(32),
    email character varying(255),
    address_line1 text,
    address_line2 text,
    city character varying(100),
    state character varying(100),
    pincode character varying(20),
    country character varying(100) DEFAULT 'India'::character varying NOT NULL,
    logo_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);

ALTER TABLE ONLY public.tenants FORCE ROW LEVEL SECURITY;


--
-- Name: units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.units (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(64) NOT NULL,
    short_name character varying(16) NOT NULL,
    allow_decimal boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.units FORCE ROW LEVEL SECURITY;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    phone character varying(32),
    status character varying(32) DEFAULT 'active'::character varying NOT NULL,
    email_verified boolean DEFAULT false NOT NULL,
    last_login_at timestamp with time zone
);


--
-- Name: warranty_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.warranty_claims (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    serial_id uuid,
    customer_id uuid,
    claim_number character varying(64) NOT NULL,
    claim_date date DEFAULT CURRENT_DATE NOT NULL,
    issue_description text,
    status character varying(32) DEFAULT 'open'::character varying NOT NULL,
    resolution_notes text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.warranty_claims FORCE ROW LEVEL SECURITY;


--
-- Name: attendance_records pk_attendance_records_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT pk_attendance_records_id PRIMARY KEY (id);


--
-- Name: attribute_definitions pk_attribute_definitions_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attribute_definitions
    ADD CONSTRAINT pk_attribute_definitions_id PRIMARY KEY (id);


--
-- Name: attribute_values pk_attribute_values_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attribute_values
    ADD CONSTRAINT pk_attribute_values_id PRIMARY KEY (id);


--
-- Name: audit_logs pk_audit_logs_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT pk_audit_logs_id PRIMARY KEY (id);


--
-- Name: branches pk_branches_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT pk_branches_id PRIMARY KEY (id);


--
-- Name: brands pk_brands_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT pk_brands_id PRIMARY KEY (id);


--
-- Name: cash_accounts pk_cash_accounts_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_accounts
    ADD CONSTRAINT pk_cash_accounts_id PRIMARY KEY (id);


--
-- Name: cash_ledger_entries pk_cash_ledger_entries_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_ledger_entries
    ADD CONSTRAINT pk_cash_ledger_entries_id PRIMARY KEY (id);


--
-- Name: categories pk_categories_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT pk_categories_id PRIMARY KEY (id);


--
-- Name: coupons pk_coupons_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT pk_coupons_id PRIMARY KEY (id);


--
-- Name: customer_groups pk_customer_groups_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_groups
    ADD CONSTRAINT pk_customer_groups_id PRIMARY KEY (id);


--
-- Name: customer_payments pk_customer_payments_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_payments
    ADD CONSTRAINT pk_customer_payments_id PRIMARY KEY (id);


--
-- Name: customers pk_customers_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT pk_customers_id PRIMARY KEY (id);


--
-- Name: daily_closings pk_daily_closings_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_closings
    ADD CONSTRAINT pk_daily_closings_id PRIMARY KEY (id);


--
-- Name: expense_categories pk_expense_categories_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_categories
    ADD CONSTRAINT pk_expense_categories_id PRIMARY KEY (id);


--
-- Name: expenses pk_expenses_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT pk_expenses_id PRIMARY KEY (id);


--
-- Name: files pk_files_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT pk_files_id PRIMARY KEY (id);


--
-- Name: grn_items pk_grn_items_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grn_items
    ADD CONSTRAINT pk_grn_items_id PRIMARY KEY (id);


--
-- Name: grns pk_grns_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grns
    ADD CONSTRAINT pk_grns_id PRIMARY KEY (id);


--
-- Name: held_carts pk_held_carts_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_carts
    ADD CONSTRAINT pk_held_carts_id PRIMARY KEY (id);


--
-- Name: industries pk_industries_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industries
    ADD CONSTRAINT pk_industries_id PRIMARY KEY (id);


--
-- Name: industry_feature_flags pk_industry_feature_flags_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_feature_flags
    ADD CONSTRAINT pk_industry_feature_flags_id PRIMARY KEY (id);


--
-- Name: inventory_batches pk_inventory_batches_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_batches
    ADD CONSTRAINT pk_inventory_batches_id PRIMARY KEY (id);


--
-- Name: inventory_forecasts pk_inventory_forecasts_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_forecasts
    ADD CONSTRAINT pk_inventory_forecasts_id PRIMARY KEY (id);


--
-- Name: loyalty_settings pk_loyalty_settings_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_settings
    ADD CONSTRAINT pk_loyalty_settings_id PRIMARY KEY (id);


--
-- Name: loyalty_transactions pk_loyalty_transactions_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_transactions
    ADD CONSTRAINT pk_loyalty_transactions_id PRIMARY KEY (id);


--
-- Name: party_ledger_entries pk_party_ledger_entries_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_ledger_entries
    ADD CONSTRAINT pk_party_ledger_entries_id PRIMARY KEY (id);


--
-- Name: permissions pk_permissions_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT pk_permissions_id PRIMARY KEY (id);


--
-- Name: plan_features pk_plan_features_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT pk_plan_features_id PRIMARY KEY (id);


--
-- Name: plan_limits pk_plan_limits_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_limits
    ADD CONSTRAINT pk_plan_limits_id PRIMARY KEY (id);


--
-- Name: plans pk_plans_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT pk_plans_id PRIMARY KEY (id);


--
-- Name: product_variants pk_product_variants_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT pk_product_variants_id PRIMARY KEY (id);


--
-- Name: products pk_products_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT pk_products_id PRIMARY KEY (id);


--
-- Name: promotions pk_promotions_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promotions
    ADD CONSTRAINT pk_promotions_id PRIMARY KEY (id);


--
-- Name: purchase_invoices pk_purchase_invoices_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_invoices
    ADD CONSTRAINT pk_purchase_invoices_id PRIMARY KEY (id);


--
-- Name: purchase_order_items pk_purchase_order_items_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT pk_purchase_order_items_id PRIMARY KEY (id);


--
-- Name: purchase_orders pk_purchase_orders_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT pk_purchase_orders_id PRIMARY KEY (id);


--
-- Name: purchase_return_items pk_purchase_return_items_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_return_items
    ADD CONSTRAINT pk_purchase_return_items_id PRIMARY KEY (id);


--
-- Name: purchase_returns pk_purchase_returns_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_returns
    ADD CONSTRAINT pk_purchase_returns_id PRIMARY KEY (id);


--
-- Name: refresh_tokens pk_refresh_tokens_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT pk_refresh_tokens_id PRIMARY KEY (id);


--
-- Name: role_template_permissions pk_role_template_permissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_template_permissions
    ADD CONSTRAINT pk_role_template_permissions PRIMARY KEY (role_template_id, permission_id);


--
-- Name: role_templates pk_role_templates_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_templates
    ADD CONSTRAINT pk_role_templates_id PRIMARY KEY (id);


--
-- Name: sales_invoice_items pk_sales_invoice_items_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoice_items
    ADD CONSTRAINT pk_sales_invoice_items_id PRIMARY KEY (id);


--
-- Name: sales_invoices pk_sales_invoices_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoices
    ADD CONSTRAINT pk_sales_invoices_id PRIMARY KEY (id);


--
-- Name: sales_payments pk_sales_payments_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_payments
    ADD CONSTRAINT pk_sales_payments_id PRIMARY KEY (id);


--
-- Name: sales_return_items pk_sales_return_items_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_return_items
    ADD CONSTRAINT pk_sales_return_items_id PRIMARY KEY (id);


--
-- Name: sales_returns pk_sales_returns_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_returns
    ADD CONSTRAINT pk_sales_returns_id PRIMARY KEY (id);


--
-- Name: serial_numbers pk_serial_numbers_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_numbers
    ADD CONSTRAINT pk_serial_numbers_id PRIMARY KEY (id);


--
-- Name: shifts pk_shifts_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT pk_shifts_id PRIMARY KEY (id);


--
-- Name: stock_levels pk_stock_levels_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_levels
    ADD CONSTRAINT pk_stock_levels_id PRIMARY KEY (id);


--
-- Name: stock_movements pk_stock_movements_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT pk_stock_movements_id PRIMARY KEY (id);


--
-- Name: stock_transfer_items pk_stock_transfer_items_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfer_items
    ADD CONSTRAINT pk_stock_transfer_items_id PRIMARY KEY (id);


--
-- Name: stock_transfers pk_stock_transfers_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfers
    ADD CONSTRAINT pk_stock_transfers_id PRIMARY KEY (id);


--
-- Name: super_admins pk_super_admins_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.super_admins
    ADD CONSTRAINT pk_super_admins_id PRIMARY KEY (id);


--
-- Name: supplier_payments pk_supplier_payments_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT pk_supplier_payments_id PRIMARY KEY (id);


--
-- Name: suppliers pk_suppliers_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT pk_suppliers_id PRIMARY KEY (id);


--
-- Name: tax_rates pk_tax_rates_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_rates
    ADD CONSTRAINT pk_tax_rates_id PRIMARY KEY (id);


--
-- Name: tenant_role_permissions pk_tenant_role_permissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_role_permissions
    ADD CONSTRAINT pk_tenant_role_permissions PRIMARY KEY (tenant_role_id, permission_id);


--
-- Name: tenant_roles pk_tenant_roles_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_roles
    ADD CONSTRAINT pk_tenant_roles_id PRIMARY KEY (id);


--
-- Name: tenant_settings pk_tenant_settings_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT pk_tenant_settings_id PRIMARY KEY (id);


--
-- Name: tenant_subscriptions pk_tenant_subscriptions_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_subscriptions
    ADD CONSTRAINT pk_tenant_subscriptions_id PRIMARY KEY (id);


--
-- Name: tenant_users pk_tenant_users_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT pk_tenant_users_id PRIMARY KEY (id);


--
-- Name: tenants pk_tenants_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT pk_tenants_id PRIMARY KEY (id);


--
-- Name: units pk_units_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT pk_units_id PRIMARY KEY (id);


--
-- Name: users pk_users_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT pk_users_id PRIMARY KEY (id);


--
-- Name: warranty_claims pk_warranty_claims_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warranty_claims
    ADD CONSTRAINT pk_warranty_claims_id PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: attendance_records uk_attendance; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT uk_attendance UNIQUE (tenant_id, user_id, attendance_date);


--
-- Name: attribute_definitions uk_attribute_definitions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attribute_definitions
    ADD CONSTRAINT uk_attribute_definitions UNIQUE (tenant_id, code);


--
-- Name: coupons uk_coupons_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT uk_coupons_code UNIQUE (tenant_id, code);


--
-- Name: daily_closings uk_daily_closings; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_closings
    ADD CONSTRAINT uk_daily_closings UNIQUE (tenant_id, branch_id, closing_date);


--
-- Name: files uk_files_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT uk_files_key UNIQUE (key);


--
-- Name: grns uk_grns_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grns
    ADD CONSTRAINT uk_grns_number UNIQUE (tenant_id, grn_number);


--
-- Name: industries uk_industries_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industries
    ADD CONSTRAINT uk_industries_code UNIQUE (code);


--
-- Name: industry_feature_flags uk_industry_feature; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_feature_flags
    ADD CONSTRAINT uk_industry_feature UNIQUE (industry_id, feature_key);


--
-- Name: inventory_batches uk_inventory_batches; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_batches
    ADD CONSTRAINT uk_inventory_batches UNIQUE (tenant_id, branch_id, variant_id, batch_number);


--
-- Name: loyalty_settings uk_loyalty_settings_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_settings
    ADD CONSTRAINT uk_loyalty_settings_tenant UNIQUE (tenant_id);


--
-- Name: permissions uk_permissions_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT uk_permissions_key UNIQUE (key);


--
-- Name: plan_features uk_plan_feature; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT uk_plan_feature UNIQUE (plan_id, feature_key);


--
-- Name: plan_limits uk_plan_limit; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_limits
    ADD CONSTRAINT uk_plan_limit UNIQUE (plan_id, limit_key);


--
-- Name: plans uk_plans_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT uk_plans_code UNIQUE (code);


--
-- Name: product_variants uk_product_variants_sku; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT uk_product_variants_sku UNIQUE (tenant_id, sku);


--
-- Name: purchase_invoices uk_purchase_invoices_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_invoices
    ADD CONSTRAINT uk_purchase_invoices_number UNIQUE (tenant_id, invoice_number);


--
-- Name: purchase_orders uk_purchase_orders_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT uk_purchase_orders_number UNIQUE (tenant_id, po_number);


--
-- Name: purchase_returns uk_purchase_returns_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_returns
    ADD CONSTRAINT uk_purchase_returns_number UNIQUE (tenant_id, return_number);


--
-- Name: role_templates uk_role_templates_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_templates
    ADD CONSTRAINT uk_role_templates_code UNIQUE (code);


--
-- Name: sales_invoices uk_sales_invoices_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoices
    ADD CONSTRAINT uk_sales_invoices_number UNIQUE (tenant_id, invoice_number);


--
-- Name: sales_returns uk_sales_returns_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_returns
    ADD CONSTRAINT uk_sales_returns_number UNIQUE (tenant_id, return_number);


--
-- Name: serial_numbers uk_serial_numbers; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_numbers
    ADD CONSTRAINT uk_serial_numbers UNIQUE (tenant_id, serial_value);


--
-- Name: stock_levels uk_stock_levels; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_levels
    ADD CONSTRAINT uk_stock_levels UNIQUE (tenant_id, branch_id, variant_id);


--
-- Name: stock_transfers uk_stock_transfers_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfers
    ADD CONSTRAINT uk_stock_transfers_number UNIQUE (tenant_id, transfer_number);


--
-- Name: super_admins uk_super_admins_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.super_admins
    ADD CONSTRAINT uk_super_admins_email UNIQUE (email);


--
-- Name: tenant_roles uk_tenant_roles; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_roles
    ADD CONSTRAINT uk_tenant_roles UNIQUE (tenant_id, code);


--
-- Name: tenant_settings uk_tenant_settings; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT uk_tenant_settings UNIQUE (tenant_id, key);


--
-- Name: tenant_subscriptions uk_tenant_subscriptions_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_subscriptions
    ADD CONSTRAINT uk_tenant_subscriptions_tenant UNIQUE (tenant_id);


--
-- Name: tenant_users uk_tenant_users; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT uk_tenant_users UNIQUE (tenant_id, user_id);


--
-- Name: tenants uk_tenants_slug; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT uk_tenants_slug UNIQUE (slug);


--
-- Name: units uk_units_tenant_short; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT uk_units_tenant_short UNIQUE (tenant_id, short_name);


--
-- Name: users uk_users_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT uk_users_email UNIQUE (email);


--
-- Name: warranty_claims uk_warranty_claims_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warranty_claims
    ADD CONSTRAINT uk_warranty_claims_number UNIQUE (tenant_id, claim_number);


--
-- Name: idx_audit_logs_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_tenant ON public.audit_logs USING btree (tenant_id, created_at DESC);


--
-- Name: idx_branches_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branches_tenant ON public.branches USING btree (tenant_id);


--
-- Name: idx_customers_tenant_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_tenant_phone ON public.customers USING btree (tenant_id, phone);


--
-- Name: idx_party_ledger_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_party_ledger_party ON public.party_ledger_entries USING btree (tenant_id, party_type, party_id, entry_date DESC);


--
-- Name: idx_products_tenant_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_tenant_name ON public.products USING btree (tenant_id, name);


--
-- Name: idx_sales_invoices_tenant_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_invoices_tenant_date ON public.sales_invoices USING btree (tenant_id, invoice_date DESC);


--
-- Name: idx_stock_movements_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movements_tenant ON public.stock_movements USING btree (tenant_id, created_at DESC);


--
-- Name: idx_tenant_users_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tenant_users_user ON public.tenant_users USING btree (user_id);


--
-- Name: uk_product_variants_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uk_product_variants_barcode ON public.product_variants USING btree (tenant_id, barcode) WHERE (barcode IS NOT NULL);


--
-- Name: attendance_records attendance_records_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: attendance_records attendance_records_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id);


--
-- Name: attendance_records attendance_records_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: attendance_records attendance_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: attribute_definitions attribute_definitions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attribute_definitions
    ADD CONSTRAINT attribute_definitions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: attribute_values attribute_values_attribute_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attribute_values
    ADD CONSTRAINT attribute_values_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES public.attribute_definitions(id) ON DELETE CASCADE;


--
-- Name: attribute_values attribute_values_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attribute_values
    ADD CONSTRAINT attribute_values_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: audit_logs audit_logs_actor_super_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_super_admin_id_fkey FOREIGN KEY (actor_super_admin_id) REFERENCES public.super_admins(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;


--
-- Name: branches branches_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: brands brands_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: cash_accounts cash_accounts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_accounts
    ADD CONSTRAINT cash_accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: cash_ledger_entries cash_ledger_entries_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_ledger_entries
    ADD CONSTRAINT cash_ledger_entries_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.cash_accounts(id) ON DELETE CASCADE;


--
-- Name: cash_ledger_entries cash_ledger_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_ledger_entries
    ADD CONSTRAINT cash_ledger_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: cash_ledger_entries cash_ledger_entries_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_ledger_entries
    ADD CONSTRAINT cash_ledger_entries_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: categories categories_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: coupons coupons_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT coupons_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: customer_groups customer_groups_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_groups
    ADD CONSTRAINT customer_groups_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: customer_payments customer_payments_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_payments
    ADD CONSTRAINT customer_payments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: customer_payments customer_payments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_payments
    ADD CONSTRAINT customer_payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: customer_payments customer_payments_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_payments
    ADD CONSTRAINT customer_payments_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: customer_payments customer_payments_sales_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_payments
    ADD CONSTRAINT customer_payments_sales_invoice_id_fkey FOREIGN KEY (sales_invoice_id) REFERENCES public.sales_invoices(id);


--
-- Name: customer_payments customer_payments_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_payments
    ADD CONSTRAINT customer_payments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: customers customers_customer_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id);


--
-- Name: customers customers_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: daily_closings daily_closings_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_closings
    ADD CONSTRAINT daily_closings_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: daily_closings daily_closings_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_closings
    ADD CONSTRAINT daily_closings_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES public.users(id);


--
-- Name: daily_closings daily_closings_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_closings
    ADD CONSTRAINT daily_closings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: expense_categories expense_categories_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_categories
    ADD CONSTRAINT expense_categories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: expenses expenses_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: expenses expenses_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.expense_categories(id);


--
-- Name: expenses expenses_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: expenses expenses_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: grn_items grn_items_grn_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grn_items
    ADD CONSTRAINT grn_items_grn_id_fkey FOREIGN KEY (grn_id) REFERENCES public.grns(id) ON DELETE CASCADE;


--
-- Name: grn_items grn_items_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grn_items
    ADD CONSTRAINT grn_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: grn_items grn_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grn_items
    ADD CONSTRAINT grn_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: grns grns_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grns
    ADD CONSTRAINT grns_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: grns grns_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grns
    ADD CONSTRAINT grns_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: grns grns_purchase_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grns
    ADD CONSTRAINT grns_purchase_order_id_fkey FOREIGN KEY (purchase_order_id) REFERENCES public.purchase_orders(id);


--
-- Name: grns grns_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grns
    ADD CONSTRAINT grns_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: grns grns_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grns
    ADD CONSTRAINT grns_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: held_carts held_carts_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_carts
    ADD CONSTRAINT held_carts_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: held_carts held_carts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_carts
    ADD CONSTRAINT held_carts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: held_carts held_carts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.held_carts
    ADD CONSTRAINT held_carts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: industry_feature_flags industry_feature_flags_industry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_feature_flags
    ADD CONSTRAINT industry_feature_flags_industry_id_fkey FOREIGN KEY (industry_id) REFERENCES public.industries(id) ON DELETE CASCADE;


--
-- Name: inventory_batches inventory_batches_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_batches
    ADD CONSTRAINT inventory_batches_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: inventory_batches inventory_batches_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_batches
    ADD CONSTRAINT inventory_batches_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: inventory_batches inventory_batches_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_batches
    ADD CONSTRAINT inventory_batches_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: inventory_forecasts inventory_forecasts_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_forecasts
    ADD CONSTRAINT inventory_forecasts_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: inventory_forecasts inventory_forecasts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_forecasts
    ADD CONSTRAINT inventory_forecasts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: inventory_forecasts inventory_forecasts_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_forecasts
    ADD CONSTRAINT inventory_forecasts_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: loyalty_settings loyalty_settings_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_settings
    ADD CONSTRAINT loyalty_settings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: loyalty_transactions loyalty_transactions_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_transactions
    ADD CONSTRAINT loyalty_transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: loyalty_transactions loyalty_transactions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_transactions
    ADD CONSTRAINT loyalty_transactions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: party_ledger_entries party_ledger_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_ledger_entries
    ADD CONSTRAINT party_ledger_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: party_ledger_entries party_ledger_entries_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_ledger_entries
    ADD CONSTRAINT party_ledger_entries_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: plan_features plan_features_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT plan_features_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE CASCADE;


--
-- Name: plan_limits plan_limits_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_limits
    ADD CONSTRAINT plan_limits_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE CASCADE;


--
-- Name: product_variants product_variants_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT product_variants_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: product_variants product_variants_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT product_variants_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: products products_brand_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id) ON DELETE SET NULL;


--
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: products products_tax_rate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_tax_rate_id_fkey FOREIGN KEY (tax_rate_id) REFERENCES public.tax_rates(id) ON DELETE SET NULL;


--
-- Name: products products_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: products products_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id) ON DELETE SET NULL;


--
-- Name: promotions promotions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promotions
    ADD CONSTRAINT promotions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: purchase_invoices purchase_invoices_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_invoices
    ADD CONSTRAINT purchase_invoices_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: purchase_invoices purchase_invoices_grn_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_invoices
    ADD CONSTRAINT purchase_invoices_grn_id_fkey FOREIGN KEY (grn_id) REFERENCES public.grns(id);


--
-- Name: purchase_invoices purchase_invoices_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_invoices
    ADD CONSTRAINT purchase_invoices_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: purchase_invoices purchase_invoices_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_invoices
    ADD CONSTRAINT purchase_invoices_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: purchase_order_items purchase_order_items_purchase_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_purchase_order_id_fkey FOREIGN KEY (purchase_order_id) REFERENCES public.purchase_orders(id) ON DELETE CASCADE;


--
-- Name: purchase_order_items purchase_order_items_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: purchase_order_items purchase_order_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: purchase_orders purchase_orders_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: purchase_orders purchase_orders_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: purchase_orders purchase_orders_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: purchase_orders purchase_orders_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: purchase_return_items purchase_return_items_purchase_return_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_return_items
    ADD CONSTRAINT purchase_return_items_purchase_return_id_fkey FOREIGN KEY (purchase_return_id) REFERENCES public.purchase_returns(id) ON DELETE CASCADE;


--
-- Name: purchase_return_items purchase_return_items_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_return_items
    ADD CONSTRAINT purchase_return_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: purchase_return_items purchase_return_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_return_items
    ADD CONSTRAINT purchase_return_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: purchase_returns purchase_returns_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_returns
    ADD CONSTRAINT purchase_returns_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: purchase_returns purchase_returns_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_returns
    ADD CONSTRAINT purchase_returns_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: purchase_returns purchase_returns_purchase_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_returns
    ADD CONSTRAINT purchase_returns_purchase_invoice_id_fkey FOREIGN KEY (purchase_invoice_id) REFERENCES public.purchase_invoices(id);


--
-- Name: purchase_returns purchase_returns_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_returns
    ADD CONSTRAINT purchase_returns_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: purchase_returns purchase_returns_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_returns
    ADD CONSTRAINT purchase_returns_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_super_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_super_admin_id_fkey FOREIGN KEY (super_admin_id) REFERENCES public.super_admins(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: role_template_permissions role_template_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_template_permissions
    ADD CONSTRAINT role_template_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: role_template_permissions role_template_permissions_role_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_template_permissions
    ADD CONSTRAINT role_template_permissions_role_template_id_fkey FOREIGN KEY (role_template_id) REFERENCES public.role_templates(id) ON DELETE CASCADE;


--
-- Name: sales_invoice_items sales_invoice_items_sales_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoice_items
    ADD CONSTRAINT sales_invoice_items_sales_invoice_id_fkey FOREIGN KEY (sales_invoice_id) REFERENCES public.sales_invoices(id) ON DELETE CASCADE;


--
-- Name: sales_invoice_items sales_invoice_items_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoice_items
    ADD CONSTRAINT sales_invoice_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: sales_invoice_items sales_invoice_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoice_items
    ADD CONSTRAINT sales_invoice_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: sales_invoices sales_invoices_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoices
    ADD CONSTRAINT sales_invoices_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: sales_invoices sales_invoices_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoices
    ADD CONSTRAINT sales_invoices_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: sales_invoices sales_invoices_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoices
    ADD CONSTRAINT sales_invoices_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: sales_invoices sales_invoices_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_invoices
    ADD CONSTRAINT sales_invoices_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: sales_payments sales_payments_sales_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_payments
    ADD CONSTRAINT sales_payments_sales_invoice_id_fkey FOREIGN KEY (sales_invoice_id) REFERENCES public.sales_invoices(id) ON DELETE CASCADE;


--
-- Name: sales_payments sales_payments_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_payments
    ADD CONSTRAINT sales_payments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: sales_return_items sales_return_items_sales_return_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_return_items
    ADD CONSTRAINT sales_return_items_sales_return_id_fkey FOREIGN KEY (sales_return_id) REFERENCES public.sales_returns(id) ON DELETE CASCADE;


--
-- Name: sales_return_items sales_return_items_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_return_items
    ADD CONSTRAINT sales_return_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: sales_return_items sales_return_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_return_items
    ADD CONSTRAINT sales_return_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: sales_returns sales_returns_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_returns
    ADD CONSTRAINT sales_returns_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: sales_returns sales_returns_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_returns
    ADD CONSTRAINT sales_returns_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: sales_returns sales_returns_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_returns
    ADD CONSTRAINT sales_returns_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: sales_returns sales_returns_sales_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_returns
    ADD CONSTRAINT sales_returns_sales_invoice_id_fkey FOREIGN KEY (sales_invoice_id) REFERENCES public.sales_invoices(id);


--
-- Name: sales_returns sales_returns_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_returns
    ADD CONSTRAINT sales_returns_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: serial_numbers serial_numbers_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_numbers
    ADD CONSTRAINT serial_numbers_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: serial_numbers serial_numbers_sales_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_numbers
    ADD CONSTRAINT serial_numbers_sales_invoice_id_fkey FOREIGN KEY (sales_invoice_id) REFERENCES public.sales_invoices(id);


--
-- Name: serial_numbers serial_numbers_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_numbers
    ADD CONSTRAINT serial_numbers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: serial_numbers serial_numbers_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_numbers
    ADD CONSTRAINT serial_numbers_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: shifts shifts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: stock_levels stock_levels_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_levels
    ADD CONSTRAINT stock_levels_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: stock_levels stock_levels_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_levels
    ADD CONSTRAINT stock_levels_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: stock_levels stock_levels_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_levels
    ADD CONSTRAINT stock_levels_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id) ON DELETE CASCADE;


--
-- Name: stock_movements stock_movements_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT stock_movements_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: stock_movements stock_movements_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT stock_movements_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: stock_movements stock_movements_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT stock_movements_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: stock_movements stock_movements_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT stock_movements_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id) ON DELETE CASCADE;


--
-- Name: stock_transfer_items stock_transfer_items_stock_transfer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfer_items
    ADD CONSTRAINT stock_transfer_items_stock_transfer_id_fkey FOREIGN KEY (stock_transfer_id) REFERENCES public.stock_transfers(id) ON DELETE CASCADE;


--
-- Name: stock_transfer_items stock_transfer_items_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfer_items
    ADD CONSTRAINT stock_transfer_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: stock_transfer_items stock_transfer_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfer_items
    ADD CONSTRAINT stock_transfer_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: stock_transfers stock_transfers_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfers
    ADD CONSTRAINT stock_transfers_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: stock_transfers stock_transfers_from_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfers
    ADD CONSTRAINT stock_transfers_from_branch_id_fkey FOREIGN KEY (from_branch_id) REFERENCES public.branches(id);


--
-- Name: stock_transfers stock_transfers_received_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfers
    ADD CONSTRAINT stock_transfers_received_by_fkey FOREIGN KEY (received_by) REFERENCES public.users(id);


--
-- Name: stock_transfers stock_transfers_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfers
    ADD CONSTRAINT stock_transfers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: stock_transfers stock_transfers_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_transfers
    ADD CONSTRAINT stock_transfers_to_branch_id_fkey FOREIGN KEY (to_branch_id) REFERENCES public.branches(id);


--
-- Name: supplier_payments supplier_payments_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: supplier_payments supplier_payments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: supplier_payments supplier_payments_purchase_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_purchase_invoice_id_fkey FOREIGN KEY (purchase_invoice_id) REFERENCES public.purchase_invoices(id);


--
-- Name: supplier_payments supplier_payments_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: supplier_payments supplier_payments_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: suppliers suppliers_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tax_rates tax_rates_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_rates
    ADD CONSTRAINT tax_rates_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_role_permissions tenant_role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_role_permissions
    ADD CONSTRAINT tenant_role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: tenant_role_permissions tenant_role_permissions_tenant_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_role_permissions
    ADD CONSTRAINT tenant_role_permissions_tenant_role_id_fkey FOREIGN KEY (tenant_role_id) REFERENCES public.tenant_roles(id) ON DELETE CASCADE;


--
-- Name: tenant_roles tenant_roles_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_roles
    ADD CONSTRAINT tenant_roles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_settings tenant_settings_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT tenant_settings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_subscriptions tenant_subscriptions_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_subscriptions
    ADD CONSTRAINT tenant_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: tenant_subscriptions tenant_subscriptions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_subscriptions
    ADD CONSTRAINT tenant_subscriptions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_users tenant_users_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT tenant_users_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: tenant_users tenant_users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT tenant_users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.tenant_roles(id);


--
-- Name: tenant_users tenant_users_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT tenant_users_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_users tenant_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_users
    ADD CONSTRAINT tenant_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tenants tenants_industry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_industry_id_fkey FOREIGN KEY (industry_id) REFERENCES public.industries(id);


--
-- Name: units units_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: warranty_claims warranty_claims_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warranty_claims
    ADD CONSTRAINT warranty_claims_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: warranty_claims warranty_claims_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warranty_claims
    ADD CONSTRAINT warranty_claims_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: warranty_claims warranty_claims_serial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warranty_claims
    ADD CONSTRAINT warranty_claims_serial_id_fkey FOREIGN KEY (serial_id) REFERENCES public.serial_numbers(id);


--
-- Name: warranty_claims warranty_claims_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warranty_claims
    ADD CONSTRAINT warranty_claims_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: attendance_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

--
-- Name: attendance_records attendance_records_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_records_isolation ON public.attendance_records USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: attribute_definitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attribute_definitions ENABLE ROW LEVEL SECURITY;

--
-- Name: attribute_definitions attribute_definitions_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attribute_definitions_isolation ON public.attribute_definitions USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: attribute_values; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attribute_values ENABLE ROW LEVEL SECURITY;

--
-- Name: attribute_values attribute_values_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attribute_values_isolation ON public.attribute_values USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs audit_logs_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_isolation ON public.audit_logs USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: branches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

--
-- Name: branches branches_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branches_isolation ON public.branches USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: brands; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

--
-- Name: brands brands_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY brands_isolation ON public.brands USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: cash_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cash_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: cash_accounts cash_accounts_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cash_accounts_isolation ON public.cash_accounts USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: cash_ledger_entries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cash_ledger_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: cash_ledger_entries cash_ledger_entries_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cash_ledger_entries_isolation ON public.cash_ledger_entries USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: categories categories_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categories_isolation ON public.categories USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: coupons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

--
-- Name: coupons coupons_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coupons_isolation ON public.coupons USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: customer_groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customer_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: customer_groups customer_groups_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_groups_isolation ON public.customer_groups USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: customer_payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customer_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: customer_payments customer_payments_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_payments_isolation ON public.customer_payments USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: customers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

--
-- Name: customers customers_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customers_isolation ON public.customers USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: daily_closings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.daily_closings ENABLE ROW LEVEL SECURITY;

--
-- Name: daily_closings daily_closings_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY daily_closings_isolation ON public.daily_closings USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: expense_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: expense_categories expense_categories_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY expense_categories_isolation ON public.expense_categories USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: expenses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

--
-- Name: expenses expenses_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY expenses_isolation ON public.expenses USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: grn_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.grn_items ENABLE ROW LEVEL SECURITY;

--
-- Name: grn_items grn_items_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY grn_items_isolation ON public.grn_items USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: grns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.grns ENABLE ROW LEVEL SECURITY;

--
-- Name: grns grns_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY grns_isolation ON public.grns USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: held_carts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.held_carts ENABLE ROW LEVEL SECURITY;

--
-- Name: held_carts held_carts_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY held_carts_isolation ON public.held_carts USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: inventory_batches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory_batches inventory_batches_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inventory_batches_isolation ON public.inventory_batches USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: inventory_forecasts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.inventory_forecasts ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory_forecasts inventory_forecasts_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inventory_forecasts_isolation ON public.inventory_forecasts USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: loyalty_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.loyalty_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: loyalty_settings loyalty_settings_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY loyalty_settings_isolation ON public.loyalty_settings USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: loyalty_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.loyalty_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: loyalty_transactions loyalty_transactions_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY loyalty_transactions_isolation ON public.loyalty_transactions USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: party_ledger_entries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.party_ledger_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: party_ledger_entries party_ledger_entries_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY party_ledger_entries_isolation ON public.party_ledger_entries USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: product_variants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;

--
-- Name: product_variants product_variants_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY product_variants_isolation ON public.product_variants USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

--
-- Name: products products_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY products_isolation ON public.products USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: promotions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;

--
-- Name: promotions promotions_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY promotions_isolation ON public.promotions USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: purchase_invoices; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.purchase_invoices ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_invoices purchase_invoices_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY purchase_invoices_isolation ON public.purchase_invoices USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: purchase_order_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_order_items purchase_order_items_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY purchase_order_items_isolation ON public.purchase_order_items USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: purchase_orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_orders purchase_orders_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY purchase_orders_isolation ON public.purchase_orders USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: purchase_return_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.purchase_return_items ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_return_items purchase_return_items_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY purchase_return_items_isolation ON public.purchase_return_items USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: purchase_returns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.purchase_returns ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_returns purchase_returns_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY purchase_returns_isolation ON public.purchase_returns USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: sales_invoice_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_invoice_items ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_invoice_items sales_invoice_items_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sales_invoice_items_isolation ON public.sales_invoice_items USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: sales_invoices; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_invoices ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_invoices sales_invoices_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sales_invoices_isolation ON public.sales_invoices USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: sales_payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_payments sales_payments_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sales_payments_isolation ON public.sales_payments USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: sales_return_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_return_items ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_return_items sales_return_items_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sales_return_items_isolation ON public.sales_return_items USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: sales_returns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_returns ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_returns sales_returns_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sales_returns_isolation ON public.sales_returns USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: serial_numbers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.serial_numbers ENABLE ROW LEVEL SECURITY;

--
-- Name: serial_numbers serial_numbers_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY serial_numbers_isolation ON public.serial_numbers USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: shifts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;

--
-- Name: shifts shifts_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shifts_isolation ON public.shifts USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: stock_levels; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stock_levels ENABLE ROW LEVEL SECURITY;

--
-- Name: stock_levels stock_levels_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stock_levels_isolation ON public.stock_levels USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: stock_movements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

--
-- Name: stock_movements stock_movements_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stock_movements_isolation ON public.stock_movements USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: stock_transfer_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stock_transfer_items ENABLE ROW LEVEL SECURITY;

--
-- Name: stock_transfer_items stock_transfer_items_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stock_transfer_items_isolation ON public.stock_transfer_items USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: stock_transfers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stock_transfers ENABLE ROW LEVEL SECURITY;

--
-- Name: stock_transfers stock_transfers_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stock_transfers_isolation ON public.stock_transfers USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: supplier_payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.supplier_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: supplier_payments supplier_payments_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY supplier_payments_isolation ON public.supplier_payments USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: suppliers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

--
-- Name: suppliers suppliers_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY suppliers_isolation ON public.suppliers USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: tax_rates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tax_rates ENABLE ROW LEVEL SECURITY;

--
-- Name: tax_rates tax_rates_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tax_rates_isolation ON public.tax_rates USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: tenant_role_permissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_role_permissions ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_role_permissions tenant_role_permissions_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_role_permissions_isolation ON public.tenant_role_permissions USING ((public.app_is_super_admin() OR (EXISTS ( SELECT 1
   FROM public.tenant_roles tr
  WHERE ((tr.id = tenant_role_permissions.tenant_role_id) AND (tr.tenant_id = public.app_current_tenant_id())))))) WITH CHECK ((public.app_is_super_admin() OR (EXISTS ( SELECT 1
   FROM public.tenant_roles tr
  WHERE ((tr.id = tenant_role_permissions.tenant_role_id) AND (tr.tenant_id = public.app_current_tenant_id()))))));


--
-- Name: tenant_roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_roles tenant_roles_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_roles_isolation ON public.tenant_roles USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: tenant_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_settings tenant_settings_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_settings_isolation ON public.tenant_settings USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: tenant_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_subscriptions tenant_subscriptions_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_subscriptions_isolation ON public.tenant_subscriptions USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: tenant_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_users ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_users tenant_users_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_users_isolation ON public.tenant_users USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: tenants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

--
-- Name: tenants tenants_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenants_isolation ON public.tenants USING ((public.app_is_super_admin() OR (id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (id = public.app_current_tenant_id())));


--
-- Name: units; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;

--
-- Name: units units_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY units_isolation ON public.units USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- Name: warranty_claims; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.warranty_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: warranty_claims warranty_claims_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY warranty_claims_isolation ON public.warranty_claims USING ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id()))) WITH CHECK ((public.app_is_super_admin() OR (tenant_id = public.app_current_tenant_id())));


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20260213214937'),
    ('20261121100000'),
    ('20261121110000'),
    ('20261121200000'),
    ('20261121210000'),
    ('20261121220000');

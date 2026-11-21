import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { applyTenantRls } from '@/shared/middlewares/tenant-context.js';

function slugify(input: string) {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 80);
}

export async function createTenantForOwner(
  db: DatabaseClient,
  input: {
    userId: string;
    businessName: string;
    industryId: string;
    email: string;
  },
) {
  // Bypass RLS while creating the tenant row, then switch into tenant context
  await applyTenantRls(db, { isSuperAdmin: true });

  const baseSlug = slugify(input.businessName) || 'shop';
  let slug = baseSlug;
  let attempt = 0;
  while (await db.queryOne('SELECT id FROM tenants WHERE slug = $1', [slug])) {
    attempt += 1;
    slug = `${baseSlug}-${attempt}`;
  }

  const trialPlan = await db.queryOne<{ id: string; trial_days: number }>(
    `SELECT id, trial_days FROM plans WHERE code = 'trial' AND is_active = true`,
  );
  if (!trialPlan) throw new Error('Trial plan not found');

  const tenant = await db.queryOne<{ id: string }>(
    `INSERT INTO tenants (name, slug, industry_id, email, onboarding_step, status)
     VALUES ($1, $2, $3, $4, 'business_profile', 'active')
     RETURNING id`,
    [input.businessName, slug, input.industryId, input.email],
  );
  if (!tenant) throw new Error('Failed to create tenant');

  await applyTenantRls(db, { tenantId: tenant.id });

  const trialEnds = new Date();
  trialEnds.setDate(trialEnds.getDate() + (trialPlan.trial_days || 14));

  await db.query(
    `INSERT INTO tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at, current_period_end)
     VALUES ($1, $2, 'trialing', $3, $3)`,
    [tenant.id, trialPlan.id, trialEnds.toISOString()],
  );

  const branch = await db.queryOne<{ id: string }>(
    `INSERT INTO branches (tenant_id, name, code, is_default, is_active)
     VALUES ($1, 'Main Branch', 'MAIN', true, true)
     RETURNING id`,
    [tenant.id],
  );

  // Copy role templates into tenant roles
  const templates = await db.queryAll<{ id: string; code: string; name: string; description: string }>(
    `SELECT id, code, name, description FROM role_templates`,
  );

  let ownerRoleId: string | null = null;
  for (const template of templates) {
    const role = await db.queryOne<{ id: string }>(
      `INSERT INTO tenant_roles (tenant_id, code, name, description, is_system)
       VALUES ($1, $2, $3, $4, true) RETURNING id`,
      [tenant.id, template.code, template.name, template.description],
    );
    if (!role) continue;

    await db.query(
      `INSERT INTO tenant_role_permissions (tenant_role_id, permission_id)
       SELECT $1, permission_id FROM role_template_permissions WHERE role_template_id = $2`,
      [role.id, template.id],
    );

    if (template.code === 'owner') ownerRoleId = role.id;
  }

  if (!ownerRoleId) throw new Error('Owner role not created');

  const tenantUser = await db.queryOne<{ id: string }>(
    `INSERT INTO tenant_users (tenant_id, user_id, role_id, branch_id, status)
     VALUES ($1, $2, $3, $4, 'active') RETURNING id`,
    [tenant.id, input.userId, ownerRoleId, branch?.id ?? null],
  );

  // Default settings
  const defaults: Record<string, unknown> = {
    currency: 'INR',
    timezone: 'Asia/Kolkata',
    invoice_prefix: 'INV',
    po_prefix: 'PO',
    grn_prefix: 'GRN',
    fiscal_year_start_month: 4,
    place_of_supply_state: null,
    tax_inclusive: false,
  };

  for (const [key, value] of Object.entries(defaults)) {
    await db.query(
      `INSERT INTO tenant_settings (tenant_id, key, value) VALUES ($1, $2, $3::jsonb)`,
      [tenant.id, key, JSON.stringify(value)],
    );
  }

  // Copy industry feature flags into settings
  const flags = await db.queryAll<{ feature_key: string; enabled: boolean; config: unknown }>(
    `SELECT feature_key, enabled, config FROM industry_feature_flags WHERE industry_id = $1`,
    [input.industryId],
  );
  await db.query(
    `INSERT INTO tenant_settings (tenant_id, key, value) VALUES ($1, 'industry_features', $2::jsonb)`,
    [tenant.id, JSON.stringify(flags)],
  );

  // Default units
  const units = [
    ['Piece', 'pcs', false],
    ['Kilogram', 'kg', true],
    ['Gram', 'g', true],
    ['Litre', 'ltr', true],
    ['Meter', 'm', true],
  ] as const;
  for (const [name, shortName, allowDecimal] of units) {
    await db.query(
      `INSERT INTO units (tenant_id, name, short_name, allow_decimal) VALUES ($1, $2, $3, $4)`,
      [tenant.id, name, shortName, allowDecimal],
    );
  }

  // Default GST rates
  const taxes = [
    ['GST 0%', 0, 0, 0],
    ['GST 5%', 2.5, 2.5, 5],
    ['GST 12%', 6, 6, 12],
    ['GST 18%', 9, 9, 18],
    ['GST 28%', 14, 14, 28],
  ] as const;
  for (const [name, cgst, sgst, igst] of taxes) {
    await db.query(
      `INSERT INTO tax_rates (tenant_id, name, cgst_rate, sgst_rate, igst_rate)
       VALUES ($1, $2, $3, $4, $5)`,
      [tenant.id, name, cgst, sgst, igst],
    );
  }

  return {
    tenant_id: tenant.id,
    tenant_user_id: tenantUser?.id,
    role_id: ownerRoleId,
    branch_id: branch?.id,
  };
}

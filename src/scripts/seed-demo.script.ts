/**
 * Demo seed helper — run after migrations with:
 * npx tsx src/scripts/seed-demo.script.ts
 */
import bcrypt from 'bcryptjs';
import Database from '@/shared/helpers/database.helper.js';
import { createTenantForOwner } from '@/shared/services/tenant-bootstrap.service.js';
import { applyStockChange } from '@/shared/services/stock.service.js';

async function main() {
  const db = await Database.getConnection();
  await db.begin();
  try {
    const clothing = await db.queryOne<{ id: string }>(
      `SELECT id FROM industries WHERE code = 'clothing'`,
    );
    if (!clothing) throw new Error('Industries not seeded');

    const email = 'demo@retailos.com';
    let user = await db.queryOne<{ id: string }>('SELECT id FROM users WHERE email = $1', [email]);
    if (!user) {
      const hash = await bcrypt.hash('Demo@123', 10);
      user = await db.queryOne<{ id: string }>(
        `INSERT INTO users (name, email, password_hash, status, email_verified)
         VALUES ('Demo Owner', $1, $2, 'active', true) RETURNING id`,
        [email, hash],
      );
      const ctx = await createTenantForOwner(db, {
        userId: user!.id,
        businessName: 'Demo Clothing Co',
        industryId: clothing.id,
        email,
      });
      await db.query(
        `UPDATE tenants SET onboarding_completed = true, onboarding_step = 'done' WHERE id = $1`,
        [ctx.tenant_id],
      );

      const unit = await db.queryOne<{ id: string }>(
        `SELECT id FROM units WHERE tenant_id = $1 AND short_name = 'pcs'`,
        [ctx.tenant_id],
      );
      const tax = await db.queryOne<{ id: string }>(
        `SELECT id FROM tax_rates WHERE tenant_id = $1 AND name = 'GST 18%'`,
        [ctx.tenant_id],
      );
      const product = await db.queryOne<{ id: string }>(
        `INSERT INTO products (tenant_id, name, unit_id, tax_rate_id, product_type)
         VALUES ($1, 'Classic Tee', $2, $3, 'variant') RETURNING id`,
        [ctx.tenant_id, unit!.id, tax!.id],
      );
      const variant = await db.queryOne<{ id: string }>(
        `INSERT INTO product_variants (tenant_id, product_id, sku, barcode, selling_price, cost_price, attrs)
         VALUES ($1,$2,'TEE-BLK-M','8901001001',799,350,'{"size":"M","color":"Black"}'::jsonb)
         RETURNING id`,
        [ctx.tenant_id, product!.id],
      );
      await applyStockChange(db, {
        tenantId: ctx.tenant_id,
        branchId: ctx.branch_id!,
        variantId: variant!.id,
        qtyDelta: 50,
        movementType: 'adjustment',
        reason: 'Demo opening stock',
      });
      console.log('Demo tenant ready');
      console.log('Login: demo@retailos.com / Demo@123');
    } else {
      console.log('Demo user already exists: demo@retailos.com');
    }
    await db.commit();
  } catch (e) {
    await db.rollback();
    throw e;
  } finally {
    db.release();
    process.exit(0);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

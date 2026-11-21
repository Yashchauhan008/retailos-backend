import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import z from 'zod';

const variantSchema = z.object({
  sku: z.string().trim().min(1).max(100),
  barcode: z.string().trim().max(100).optional().nullable(),
  name: z.string().optional().nullable(),
  selling_price: z.number().nonnegative(),
  cost_price: z.number().nonnegative().optional(),
  mrp: z.number().nonnegative().optional().nullable(),
  attrs: z.record(z.string(), z.any()).optional(),
});

export const ValidationSchema = {
  category: {
    body: z.object({
      name: z.string().trim().min(1),
      parent_id: z.uuid().optional().nullable(),
      description: z.string().optional().nullable(),
    }),
  },
  brand: {
    body: z.object({ name: z.string().trim().min(1) }),
  },
  product: {
    body: z.object({
      name: z.string().trim().min(1),
      description: z.string().optional().nullable(),
      category_id: z.uuid().optional().nullable(),
      brand_id: z.uuid().optional().nullable(),
      unit_id: z.uuid().optional().nullable(),
      tax_rate_id: z.uuid().optional().nullable(),
      product_type: z.enum(['simple', 'variant']).default('simple'),
      track_inventory: z.boolean().optional(),
      low_stock_threshold: z.number().nonnegative().optional(),
      attrs: z.record(z.string(), z.any()).optional(),
      variants: z.array(variantSchema).min(1),
    }),
  },
  productUpdate: {
    body: z.object({
      name: z.string().trim().min(1).optional(),
      description: z.string().optional().nullable(),
      category_id: z.uuid().optional().nullable(),
      brand_id: z.uuid().optional().nullable(),
      unit_id: z.uuid().optional().nullable(),
      tax_rate_id: z.uuid().optional().nullable(),
      track_inventory: z.boolean().optional(),
      low_stock_threshold: z.number().nonnegative().optional(),
      is_active: z.boolean().optional(),
      attrs: z.record(z.string(), z.any()).optional(),
      variants: z.array(variantSchema.extend({ id: z.uuid().optional() })).optional(),
    }),
  },
};

export async function listCategories(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT * FROM categories WHERE tenant_id = $1 ORDER BY name`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createCategory(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.category.body>;
  const row = await db.queryOne(
    `INSERT INTO categories (tenant_id, name, parent_id, description)
     VALUES ($1,$2,$3,$4) RETURNING *`,
    [req.user!.tenant_id, body.name, body.parent_id ?? null, body.description ?? null],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function listBrands(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(`SELECT * FROM brands WHERE tenant_id = $1 ORDER BY name`, [
    req.user!.tenant_id,
  ]);
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createBrand(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.brand.body>;
  const row = await db.queryOne(
    `INSERT INTO brands (tenant_id, name) VALUES ($1,$2) RETURNING *`,
    [req.user!.tenant_id, body.name],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function listUnits(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(`SELECT * FROM units WHERE tenant_id = $1 ORDER BY name`, [
    req.user!.tenant_id,
  ]);
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function listTaxRates(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT * FROM tax_rates WHERE tenant_id = $1 AND is_active = true ORDER BY name`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function listProducts(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const q = String(req.query.q || '').trim();
  const rows = await db.queryAll(
    `SELECT p.*, c.name AS category_name, b.name AS brand_name, u.short_name AS unit,
      (SELECT json_agg(v.*) FROM product_variants v WHERE v.product_id = p.id) AS variants
     FROM products p
     LEFT JOIN categories c ON c.id = p.category_id
     LEFT JOIN brands b ON b.id = p.brand_id
     LEFT JOIN units u ON u.id = p.unit_id
     WHERE p.tenant_id = $1
       AND ($2 = '' OR p.name ILIKE '%' || $2 || '%')
     ORDER BY p.created_at DESC`,
    [req.user!.tenant_id, q],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function getProduct(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const product = await db.queryOne(
    `SELECT * FROM products WHERE id = $1 AND tenant_id = $2`,
    [req.params.id, req.user!.tenant_id],
  );
  if (!product) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Product not found' });
  const variants = await db.queryAll(
    `SELECT * FROM product_variants WHERE product_id = $1 ORDER BY created_at`,
    [product.id],
  );
  return res.status(STATUS_CODES.OK).json({ data: { ...product, variants } });
}

export async function createProduct(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.product.body>;
  await db.begin();
  try {
    const product = await db.queryOne(
      `INSERT INTO products
        (tenant_id, name, description, category_id, brand_id, unit_id, tax_rate_id,
         product_type, track_inventory, low_stock_threshold, attrs)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb)
       RETURNING *`,
      [
        req.user!.tenant_id,
        body.name,
        body.description ?? null,
        body.category_id ?? null,
        body.brand_id ?? null,
        body.unit_id ?? null,
        body.tax_rate_id ?? null,
        body.product_type,
        body.track_inventory ?? true,
        body.low_stock_threshold ?? 0,
        JSON.stringify(body.attrs ?? {}),
      ],
    );

    const variants = [];
    for (const v of body.variants) {
      const variant = await db.queryOne(
        `INSERT INTO product_variants
          (tenant_id, product_id, sku, barcode, name, selling_price, cost_price, mrp, attrs)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb) RETURNING *`,
        [
          req.user!.tenant_id,
          product!.id,
          v.sku,
          v.barcode ?? null,
          v.name ?? null,
          v.selling_price,
          v.cost_price ?? 0,
          v.mrp ?? null,
          JSON.stringify(v.attrs ?? {}),
        ],
      );
      variants.push(variant);
    }
    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: { ...product, variants } });
  } catch (error) {
    await db.rollback();
    throw error;
  }
}

export async function updateProduct(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.productUpdate.body>;
  const product = await db.queryOne(
    `UPDATE products SET
       name = COALESCE($3, name),
       description = COALESCE($4, description),
       category_id = COALESCE($5, category_id),
       brand_id = COALESCE($6, brand_id),
       unit_id = COALESCE($7, unit_id),
       tax_rate_id = COALESCE($8, tax_rate_id),
       track_inventory = COALESCE($9, track_inventory),
       low_stock_threshold = COALESCE($10, low_stock_threshold),
       is_active = COALESCE($11, is_active),
       attrs = COALESCE($12::jsonb, attrs),
       updated_at = now()
     WHERE id = $1 AND tenant_id = $2
     RETURNING *`,
    [
      req.params.id,
      req.user!.tenant_id,
      body.name ?? null,
      body.description ?? null,
      body.category_id ?? null,
      body.brand_id ?? null,
      body.unit_id ?? null,
      body.tax_rate_id ?? null,
      body.track_inventory ?? null,
      body.low_stock_threshold ?? null,
      body.is_active ?? null,
      body.attrs ? JSON.stringify(body.attrs) : null,
    ],
  );
  if (!product) return res.status(STATUS_CODES.NOT_FOUND).json({ message: 'Product not found' });

  if (body.variants) {
    for (const v of body.variants) {
      if (v.id) {
        await db.query(
          `UPDATE product_variants SET
             sku = $3, barcode = $4, name = $5, selling_price = $6,
             cost_price = $7, mrp = $8, attrs = $9::jsonb, updated_at = now()
           WHERE id = $1 AND tenant_id = $2`,
          [
            v.id,
            req.user!.tenant_id,
            v.sku,
            v.barcode ?? null,
            v.name ?? null,
            v.selling_price,
            v.cost_price ?? 0,
            v.mrp ?? null,
            JSON.stringify(v.attrs ?? {}),
          ],
        );
      } else {
        await db.query(
          `INSERT INTO product_variants
            (tenant_id, product_id, sku, barcode, name, selling_price, cost_price, mrp, attrs)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb)`,
          [
            req.user!.tenant_id,
            product.id,
            v.sku,
            v.barcode ?? null,
            v.name ?? null,
            v.selling_price,
            v.cost_price ?? 0,
            v.mrp ?? null,
            JSON.stringify(v.attrs ?? {}),
          ],
        );
      }
    }
  }

  return getProduct(req, res, next, db);
}

export async function searchCatalog(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const q = String(req.query.q || '').trim();
  const branchId = String(req.query.branch_id || req.user!.branch_id || '');
  const rows = await db.queryAll(
    `SELECT v.id AS variant_id, v.sku, v.barcode, v.selling_price, v.cost_price, v.attrs AS variant_attrs,
            p.id AS product_id, p.name AS product_name, p.track_inventory, p.product_type,
            u.allow_decimal, u.short_name AS unit,
            t.cgst_rate, t.sgst_rate, t.igst_rate, t.name AS tax_name,
            COALESCE(s.quantity, 0) AS stock_qty
     FROM product_variants v
     JOIN products p ON p.id = v.product_id
     LEFT JOIN units u ON u.id = p.unit_id
     LEFT JOIN tax_rates t ON t.id = p.tax_rate_id
     LEFT JOIN stock_levels s ON s.variant_id = v.id AND s.branch_id = $3::uuid
     WHERE v.tenant_id = $1 AND v.is_active = true AND p.is_active = true
       AND (
         $2 = '' OR p.name ILIKE '%' || $2 || '%' OR v.sku ILIKE '%' || $2 || '%'
         OR v.barcode = $2
       )
     ORDER BY p.name
     LIMIT 40`,
    [req.user!.tenant_id, q, branchId || null],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

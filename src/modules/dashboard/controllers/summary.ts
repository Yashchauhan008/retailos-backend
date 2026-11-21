import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';

export async function summary(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const from = String(req.query.from || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString());
  const to = String(req.query.to || new Date().toISOString());
  const tenantId = req.user!.tenant_id;

  const kpis = await db.queryOne(
    `SELECT
       COALESCE(SUM(grand_total),0)::text AS total_revenue,
       COUNT(*)::text AS total_orders,
       COALESCE(SUM(CASE WHEN customer_id IS NOT NULL THEN 1 ELSE 0 END),0)::text AS customer_orders
     FROM sales_invoices
     WHERE tenant_id = $1 AND invoice_date >= $2::timestamptz AND invoice_date <= $3::timestamptz
       AND status = 'completed'`,
    [tenantId, from, to],
  );

  const newCustomers = await db.queryOne<{ c: string }>(
    `SELECT COUNT(*)::text AS c FROM customers
     WHERE tenant_id = $1 AND created_at >= $2::timestamptz AND created_at <= $3::timestamptz`,
    [tenantId, from, to],
  );

  const revenueSeries = await db.queryAll(
    `SELECT to_char(date_trunc('day', invoice_date), 'YYYY-MM-DD') AS day,
            COALESCE(SUM(grand_total),0)::float AS revenue
     FROM sales_invoices
     WHERE tenant_id = $1 AND invoice_date >= $2::timestamptz AND invoice_date <= $3::timestamptz
       AND status = 'completed'
     GROUP BY 1 ORDER BY 1`,
    [tenantId, from, to],
  );

  const salesByCategory = await db.queryAll(
    `SELECT COALESCE(c.name, 'Uncategorized') AS category,
            COALESCE(SUM(si.line_total),0)::float AS amount
     FROM sales_invoice_items si
     JOIN sales_invoices s ON s.id = si.sales_invoice_id
     JOIN product_variants v ON v.id = si.variant_id
     JOIN products p ON p.id = v.product_id
     LEFT JOIN categories c ON c.id = p.category_id
     WHERE s.tenant_id = $1 AND s.invoice_date >= $2::timestamptz AND s.invoice_date <= $3::timestamptz
     GROUP BY 1 ORDER BY amount DESC
     LIMIT 8`,
    [tenantId, from, to],
  );

  const topProducts = await db.queryAll(
    `SELECT si.product_name, COUNT(*)::int AS orders, COALESCE(SUM(si.line_total),0)::float AS revenue
     FROM sales_invoice_items si
     JOIN sales_invoices s ON s.id = si.sales_invoice_id
     WHERE s.tenant_id = $1 AND s.invoice_date >= $2::timestamptz AND s.invoice_date <= $3::timestamptz
     GROUP BY si.product_name
     ORDER BY revenue DESC
     LIMIT 6`,
    [tenantId, from, to],
  );

  const recentOrders = await db.queryAll(
    `SELECT si.id, si.invoice_number, si.grand_total, si.invoice_date, si.status,
            COALESCE(c.name, 'Walk-in') AS customer_name
     FROM sales_invoices si
     LEFT JOIN customers c ON c.id = si.customer_id
     WHERE si.tenant_id = $1
     ORDER BY si.invoice_date DESC
     LIMIT 8`,
    [tenantId],
  );

  const lowStock = await db.queryOne<{ c: string }>(
    `SELECT COUNT(*)::text AS c
     FROM stock_levels sl
     JOIN product_variants v ON v.id = sl.variant_id
     JOIN products p ON p.id = v.product_id
     WHERE sl.tenant_id = $1 AND sl.quantity <= p.low_stock_threshold`,
    [tenantId],
  );

  return res.status(STATUS_CODES.OK).json({
    data: {
      kpis: {
        total_revenue: Number(kpis?.total_revenue || 0),
        total_orders: Number(kpis?.total_orders || 0),
        new_customers: Number(newCustomers?.c || 0),
        low_stock_items: Number(lowStock?.c || 0),
      },
      revenue_series: revenueSeries,
      sales_by_category: salesByCategory,
      top_products: topProducts,
      recent_orders: recentOrders,
      range: { from, to },
    },
  });
}

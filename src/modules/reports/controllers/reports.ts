import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';

function range(req: Request) {
  const from =
    String(req.query.from || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString());
  const to = String(req.query.to || new Date().toISOString());
  return { from, to };
}

export async function salesReport(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const { from, to } = range(req);
  const summary = await db.queryOne(
    `SELECT COUNT(*)::int AS invoices,
            COALESCE(SUM(grand_total),0)::float AS revenue,
            COALESCE(SUM(tax_total),0)::float AS tax,
            COALESCE(SUM(discount_total),0)::float AS discounts
     FROM sales_invoices
     WHERE tenant_id = $1 AND invoice_date >= $2::timestamptz AND invoice_date <= $3::timestamptz
       AND status = 'completed'`,
    [req.user!.tenant_id, from, to],
  );
  const byDay = await db.queryAll(
    `SELECT invoice_date::date AS day, COUNT(*)::int AS invoices, COALESCE(SUM(grand_total),0)::float AS revenue
     FROM sales_invoices
     WHERE tenant_id = $1 AND invoice_date >= $2::timestamptz AND invoice_date <= $3::timestamptz
     GROUP BY 1 ORDER BY 1`,
    [req.user!.tenant_id, from, to],
  );
  return res.status(STATUS_CODES.OK).json({ data: { summary, by_day: byDay, range: { from, to } } });
}

export async function purchaseReport(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const { from, to } = range(req);
  const summary = await db.queryOne(
    `SELECT COUNT(*)::int AS invoices,
            COALESCE(SUM(grand_total),0)::float AS total,
            COALESCE(SUM(amount_paid),0)::float AS paid
     FROM purchase_invoices
     WHERE tenant_id = $1 AND invoice_date >= $2::date AND invoice_date <= $3::date`,
    [req.user!.tenant_id, from.slice(0, 10), to.slice(0, 10)],
  );
  return res.status(STATUS_CODES.OK).json({ data: { summary, range: { from, to } } });
}

export async function inventoryValuation(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT p.name AS product_name, v.sku, sl.quantity,
            v.cost_price, v.selling_price,
            (sl.quantity * v.cost_price)::float AS stock_value,
            (sl.quantity * v.selling_price)::float AS retail_value
     FROM stock_levels sl
     JOIN product_variants v ON v.id = sl.variant_id
     JOIN products p ON p.id = v.product_id
     WHERE sl.tenant_id = $1 AND sl.quantity > 0
     ORDER BY stock_value DESC`,
    [req.user!.tenant_id],
  );
  const totals = rows.reduce(
    (acc, r) => {
      acc.stock_value += Number(r.stock_value || 0);
      acc.retail_value += Number(r.retail_value || 0);
      return acc;
    },
    { stock_value: 0, retail_value: 0 },
  );
  return res.status(STATUS_CODES.OK).json({ data: { rows, totals } });
}

export async function profitAndLoss(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const { from, to } = range(req);
  const sales = await db.queryOne<{ revenue: string; cogs: string }>(
    `SELECT
       COALESCE(SUM(si.grand_total),0)::text AS revenue,
       COALESCE(SUM(sii.quantity * v.cost_price),0)::text AS cogs
     FROM sales_invoices si
     JOIN sales_invoice_items sii ON sii.sales_invoice_id = si.id
     JOIN product_variants v ON v.id = sii.variant_id
     WHERE si.tenant_id = $1 AND si.invoice_date >= $2::timestamptz AND si.invoice_date <= $3::timestamptz
       AND si.status = 'completed'`,
    [req.user!.tenant_id, from, to],
  );
  const returns = await db.queryOne<{ total: string }>(
    `SELECT COALESCE(SUM(grand_total),0)::text AS total FROM sales_returns
     WHERE tenant_id = $1 AND return_date >= $2::timestamptz AND return_date <= $3::timestamptz`,
    [req.user!.tenant_id, from, to],
  );
  const expenses = await db.queryOne<{ total: string }>(
    `SELECT COALESCE(SUM(amount),0)::text AS total FROM expenses
     WHERE tenant_id = $1 AND expense_date >= $2::date AND expense_date <= $3::date`,
    [req.user!.tenant_id, from.slice(0, 10), to.slice(0, 10)],
  );

  const revenue = Number(sales?.revenue || 0);
  const cogs = Number(sales?.cogs || 0);
  const returnsTotal = Number(returns?.total || 0);
  const expenseTotal = Number(expenses?.total || 0);
  const gross = revenue - returnsTotal - cogs;
  const net = gross - expenseTotal;

  return res.status(STATUS_CODES.OK).json({
    data: {
      revenue,
      sales_returns: returnsTotal,
      cogs,
      gross_profit: Math.round((gross + Number.EPSILON) * 100) / 100,
      expenses: expenseTotal,
      net_profit: Math.round((net + Number.EPSILON) * 100) / 100,
      range: { from, to },
    },
  });
}

export async function gstReport(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const { from, to } = range(req);
  const output = await db.queryOne(
    `SELECT
       COALESCE(SUM(cgst_total),0)::float AS cgst,
       COALESCE(SUM(sgst_total),0)::float AS sgst,
       COALESCE(SUM(igst_total),0)::float AS igst,
       COALESCE(SUM(tax_total),0)::float AS tax_total,
       COALESCE(SUM(subtotal),0)::float AS taxable
     FROM sales_invoices
     WHERE tenant_id = $1 AND invoice_date >= $2::timestamptz AND invoice_date <= $3::timestamptz`,
    [req.user!.tenant_id, from, to],
  );
  const byRate = await db.queryAll(
    `SELECT tax_rate,
            COALESCE(SUM(cgst_amount + sgst_amount + igst_amount),0)::float AS tax,
            COALESCE(SUM(line_total),0)::float AS taxable_sales
     FROM sales_invoice_items sii
     JOIN sales_invoices si ON si.id = sii.sales_invoice_id
     WHERE si.tenant_id = $1 AND si.invoice_date >= $2::timestamptz AND si.invoice_date <= $3::timestamptz
     GROUP BY tax_rate
     ORDER BY tax_rate`,
    [req.user!.tenant_id, from, to],
  );
  return res.status(STATUS_CODES.OK).json({ data: { output, by_rate: byRate, range: { from, to } } });
}

export async function dailyClosingReport(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT dc.*, b.name AS branch_name
     FROM daily_closings dc
     JOIN branches b ON b.id = dc.branch_id
     WHERE dc.tenant_id = $1
     ORDER BY dc.closing_date DESC
     LIMIT 60`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

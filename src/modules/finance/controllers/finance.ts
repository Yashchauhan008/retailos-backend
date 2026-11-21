import type { NextFunction, Request, Response } from 'express';
import type { DatabaseClient } from '@/shared/helpers/database.helper.js';
import { STATUS_CODES } from '@/shared/constants/status-codes.js';
import {
  ensureDefaultCashAccount,
  postCashEntry,
  postPartyLedger,
  syncNewPermissionsToTenantOwners,
} from '@/shared/services/ledger.service.js';
import z from 'zod';

export const ValidationSchema = {
  expense: {
    body: z.object({
      title: z.string().trim().min(1),
      amount: z.number().positive(),
      expense_date: z.string().optional(),
      category_id: z.uuid().optional().nullable(),
      branch_id: z.uuid().optional().nullable(),
      payment_method: z.enum(['cash', 'upi', 'card', 'bank']).default('cash'),
      notes: z.string().optional().nullable(),
    }),
  },
  expenseCategory: {
    body: z.object({ name: z.string().trim().min(1) }),
  },
  customerPayment: {
    body: z.object({
      customer_id: z.uuid(),
      amount: z.number().positive(),
      method: z.enum(['cash', 'upi', 'card', 'bank']).default('cash'),
      reference: z.string().optional().nullable(),
      notes: z.string().optional().nullable(),
      sales_invoice_id: z.uuid().optional().nullable(),
      branch_id: z.uuid().optional().nullable(),
    }),
  },
  supplierPayment: {
    body: z.object({
      supplier_id: z.uuid(),
      amount: z.number().positive(),
      method: z.enum(['cash', 'upi', 'card', 'bank']).default('cash'),
      reference: z.string().optional().nullable(),
      notes: z.string().optional().nullable(),
      purchase_invoice_id: z.uuid().optional().nullable(),
      branch_id: z.uuid().optional().nullable(),
    }),
  },
  dailyClosing: {
    body: z.object({
      branch_id: z.uuid(),
      closing_date: z.string().optional(),
      counted_cash: z.number().nonnegative(),
      opening_cash: z.number().nonnegative().optional(),
      notes: z.string().optional().nullable(),
    }),
  },
};

async function bootstrapFinance(db: DatabaseClient, tenantId: string) {
  await syncNewPermissionsToTenantOwners(db, tenantId);
  await ensureDefaultCashAccount(db, tenantId);
  const cats = await db.queryOne(
    `SELECT id FROM expense_categories WHERE tenant_id = $1 LIMIT 1`,
    [tenantId],
  );
  if (!cats) {
    for (const name of ['Rent', 'Utilities', 'Salaries', 'Transport', 'Misc']) {
      await db.query(
        `INSERT INTO expense_categories (tenant_id, name) VALUES ($1, $2)`,
        [tenantId, name],
      );
    }
  }
}

export async function listExpenseCategories(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await bootstrapFinance(db, req.user!.tenant_id!);
  const rows = await db.queryAll(
    `SELECT * FROM expense_categories WHERE tenant_id = $1 ORDER BY name`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createExpenseCategory(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.expenseCategory.body>;
  const row = await db.queryOne(
    `INSERT INTO expense_categories (tenant_id, name) VALUES ($1,$2) RETURNING *`,
    [req.user!.tenant_id, body.name],
  );
  return res.status(STATUS_CODES.CREATED).json({ data: row });
}

export async function listExpenses(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await bootstrapFinance(db, req.user!.tenant_id!);
  const rows = await db.queryAll(
    `SELECT e.*, c.name AS category_name
     FROM expenses e
     LEFT JOIN expense_categories c ON c.id = e.category_id
     WHERE e.tenant_id = $1
     ORDER BY e.expense_date DESC, e.created_at DESC
     LIMIT 200`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function createExpense(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.expense.body>;
  await bootstrapFinance(db, req.user!.tenant_id!);
  await db.begin();
  try {
    const row = await db.queryOne(
      `INSERT INTO expenses
        (tenant_id, branch_id, category_id, title, amount, expense_date, payment_method, notes, created_by)
       VALUES ($1,$2,$3,$4,$5,COALESCE($6::date, CURRENT_DATE),$7,$8,$9) RETURNING *`,
      [
        req.user!.tenant_id,
        body.branch_id ?? req.user!.branch_id ?? null,
        body.category_id ?? null,
        body.title,
        body.amount,
        body.expense_date ?? null,
        body.payment_method,
        body.notes ?? null,
        req.user!.id,
      ],
    );

    const accounts = await ensureDefaultCashAccount(db, req.user!.tenant_id!);
    const accountId = body.payment_method === 'bank' ? accounts.bankId : accounts.cashId;
    await postCashEntry(db, {
      tenantId: req.user!.tenant_id!,
      accountId,
      direction: 'out',
      amount: body.amount,
      description: `Expense: ${body.title}`,
      refType: 'expense',
      refId: row!.id,
      userId: req.user!.id,
    });

    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: row });
  } catch (e) {
    await db.rollback();
    throw e;
  }
}

export async function listCashAccounts(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  await bootstrapFinance(db, req.user!.tenant_id!);
  const rows = await db.queryAll(
    `SELECT * FROM cash_accounts WHERE tenant_id = $1 ORDER BY account_type, name`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

async function ledgerByType(
  req: Request,
  res: Response,
  db: DatabaseClient,
  accountType: 'cash' | 'bank',
) {
  await bootstrapFinance(db, req.user!.tenant_id!);
  const rows = await db.queryAll(
    `SELECT e.*, a.name AS account_name
     FROM cash_ledger_entries e
     JOIN cash_accounts a ON a.id = e.account_id
     WHERE e.tenant_id = $1 AND a.account_type = $2
     ORDER BY e.entry_date DESC
     LIMIT 200`,
    [req.user!.tenant_id, accountType],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function cashbook(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  return ledgerByType(req, res, db, 'cash');
}

export async function bankbook(req: Request, res: Response, next: NextFunction, db: DatabaseClient) {
  return ledgerByType(req, res, db, 'bank');
}

export async function recordCustomerPayment(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.customerPayment.body>;
  await bootstrapFinance(db, req.user!.tenant_id!);
  await db.begin();
  try {
    const payment = await db.queryOne(
      `INSERT INTO customer_payments
        (tenant_id, customer_id, branch_id, amount, method, reference, notes, sales_invoice_id, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [
        req.user!.tenant_id,
        body.customer_id,
        body.branch_id ?? req.user!.branch_id ?? null,
        body.amount,
        body.method,
        body.reference ?? null,
        body.notes ?? null,
        body.sales_invoice_id ?? null,
        req.user!.id,
      ],
    );

    await db.query(
      `UPDATE customers SET outstanding = GREATEST(0, outstanding - $2) WHERE id = $1 AND tenant_id = $3`,
      [body.customer_id, body.amount, req.user!.tenant_id],
    );

    if (body.sales_invoice_id) {
      await db.query(
        `UPDATE sales_invoices
         SET amount_paid = amount_paid + $2,
             amount_due = GREATEST(0, amount_due - $2)
         WHERE id = $1 AND tenant_id = $3`,
        [body.sales_invoice_id, body.amount, req.user!.tenant_id],
      );
    }

    await postPartyLedger(db, {
      tenantId: req.user!.tenant_id!,
      partyType: 'customer',
      partyId: body.customer_id,
      direction: 'credit',
      amount: body.amount,
      description: 'Customer payment',
      refType: 'customer_payment',
      refId: payment!.id,
      userId: req.user!.id,
    });

    const accounts = await ensureDefaultCashAccount(db, req.user!.tenant_id!);
    await postCashEntry(db, {
      tenantId: req.user!.tenant_id!,
      accountId: body.method === 'bank' ? accounts.bankId : accounts.cashId,
      direction: 'in',
      amount: body.amount,
      description: 'Customer payment',
      refType: 'customer_payment',
      refId: payment!.id,
      userId: req.user!.id,
    });

    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: payment });
  } catch (e) {
    await db.rollback();
    throw e;
  }
}

export async function recordSupplierPayment(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.supplierPayment.body>;
  await bootstrapFinance(db, req.user!.tenant_id!);
  await db.begin();
  try {
    const payment = await db.queryOne(
      `INSERT INTO supplier_payments
        (tenant_id, supplier_id, branch_id, amount, method, reference, notes, purchase_invoice_id, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [
        req.user!.tenant_id,
        body.supplier_id,
        body.branch_id ?? req.user!.branch_id ?? null,
        body.amount,
        body.method,
        body.reference ?? null,
        body.notes ?? null,
        body.purchase_invoice_id ?? null,
        req.user!.id,
      ],
    );

    if (body.purchase_invoice_id) {
      await db.query(
        `UPDATE purchase_invoices
         SET amount_paid = amount_paid + $2,
             status = CASE WHEN amount_paid + $2 >= grand_total THEN 'paid' ELSE 'partial' END
         WHERE id = $1 AND tenant_id = $3`,
        [body.purchase_invoice_id, body.amount, req.user!.tenant_id],
      );
    }

    await postPartyLedger(db, {
      tenantId: req.user!.tenant_id!,
      partyType: 'supplier',
      partyId: body.supplier_id,
      direction: 'debit',
      amount: body.amount,
      description: 'Supplier payment',
      refType: 'supplier_payment',
      refId: payment!.id,
      userId: req.user!.id,
    });

    const accounts = await ensureDefaultCashAccount(db, req.user!.tenant_id!);
    await postCashEntry(db, {
      tenantId: req.user!.tenant_id!,
      accountId: body.method === 'bank' ? accounts.bankId : accounts.cashId,
      direction: 'out',
      amount: body.amount,
      description: 'Supplier payment',
      refType: 'supplier_payment',
      refId: payment!.id,
      userId: req.user!.id,
    });

    await db.commit();
    return res.status(STATUS_CODES.CREATED).json({ data: payment });
  } catch (e) {
    await db.rollback();
    throw e;
  }
}

export async function customerLedger(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT * FROM party_ledger_entries
     WHERE tenant_id = $1 AND party_type = 'customer' AND party_id = $2
     ORDER BY entry_date DESC LIMIT 200`,
    [req.user!.tenant_id, req.params.customerId],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function supplierLedger(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT * FROM party_ledger_entries
     WHERE tenant_id = $1 AND party_type = 'supplier' AND party_id = $2
     ORDER BY entry_date DESC LIMIT 200`,
    [req.user!.tenant_id, req.params.supplierId],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

export async function receivables(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT id, name, phone, outstanding, credit_limit
     FROM customers
     WHERE tenant_id = $1 AND outstanding > 0
     ORDER BY outstanding DESC`,
    [req.user!.tenant_id],
  );
  const invoices = await db.queryAll(
    `SELECT id, invoice_number, customer_id, grand_total, amount_due, invoice_date
     FROM sales_invoices
     WHERE tenant_id = $1 AND amount_due > 0
     ORDER BY invoice_date DESC`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: { customers: rows, invoices } });
}

export async function payables(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const invoices = await db.queryAll(
    `SELECT pi.*, s.name AS supplier_name,
            (pi.grand_total - pi.amount_paid) AS amount_due
     FROM purchase_invoices pi
     JOIN suppliers s ON s.id = pi.supplier_id
     WHERE pi.tenant_id = $1 AND pi.grand_total > pi.amount_paid
     ORDER BY pi.invoice_date DESC`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: invoices });
}

export async function dailyClosing(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const body = req.body as z.infer<typeof ValidationSchema.dailyClosing.body>;
  const date = body.closing_date || new Date().toISOString().slice(0, 10);

  const sales = await db.queryOne(
    `SELECT
       COALESCE(SUM(grand_total),0)::float AS total_sales,
       COALESCE(SUM(CASE WHEN EXISTS (
         SELECT 1 FROM sales_payments sp WHERE sp.sales_invoice_id = si.id AND sp.method = 'cash'
       ) THEN grand_total ELSE 0 END),0)::float AS cash_sales
     FROM sales_invoices si
     WHERE tenant_id = $1 AND branch_id = $2
       AND invoice_date::date = $3::date AND status = 'completed'`,
    [req.user!.tenant_id, body.branch_id, date],
  );

  const returns = await db.queryOne<{ total: string }>(
    `SELECT COALESCE(SUM(grand_total),0)::text AS total FROM sales_returns
     WHERE tenant_id = $1 AND branch_id = $2 AND return_date::date = $3::date`,
    [req.user!.tenant_id, body.branch_id, date],
  );

  const expenses = await db.queryOne<{ total: string }>(
    `SELECT COALESCE(SUM(amount),0)::text AS total FROM expenses
     WHERE tenant_id = $1 AND COALESCE(branch_id, $2) = $2
       AND expense_date = $3::date AND payment_method = 'cash'`,
    [req.user!.tenant_id, body.branch_id, date],
  );

  const opening = body.opening_cash ?? 0;
  const cashSales = Number(sales?.cash_sales || 0);
  const cashExpenses = Number(expenses?.total || 0);
  const expected = opening + cashSales - cashExpenses;
  const variance = body.counted_cash - expected;

  const row = await db.queryOne(
    `INSERT INTO daily_closings
      (tenant_id, branch_id, closing_date, opening_cash, cash_sales, cash_expenses,
       expected_cash, counted_cash, variance, total_sales, total_returns, notes, closed_by)
     VALUES ($1,$2,$3::date,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
     ON CONFLICT (tenant_id, branch_id, closing_date) DO UPDATE SET
       opening_cash = EXCLUDED.opening_cash,
       cash_sales = EXCLUDED.cash_sales,
       cash_expenses = EXCLUDED.cash_expenses,
       expected_cash = EXCLUDED.expected_cash,
       counted_cash = EXCLUDED.counted_cash,
       variance = EXCLUDED.variance,
       total_sales = EXCLUDED.total_sales,
       total_returns = EXCLUDED.total_returns,
       notes = EXCLUDED.notes,
       closed_by = EXCLUDED.closed_by
     RETURNING *`,
    [
      req.user!.tenant_id,
      body.branch_id,
      date,
      opening,
      cashSales,
      cashExpenses,
      expected,
      body.counted_cash,
      variance,
      Number(sales?.total_sales || 0),
      Number(returns?.total || 0),
      body.notes ?? null,
      req.user!.id,
    ],
  );

  return res.status(STATUS_CODES.OK).json({ data: row });
}

export async function listDailyClosings(
  req: Request,
  res: Response,
  next: NextFunction,
  db: DatabaseClient,
) {
  const rows = await db.queryAll(
    `SELECT * FROM daily_closings WHERE tenant_id = $1 ORDER BY closing_date DESC LIMIT 60`,
    [req.user!.tenant_id],
  );
  return res.status(STATUS_CODES.OK).json({ data: rows });
}

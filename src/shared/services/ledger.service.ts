import type { DatabaseClient } from '@/shared/helpers/database.helper.js';

export async function postPartyLedger(
  db: DatabaseClient,
  input: {
    tenantId: string;
    partyType: 'customer' | 'supplier';
    partyId: string;
    direction: 'debit' | 'credit';
    amount: number;
    description?: string;
    refType?: string;
    refId?: string;
    userId?: string;
  },
) {
  const last = await db.queryOne<{ balance_after: string }>(
    `SELECT balance_after FROM party_ledger_entries
     WHERE tenant_id = $1 AND party_type = $2 AND party_id = $3
     ORDER BY created_at DESC LIMIT 1`,
    [input.tenantId, input.partyType, input.partyId],
  );
  const prev = Number(last?.balance_after || 0);
  const delta = input.direction === 'debit' ? input.amount : -input.amount;
  const balanceAfter = Math.round((prev + delta + Number.EPSILON) * 100) / 100;

  await db.query(
    `INSERT INTO party_ledger_entries
      (tenant_id, party_type, party_id, direction, amount, balance_after, description, ref_type, ref_id, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
    [
      input.tenantId,
      input.partyType,
      input.partyId,
      input.direction,
      input.amount,
      balanceAfter,
      input.description ?? null,
      input.refType ?? null,
      input.refId ?? null,
      input.userId ?? null,
    ],
  );
  return balanceAfter;
}

export async function ensureDefaultCashAccount(db: DatabaseClient, tenantId: string) {
  let cash = await db.queryOne<{ id: string }>(
    `SELECT id FROM cash_accounts WHERE tenant_id = $1 AND account_type = 'cash' LIMIT 1`,
    [tenantId],
  );
  if (!cash) {
    cash = await db.queryOne<{ id: string }>(
      `INSERT INTO cash_accounts (tenant_id, name, account_type, opening_balance, current_balance)
       VALUES ($1, 'Main Cash', 'cash', 0, 0) RETURNING id`,
      [tenantId],
    );
  }
  let bank = await db.queryOne<{ id: string }>(
    `SELECT id FROM cash_accounts WHERE tenant_id = $1 AND account_type = 'bank' LIMIT 1`,
    [tenantId],
  );
  if (!bank) {
    bank = await db.queryOne<{ id: string }>(
      `INSERT INTO cash_accounts (tenant_id, name, account_type, opening_balance, current_balance)
       VALUES ($1, 'Main Bank', 'bank', 0, 0) RETURNING id`,
      [tenantId],
    );
  }
  return { cashId: cash!.id, bankId: bank!.id };
}

export async function postCashEntry(
  db: DatabaseClient,
  input: {
    tenantId: string;
    accountId: string;
    direction: 'in' | 'out';
    amount: number;
    description?: string;
    refType?: string;
    refId?: string;
    userId?: string;
  },
) {
  const account = await db.queryOne<{ id: string; current_balance: string }>(
    `SELECT id, current_balance FROM cash_accounts WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
    [input.accountId, input.tenantId],
  );
  if (!account) throw Object.assign(new Error('Cash account not found'), { status: 404 });

  const prev = Number(account.current_balance);
  const next =
    input.direction === 'in'
      ? prev + input.amount
      : prev - input.amount;
  const balanceAfter = Math.round((next + Number.EPSILON) * 100) / 100;

  await db.query(`UPDATE cash_accounts SET current_balance = $2 WHERE id = $1`, [
    account.id,
    balanceAfter,
  ]);
  await db.query(
    `INSERT INTO cash_ledger_entries
      (tenant_id, account_id, direction, amount, balance_after, description, ref_type, ref_id, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
    [
      input.tenantId,
      account.id,
      input.direction,
      input.amount,
      balanceAfter,
      input.description ?? null,
      input.refType ?? null,
      input.refId ?? null,
      input.userId ?? null,
    ],
  );
  return balanceAfter;
}

export async function syncNewPermissionsToTenantOwners(db: DatabaseClient, tenantId: string) {
  await db.query(
    `INSERT INTO tenant_role_permissions (tenant_role_id, permission_id)
     SELECT tr.id, p.id
     FROM tenant_roles tr
     CROSS JOIN permissions p
     WHERE tr.tenant_id = $1 AND tr.code = 'owner'
       AND NOT EXISTS (
         SELECT 1 FROM tenant_role_permissions x
         WHERE x.tenant_role_id = tr.id AND x.permission_id = p.id
       )`,
    [tenantId],
  );
}

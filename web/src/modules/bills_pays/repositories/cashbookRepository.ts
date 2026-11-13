import { supabase } from 'src/boot/supabase';
import { cashbookPointCodeFromName, uniqueCashbookPointCode } from '../utils/cashbookPointCode';
import type { PayListRow } from '../repositories/paysRepository';

export type CashbookEntityType = 'customer' | 'courier' | 'vendor' | 'cargo_company' | 'investor';

export type CashbookEntityRow = {
  entity_id: number;
  entity_type: string;
  name: string;
  code: string | null;
  caption: string | null;
  available_balance: number;
  pending_balance: number;
  locked_balance: number;
  total_balance: number;
};

export type CashbookPartyDetail = {
  name: string;
  caption: string | null;
  code: string | null;
  available_balance: number;
  pending_balance: number;
  locked_balance: number;
  total_balance: number;
  account_class?: string | null;
};

export type CashbookPointRow = {
  id: number;
  cashbook_account_id: number;
  tenant_id: number;
  code: string;
  name: string;
  is_active: boolean;
};

export type CashbookPointPotRow = {
  id: number;
  cashbook_point_id: number;
  tenant_id: number;
  currency_code: string;
  amount: number;
};

export type CashbookLedgerRow = {
  id: string;
  type: string;
  amount: number;
  balance_after: number | null;
  source_type: string | null;
  source_id: string | null;
  created_at: string;
  is_reversal: boolean;
  metadata: Record<string, unknown> | null;
  cashbook_point_id: number | null;
  cashbook_point_name: string | null;
};

const parseDetail = (data: unknown): CashbookPartyDetail => {
  const payload = (data ?? {}) as {
    success?: boolean;
    error?: string;
    entity?: { name?: string; caption?: string; code?: string };
    account?: {
      available_balance?: number;
      pending_balance?: number;
      locked_balance?: number;
      total_balance?: number;
      account_class?: string;
    };
  };
  if (payload.success === false) {
    throw new Error(payload.error || 'Could not load cashbook party.');
  }
  return {
    name: payload.entity?.name ?? '—',
    caption: payload.entity?.caption ?? null,
    code: payload.entity?.code ?? null,
    available_balance: Number(payload.account?.available_balance ?? 0),
    pending_balance: Number(payload.account?.pending_balance ?? 0),
    locked_balance: Number(payload.account?.locked_balance ?? 0),
    total_balance: Number(payload.account?.total_balance ?? 0),
    account_class: payload.account?.account_class ?? null,
  };
};

const listEntities = async (params: {
  tenantId: number;
  entityType: CashbookEntityType;
  search?: string;
  limit?: number;
  offset?: number;
}): Promise<CashbookEntityRow[]> => {
  const { data, error } = await supabase.rpc('list_cashbook_entities_for_staff', {
    p_tenant_id: params.tenantId,
    p_entity_type: params.entityType,
    p_search: params.search ?? null,
    p_limit: params.limit ?? 100,
    p_offset: params.offset ?? 0,
    p_currency_code: 'BDT',
  });
  if (error) throw error;
  return ((data as CashbookEntityRow[] | null) ?? []).map((row) => ({
    entity_id: Number(row.entity_id),
    entity_type: row.entity_type,
    name: row.name,
    code: row.code ?? null,
    caption: row.caption ?? null,
    available_balance: Number(row.available_balance ?? 0),
    pending_balance: Number(row.pending_balance ?? 0),
    locked_balance: Number(row.locked_balance ?? 0),
    total_balance: Number(row.total_balance ?? 0),
  }));
};

const getTenantCashRow = async (tenantId: number, booksTenantId: number): Promise<CashbookEntityRow> => {
  const detail = await getPartyDetail(tenantId, 'tenant', booksTenantId);
  return {
    entity_id: booksTenantId,
    entity_type: 'tenant',
    name: detail.name,
    code: detail.code,
    caption: detail.caption ?? 'Company cash pool',
    available_balance: detail.available_balance,
    pending_balance: detail.pending_balance,
    locked_balance: detail.locked_balance,
    total_balance: detail.total_balance,
  };
};

export type CashbookPaymentProfileBundle = {
  detail: CashbookPartyDetail;
  dueTotal: number;
  ledger: CashbookLedgerRow[];
  pays: PayListRow[];
};

const mapLedgerJsonRow = (row: Record<string, unknown>): CashbookLedgerRow => ({
  id: String(row.id ?? ''),
  type: String(row.type ?? ''),
  amount: Number(row.amount ?? 0),
  balance_after: row.balance_after == null ? null : Number(row.balance_after),
  source_type: (row.source_type as string | null) ?? null,
  source_id: (row.source_id as string | null) ?? null,
  created_at: String(row.created_at ?? ''),
  is_reversal: Boolean(row.is_reversal),
  metadata: (row.metadata as Record<string, unknown> | null) ?? null,
  cashbook_point_id: row.cashbook_point_id == null ? null : Number(row.cashbook_point_id),
  cashbook_point_name: (row.cashbook_point_name as string | null) ?? null,
});

const mapPayJsonRow = (row: Record<string, unknown>): PayListRow => ({
  id: Number(row.id),
  payment_date: String(row.payment_date ?? ''),
  amount: Number(row.amount ?? 0),
  unallocated_amount: Number(row.unallocated_amount ?? 0),
  source: String(row.source ?? ''),
  direction: row.direction === 'out' ? 'out' : row.direction === 'in' ? 'in' : undefined,
  counterparty_name: (row.counterparty_name as string | null) ?? null,
  cashbook_point_id: row.cashbook_point_id == null ? null : Number(row.cashbook_point_id),
  cashbook_point_name: (row.cashbook_point_name as string | null) ?? null,
  method: (row.method as string | null) ?? null,
  reference: (row.reference as string | null) ?? null,
  note: (row.note as string | null) ?? null,
  voided_at: (row.voided_at as string | null) ?? null,
  profile_id: row.profile_id == null ? null : Number(row.profile_id),
  profile_name: (row.profile_name as string | null) ?? null,
  shop_order_id: row.shop_order_id == null ? null : Number(row.shop_order_id),
  settlement_currency_code: String(row.settlement_currency_code ?? 'BDT'),
  foreign_amount: row.foreign_amount == null ? null : Number(row.foreign_amount),
  exchange_rate: Number(row.exchange_rate ?? 1),
  related_invoice_no: (row.related_invoice_no as string | null) ?? null,
  perspective:
    row.perspective === 'tenant' || row.perspective === 'party'
      ? row.perspective
      : undefined,
});

const parsePaymentProfileBundle = (data: unknown): CashbookPaymentProfileBundle => {
  const payload = (data ?? {}) as {
    success?: boolean;
    error?: string;
    due_total?: number;
    ledger?: unknown[];
    pays?: unknown[];
  };
  if (payload.success === false) {
    throw new Error(payload.error || 'Could not load payment profile.');
  }
  const detail = parseDetail(data);
  const ledger = ((payload.ledger as Record<string, unknown>[] | null) ?? []).map(mapLedgerJsonRow);
  const pays = ((payload.pays as Record<string, unknown>[] | null) ?? []).map(mapPayJsonRow);
  return {
    detail,
    dueTotal: Number(payload.due_total ?? 0),
    ledger,
    pays,
  };
};

const getPartyDetail = async (
  tenantId: number,
  entityType: string,
  entityId: number,
): Promise<CashbookPartyDetail> => {
  const { data, error } = await supabase.rpc('get_cashbook_detail_for_staff', {
    p_tenant_id: tenantId,
    p_entity_type: entityType,
    p_entity_id: entityId,
    p_currency_code: 'BDT',
  });
  if (error) throw error;
  return parseDetail(data);
};

const getPaymentProfileForStaff = async (params: {
  tenantId: number;
  entityType: string;
  entityId: number;
  ledgerLimit?: number;
  paysLimit?: number;
}): Promise<CashbookPaymentProfileBundle> => {
  const { data, error } = await supabase.rpc('get_payment_profile_for_staff', {
    p_tenant_id: params.tenantId,
    p_entity_type: params.entityType,
    p_entity_id: params.entityId,
    p_currency_code: 'BDT',
    p_ledger_limit: params.ledgerLimit ?? 50,
    p_pays_limit: params.paysLimit ?? 50,
  });
  if (error) throw error;
  return parsePaymentProfileBundle(data);
};

const listLedger = async (params: {
  tenantId: number;
  entityType: string;
  entityId: number;
  search?: string;
  limit?: number;
  offset?: number;
}): Promise<CashbookLedgerRow[]> => {
  const { data, error } = await supabase.rpc('list_cashbook_ledger_for_staff', {
    p_tenant_id: params.tenantId,
    p_entity_type: params.entityType,
    p_entity_id: params.entityId,
    p_search: params.search ?? null,
    p_limit: params.limit ?? 50,
    p_offset: params.offset ?? 0,
  });
  if (error) throw error;
  return ((data as CashbookLedgerRow[] | null) ?? []).map((row) => ({
    id: String(row.id),
    type: row.type,
    amount: Number(row.amount),
    balance_after: row.balance_after == null ? null : Number(row.balance_after),
    source_type: row.source_type,
    source_id: row.source_id,
    created_at: row.created_at,
    is_reversal: Boolean(row.is_reversal),
    metadata: (row.metadata as Record<string, unknown> | null) ?? null,
    cashbook_point_id: row.cashbook_point_id == null ? null : Number(row.cashbook_point_id),
    cashbook_point_name: row.cashbook_point_name ?? null,
  }));
};

const findCashbookAccountId = async (params: {
  booksTenantId: number;
  entityType: string;
  entityId: number;
  currencyCode?: string;
}): Promise<number | null> => {
  const entityId = params.entityType === 'tenant' ? params.booksTenantId : params.entityId;
  const { data, error } = await supabase
    .from('cashbook_accounts')
    .select('id')
    .eq('tenant_id', params.booksTenantId)
    .eq('entity_type', params.entityType)
    .eq('entity_id', entityId)
    .eq('currency_code', params.currencyCode ?? 'BDT')
    .maybeSingle();
  if (error) throw error;
  return data?.id ?? null;
};

const findCashbookAccountIdByProfile = async (
  booksTenantId: number,
  profileId: number,
): Promise<number | null> => {
  const { data, error } = await supabase
    .from('cashbook_accounts')
    .select('id')
    .eq('tenant_id', booksTenantId)
    .eq('profile_id', profileId)
    .maybeSingle();
  if (error) throw error;
  return data?.id ?? null;
};

/** Mirrors `public._kernel_cashbook_axes_for_profile` for client account lookup. */
const cashbookAxesForProfile = (
  profile: { profile_type: string; subject_id: number },
  profileId: number,
): { entityType: string; entityId: number } => {
  switch (profile.profile_type) {
    case 'tenant':
      return { entityType: 'tenant', entityId: profile.subject_id };
    case 'vendor':
      return { entityType: 'vendor', entityId: profile.subject_id };
    case 'cargo':
      return { entityType: 'cargo_company', entityId: profile.subject_id };
    case 'courier':
      return { entityType: 'courier', entityId: profile.subject_id };
    case 'investor':
      return { entityType: 'investor', entityId: profile.subject_id };
    case 'customer':
    default:
      return { entityType: 'customer', entityId: profileId };
  }
};

/** Profile id first; fall back to legacy entity-keyed cashbook_accounts (see ensure_cashbook_account_for_profile). */
const resolveCashbookAccountIdForProfile = async (
  booksTenantId: number,
  profileId: number,
): Promise<number | null> => {
  const byProfile = await findCashbookAccountIdByProfile(booksTenantId, profileId);
  if (byProfile) return byProfile;

  const { data: profile, error } = await supabase
    .from('profiles')
    .select('profile_type, subject_id, tenant_id')
    .eq('id', profileId)
    .maybeSingle();
  if (error) throw error;
  if (!profile) return null;

  const { entityType, entityId } = cashbookAxesForProfile(profile, profileId);

  const { data: accounts, error: accError } = await supabase
    .from('cashbook_accounts')
    .select('id, currency_code')
    .eq('tenant_id', booksTenantId)
    .eq('entity_type', entityType)
    .eq('entity_id', entityId)
    .order('currency_code', { ascending: true });
  if (accError) throw accError;
  if (!accounts?.length) return null;
  const bdt = accounts.find((a) => a.currency_code === 'BDT');
  return (bdt ?? accounts[0]).id;
};

export type CashbookLegAccountPrep = {
  accountId: number;
  defaultPotId: number | null;
};

/** Ensures main point + currency pot and default pointers (DB: ensure_cashbook_account_for_profile). */
const ensureCashbookAccountForProfile = async (
  profileId: number,
  currencyCode: string,
): Promise<number> => {
  const ccy = currencyCode.trim().toUpperCase() || 'BDT';
  const { data, error } = await supabase.rpc('ensure_cashbook_account_for_profile', {
    p_profile_id: profileId,
    p_currency_code: ccy,
  });
  if (error) throw error;
  if (data == null) {
    throw new Error('ensure_cashbook_account_for_profile returned no account id');
  }
  return data;
};

const getCashbookAccountDefaultPotId = async (cashbookAccountId: number): Promise<number | null> => {
  const { data, error } = await supabase
    .from('cashbook_accounts')
    .select('default_cashbook_point_pot_id')
    .eq('id', cashbookAccountId)
    .maybeSingle();
  if (error) throw error;
  return data?.default_cashbook_point_pot_id ?? null;
};

const prepareCashbookLegForProfile = async (
  profileId: number,
  currencyCode: string,
): Promise<CashbookLegAccountPrep> => {
  const accountId = await ensureCashbookAccountForProfile(profileId, currencyCode);
  const defaultPotId = await getCashbookAccountDefaultPotId(accountId);
  return { accountId, defaultPotId };
};

const listCashbookPoints = async (cashbookAccountId: number): Promise<CashbookPointRow[]> => {
  const { data, error } = await supabase
    .from('cashbook_points')
    .select('id, cashbook_account_id, tenant_id, code, name, is_active')
    .eq('cashbook_account_id', cashbookAccountId)
    .order('name', { ascending: true });
  if (error) throw error;
  return (data ?? []).map((row) => ({
    id: row.id,
    cashbook_account_id: row.cashbook_account_id,
    tenant_id: row.tenant_id,
    code: row.code,
    name: row.name,
    is_active: row.is_active,
  }));
};

const listPointCodes = async (cashbookAccountId: number, excludePointId?: number): Promise<Set<string>> => {
  const { data, error } = await supabase
    .from('cashbook_points')
    .select('id, code')
    .eq('cashbook_account_id', cashbookAccountId);
  if (error) throw error;
  const taken = new Set<string>();
  for (const row of data ?? []) {
    if (excludePointId != null && row.id === excludePointId) continue;
    taken.add(row.code);
  }
  return taken;
};

const resolvePointCode = async (
  cashbookAccountId: number,
  name: string,
  excludePointId?: number,
): Promise<string> => {
  const taken = await listPointCodes(cashbookAccountId, excludePointId);
  const base = cashbookPointCodeFromName(name);
  return uniqueCashbookPointCode(base, taken);
};

const normalizePotCurrencyCodes = (codes: string[]): string[] => {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of codes) {
    const code = raw.trim().toUpperCase();
    if (!code || seen.has(code)) continue;
    seen.add(code);
    out.push(code);
  }
  if (!out.length) {
    throw new Error('Add at least one currency pot.');
  }
  return out;
};

const mapPointPotRow = (row: {
  id: number;
  cashbook_point_id: number;
  tenant_id: number;
  currency_code: string;
  amount: number | string | null;
}): CashbookPointPotRow => ({
  id: row.id,
  cashbook_point_id: row.cashbook_point_id,
  tenant_id: row.tenant_id,
  currency_code: row.currency_code,
  amount: Number(row.amount ?? 0),
});

const listCashbookPointPots = async (pointId: number): Promise<CashbookPointPotRow[]> => {
  const { data, error } = await supabase
    .from('cashbook_point_pots')
    .select('id, cashbook_point_id, tenant_id, currency_code, amount')
    .eq('cashbook_point_id', pointId)
    .order('currency_code', { ascending: true });
  if (error) throw error;
  return (data ?? []).map(mapPointPotRow);
};

const listCashbookPointPotsForPoints = async (pointIds: number[]): Promise<CashbookPointPotRow[]> => {
  if (!pointIds.length) return [];
  const { data, error } = await supabase
    .from('cashbook_point_pots')
    .select('id, cashbook_point_id, tenant_id, currency_code, amount')
    .in('cashbook_point_id', pointIds)
    .order('currency_code', { ascending: true });
  if (error) throw error;
  return (data ?? []).map(mapPointPotRow);
};

const insertCashbookPointPots = async (
  parentTenantId: number,
  pointId: number,
  currencyCodes: string[],
): Promise<void> => {
  const codes = normalizePotCurrencyCodes(currencyCodes);
  const { error } = await supabase.from('cashbook_point_pots').insert(
    codes.map((currency_code) => ({
      tenant_id: parentTenantId,
      cashbook_point_id: pointId,
      currency_code,
      amount: 0,
    })),
  );
  if (error) throw error;
};

const syncCashbookPointPots = async (
  parentTenantId: number,
  pointId: number,
  currencyCodes: string[],
): Promise<void> => {
  const desired = normalizePotCurrencyCodes(currencyCodes);
  const existing = await listCashbookPointPots(pointId);
  const desiredSet = new Set(desired);
  const existingByCode = new Map(existing.map((p) => [p.currency_code.toUpperCase(), p]));

  for (const pot of existing) {
    const code = pot.currency_code.toUpperCase();
    if (desiredSet.has(code)) continue;
    if (pot.amount > 0) {
      throw new Error(`Cannot remove ${code} pot while it still holds cash.`);
    }
    const { error } = await supabase.from('cashbook_point_pots').delete().eq('id', pot.id);
    if (error) throw error;
  }

  const toAdd = desired.filter((code) => !existingByCode.has(code));
  if (toAdd.length) {
    await insertCashbookPointPots(parentTenantId, pointId, toAdd);
  }
};

const createCashbookPoint = async (input: {
  parentTenantId: number;
  cashbookAccountId: number;
  name: string;
  currencyCodes: string[];
}): Promise<number> => {
  const code = await resolvePointCode(input.cashbookAccountId, input.name);
  const { data, error } = await supabase
    .from('cashbook_points')
    .insert({
      tenant_id: input.parentTenantId,
      cashbook_account_id: input.cashbookAccountId,
      code,
      name: input.name.trim(),
      is_active: true,
    })
    .select('id')
    .single();
  if (error) throw error;
  const pointId = data?.id;
  if (!pointId) throw new Error('Could not create cash point.');
  await insertCashbookPointPots(input.parentTenantId, pointId, input.currencyCodes);
  return pointId;
};

const updateCashbookPoint = async (
  pointId: number,
  cashbookAccountId: number,
  patch: Partial<Pick<CashbookPointRow, 'name' | 'code' | 'is_active'>>,
): Promise<void> => {
  const payload: Record<string, unknown> = { ...patch, updated_at: new Date().toISOString() };
  if (patch.name) {
    payload.code = await resolvePointCode(cashbookAccountId, patch.name, pointId);
  }
  const { error } = await supabase.from('cashbook_points').update(payload).eq('id', pointId);
  if (error) throw error;
};

const deleteCashbookPoint = async (tenantId: number, pointId: number): Promise<void> => {
  const { data, error } = await supabase.rpc('delete_cashbook_point_for_staff', {
    p_tenant_id: tenantId,
    p_point_id: pointId,
  });
  if (error) throw error;
  const payload = (data ?? {}) as { success?: boolean; error?: string };
  if (payload.success === false) {
    throw new Error(payload.error || 'Could not delete cash point.');
  }
};

const transferCashbookPoint = async (params: {
  tenantId: number;
  fromPointId: number;
  toPointId: number;
  currencyCode: string;
  amount: number;
  note?: string | null;
}) => {
  const { data, error } = await supabase.rpc('transfer_cashbook_point', {
    p_tenant_id: params.tenantId,
    p_from_point_id: params.fromPointId,
    p_to_point_id: params.toPointId,
    p_currency_code: params.currencyCode,
    p_amount: params.amount,
    p_note: params.note ?? null,
  });
  if (error) throw error;
  const payload = (data ?? {}) as { success?: boolean; error?: string };
  if (payload.success === false) {
    throw new Error(payload.error || 'Could not transfer cash.');
  }
  return payload;
};

const listBooksExchangeRates = async (params: {
  parentTenantId: number;
  quoteCurrencyCode?: string | null;
  limit?: number;
}) => {
  const { data, error } = await supabase.rpc('list_books_exchange_rates', {
    p_tenant_id: params.parentTenantId,
    p_quote_currency_code: params.quoteCurrencyCode ?? null,
    p_limit: params.limit ?? 20,
  });
  if (error) throw error;
  return (data ?? []) as Array<{
    id: number;
    base_currency_code: string;
    quote_currency_code: string;
    rate: number;
    rate_date: string;
  }>;
};

export type ProfileActivityKind = 'payments' | 'custody' | 'bills';

export type ProfileActivityResult = {
  kind: ProfileActivityKind;
  items: unknown[];
  nextCursor: string | null;
};

const listProfileActivity = async (params: {
  tenantId: number;
  entityType: string;
  entityId: number;
  kind: ProfileActivityKind;
  limit?: number;
  cursor?: string | null;
}): Promise<ProfileActivityResult> => {
  const { data, error } = await supabase.rpc('list_profile_activity_for_staff', {
    p_tenant_id: params.tenantId,
    p_entity_type: params.entityType,
    p_entity_id: params.entityId,
    p_kind: params.kind,
    p_limit: params.limit ?? 50,
    p_cursor: params.cursor ?? null,
  });
  if (error) throw error;
  const payload = (data ?? {}) as {
    success?: boolean;
    error?: string;
    kind?: ProfileActivityKind;
    items?: unknown[];
    next_cursor?: string | null;
  };
  if (payload.success === false) {
    throw new Error(payload.error || 'Could not load profile activity.');
  }
  return {
    kind: (payload.kind as ProfileActivityKind) ?? params.kind,
    items: payload.items ?? [],
    nextCursor: payload.next_cursor ?? null,
  };
};

export const cashbookRepository = {
  listEntities,
  getTenantCashRow,
  getPartyDetail,
  getPaymentProfileForStaff,
  listProfileActivity,
  listLedger,
  findCashbookAccountId,
  findCashbookAccountIdByProfile,
  resolveCashbookAccountIdForProfile,
  ensureCashbookAccountForProfile,
  prepareCashbookLegForProfile,
  listCashbookPoints,
  listCashbookPointPots,
  listCashbookPointPotsForPoints,
  syncCashbookPointPots,
  createCashbookPoint,
  updateCashbookPoint,
  deleteCashbookPoint,
  transferCashbookPoint,
  listBooksExchangeRates,
};

import { supabase } from 'src/boot/supabase';
import type { CashbookPointKind } from '../constants/cashbookPointKinds';
import { cashbookPointCodeFromName, uniqueCashbookPointCode } from '../utils/cashbookPointCode';

export type CashbookEntityType = 'customer' | 'courier' | 'vendor';

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
};

export type CashbookPointRow = {
  id: number;
  cashbook_account_id: number;
  parent_tenant_id: number;
  code: string;
  name: string;
  kind: CashbookPointKind;
  is_active: boolean;
  sort_order: number;
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
  };
};

const listEntities = async (params: {
  tenantId: number;
  entityType: CashbookEntityType;
  search?: string;
  limit?: number;
  offset?: number;
}): Promise<CashbookEntityRow[]> => {
  const { data, error } = await supabase.rpc('list_wallet_entities_for_staff', {
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

const getPartyDetail = async (
  tenantId: number,
  entityType: string,
  entityId: number,
): Promise<CashbookPartyDetail> => {
  const { data, error } = await supabase.rpc('get_wallet_detail_for_staff', {
    p_tenant_id: tenantId,
    p_entity_type: entityType,
    p_entity_id: entityId,
    p_currency_code: 'BDT',
  });
  if (error) throw error;
  return parseDetail(data);
};

const listLedger = async (params: {
  tenantId: number;
  entityType: string;
  entityId: number;
  search?: string;
  limit?: number;
  offset?: number;
}): Promise<CashbookLedgerRow[]> => {
  const { data, error } = await supabase.rpc('list_wallet_ledger_for_staff', {
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
    .eq('parent_tenant_id', params.booksTenantId)
    .eq('entity_type', params.entityType)
    .eq('entity_id', entityId)
    .eq('currency_code', params.currencyCode ?? 'BDT')
    .maybeSingle();
  if (error) throw error;
  return data?.id ?? null;
};

const listCashbookPoints = async (cashbookAccountId: number): Promise<CashbookPointRow[]> => {
  const { data, error } = await supabase
    .from('cashbook_points')
    .select('id, cashbook_account_id, parent_tenant_id, code, name, kind, is_active, sort_order')
    .eq('cashbook_account_id', cashbookAccountId)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });
  if (error) throw error;
  return (data ?? []).map((row) => ({
    id: row.id,
    cashbook_account_id: row.cashbook_account_id,
    parent_tenant_id: row.parent_tenant_id,
    code: row.code,
    name: row.name,
    kind: row.kind,
    is_active: row.is_active,
    sort_order: row.sort_order,
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

const createCashbookPoint = async (input: {
  parentTenantId: number;
  cashbookAccountId: number;
  name: string;
  kind: CashbookPointKind;
}): Promise<void> => {
  const code = await resolvePointCode(input.cashbookAccountId, input.name);
  const { error } = await supabase.from('cashbook_points').insert({
    parent_tenant_id: input.parentTenantId,
    cashbook_account_id: input.cashbookAccountId,
    code,
    name: input.name.trim(),
    kind: input.kind,
    is_active: true,
  });
  if (error) throw error;
};

const updateCashbookPoint = async (
  pointId: number,
  cashbookAccountId: number,
  patch: Partial<Pick<CashbookPointRow, 'name' | 'code' | 'kind' | 'is_active' | 'sort_order'>>,
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

export const cashbookRepository = {
  listEntities,
  getTenantCashRow,
  getPartyDetail,
  listLedger,
  findCashbookAccountId,
  listCashbookPoints,
  createCashbookPoint,
  updateCashbookPoint,
  deleteCashbookPoint,
};

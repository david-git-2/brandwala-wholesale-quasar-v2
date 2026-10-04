import { supabase } from 'src/boot/supabase';

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
  }));
};

export const cashbookRepository = {
  listEntities,
  getTenantCashRow,
  getPartyDetail,
  listLedger,
};

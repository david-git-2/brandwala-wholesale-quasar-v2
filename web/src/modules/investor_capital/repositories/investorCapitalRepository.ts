import { supabase } from 'src/boot/supabase';
import type {
  InvestorBalance,
  Investor,
  InvestorCreateInput,
  InvestorUpdateInput,
  InvestorTransaction,
  InvestorTransactionMethod,
  InvestorTransactionType,
  ShipmentInvestment,
  InvestorAllocationRow,
} from '../types';

const walletRowIdToNumericId = (walletId: string): number => {
  const digits = walletId.replace(/\D/g, '').slice(0, 12);
  const parsed = Number.parseInt(digits, 10);
  return Number.isFinite(parsed) ? parsed : 0;
};

const mapCapitalRpcToTransaction = (payload: Record<string, unknown>): InvestorTransaction => {
  const rawType = String(payload.transaction_type ?? 'capital_adjustment');
  const allowedTypes: InvestorTransactionType[] = [
    'capital_in',
    'withdrawal_paid',
    'capital_adjustment',
  ];
  const type = (
    allowedTypes.includes(rawType as InvestorTransactionType)
      ? rawType
      : 'capital_adjustment'
  ) as InvestorTransactionType;

  return {
    id: 0,
    tenant_id: Number(payload.tenant_id),
    investor_id: Number(payload.investor_id),
    amount: Number(payload.amount),
    date: String(payload.date),
    method: (payload.method as InvestorTransactionMethod) ?? 'other',
    type,
    note: (payload.note as string | null) ?? null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
};

const mapWalletActivityToTransaction = (
  row: {
    id: string;
    investor_id: number;
    amount: number;
    activity_date: string;
    method: InvestorTransactionMethod;
    transaction_type: string;
    note: string | null;
    created_at: string;
  },
  tenantId: number,
): InvestorTransaction => {
  const base = mapCapitalRpcToTransaction({
    tenant_id: tenantId,
    investor_id: row.investor_id,
    amount: row.amount,
    date: row.activity_date,
    method: row.method,
    transaction_type: row.transaction_type,
    note: row.note,
  });

  return {
    ...base,
    id: walletRowIdToNumericId(row.id),
    created_at: row.created_at,
    updated_at: row.created_at,
  };
};

const listInvestorProfiles = async (tenantId: number): Promise<InvestorBalance[]> => {
  const { data, error } = await supabase.rpc('list_investor_profiles', {
    p_tenant_id: tenantId,
    p_limit: 1000,
  });

  if (error) {
    throw error;
  }

  const rows = data ?? [];

  return rows.map((row) => ({
    investor_id: row.id,
    name: row.name,
    email: row.email,
    phone: row.phone,
    address: row.address,
    is_active: row.is_active,
    currency_code: row.currency_code,
    notes: row.notes,
    total_capital_in: Number(row.total_capital_in ?? 0),
    total_withdrawn: Number(row.total_withdrawn ?? 0),
    total_invested_active: Number(row.deployed_capital ?? 0),
    available_balance: Number(row.available_balance ?? 0),
    total_profit_realized: 0,
    total_profit_unrealized: 0,
  }));
};

const upsertInvestorProfile = async (
  payload: InvestorUpdateInput | InvestorCreateInput,
): Promise<Investor> => {
  const isEdit = 'id' in payload;
  const { data, error } = await supabase.rpc('upsert_investor_profile', {
    p_id: isEdit ? (payload as any).id : null,
    p_tenant_id: payload.tenant_id,
    p_name: payload.name.trim(),
    p_phone: payload.phone?.trim() || null,
    p_email: payload.email?.trim() || null,
    p_address: payload.address?.trim() || null,
    p_is_active: payload.is_active ?? true,
    p_currency_code: payload.currency_code || 'BDT',
    p_notes: payload.notes?.trim() || null,
  });

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Investor was not saved.');
  }

  return data as Investor;
};

const deleteInvestorProfile = async (id: number, tenantId: number): Promise<void> => {
  const { error } = await supabase
    .from('investors')
    .delete()
    .eq('id', id)
    .eq('tenant_id', tenantId);

  if (error) {
    throw error;
  }
};

const listTransactions = async (
  tenantId: number,
  limit = 50,
  offset = 0,
  investorId?: number | null,
  type?: string | null,
  startDate?: string | null,
  endDate?: string | null,
): Promise<InvestorTransaction[]> => {
  const { data, error } = await supabase.rpc('list_investor_wallet_activity', {
    p_tenant_id: tenantId,
    p_investor_id: investorId ?? null,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    throw error;
  }

  let list = ((data as Array<Record<string, unknown>> | null) ?? []).map((row) =>
    mapWalletActivityToTransaction(
      {
        id: String(row.id),
        investor_id: Number(row.investor_id),
        amount: Number(row.amount),
        activity_date: String(row.activity_date),
        method: row.method as InvestorTransactionMethod,
        transaction_type: String(row.transaction_type),
        note: (row.note as string | null) ?? null,
        created_at: String(row.created_at),
      },
      tenantId,
    ),
  );

  // Apply filters in memory since wallet activity RPC uses simple pagination.
  if (type) {
    list = list.filter((item) => item.type === type);
  }
  if (startDate) {
    list = list.filter((item) => item.date >= startDate);
  }
  if (endDate) {
    list = list.filter((item) => item.date <= endDate);
  }

  return list;
};

const recordCapitalIn = async (payload: {
  tenant_id: number;
  investor_id: number;
  amount: number;
  date: string;
  method: string;
  note?: string | null;
}): Promise<InvestorTransaction> => {
  const { data, error } = await supabase.rpc('record_investor_capital_in', {
    p_tenant_id: payload.tenant_id,
    p_investor_id: payload.investor_id,
    p_amount: payload.amount,
    p_date: payload.date,
    p_method: payload.method,
    p_note: payload.note || null,
  });

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Capital in was not recorded.');
  }

  return mapCapitalRpcToTransaction(data as Record<string, unknown>);
};

const recordWithdrawalPaid = async (payload: {
  tenant_id: number;
  investor_id: number;
  amount: number;
  date: string;
  method: string;
  note?: string | null;
}): Promise<InvestorTransaction> => {
  const { data, error } = await supabase.rpc('record_investor_withdrawal_paid', {
    p_tenant_id: payload.tenant_id,
    p_investor_id: payload.investor_id,
    p_amount: payload.amount,
    p_date: payload.date,
    p_method: payload.method,
    p_note: payload.note || null,
  });

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Withdrawal was not recorded.');
  }

  return mapCapitalRpcToTransaction(data as Record<string, unknown>);
};

const recordCapitalAdjustment = async (payload: {
  tenant_id: number;
  investor_id: number;
  amount: number;
  date: string;
  method: string;
  note?: string | null;
}): Promise<InvestorTransaction> => {
  const { data, error } = await supabase.rpc('record_investor_capital_adjustment', {
    p_tenant_id: payload.tenant_id,
    p_investor_id: payload.investor_id,
    p_amount: payload.amount,
    p_date: payload.date,
    p_method: payload.method,
    p_note: payload.note || null,
  });

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Capital adjustment was not recorded.');
  }

  return mapCapitalRpcToTransaction(data as Record<string, unknown>);
};

const listShipmentInvestmentsByShipment = async (
  tenantId: number,
  globalShipmentId: number,
): Promise<ShipmentInvestment[]> => {
  const { data, error } = await supabase
    .from('shipment_investments')
    .select('*')
    .eq('tenant_id', tenantId)
    .eq('global_shipment_id', globalShipmentId)
    .order('id', { ascending: true });

  if (error) {
    throw error;
  }

  return (data as ShipmentInvestment[] | null) ?? [];
};

const upsertShipmentInvestment = async (payload: {
  id?: number | null;
  tenant_id: number;
  global_shipment_id: number;
  investor_id: number;
  cost_share_pct: number;
}): Promise<ShipmentInvestment> => {
  const { data, error } = await supabase.rpc('upsert_shipment_investment', {
    p_id: payload.id || null,
    p_tenant_id: payload.tenant_id,
    p_global_shipment_id: payload.global_shipment_id,
    p_investor_id: payload.investor_id,
    p_cost_share_pct: payload.cost_share_pct,
  });

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Shipment investment was not saved.');
  }

  return data as ShipmentInvestment;
};

const deleteShipmentInvestment = async (id: number, tenantId: number): Promise<void> => {
  const { error } = await supabase
    .from('shipment_investments')
    .delete()
    .eq('id', id)
    .eq('tenant_id', tenantId);

  if (error) {
    throw error;
  }
};

const refreshShipmentInvestorProfits = async (globalShipmentId: number): Promise<void> => {
  const { error } = await supabase.rpc('refresh_shipment_investor_profits', {
    p_global_shipment_id: globalShipmentId,
  });

  if (error) {
    throw error;
  }
};

const getInvestorCapitalReport = async (
  tenantId: number,
  investorId: number,
  startDate: string,
  endDate: string,
) => {
  const { data, error } = await supabase.rpc('get_investor_capital_report', {
    p_tenant_id: tenantId,
    p_investor_id: investorId,
    p_start_date: startDate,
    p_end_date: endDate,
  });

  if (error) {
    throw error;
  }

  return data;
};

const listInvestorAllocations = async (
  tenantId: number,
  investorId: number,
  limit = 100,
  offset = 0,
) => {
  const { data, error } = await supabase.rpc('list_investor_allocations', {
    p_tenant_id: tenantId,
    p_investor_id: investorId,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    throw error;
  }

  return (data ?? []) as InvestorAllocationRow[];
};

export const investorCapitalRepository = {
  listInvestorProfiles,
  upsertInvestorProfile,
  deleteInvestorProfile,
  listTransactions,
  recordCapitalIn,
  recordWithdrawalPaid,
  recordCapitalAdjustment,
  listShipmentInvestmentsByShipment,
  upsertShipmentInvestment,
  deleteShipmentInvestment,
  refreshShipmentInvestorProfits,
  getInvestorCapitalReport,
  listInvestorAllocations,
};

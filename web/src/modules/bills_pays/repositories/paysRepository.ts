import { supabase } from 'src/boot/supabase';
import type { WholesalePaymentInstrumentInput } from 'src/modules/sales_invoice/types';
import {
  postApPayout,
  postApPayoutSnapshot,
  type ApPayoutBillDetailSnapshot,
  type ApPayoutWithAllocationsPayload,
} from '../services/apPayoutService';

export type { ApPayoutWithAllocationsPayload, ApPayoutBillDetailSnapshot };

const localToday = (): string => {
  const d = new Date();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
};

const PAY_IN_SOURCES = ['customer_cash', 'bank', 'store_credit', 'courier_remittance'] as const;

export type PayListRow = {
  id: number;
  payment_date: string;
  amount: number;
  unallocated_amount: number;
  source: string;
  method: string | null;
  reference: string | null;
  note: string | null;
  voided_at: string | null;
  profile_id: number | null;
  profile_name: string | null;
  shop_order_id: number | null;
  settlement_currency_code: string;
  foreign_amount: number | null;
  exchange_rate: number;
};

export type ListPaysParams = {
  tenantId: number;
  /** Books tenant id when pays rows use parent tenant (default: tenantId). */
  booksTenantId?: number;
  page?: number;
  pageSize?: number;
  search?: string;
  side?: 'in' | 'out';
  profileId?: number;
};

export type CustomerGroupPaymentSummary = {
  id: number;
  name: string;
  account_code: string;
  total_due: number;
  open_invoice_count: number;
};

export type CustomerGroupPayoutSummary = {
  customer_group_id: number;
  name: string;
  account_code: string;
  payable_balance: number;
  profiles: Array<{
    profile_id: number;
    name: string;
    payable_balance: number;
  }>;
};

export type PayAllocationRow = {
  id: number;
  amount: number;
  global_invoice_id: number;
  invoice_no: string | null;
};

export type PayDetail = PayListRow & {
  tenant_id: number;
  customer_group_id: number | null;
  cashbook_point_id: number | null;
  cashbook_point_pot_id: number | null;
  transaction_rate: number | null;
  source_currency_code: string | null;
  instruments: Array<{
    id: number;
    payment_method_code: string;
    amount: number;
    reference: string | null;
    cheque_number: string | null;
    cheque_date: string | null;
    bounced_at: string | null;
  }>;
  allocations: PayAllocationRow[];
};

const listPays = async (params: ListPaysParams): Promise<{ data: PayListRow[]; total: number }> => {
  const { tenantId, page = 1, pageSize = 25, search, side, profileId } = params;
  const offset = (page - 1) * pageSize;
  // pays.tenant_id is always the books (parent) tenant, not the child operating tenant.
  const booksTenantId = params.booksTenantId ?? tenantId;

  let query = supabase
    .from('pays')
    .select(
      'id, payment_date, amount, unallocated_amount, source, method, reference, note, voided_at, profile_id, shop_order_id, settlement_currency_code, foreign_amount, exchange_rate, profiles:profiles!pays_profile_id_fkey(name)',
      { count: 'exact' },
    )
    .eq('tenant_id', booksTenantId);

  if (profileId != null) {
    query = query.eq('profile_id', profileId);
  } else if (side === 'out') {
    query = query.in('source', ['ap_payout', 'commission']);
  } else {
    query = query.in('source', [...PAY_IN_SOURCES]);
  }

  if (search?.trim()) {
    const clean = search.trim();
    const conditions = [`reference.ilike.%${clean}%`, `note.ilike.%${clean}%`];
    const maybeId = Number(clean);
    if (!Number.isNaN(maybeId) && Number.isFinite(maybeId)) {
      conditions.push(`id.eq.${maybeId}`);
    }
    query = query.or(conditions.join(','));
  }

  const { data, error, count } = await query
    .order('id', { ascending: false })
    .range(offset, offset + pageSize - 1);

  if (error) throw error;

  type Raw = PayListRow & {
    profiles?: { name: string } | { name: string }[] | null;
  };

  const rows = ((data as Raw[] | null) ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      payment_date: row.payment_date,
      amount: row.amount,
      unallocated_amount: row.unallocated_amount,
      source: row.source,
      method: row.method,
      reference: row.reference,
      note: row.note,
      voided_at: row.voided_at,
      profile_id: row.profile_id,
      profile_name: profile?.name ?? null,
      shop_order_id: row.shop_order_id,
      settlement_currency_code: row.settlement_currency_code ?? 'BDT',
      foreign_amount: row.foreign_amount,
      exchange_rate: row.exchange_rate ?? 1,
    };
  });

  return { data: rows, total: count ?? 0 };
};

const getPayById = async (payId: number): Promise<PayDetail> => {
  const { data: pay, error: payError } = await supabase
    .from('pays')
    .select(
      'id, payment_date, amount, unallocated_amount, source, method, reference, note, voided_at, profile_id, shop_order_id, tenant_id, customer_group_id, settlement_currency_code, foreign_amount, exchange_rate, cashbook_point_id, cashbook_point_pot_id, transaction_rate, source_currency_code, profiles:profiles!pays_profile_id_fkey(name)',
    )
    .eq('id', payId)
    .single();
  if (payError) throw payError;

  const { data: instruments, error: instError } = await supabase
    .from('pay_instruments')
    .select('id, payment_method_code, amount, reference, cheque_number, cheque_date, bounced_at')
    .eq('payment_id', payId)
    .order('sort_order', { ascending: true });
  if (instError) throw instError;

  const { data: allocations, error: allocError } = await supabase
    .from('bill_settlements')
    .select(
      'id, pay_allocation_id, allocated_books_amount, bill_id, bills:bills!bill_settlements_bill_id_fkey(invoice_no)',
    )
    .eq('allocator_kind', 'pay')
    .eq('allocator_id', payId);
  if (allocError) throw allocError;

  const profile = Array.isArray(pay.profiles) ? pay.profiles[0] : pay.profiles;

  return {
    id: pay.id,
    payment_date: pay.payment_date,
    amount: pay.amount,
    unallocated_amount: pay.unallocated_amount,
    source: pay.source,
    method: pay.method,
    reference: pay.reference,
    note: pay.note,
    voided_at: pay.voided_at,
    profile_id: pay.profile_id,
    profile_name: profile?.name ?? null,
    shop_order_id: pay.shop_order_id,
    tenant_id: pay.tenant_id,
    customer_group_id: pay.customer_group_id,
    settlement_currency_code: pay.settlement_currency_code ?? 'BDT',
    foreign_amount: pay.foreign_amount,
    exchange_rate: pay.exchange_rate ?? 1,
    cashbook_point_id: pay.cashbook_point_id ?? null,
    cashbook_point_pot_id: pay.cashbook_point_pot_id ?? null,
    transaction_rate: pay.transaction_rate ?? null,
    source_currency_code: pay.source_currency_code ?? null,
    instruments: (instruments ?? []).map((i) => ({
      id: i.id,
      payment_method_code: i.payment_method_code,
      amount: Number(i.amount),
      reference: i.reference,
      cheque_number: i.cheque_number,
      cheque_date: i.cheque_date,
      bounced_at: i.bounced_at ?? null,
    })),
    allocations: ((allocations as any[]) ?? []).map((a) => ({
      id: a.pay_allocation_id ?? a.id,
      amount: Number(a.allocated_books_amount),
      global_invoice_id: a.bill_id,
      invoice_no: a.bills?.invoice_no ?? null,
    })),
  };
};

const listCustomerGroupsPaymentSummary = async (
  tenantId: number,
  opts: { search?: string; onlyWithDue?: boolean; limit?: number } = {},
): Promise<CustomerGroupPaymentSummary[]> => {
  const { data, error } = await supabase.rpc('list_customer_groups_payment_summary', {
    p_tenant_id: tenantId,
    p_search: opts.search ?? null,
    p_limit: opts.limit ?? 50,
    p_offset: 0,
    p_only_with_due: opts.onlyWithDue ?? false,
  });
  if (error) throw error;
  return (data as CustomerGroupPaymentSummary[]) ?? [];
};

const listCustomerGroupsPayoutSummary = async (
  tenantId: number,
  opts: { search?: string; onlyWithPayable?: boolean; limit?: number } = {},
): Promise<CustomerGroupPayoutSummary[]> => {
  const { data, error } = await supabase.rpc('list_customer_groups_payout_summary', {
    p_tenant_id: tenantId,
    p_search: opts.search ?? null,
    p_limit: opts.limit ?? 50,
    p_only_with_payable: opts.onlyWithPayable ?? true,
  });
  if (error) throw error;
  return (data as CustomerGroupPayoutSummary[]) ?? [];
};

const listCustomerProfilesForGroup = async (customerGroupId: number) => {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, name')
    .eq('customer_group_id', customerGroupId)
    .order('name');
  if (error) throw error;
  return data ?? [];
};

export type PostCustomerReceiptInput = {
  tenant_id: number;
  profile_id: number;
  received_on?: string;
  note?: string | null;
  reference?: string | null;
  source: 'customer_cash' | 'bank' | 'store_credit' | 'courier_remittance';
  instruments?: WholesalePaymentInstrumentInput[];
  allocations: Array<{ bill_id: number; amount: number }>;
  settlement_currency_code?: string;
  foreign_amount?: number | null;
  exchange_rate?: number | null;
  shop_order_id?: number | null;
  idempotency_key: string;
  cashbook_point_id?: number | null;
  cashbook_point_pot_id?: number | null;
  source_currency_code?: string | null;
  transaction_rate?: number | null;
};

export const createPayIdempotencyKey = (): string => crypto.randomUUID();

const postMoneyIn = async (payload: PostCustomerReceiptInput) => {
  const { data, error } = await supabase.rpc('post_money_in', {
    p_tenant_id: payload.tenant_id,
    p_profile_id: payload.profile_id,
    p_received_on: payload.received_on ?? localToday(),
    p_note: payload.note ?? null,
    p_reference: payload.reference ?? null,
    p_source: payload.source,
    p_instruments: payload.instruments ?? [],
    p_allocations: payload.allocations,
    p_shop_order_id: payload.shop_order_id ?? null,
    p_settlement_currency_code: payload.settlement_currency_code ?? 'BDT',
    p_foreign_amount: payload.foreign_amount ?? null,
    p_exchange_rate: payload.exchange_rate ?? null,
    p_idempotency_key: payload.idempotency_key,
    p_cashbook_point_id: payload.cashbook_point_id ?? null,
    p_cashbook_point_pot_id: payload.cashbook_point_pot_id ?? null,
    p_source_currency_code: payload.source_currency_code ?? null,
    p_transaction_rate: payload.transaction_rate ?? null,
  });
  if (error) throw error;
  return data;
};

export type PostMoneyOutInput = {
  tenant_id: number;
  profile_id: number;
  paid_on?: string;
  amount: number;
  source?: string;
  source_type?: string;
  source_id?: string | null;
  note?: string | null;
  reference?: string | null;
  cashbook_point_id: number;
  cashbook_point_pot_id?: number | null;
  payout_method?: string;
  idempotency_key?: string;
};

const postMoneyOut = async (payload: PostMoneyOutInput) => {
  const { data, error } = await supabase.rpc('post_money_out', {
    p_tenant_id: payload.tenant_id,
    p_profile_id: payload.profile_id,
    p_paid_on: payload.paid_on ?? localToday(),
    p_amount: payload.amount,
    p_source: payload.source ?? 'commission',
    p_note: payload.note ?? null,
    p_reference: payload.reference ?? null,
    p_cashbook_point_id: payload.cashbook_point_id,
    p_cashbook_point_pot_id: payload.cashbook_point_pot_id ?? null,
    p_source_type: payload.source_type ?? 'commission',
    p_source_id: payload.source_id ?? null,
    p_idempotency_key: payload.idempotency_key ?? null,
    p_payout_method: payload.payout_method ?? 'bank_transfer',
  });
  if (error) throw error;
  return data;
};

/** @deprecated Prefer postMoneyIn with idempotency_key */
const postCustomerReceipt = async (payload: PostCustomerReceiptInput) => postMoneyIn(payload);

const voidCustomerReceipt = async (tenantId: number, paymentId: number, reason: string) => {
  const { data, error } = await supabase.rpc('void_customer_receipt', {
    p_tenant_id: tenantId,
    p_payment_id: paymentId,
    p_reason: reason,
  });
  if (error) throw error;
  return data;
};

const reversePay = async (paymentId: number, reason: string) => {
  const { error } = await supabase.rpc('reverse_pay', {
    p_payment_id: paymentId,
    p_reason: reason,
  });
  if (error) throw error;
};

const bounceChequeInstrument = async (tenantId: number, instrumentId: number, reason: string) => {
  const { data, error } = await supabase.rpc('bounce_cheque_instrument', {
    p_tenant_id: tenantId,
    p_instrument_id: instrumentId,
    p_reason: reason,
  });
  if (error) throw error;
  return data;
};

export type OpenApBillRow = {
  id: number;
  invoice_no: string;
  due_amount: number;
  total_amount: number;
  ap_kind: string | null;
  ap_shipment_id: number | null;
  note: string | null;
  channel_meta: Record<string, unknown> | null;
};

export type ApPayProfileSummary = {
  profile_id: number;
  name: string;
  profile_type: string;
  total_due: number;
};

const listOpenApBillsForProfile = async (
  parentTenantId: number,
  profileId: number,
): Promise<OpenApBillRow[]> => {
  const { data, error } = await supabase
    .from('bills')
    .select('id, invoice_no, due_amount, total_amount, ap_kind, ap_shipment_id, note, channel_meta')
    .eq('parent_tenant_id', parentTenantId)
    .eq('invoice_type', 'ap')
    .eq('profile_id', profileId)
    .eq('invoice_status', 'issued')
    .gt('due_amount', 0)
    .order('invoice_date', { ascending: true });

  if (error) throw error;
  return (data ?? []) as OpenApBillRow[];
};

const listApPayProfileSummaries = async (
  parentTenantId: number,
  search?: string,
): Promise<ApPayProfileSummary[]> => {
  const { data, error } = await supabase
    .from('bills')
    .select('profile_id, due_amount, profiles:profiles!bills_profile_id_fkey(name, profile_type)')
    .eq('parent_tenant_id', parentTenantId)
    .eq('invoice_type', 'ap')
    .eq('invoice_status', 'issued')
    .gt('due_amount', 0);

  if (error) throw error;

  type Raw = {
    profile_id: number | null;
    due_amount: number;
    profiles?: { name: string; profile_type: string } | { name: string; profile_type: string }[] | null;
  };

  const byProfile = new Map<number, ApPayProfileSummary>();
  for (const row of (data as Raw[] | null) ?? []) {
    if (row.profile_id == null) continue;
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    const name = profile?.name ?? `Profile #${row.profile_id}`;
    if (search?.trim() && !name.toLowerCase().includes(search.trim().toLowerCase())) {
      continue;
    }
    const existing = byProfile.get(row.profile_id);
    if (existing) {
      existing.total_due += Number(row.due_amount) || 0;
    } else {
      byProfile.set(row.profile_id, {
        profile_id: row.profile_id,
        name,
        profile_type: profile?.profile_type ?? '',
        total_due: Number(row.due_amount) || 0,
      });
    }
  }

  return [...byProfile.values()].sort((a, b) => b.total_due - a.total_due);
};

const postApPayoutWithAllocations = async (payload: ApPayoutWithAllocationsPayload) => {
  const result = await postApPayout(payload);
  return result.pay;
};

const postApPayoutWithAllocationsSnapshot = async (
  payload: ApPayoutWithAllocationsPayload,
): Promise<ApPayoutBillDetailSnapshot> => {
  const result = await postApPayoutSnapshot(payload);
  return {
    pay: result.pay,
    bill: result.bill,
    net_balances: result.net_balances,
    payment_history: result.payment_history,
  };
};

const allocatePayToBill = async (payload: {
  tenant_id: number;
  payment_id: number;
  bill_id: number;
  amount: number;
}) => {
  const { data, error } = await supabase.rpc('allocate_payment_to_global_invoice', {
    p_tenant_id: payload.tenant_id,
    p_payment_id: payload.payment_id,
    p_global_invoice_id: payload.bill_id,
    p_amount: payload.amount,
  });
  if (error) throw error;
  return data;
};

export const paysRepository = {
  listPays,
  getPayById,
  listCustomerGroupsPaymentSummary,
  listCustomerGroupsPayoutSummary,
  listCustomerProfilesForGroup,
  listOpenApBillsForProfile,
  listApPayProfileSummaries,
  postCustomerReceipt,
  postMoneyIn,
  postMoneyOut,
  createPayIdempotencyKey,
  allocatePayToBill,
  postApPayoutWithAllocations,
  postApPayoutWithAllocationsSnapshot,
  voidCustomerReceipt,
  reversePay,
  bounceChequeInstrument,
};

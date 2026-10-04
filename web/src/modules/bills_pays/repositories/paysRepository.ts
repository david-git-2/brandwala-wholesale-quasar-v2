import { supabase } from 'src/boot/supabase';
import type { WholesalePaymentInstrumentInput } from 'src/modules/sales_invoice/types';

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
};

export type ListPaysParams = {
  tenantId: number;
  page?: number;
  pageSize?: number;
  search?: string;
  side?: 'in' | 'out';
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
  billing_profiles: Array<{
    billing_profile_id: number;
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
  customer_group_id: number | null;
  instruments: Array<{
    id: number;
    payment_method_code: string;
    amount: number;
    reference: string | null;
    cheque_number: string | null;
    cheque_date: string | null;
  }>;
  allocations: PayAllocationRow[];
};

const listPays = async (params: ListPaysParams): Promise<{ data: PayListRow[]; total: number }> => {
  const { tenantId, page = 1, pageSize = 25, search, side = 'in' } = params;
  const offset = (page - 1) * pageSize;

  if (side === 'out') {
    return { data: [], total: 0 };
  }

  let query = supabase
    .from('pays')
    .select(
      'id, payment_date, amount, unallocated_amount, source, method, reference, note, voided_at, profile_id, shop_order_id, profiles:profiles!pays_profile_id_fkey(name)',
      { count: 'exact' },
    )
    .eq('tenant_id', tenantId)
    .in('source', [...PAY_IN_SOURCES]);

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
    };
  });

  return { data: rows, total: count ?? 0 };
};

const getPayById = async (payId: number): Promise<PayDetail> => {
  const { data: pay, error: payError } = await supabase
    .from('pays')
    .select(
      'id, payment_date, amount, unallocated_amount, source, method, reference, note, voided_at, profile_id, shop_order_id, tenant_id, customer_group_id, profiles:profiles!pays_profile_id_fkey(name)',
    )
    .eq('id', payId)
    .single();
  if (payError) throw payError;

  const { data: instruments, error: instError } = await supabase
    .from('pay_instruments')
    .select('id, payment_method_code, amount, reference, cheque_number, cheque_date')
    .eq('payment_id', payId)
    .order('sort_order', { ascending: true });
  if (instError) throw instError;

  const { data: allocations, error: allocError } = await supabase
    .from('pay_allocations')
    .select('id, amount, global_invoice_id, bills:bills!payment_allocations_global_invoice_id_fkey(invoice_no)')
    .eq('payment_id', payId);
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
    customer_group_id: pay.customer_group_id,
    instruments: (instruments ?? []).map((i) => ({
      id: i.id,
      payment_method_code: i.payment_method_code,
      amount: Number(i.amount),
      reference: i.reference,
      cheque_number: i.cheque_number,
      cheque_date: i.cheque_date,
    })),
    allocations: ((allocations as any[]) ?? []).map((a) => ({
      id: a.id,
      amount: Number(a.amount),
      global_invoice_id: a.global_invoice_id,
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

const listBillingProfilesForGroup = async (customerGroupId: number) => {
  const { data, error } = await supabase
    .from('billing_profiles')
    .select('id, name')
    .eq('customer_group_id', customerGroupId)
    .order('name');
  if (error) throw error;
  return data ?? [];
};

export type PostCustomerReceiptInput = {
  tenant_id: number;
  billing_profile_id: number;
  received_on?: string;
  note?: string | null;
  reference?: string | null;
  source: 'customer_cash' | 'bank' | 'store_credit';
  instruments?: WholesalePaymentInstrumentInput[];
  allocations: Array<{ bill_id: number; amount: number }>;
};

const postCustomerReceipt = async (payload: PostCustomerReceiptInput) => {
  const { data, error } = await supabase.rpc('post_customer_receipt_with_allocations', {
    p_tenant_id: payload.tenant_id,
    p_billing_profile_id: payload.billing_profile_id,
    p_received_on: payload.received_on ?? localToday(),
    p_note: payload.note ?? null,
    p_reference: payload.reference ?? null,
    p_source: payload.source,
    p_instruments: payload.instruments ?? [],
    p_allocations: payload.allocations,
  });
  if (error) throw error;
  return data;
};

const voidCustomerReceipt = async (tenantId: number, paymentId: number, reason: string) => {
  const { data, error } = await supabase.rpc('void_customer_receipt', {
    p_tenant_id: tenantId,
    p_payment_id: paymentId,
    p_reason: reason,
  });
  if (error) throw error;
  return data;
};

const dispenseMiddlemanPayout = async (payload: {
  tenant_id: number;
  billing_profile_id: number;
  amount: number;
  payout_method?: string;
  reference_notes?: string | null;
}) => {
  const { data, error } = await supabase.rpc('dispense_middleman_payout_from_tenant', {
    p_tenant_id: payload.tenant_id,
    p_billing_profile_id: payload.billing_profile_id,
    p_amount: payload.amount,
    p_payout_method: payload.payout_method ?? 'bank_transfer',
    p_reference_notes: payload.reference_notes ?? null,
  });
  if (error) throw error;
  if (data && typeof data === 'object' && (data as { success?: boolean }).success === false) {
    throw new Error((data as { error?: string }).error || 'Payout failed');
  }
  return data;
};

export const paysRepository = {
  listPays,
  getPayById,
  listCustomerGroupsPaymentSummary,
  listCustomerGroupsPayoutSummary,
  listBillingProfilesForGroup,
  postCustomerReceipt,
  voidCustomerReceipt,
  dispenseMiddlemanPayout,
};

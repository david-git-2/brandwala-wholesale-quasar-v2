import { supabase } from 'src/boot/supabase';
import type { GlobalStockCostingInput } from 'src/modules/global/types';
import type {
  CreateGlobalInvoiceInput,
  GlobalInvoiceCreated,
  GlobalInvoiceDetail,
  GlobalInvoiceItemRow,
  GlobalInvoiceRow,
} from '../types';

const localToday = (): string => {
  const d = new Date();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
};

export type ListGlobalInvoicesParams = {
  parentTenantId: number;
  page?: number;
  pageSize?: number;
  search?: string;
  paymentStatus?: string | null;
  invoiceStatus?: string | null;
  invoiceType?: string | null;
  fromDate?: string | null;
  toDate?: string | null;
  quickFilter?: 'all' | 'paid' | 'unpaid';
};

export type PaginatedGlobalInvoices = {
  data: GlobalInvoiceRow[];
  total: number;
};

const listGlobalInvoices = async (
  params: ListGlobalInvoicesParams,
): Promise<PaginatedGlobalInvoices> => {
  const {
    parentTenantId,
    page = 1,
    pageSize = 10,
    search,
    paymentStatus,
    invoiceStatus,
    invoiceType,
    fromDate,
    toDate,
    quickFilter,
  } = params;

  const offset = (page - 1) * pageSize;

  let query = supabase
    .from('global_invoices')
    .select(
      'id, tenant_id, parent_tenant_id, invoice_no, invoice_type, invoice_status, payment_status, invoice_date, due_date, total_amount, due_amount, paid_amount, billing_profile_id, recipient_name, billing_profiles(name, email, color, customer_group_id)',
      { count: 'exact' },
    )
    .eq('parent_tenant_id', parentTenantId);

  if (paymentStatus) {
    query = query.eq('payment_status', paymentStatus);
  }
  if (invoiceStatus) {
    query = query.eq('invoice_status', invoiceStatus);
  }
  if (invoiceType) {
    query = query.eq('invoice_type', invoiceType);
  }

  if (quickFilter === 'paid') {
    query = query.eq('payment_status', 'paid');
  } else if (quickFilter === 'unpaid') {
    query = query.neq('payment_status', 'paid');
  }

  if (fromDate) {
    query = query.gte('invoice_date', fromDate);
  }
  if (toDate) {
    query = query.lte('invoice_date', toDate);
  }

  if (search && search.trim()) {
    const cleanSearch = search.trim();
    let billingProfileIds: number[] = [];
    const { data: profiles } = await supabase
      .from('billing_profiles')
      .select('id')
      .ilike('name', `%${cleanSearch}%`);
    if (profiles) {
      billingProfileIds = profiles.map((p) => p.id);
    }

    const conditions = [
      `invoice_no.ilike.%${cleanSearch}%`,
      `recipient_name.ilike.%${cleanSearch}%`,
    ];
    const maybeId = Number(cleanSearch);
    if (!Number.isNaN(maybeId) && Number.isFinite(maybeId)) {
      conditions.push(`id.eq.${maybeId}`);
    }
    if (billingProfileIds.length > 0) {
      conditions.push(`billing_profile_id.in.(${billingProfileIds.join(',')})`);
    }
    query = query.or(conditions.join(','));
  }

  const { data, error, count } = await query
    .order('id', { ascending: false })
    .range(offset, offset + pageSize - 1);

  if (error) throw error;

  type GlobalInvoiceListRow = GlobalInvoiceRow & {
    billing_profiles?: { name: string; email: string | null; color: string | null; customer_group_id: number | null } | { name: string; email: string | null; color: string | null; customer_group_id: number | null }[] | null;
  };

  const rows = ((data as GlobalInvoiceListRow[] | null) ?? []).map((row) => {
    const billingProfile = Array.isArray(row.billing_profiles)
      ? (row.billing_profiles[0] ?? null)
      : (row.billing_profiles ?? null);

    return {
      ...row,
      billing_profile_name: billingProfile?.name ?? null,
      billing_profile_email: billingProfile?.email ?? null,
      billing_profile_color: billingProfile?.color ?? null,
      billing_profile_customer_group_id: billingProfile?.customer_group_id ?? null,
    };
  });

  return {
    data: rows,
    total: count ?? 0,
  };
};

const createGlobalInvoice = async (
  payload: CreateGlobalInvoiceInput,
): Promise<GlobalInvoiceCreated> => {
  const { data, error } = await supabase.rpc('create_global_invoice', {
    p_tenant_id: payload.tenant_id,
    p_invoice_no: payload.invoice_no.trim(),
    p_billing_profile_id: payload.billing_profile_id ?? null,
    p_recipient_profile_id: payload.recipient_profile_id ?? null,
    p_invoice_type: payload.invoice_type ?? 'wholesale',
    p_recipient_name: payload.recipient_name ?? null,
    p_recipient_phone: payload.recipient_phone ?? null,
    p_recipient_address: payload.recipient_address ?? null,
    p_retail_billing_mode: payload.retail_billing_mode ?? null,
    p_due_date: payload.due_date ?? null,
    p_note: payload.note?.trim() || null,
    p_invoice_date: payload.invoice_date ?? null,
  });

  if (error) throw error;
  if (!data) throw new Error('Global invoice was not created.');

  return data as GlobalInvoiceCreated;
};

const getGlobalInvoiceById = async (invoiceId: number): Promise<GlobalInvoiceDetail> => {
  const { data, error } = await supabase
    .from('global_invoices')
    .select('*, billing_profiles(id, name, email, phone, address, color)')
    .eq('id', invoiceId)
    .single();

  if (error) throw error;
  return data as GlobalInvoiceDetail;
};

const mapListGlobalInvoiceItemRow = (row: any): GlobalInvoiceItemRow => {
  const shipmentItemId = row.shipment_item_id ? Number(row.shipment_item_id) : null;
  const shipmentId = row.shipment_id ? Number(row.shipment_id) : null;
  const shipmentType = row.shipment_type;

  const hasCosting =
    shipmentItemId !== null &&
    shipmentId !== null &&
    (shipmentType === 'domestic' || shipmentType === 'international');

  const costing: GlobalStockCostingInput | null = hasCosting
    ? {
        shipment_id: shipmentId,
        shipment_item_id: shipmentItemId,
        purchase_price: Number(row.purchase_price ?? 0),
        product_weight: Number(row.product_weight ?? 0),
        package_weight: Number(row.package_weight ?? 0),
        ordered_quantity: Number(row.ordered_quantity ?? 0),
        shipment_type: shipmentType as 'domestic' | 'international',
        product_conversion_rate: Number(row.product_conversion_rate ?? 1),
        cargo_conversion_rate: Number(row.cargo_conversion_rate ?? 1),
        cargo_rate: Number(row.cargo_rate ?? 0),
        received_weight: row.received_weight == null ? null : Number(row.received_weight),
        transaction_rate: row.transaction_rate == null ? null : Number(row.transaction_rate),
      }
    : null;

  return {
    id: Number(row.id),
    invoice_id: Number(row.invoice_id),
    global_stock_id: Number(row.global_stock_id),
    name_snapshot: row.name_snapshot,
    quantity: Number(row.quantity),
    sell_price_amount: Number(row.sell_price_amount),
    recipient_price_amount:
      row.recipient_price_amount == null ? null : Number(row.recipient_price_amount),
    line_face_total_amount:
      row.line_face_total_amount == null ? null : Number(row.line_face_total_amount),
    line_discount_amount: Number(row.line_discount_amount),
    line_total_amount: Number(row.line_total_amount),
    return_quantity: Number(row.return_quantity),
    costing,
    image_url: row.image_url || null,
  };
};

const listGlobalInvoiceItems = async (invoiceId: number): Promise<GlobalInvoiceItemRow[]> => {
  const { data, error } = await supabase.rpc('list_global_invoice_items', {
    p_invoice_id: invoiceId,
  });

  if (error) throw error;

  return ((data as any[]) ?? []).map(mapListGlobalInvoiceItemRow);
};

const addGlobalInvoiceItem = async (payload: {
  invoice_id: number;
  global_stock_id: number;
  quantity: number;
  sell_price_amount: number;
  line_discount_amount?: number;
  recipient_price_amount?: number;
}): Promise<GlobalInvoiceItemRow> => {
  const { data, error } = await supabase.rpc('add_global_invoice_item', {
    p_invoice_id: payload.invoice_id,
    p_global_stock_id: payload.global_stock_id,
    p_quantity: payload.quantity,
    p_sell_price_amount: payload.sell_price_amount,
    p_line_discount_amount: payload.line_discount_amount ?? 0,
    p_recipient_price_amount: payload.recipient_price_amount ?? null,
  });

  if (error) throw error;
  return data as GlobalInvoiceItemRow;
};

const recordBillingProfilePayment = async (payload: {
  tenant_id: number;
  billing_profile_id: number;
  amount: number;
  payment_date?: string;
  method?: string;
  reference?: string | null;
  allocations: Array<{ global_invoice_id: number; amount: number }>;
}) => {
  const { data, error } = await supabase.rpc('create_billing_profile_payment_with_allocations', {
    p_tenant_id: payload.tenant_id,
    p_billing_profile_id: payload.billing_profile_id,
    p_amount: payload.amount,
    p_payment_date: payload.payment_date ?? localToday(),
    p_method: payload.method ?? 'cash',
    p_reference: payload.reference ?? null,
    p_note: null,
    p_allocations: payload.allocations.map((a) => ({
      global_invoice_id: a.global_invoice_id,
      amount: a.amount,
    })),
  });
  if (error) throw error;
  return data;
};

const recordRecipientInvoiceCollection = async (
  globalInvoiceId: number,
  amount: number,
  opts?: {
    payment_date?: string;
    method?: string;
    reference?: string | null;
    note?: string | null;
  },
) => {
  const { data, error } = await supabase.rpc('record_recipient_invoice_collection', {
    p_global_invoice_id: globalInvoiceId,
    p_amount: amount,
    p_payment_date: opts?.payment_date ?? localToday(),
    p_method: opts?.method ?? 'cash',
    p_reference: opts?.reference ?? null,
    p_note: opts?.note ?? null,
  });
  if (error) throw error;
  return data;
};

const applySettlementDiscount = async (invoiceId: number, amount: number, note?: string | null) => {
  const { data, error } = await supabase.rpc('apply_global_invoice_settlement_discount', {
    p_invoice_id: invoiceId,
    p_amount: amount,
    p_note: note ?? null,
  });
  if (error) throw error;
  return data;
};

const createMiddleManPayout = async (payload: {
  tenant_id: number;
  billing_profile_id: number;
  global_invoice_id: number;
  amount: number;
}) => {
  const { data, error } = await supabase.rpc('create_middle_man_payout', {
    p_tenant_id: payload.tenant_id,
    p_billing_profile_id: payload.billing_profile_id,
    p_global_invoice_id: payload.global_invoice_id,
    p_amount: payload.amount,
    p_note: null,
  });
  if (error) throw error;
  return data;
};

const addGlobalReturnItem = async (payload: {
  invoice_id: number;
  invoice_item_id: number;
  quantity: number;
  return_face_amount: number;
  return_accounting_amount: number;
  return_charge_amount?: number;
  note?: string | null;
}) => {
  const { data, error } = await supabase.rpc('add_global_return_item', {
    p_invoice_id: payload.invoice_id,
    p_invoice_item_id: payload.invoice_item_id,
    p_quantity: payload.quantity,
    p_return_face_amount: payload.return_face_amount,
    p_return_accounting_amount: payload.return_accounting_amount,
    p_return_charge_amount: payload.return_charge_amount ?? 0,
    p_note: payload.note ?? null,
  });
  if (error) throw error;
  return data;
};

const getGlobalInvoicesPaidAmounts = async (
  invoiceIds: number[],
): Promise<Record<string, number>> => {
  if (!invoiceIds.length) return {};

  const { data, error } = await supabase
    .from('global_invoices')
    .select('id, paid_amount')
    .in('id', invoiceIds);

  if (error) throw error;

  const paidAmounts: Record<string, number> = {};
  for (const invoice of data ?? []) {
    paidAmounts[`normal_${invoice.id}`] = Number(invoice.paid_amount ?? 0);
  }
  return paidAmounts;
};

const removeGlobalInvoiceItem = async (invoiceItemId: number): Promise<void> => {
  const { error } = await supabase.rpc('remove_global_invoice_item', {
    p_invoice_item_id: invoiceItemId,
  });
  if (error) throw error;
};

const updateGlobalInvoiceItem = async (payload: {
  id: number;
  quantity: number;
  sell_price_amount: number;
  recipient_price_amount?: number;
}): Promise<GlobalInvoiceItemRow> => {
  const { data, error } = await supabase.rpc('update_global_invoice_item', {
    p_item_id: payload.id,
    p_quantity: payload.quantity,
    p_sell_price_amount: payload.sell_price_amount,
    p_recipient_price_amount: payload.recipient_price_amount ?? null,
  });

  if (error) throw error;
  return data as GlobalInvoiceItemRow;
};

export type TargetTotalLineChange = {
  item_id: number;
  name: string;
  quantity: number;
  old_price: number;
  new_price: number;
  unit_delta: number;
  line_delta: number;
};

export type TargetTotalSummary = {
  current_total: number;
  target_total: number;
  adjustment: number;
  is_dropship: boolean;
  lines: TargetTotalLineChange[];
};

const applyGlobalInvoiceTargetTotal = async (payload: {
  id: number;
  target_total: number;
  dry_run?: boolean;
}): Promise<TargetTotalSummary> => {
  const { data, error } = await supabase.rpc('apply_global_invoice_target_total', {
    p_invoice_id: payload.id,
    p_target_total: payload.target_total,
    p_dry_run: payload.dry_run ?? false,
  });

  if (error) throw error;
  return data;
};

const updateGlobalInvoiceHeader = async (payload: {
  id: number;
  discount_amount?: number | null;
  shipping_charge?: number | null;
  cod_charge?: number | null;
  wrapping_charge?: number | null;
  print_charge?: number | null;
  recipient_name?: string | null;
  recipient_phone?: string | null;
  recipient_address?: string | null;
  note?: string | null;
  invoice_no?: string | null;
  invoice_date?: string | null;
}): Promise<void> => {
  const { error } = await supabase.rpc('update_global_invoice_header', {
    p_invoice_id: payload.id,
    p_discount_amount: payload.discount_amount,
    p_shipping_charge: payload.shipping_charge,
    p_cod_charge: payload.cod_charge,
    p_wrapping_charge: payload.wrapping_charge,
    p_print_charge: payload.print_charge,
    p_recipient_name: payload.recipient_name,
    p_recipient_phone: payload.recipient_phone,
    p_recipient_address: payload.recipient_address,
    p_note: payload.note,
    p_invoice_no: payload.invoice_no ?? null,
    p_invoice_date: payload.invoice_date ?? null,
  });
  if (error) throw error;
};

const postGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.rpc('post_global_invoice', {
    p_invoice_id: invoiceId,
  });
  if (error) throw error;
};

const voidGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.rpc('void_global_invoice', {
    p_invoice_id: invoiceId,
  });
  if (error) throw error;
};

const unpostGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.rpc('unpost_global_invoice', {
    p_invoice_id: invoiceId,
  });
  if (error) throw error;
};

const deleteGlobalInvoice = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.from('global_invoices').delete().eq('id', invoiceId);
  if (error) throw error;
};

const convertWholesaleDraftToRetail = async (invoiceId: number): Promise<void> => {
  const { error } = await supabase.rpc('convert_wholesale_draft_to_retail', {
    p_invoice_id: invoiceId,
  });
  if (error) throw error;
};

const updateInvoiceItemsBulk = async (
  updates: Array<{
    id: number;
    quantity: number;
    sell_price_amount: number;
    recipient_price_amount?: number;
  }>,
) => Promise.all(updates.map(updateGlobalInvoiceItem));

export type InvoiceBrand = {
  id: number;
  tenant_id: number;
  name: string;
  address: string;
  created_at?: string;
  updated_at?: string;
};

export type CreateInvoiceBrandInput = Omit<InvoiceBrand, 'id' | 'created_at' | 'updated_at'>;

const listInvoiceBrands = async (
  payload: { tenant_id?: number } = {},
): Promise<(InvoiceBrand & { tenants?: { name: string } })[]> => {
  let query = supabase.from('invoice_brands').select('*, tenants(name)');
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id);
  }
  const { data, error } = await query.order('name', { ascending: true });
  if (error) throw error;
  return data || [];
};

const createInvoiceBrand = async (payload: CreateInvoiceBrandInput): Promise<InvoiceBrand> => {
  const { data, error } = await supabase
    .from('invoice_brands')
    .insert([payload])
    .select('*')
    .single();
  if (error) throw error;
  return data as InvoiceBrand;
};

const updateInvoiceBrand = async (payload: {
  id: number;
  patch: Partial<Omit<InvoiceBrand, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>>;
}): Promise<InvoiceBrand> => {
  const { data, error } = await supabase
    .from('invoice_brands')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single();
  if (error) throw error;
  return data as InvoiceBrand;
};

const deleteInvoiceBrand = async (payload: { id: number }): Promise<void> => {
  const { error } = await supabase.from('invoice_brands').delete().eq('id', payload.id);
  if (error) throw error;
};

export const invoiceRepository = {
  listGlobalInvoices,
  createGlobalInvoice,
  getGlobalInvoiceById,
  listGlobalInvoiceItems,
  addGlobalInvoiceItem,
  updateGlobalInvoiceItem,
  updateInvoiceItemsBulk,
  applyGlobalInvoiceTargetTotal,
  recordBillingProfilePayment,
  recordRecipientInvoiceCollection,
  applySettlementDiscount,
  createMiddleManPayout,
  addGlobalReturnItem,
  getGlobalInvoicesPaidAmounts,
  removeGlobalInvoiceItem,
  updateGlobalInvoiceHeader,
  postGlobalInvoice,
  voidGlobalInvoice,
  unpostGlobalInvoice,
  deleteGlobalInvoice,
  convertWholesaleDraftToRetail,
  listInvoiceBrands,
  createInvoiceBrand,
  updateInvoiceBrand,
  deleteInvoiceBrand,
};

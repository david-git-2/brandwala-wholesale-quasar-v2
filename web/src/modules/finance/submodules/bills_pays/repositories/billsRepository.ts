import { supabase } from 'src/boot/supabase';
import type { GlobalStockCostingInput } from 'src/modules/procurement_stock/submodules/global_stock/types';
import type {
  GlobalInvoiceDetail,
  GlobalInvoiceItemRow,
  GlobalInvoiceRow,
  InvoicePaymentHistoryEntry,
} from 'src/modules/finance/submodules/bills_pays/types/invoice';
import type { BillPayCashbookLegs } from 'src/modules/finance/submodules/bills_pays/types/billPayCashbookLegs';
import { parseBillPayCashbookLegsFromRpc } from 'src/modules/finance/submodules/bills_pays/types/billPayCashbookLegs';
import type {
  BillListRow,
  BillsListPageCursor,
  BillsListPageResult,
  ListBillsDeskPageParams,
} from '../types/billList';
import { moneyKernelRepository } from './moneyKernelRepository';
import {
  buildKernelCreateBillPayload,
  buildKernelUpdateDraftPayload,
} from '../utils/kernelComposeBillPayload';

export type ListBillsParams = {
  tenantId?: number | null;
  createdBy?: string | null;
  page?: number;
  pageSize?: number;
  search?: string;
  paymentStatus?: string | null;
  invoiceStatus?: string | null;
  invoiceType?: string | null;
  retailBillingMode?: 'account' | 'direct' | null;
  fromDate?: string | null;
  toDate?: string | null;
  quickFilter?: 'all' | 'paid' | 'unpaid';
  profileId?: number | null;
  arSide?: 'they_owe' | 'we_owe';
};

export type PaginatedBills = {
  data: GlobalInvoiceRow[];
  total: number;
};

export type BillPayloadItem = {
  id?: number;
  global_stock_id?: number | null;
  product_id?: number | null;
  shipment_item_id?: number | null;
  line_kind?: 'stock' | 'description' | 'service' | 'charge' | 'adjustment';
  name_snapshot?: string;
  quantity: number;
  sell_price_amount: number;
  line_discount_amount?: number;
  line_total_amount?: number;
  line_meta?: Record<string, unknown>;
};

export type BillFromPayloadInput = {
  invoice: {
    invoice_no?: string;
    invoice_type: string;
    profile_id: number | null;
    from_profile_id?: number | null;
    to_profile_id?: number | null;
    settlement_kind?: string | null;
    document_kind?: string;
    parent_bill_id?: number | null;
    source_type?: string | null;
    source_id?: string | null;
    source_key?: string | null;
    recipient_profile_id?: number | null;
    recipient_name?: string | null;
    recipient_phone?: string | null;
    recipient_address?: string | null;
    retail_billing_mode?: 'account' | 'direct' | null;
    due_date?: string | null;
    invoice_date?: string | null;
    note?: string | null;
    discount_amount?: number | null;
    shipping_charge?: number | null;
    cod_charge_amount?: number | null;
    wrapping_charge?: number | null;
    print_charge?: number | null;
    channel_meta?: Record<string, unknown> | null;
  };
  items: BillPayloadItem[];
  issue?: boolean;
};

export type BillFromPayloadResult = {
  success: boolean;
  invoice_id?: number;
  invoice_no?: string;
  invoice_status?: string;
  payment_status?: string;
  total_amount?: number;
  due_amount?: number;
  paid_amount?: number;
  error?: string;
};

export type BillUpdatePayloadInput = {
  invoice?: Partial<BillFromPayloadInput['invoice']>;
  items?: BillPayloadItem[];
  remove_item_ids?: number[];
  options?: { recompute_totals?: boolean };
};

export type BillStockItem = {
  global_stock_id: number;
  shipment_item_id: number;
  product_id: number | null;
  name: string;
  barcode: string | null;
  product_code: string | null;
  image_url: string | null;
  quantity: number;
  available_atp: number;
  unit_cost_price: number;
  suggested_sell_price: number;
  shipment_id: number;
  shipment_name: string;
  holding_tenant_id: number;
  holding_tenant_name: string;
  is_allocated_to_tenant: boolean;
  allocation_rank: number;
  location_id: number | null;
  location_name: string | null;
  stock_created_at: string;
};

export type BillBrand = {
  id: number;
  tenant_id: number;
  name: string;
  address: string;
  created_at?: string;
  updated_at?: string;
};

export type CreateBillBrandInput = Omit<BillBrand, 'id' | 'created_at' | 'updated_at'>;

export type BillDetailBundleLine = {
  id: number;
  name_snapshot: string;
  currency_code: string;
  line_total_amount: number;
  books_amount: number;
  quantity: number;
  sell_price_amount?: number | null;
  global_stock_id?: number | null;
  product_id?: number | null;
  shipment_item_id?: number | null;
  shipment_id?: number | null;
};

export type BillDetailBundle = {
  bill: GlobalInvoiceDetail;
  paymentHistory: InvoicePaymentHistoryEntry[];
  netBalances: Record<string, unknown>;
  adjustments: Record<string, unknown>[];
  stockItems: GlobalInvoiceItemRow[];
  billLines: BillDetailBundleLine[];
  payCashbookLegs: BillPayCashbookLegs | null;
};

export type BillDetailBundlesResult = {
  success: boolean;
  bundles: BillDetailBundle[];
  missingIds: number[];
};

// Re-export legacy type aliases for callers migrating gradually
export type {
  ListBillsParams as ListGlobalInvoicesParams,
  PaginatedBills as PaginatedGlobalInvoices,
  BillFromPayloadInput as SalesInvoiceFromPayloadInput,
  BillFromPayloadResult as SalesInvoiceFromPayloadResult,
  BillPayloadItem as SalesInvoicePayloadItem,
  BillStockItem as SalesInvoiceStockItem,
  BillUpdatePayloadInput as SalesInvoiceUpdatePayloadInput,
  BillBrand as InvoiceBrand,
  CreateBillBrandInput as CreateInvoiceBrandInput,
};

export type IssueBillOptions = {
  invoiceType: string;
  tenantId?: number;
  stockItems?: Array<{
    id?: number;
    global_stock_id: number;
    quantity: number;
    sell_price_amount?: number;
  }>;
};

const AP_KINDS = ['shipment_cost_ap', 'dropship_courier_ap'];
const AR_KINDS = [
  'sales_invoice_wholesale',
  'sales_invoice_retail',
  'sales_invoice_dropship',
  'dropship_courier_ar',
];

function kindToInvoiceType(kind: string | null | undefined): string {
  switch (kind) {
    case 'shipment_cost_ap':
    case 'dropship_courier_ap':
      return 'ap';
    case 'sales_invoice_retail':
      return 'retail';
    case 'sales_invoice_dropship':
    case 'dropship_courier_ar':
      return 'dropship';
    case 'sales_invoice_wholesale':
    default:
      return 'wholesale';
  }
}

function resolveQueryKinds(params: ListBillsParams): string[] | undefined {
  if (params.arSide === 'we_owe' || params.invoiceType === 'ap') return AP_KINDS;
  if (params.invoiceType === 'wholesale') return ['sales_invoice_wholesale'];
  if (params.invoiceType === 'retail' || params.retailBillingMode) return ['sales_invoice_retail'];
  if (params.invoiceType === 'dropship') return ['sales_invoice_dropship', 'dropship_courier_ar'];
  if (params.arSide === 'they_owe') return AR_KINDS;
  return undefined;
}

const mapListBillItemRow = (row: any): GlobalInvoiceItemRow => {
  const shipmentItemId = row.shipment_item_id ? Number(row.shipment_item_id) : null;
  const shipmentId = row.shipment_id ? Number(row.shipment_id) : null;
  const shipmentType = row.shipment_type;

  const hasCosting =
    shipmentItemId !== null &&
    shipmentId !== null &&
    (shipmentType === 'local' ||
      shipmentType === 'international' ||
      shipmentType === 'transfer');

  const costing: GlobalStockCostingInput | null = hasCosting
    ? {
        shipment_id: shipmentId,
        shipment_item_id: shipmentItemId,
        purchase_price: Number(row.purchase_price ?? 0),
        product_weight: Number(row.product_weight ?? 0),
        package_weight: Number(row.package_weight ?? 0),
        ordered_quantity: Number(row.ordered_quantity ?? 0),
        shipment_type: shipmentType as 'international' | 'local' | 'transfer',
        received_weight: row.received_weight == null ? null : Number(row.received_weight),
        landed_cost_bdt:
          row.landed_cost_bdt == null || row.landed_cost_bdt === undefined
            ? null
            : Number(row.landed_cost_bdt),
      }
    : null;

  return {
    id: Number(row.id),
    invoice_id: Number(row.invoice_id),
    global_stock_id: row.global_stock_id == null ? 0 : Number(row.global_stock_id),
    name_snapshot: row.name_snapshot,
    quantity: Number(row.quantity),
    sell_price_amount: Number(row.sell_price_amount),
    line_discount_amount: Number(row.line_discount_amount),
    line_total_amount: Number(row.line_total_amount),
    return_quantity: Number(row.return_quantity),
    available_atp: row.available_atp == null ? null : Number(row.available_atp),
    unit_cost_price: row.unit_cost_price == null ? null : Number(row.unit_cost_price),
    costing,
    image_url: row.image_url || null,
    shipment_item_id: shipmentItemId,
    shipment_id: shipmentId,
  };
};

export function parseBillDetailBundleFromRpc(data: unknown): BillDetailBundle {
  const raw = (data ?? {}) as Record<string, unknown>;
  const stockRaw = raw.stock_items;
  const stockItems = Array.isArray(stockRaw)
    ? stockRaw.map((row) => mapListBillItemRow(row))
    : [];
  const linesRaw = raw.bill_lines;
  const billLines = Array.isArray(linesRaw)
    ? linesRaw.map((row) => {
        const r = row as Record<string, unknown>;
        return {
          id: Number(r.id),
          name_snapshot: typeof r.name_snapshot === 'string' ? r.name_snapshot : 'Line',
          currency_code: (typeof r.currency_code === 'string' ? r.currency_code : 'BDT').toUpperCase(),
          line_total_amount: Number(r.line_total_amount ?? 0),
          books_amount: Number(r.books_amount ?? r.line_total_amount ?? 0),
          quantity: Number(r.quantity ?? 1),
          sell_price_amount:
            r.sell_price_amount == null ? null : Number(r.sell_price_amount),
          global_stock_id:
            r.global_stock_id == null ? null : Number(r.global_stock_id),
          product_id: r.product_id == null ? null : Number(r.product_id),
          shipment_item_id:
            r.shipment_item_id == null ? null : Number(r.shipment_item_id),
          shipment_id: r.shipment_id == null ? null : Number(r.shipment_id),
        };
      })
    : [];
  return {
    bill: raw.bill as GlobalInvoiceDetail,
    paymentHistory: (raw.payment_history as InvoicePaymentHistoryEntry[] | null) ?? [],
    netBalances: (raw.net_balances as Record<string, unknown>) ?? {},
    adjustments: (raw.adjustments as Record<string, unknown>[] | null) ?? [],
    stockItems,
    billLines,
    payCashbookLegs: parseBillPayCashbookLegsFromRpc(raw.pay_cashbook_legs),
  };
}

const parsePayloadRpcResult = (data: unknown): BillFromPayloadResult => {
  const result = (data ?? {}) as BillFromPayloadResult;
  if (!result.success) {
    throw new Error(result.error || 'Bill payload RPC failed');
  }
  return result;
};

const billRowToPayloadResult = (row: {
  id: number;
  invoice_no: string;
  invoice_status: string;
  payment_status: string;
  total_amount: number;
  due_amount: number;
  paid_amount: number;
}): BillFromPayloadResult => ({
  success: true,
  invoice_id: row.id,
  invoice_no: row.invoice_no,
  invoice_status: row.invoice_status,
  payment_status: row.payment_status,
  total_amount: row.total_amount,
  due_amount: row.due_amount,
  paid_amount: row.paid_amount,
});

const listBills = async (params: ListBillsParams): Promise<PaginatedBills> => {
  if (!params.tenantId) {
    return { data: [], total: 0 };
  }

  const statuses =
    params.invoiceStatus === 'issued'
      ? ['issued', 'partially_paid']
      : params.invoiceStatus === 'draft'
        ? ['draft']
        : params.invoiceStatus
          ? [params.invoiceStatus]
          : undefined;

  const hasDue =
    params.quickFilter === 'unpaid'
      ? true
      : params.quickFilter === 'paid'
        ? false
        : undefined;

  const { data, error } = await supabase.rpc('rpc_query_bills', {
    p_tenant_id: params.tenantId,
    p_kinds: resolveQueryKinds(params),
    p_statuses: statuses,
    p_counterparty_profile_id: params.profileId ?? undefined,
    p_from_date: params.fromDate ?? undefined,
    p_to_date: params.toDate ?? undefined,
    p_has_due: hasDue,
    p_include_voided: params.invoiceStatus === 'voided',
    p_limit: params.pageSize ?? 50,
  });
  if (error) throw error;

  const payload = (data ?? {}) as { rows?: Array<Record<string, unknown>> };
  const rawRows = Array.isArray(payload.rows) ? payload.rows : [];

  const rows: GlobalInvoiceRow[] = rawRows.map((r) => {
    const meta = (r.meta ?? {}) as Record<string, unknown>;
    const due = Number(r.due_amount ?? 0);
    const paid = Number(r.paid_amount ?? 0);
    const status = typeof r.status === 'string' ? r.status : 'draft';
    const paymentStatus =
      status === 'voided'
        ? 'voided'
        : status === 'draft'
          ? 'draft'
          : due <= 0
            ? 'paid'
            : paid > 0
              ? 'partially_paid'
              : 'due';
    const orderNo = typeof meta.order_no === 'string' ? meta.order_no.trim() : '';
    const billIdNum = Number(r.bill_id);
    return {
      id: billIdNum,
      tenant_id: Number(r.tenant_id),
      issued_by_tenant_id: Number(r.tenant_id),
      invoice_no: typeof r.invoice_no === 'string' ? r.invoice_no : `DRAFT-${billIdNum}`,
      invoice_type: kindToInvoiceType(r.kind as string | null),
      invoice_status: status === 'partially_paid' ? 'issued' : status,
      payment_status: paymentStatus,
      invoice_date: typeof r.invoice_date === 'string' ? r.invoice_date : '',
      due_date: (r.due_date as string | null) ?? null,
      total_amount: Number(r.total_amount ?? 0),
      due_amount: due,
      paid_amount: paid,
      profile_id: r.counterparty_profile_id == null ? null : Number(r.counterparty_profile_id),
      shop_order_id: meta.shop_order_id == null ? null : Number(meta.shop_order_id),
      retail_billing_mode: (meta.retail_billing_mode as 'account' | 'direct' | null) ?? null,
      channel_meta: meta,
      recipient_name: typeof meta.recipient_name === 'string' ? meta.recipient_name : null,
      created_by: null,
      created_at: typeof r.created_at === 'string' ? r.created_at : '',
      source_context_label: orderNo ? `Order ${orderNo}` : null,
    } as GlobalInvoiceRow;
  });

  return { data: rows, total: rows.length };
};

const listBillsPage = async (
  params: ListBillsDeskPageParams,
  cursor: BillsListPageCursor,
): Promise<BillsListPageResult> => {
  const tenantId = params.tenantId;
  if (!tenantId) {
    return { data: [], meta: { has_more: false, next_cursor: null } };
  }

  const toType =
    params.toProfileType && params.toProfileType !== 'all' ? params.toProfileType : undefined;

  const { data, error } = await supabase.rpc('list_bills_desk_page', {
    p_tenant_id: tenantId,
    p_to_profile_type: toType,
    p_from_profile_id: params.fromProfileId ?? undefined,
    p_invoice_status: params.invoiceStatus ?? undefined,
    p_payment_status: params.paymentStatus ?? undefined,
    p_quick_filter: params.quickFilter ?? undefined,
    p_page_size: params.pageSize ?? 25,
    p_cursor: cursor ?? undefined,
  });
  if (error) throw error;

  const payload = (data ?? {}) as {
    data?: BillListRow[];
    meta?: { has_more?: boolean; next_cursor?: number | null };
  };

  return {
    data: payload.data ?? [],
    meta: {
      has_more: Boolean(payload.meta?.has_more),
      next_cursor: payload.meta?.next_cursor ?? null,
    },
  };
};

const getBillById = async (billId: number): Promise<GlobalInvoiceDetail> => {
  const { data, error } = await supabase.rpc('get_bill_desk_row', {
    p_bill_id: billId,
  });
  if (error) throw error;
  if (!data || typeof data !== 'object') {
    throw new Error('Bill not found');
  }
  return data as GlobalInvoiceDetail;
};

const getBillDetailBundle = async (params: {
  tenantId: number;
  billId: number;
}): Promise<BillDetailBundle> => {
  const { data, error } = await supabase.rpc('get_bill_detail_bundle', {
    p_tenant_id: params.tenantId,
    p_bill_id: params.billId,
  });
  if (error) throw error;
  return parseBillDetailBundleFromRpc(data);
};

const getBillDetailBundles = async (params: {
  tenantId: number;
  billIds: number[];
}): Promise<BillDetailBundlesResult> => {
  const ids = [...new Set(params.billIds.filter((id) => id > 0))];
  if (!ids.length) {
    return { success: true, bundles: [], missingIds: [] };
  }

  const { data, error } = await supabase.rpc('get_bill_detail_bundles', {
    p_tenant_id: params.tenantId,
    p_bill_ids: ids,
  });
  if (error) throw error;

  const raw = (data ?? {}) as Record<string, unknown>;
  const bundlesRaw = raw.bundles;
  const bundles = Array.isArray(bundlesRaw)
    ? bundlesRaw.map((entry) => parseBillDetailBundleFromRpc(entry))
    : [];
  const missingRaw = raw.missing_ids;
  const missingIds = Array.isArray(missingRaw)
    ? missingRaw.map((id) => Number(id)).filter((id) => Number.isFinite(id) && id > 0)
    : [];

  return {
    success: raw.success !== false,
    bundles,
    missingIds,
  };
};

const listBillItems = async (billId: number): Promise<GlobalInvoiceItemRow[]> => {
  const { data, error } = await supabase.rpc('list_global_invoice_items', {
    p_invoice_id: billId,
  });
  if (error) throw error;
  return ((data as any[]) ?? []).map(mapListBillItemRow);
};

const searchBillStock = async (params: {
  tenantId: number;
  search?: string;
  limit?: number;
  offset?: number;
}): Promise<BillStockItem[]> => {
  const { data, error } = await supabase.rpc('search_sales_invoice_stock', {
    p_tenant_id: params.tenantId,
    p_search: params.search?.trim() ? params.search.trim() : undefined,
    p_limit: params.limit ?? 50,
    p_offset: params.offset ?? 0,
  });
  if (error) throw error;
  return (data || []) as BillStockItem[];
};

const kernelCreateResultToPayload = (data: {
  bill_id?: number;
  invoice_no?: string;
  status?: string;
  total_amount?: number;
  due_amount?: number;
}): BillFromPayloadResult => ({
  success: true,
  invoice_id: data.bill_id,
  invoice_no: data.invoice_no,
  invoice_status: data.status === 'issued' ? 'issued' : 'draft',
  payment_status: data.status === 'issued' ? 'due' : 'draft',
  total_amount: data.total_amount,
  due_amount: data.due_amount,
  paid_amount: 0,
});

const upsertKernelComposeDraft = async (
  tenantId: number,
  payload: BillFromPayloadInput,
  autoIssue: boolean,
): Promise<BillFromPayloadResult> => {
  const body = buildKernelCreateBillPayload(tenantId, payload, { autoIssue });
  const created = await moneyKernelRepository.createBill(body);
  if (!created.bill_id) throw new Error(created.error ?? 'rpc_create_bill failed');
  if (autoIssue && created.status !== 'issued') {
    const issued = await moneyKernelRepository.issueBill(tenantId, created.bill_id);
    return kernelCreateResultToPayload({ ...created, ...issued, status: issued.status ?? 'issued' });
  }
  return kernelCreateResultToPayload(created);
};

const updateKernelComposeDraft = async (
  tenantId: number,
  billId: number,
  payload: BillUpdatePayloadInput,
): Promise<BillFromPayloadResult> => {
  const body = buildKernelUpdateDraftPayload({
    invoice: {
      invoice_type: 'wholesale',
      profile_id: 0,
      ...payload.invoice,
    },
    items: payload.items ?? [],
    issue: false,
  });
  const updated = await moneyKernelRepository.updateDraftBillV2(tenantId, billId, body);
  return kernelCreateResultToPayload({
    bill_id: billId,
    invoice_no: updated.invoice_no,
    status: updated.status ?? 'draft',
    total_amount: updated.total_amount,
    due_amount: updated.due_amount,
  });
};

const issueKernelComposeBill = async (tenantId: number, billId: number) => {
  await moneyKernelRepository.issueBill(tenantId, billId);
};

const upsertDraftBill = async (
  tenantId: number,
  payload: BillFromPayloadInput,
): Promise<BillFromPayloadResult> => {
  const body = {
    tenant_id: tenantId,
    adapter: 'compose' as const,
    ...payload,
  };
  const { data, error } = await supabase.rpc('upsert_draft_bill', {
    p_payload: body as unknown as Record<string, unknown>,
  });
  if (error) throw error;
  if (!data) throw new Error('upsert_draft_bill returned no row');
  const row = data as GlobalInvoiceDetail;
  return billRowToPayloadResult(row);
};

const updateDraftBill = async (
  tenantId: number,
  billId: number,
  payload: BillUpdatePayloadInput,
): Promise<BillFromPayloadResult> => {
  const { data, error } = await supabase.rpc('update_draft_bill', {
    p_tenant_id: tenantId,
    p_bill_id: billId,
    p_payload: payload as unknown as Record<string, unknown>,
  });
  if (error) throw error;
  return parsePayloadRpcResult(data);
};

const issueApBillFromDesk = async (
  billId: number,
  options: { tenantId: number },
): Promise<void> => {
  const { error } = await supabase.rpc('rpc_issue_bill', {
    p_tenant_id: options.tenantId,
    p_bill_id: billId,
  });
  if (error) throw error;
};

export type PatchBillDatesResult = {
  invoice_date: string;
  due_date: string | null;
};

const patchBillDates = async (params: {
  tenantId: number;
  billId: number;
  invoiceDate: string;
  dueDate?: string | null;
  touchDueDate: boolean;
}): Promise<PatchBillDatesResult> => {
  const { data, error } = await supabase.rpc('patch_bill_dates_from_desk', {
    p_tenant_id: params.tenantId,
    p_bill_id: params.billId,
    p_invoice_date: params.invoiceDate,
    p_due_date: params.dueDate ?? undefined,
    p_touch_due_date: params.touchDueDate,
  });
  if (error) throw error;
  if (!data) throw new Error('patch_bill_dates_from_desk returned no row');
  const row = data as { invoice_date?: string; due_date?: string | null };
  const dueRaw = row.due_date;
  return {
    invoice_date: String(row.invoice_date ?? params.invoiceDate).slice(0, 10),
    due_date:
      dueRaw != null && String(dueRaw).trim() !== '' ? String(dueRaw).slice(0, 10) : null,
  };
};

const issueBill = async (billId: number, options: IssueBillOptions): Promise<void> => {
  const type = options.invoiceType;
  const hasStock =
    (options.stockItems?.length ?? 0) > 0 &&
    options.stockItems!.some((i) => i.global_stock_id > 0 && i.quantity > 0);

  if (type === 'wholesale' || type === 'dropship') {
    const { error } = await supabase.rpc('issue_wholesale_bill', {
      p_bill_id: billId,
      p_items: hasStock
        ? ((options.stockItems ?? null) as unknown as Record<string, unknown>)
        : null,
    });
    if (error) throw error;
    return;
  }

  if (type === 'ap' && options.tenantId) {
    await issueApBillFromDesk(billId, { tenantId: options.tenantId });
    return;
  }

  if (type === 'retail') {
    const { error } = await supabase.rpc('issue_retail_bill', { p_bill_id: billId });
    if (error) throw error;
    return;
  }

  if (options.tenantId) {
    await moneyKernelRepository.issueBill(options.tenantId, billId);
    return;
  }

  const { error } = await supabase.rpc('issue_bill', { p_bill_id: billId });
  if (error) throw error;
};

const voidBill = async (
  billId: number,
  options?: { tenantId?: number; reason?: string | null },
): Promise<void> => {
  if (!options?.tenantId) {
    throw new Error('Tenant is required to void a bill.');
  }
  await moneyKernelRepository.voidKernelBill(
    options.tenantId,
    billId,
    options.reason ?? null,
    true,
  );
};

const applySettlementToBill = async (payload: {
  tenant_id: number;
  bill_id: number;
  allocator_kind: 'pay' | 'credit_note' | 'custody_entry';
  allocator_id?: number;
  books_amount: number;
}) => {
  if (payload.allocator_kind === 'credit_note' && payload.allocator_id) {
    return moneyKernelRepository.applyDocumentSettlement({
      tenantId: payload.tenant_id,
      sourceBillId: payload.allocator_id,
      targetBillId: payload.bill_id,
      amount: payload.books_amount,
    });
  }
  const { data, error } = await supabase.rpc('apply_settlement_to_bill', {
    p_tenant_id: payload.tenant_id,
    p_bill_id: payload.bill_id,
    p_allocator_kind: payload.allocator_kind,
    p_allocator_id: payload.allocator_id ?? 0,
    p_books_amount: payload.books_amount,
  });
  if (error) throw error;
  return data;
};

const deleteDraftBill = async (billId: number): Promise<void> => {
  const { error } = await supabase.rpc('delete_draft_bill_from_desk', {
    p_bill_id: billId,
  });
  if (error) throw error;
};

const listBillBrands = async (
  payload: { tenant_id?: number } = {},
): Promise<(BillBrand & { tenants?: { name: string } })[]> => {
  let query = supabase.from('invoice_brands').select('*, tenants(name)');
  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id);
  }
  const { data, error } = await query.order('name', { ascending: true });
  if (error) throw error;
  return (data || []) as (BillBrand & { tenants?: { name: string } })[];
};

const createBillBrand = async (payload: CreateBillBrandInput): Promise<BillBrand> => {
  const { data, error } = await supabase
    .from('invoice_brands')
    .insert([payload])
    .select('*')
    .single();
  if (error) throw error;
  return data as BillBrand;
};

const updateBillBrand = async (payload: {
  id: number;
  patch: Partial<Omit<BillBrand, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>>;
}): Promise<BillBrand> => {
  const { data, error } = await supabase
    .from('invoice_brands')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single();
  if (error) throw error;
  return data as BillBrand;
};

const deleteBillBrand = async (payload: { id: number }): Promise<void> => {
  const { error } = await supabase.from('invoice_brands').delete().eq('id', payload.id);
  if (error) throw error;
};

const listBillsForSource = async (params: {
  tenantId: number;
  sourceType: string;
  sourceId: string;
  sourceKey?: string | null;
  includeVoided?: boolean;
  apShipmentBucketsOnly?: boolean;
}) => {
  const { data, error } = await supabase.rpc('list_bills_for_source', {
    p_tenant_id: params.tenantId,
    p_source_type: params.sourceType,
    p_source_id: params.sourceId,
    p_source_key: params.sourceKey ?? undefined,
    p_include_voided: params.includeVoided ?? false,
    p_ap_shipment_buckets_only: params.apShipmentBucketsOnly ?? false,
  });
  if (error) throw error;
  return (data ?? []) as unknown[];
};

const listPaysForSource = async (params: {
  tenantId: number;
  sourceType: string;
  sourceId: string;
}) => {
  const { data, error } = await supabase.rpc('list_pays_for_source', {
    p_tenant_id: params.tenantId,
    p_source_type: params.sourceType,
    p_source_id: params.sourceId,
  });
  if (error) throw error;
  return (data ?? []) as unknown[];
};

const listOpenOnProfile = async (params: { tenantId: number; profileId: number }) => {
  const { data, error } = await supabase.rpc('list_open_on_profile', {
    p_tenant_id: params.tenantId,
    p_profile_id: params.profileId,
  });
  if (error) throw error;
  return data as {
    due_bills: unknown[];
    open_credit_notes: unknown[];
    pay_leftover: unknown[];
  };
};

export type { BillListRow, BillsListPageCursor, BillsListPageResult, ListBillsDeskPageParams };

export const billsRepository = {
  listBills,
  listBillsPage,
  getBillById,
  getBillDetailBundle,
  getBillDetailBundles,
  listBillItems,
  searchBillStock,
  upsertDraftBill,
  upsertKernelComposeDraft,
  updateKernelComposeDraft,
  issueKernelComposeBill,
  updateDraftBill,
  issueBill,
  issueApBillFromDesk,
  patchBillDates,
  voidBill,
  applySettlementToBill,
  listBillsForSource,
  listPaysForSource,
  listOpenOnProfile,
  deleteDraftBill,
  listBillBrands,
  createBillBrand,
  updateBillBrand,
  deleteBillBrand,
};

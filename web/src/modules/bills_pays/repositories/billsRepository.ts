import { supabase } from 'src/boot/supabase';
import {
  invoiceRepository,
  type BillDetailBundle,
  type CreateInvoiceBrandInput,
  type InvoiceBrand,
  type ListGlobalInvoicesParams,
  type PaginatedGlobalInvoices,
  type SalesInvoiceFromPayloadInput,
  type SalesInvoiceFromPayloadResult,
  type SalesInvoicePayloadItem,
  type SalesInvoiceStockItem,
  type SalesInvoiceUpdatePayloadInput,
} from 'src/modules/sales_invoice/repositories/invoiceRepository';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import type {
  BillListRow,
  BillsListPageCursor,
  BillsListPageResult,
  ListBillsDeskPageParams,
} from '../types/billList';

export type {
  BillDetailBundle,
  CreateInvoiceBrandInput,
  InvoiceBrand,
  ListGlobalInvoicesParams,
  PaginatedGlobalInvoices,
  SalesInvoiceFromPayloadInput,
  SalesInvoiceFromPayloadResult,
  SalesInvoicePayloadItem,
  SalesInvoiceStockItem,
  SalesInvoiceUpdatePayloadInput,
};

export type IssueBillOptions = {
  invoiceType: 'wholesale' | 'retail' | 'ap' | string;
  stockItems?: Array<{
    id?: number;
    global_stock_id: number;
    quantity: number;
    sell_price_amount?: number;
  }>;
};

const parsePayloadRpcResult = (data: unknown): SalesInvoiceFromPayloadResult => {
  const result = (data ?? {}) as SalesInvoiceFromPayloadResult;
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
}): SalesInvoiceFromPayloadResult => ({
  success: true,
  invoice_id: row.id,
  invoice_no: row.invoice_no,
  invoice_status: row.invoice_status,
  payment_status: row.payment_status,
  total_amount: row.total_amount,
  due_amount: row.due_amount,
  paid_amount: row.paid_amount,
});

const listBills = (params: ListGlobalInvoicesParams) =>
  invoiceRepository.listGlobalInvoices(params);

const listBillsPage = async (
  params: ListBillsDeskPageParams,
  cursor: BillsListPageCursor,
): Promise<BillsListPageResult> => {
  const parentTenantId = params.parentTenantId;
  if (!parentTenantId) {
    return { data: [], meta: { has_more: false, next_cursor: null } };
  }

  const toType =
    params.toProfileType && params.toProfileType !== 'all' ? params.toProfileType : undefined;

  const { data, error } = await supabase.rpc('list_bills_desk_page', {
    p_tenant_id: parentTenantId,
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

const getBillById = (billId: number) => invoiceRepository.getGlobalInvoiceById(billId);

const getBillDetailBundle = (params: { tenantId: number; billId: number }) =>
  invoiceRepository.getBillDetailBundle(params);

const listBillItems = (billId: number) => invoiceRepository.listGlobalInvoiceItems(billId);

const searchBillStock = (params: Parameters<typeof invoiceRepository.searchSalesInvoiceStock>[0]) =>
  invoiceRepository.searchSalesInvoiceStock(params);

const upsertDraftBill = async (
  tenantId: number,
  payload: SalesInvoiceFromPayloadInput,
): Promise<SalesInvoiceFromPayloadResult> => {
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
  payload: SalesInvoiceUpdatePayloadInput,
): Promise<SalesInvoiceFromPayloadResult> => {
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
  options?: { tenantId?: number; spine?: 'legacy' | 'kernel' },
): Promise<void> => {
  if (options?.spine === 'kernel' && options.tenantId) {
    const { error } = await supabase.rpc('rpc_issue_bill', {
      p_tenant_id: options.tenantId,
      p_bill_id: billId,
    });
    if (error) throw error;
    return;
  }
  const { error } = await supabase.rpc('issue_ap_bill_from_desk', { p_bill_id: billId });
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

  if (type === 'retail') {
    const { error } = await supabase.rpc('issue_retail_bill', { p_bill_id: billId });
    if (error) throw error;
    return;
  }

  if (type === 'wholesale' && hasStock) {
    const { error } = await supabase.rpc('issue_wholesale_bill', {
      p_bill_id: billId,
      p_items: (options.stockItems ?? null) as unknown as Record<string, unknown>,
    });
    if (error) throw error;
    return;
  }

  const { error } = await supabase.rpc('issue_bill', { p_bill_id: billId });
  if (error) throw error;
};

const voidBill = async (
  billId: number,
  options?: { tenantId?: number; spine?: 'legacy' | 'kernel' },
): Promise<void> => {
  if (options?.spine === 'kernel' && options.tenantId) {
    const { error } = await supabase.rpc('rpc_void_bill', {
      p_tenant_id: options.tenantId,
      p_bill_id: billId,
      p_reason: null,
      p_reverse_payments: true,
    });
    if (error) throw error;
    return;
  }
  const { error } = await supabase.rpc('void_bill', { p_bill_id: billId });
  if (error) throw error;
};

const applySettlementToBill = async (payload: {
  tenant_id: number;
  bill_id: number;
  allocator_kind: 'pay' | 'credit_note' | 'custody_entry';
  allocator_id?: number;
  books_amount: number;
}) => {
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

const deleteDraftBill = (billId: number) => invoiceRepository.deleteGlobalInvoice(billId);

const listBillBrands = invoiceRepository.listInvoiceBrands;
const createBillBrand = invoiceRepository.createInvoiceBrand;
const updateBillBrand = invoiceRepository.updateInvoiceBrand;
const deleteBillBrand = invoiceRepository.deleteInvoiceBrand;

const listBillsForSource = async (params: {
  parentTenantId: number;
  sourceType: string;
  sourceId: string;
  sourceKey?: string | null;
  includeVoided?: boolean;
  apShipmentBucketsOnly?: boolean;
}) => {
  const { data, error } = await supabase.rpc('list_bills_for_source', {
    p_tenant_id: params.parentTenantId,
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
  parentTenantId: number;
  sourceType: string;
  sourceId: string;
}) => {
  const { data, error } = await supabase.rpc('list_pays_for_source', {
    p_tenant_id: params.parentTenantId,
    p_source_type: params.sourceType,
    p_source_id: params.sourceId,
  });
  if (error) throw error;
  return (data ?? []) as unknown[];
};

const listOpenOnProfile = async (params: { parentTenantId: number; profileId: number }) => {
  const { data, error } = await supabase.rpc('list_open_on_profile', {
    p_tenant_id: params.parentTenantId,
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
  listBillItems,
  searchBillStock,
  upsertDraftBill,
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

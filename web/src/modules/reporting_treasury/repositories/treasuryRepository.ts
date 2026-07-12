import { supabase } from 'src/boot/supabase';

export interface InvoiceMarginReportQuery {
  tenantId: number;
  page?: number;
  pageSize?: number;
  startDate?: string;
  endDate?: string;
  search?: string;
  invoiceType?: string;
}

export interface InvoiceMarginReportMeta {
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface InvoiceMarginReportResponse {
  data: any[];
  meta: InvoiceMarginReportMeta;
}

export interface ShipmentPnLResponse {
  shipment: any;
  items: any[];
  totals: {
    landed_cost: number;
    sold_cost: number;
    revenue: number;
    gross_profit: number;
    sellable_on_hand_value: number;
    shrinkage_value: number;
    stolen_value: number;
    box_damage_value: number;
    expired_value: number;
    unsold_value: number;
    disposition_available: boolean;
    reconciliation_gap: number;
  };
}

export interface InvoiceMarginDetailResponse {
  invoice: any;
  lines: any[];
  returns: any[];
  gross_profit: number;
}

/**
 * Repository to retrieve read-side financial reporting and treasury analytics from operational tables.
 */
const listInvoiceMarginReport = async (
  query: InvoiceMarginReportQuery,
): Promise<InvoiceMarginReportResponse> => {
  const { data, error } = await supabase.rpc('list_invoice_margin_report', {
    p_tenant_id: query.tenantId,
    p_page: query.page ?? 1,
    p_page_size: query.pageSize ?? 20,
    p_start_date: query.startDate || null,
    p_end_date: query.endDate || null,
    p_search: query.search || null,
    p_invoice_type: query.invoiceType || null,
  });

  if (error) throw error;
  return data;
};

const getInvoiceMarginDetail = async (invoiceId: number): Promise<InvoiceMarginDetailResponse> => {
  const { data, error } = await supabase.rpc('get_invoice_margin_detail', {
    p_invoice_id: invoiceId,
  });

  if (error) throw error;
  return data;
};

const getShipmentPnL = async (
  tenantId: number,
  shipmentId: number,
): Promise<ShipmentPnLResponse> => {
  const { data, error } = await supabase.rpc('get_shipment_pnl', {
    p_tenant_id: tenantId,
    p_shipment_id: shipmentId,
  });

  if (error) throw error;
  return data;
};

export interface ShipmentItemInvoiceRow {
  shipment_item_id: number;
  shipment_item_name: string;
  product_code: string | null;
  barcode: string | null;
  ordered_quantity: number;
  invoice_id: number;
  invoice_no: string;
  invoice_date: string;
  invoice_type: string;
  invoice_status: string;
  buyer_name: string;
  qty_sold: number;
  return_qty: number;
  net_sold: number;
  unit_cost_price: number;
  sell_price_amount: number;
  line_discount_amount: number;
  line_total_amount: number;
}

const getShipmentItemInvoices = async (
  tenantId: number,
  shipmentId: number,
): Promise<ShipmentItemInvoiceRow[]> => {
  const { data, error } = await supabase.rpc('get_shipment_item_invoices', {
    p_tenant_id: tenantId,
    p_shipment_id: shipmentId,
  });

  if (error) throw error;
  return data ?? [];
};

const listBillingBalances = async (tenantId: number, search?: string): Promise<any[]> => {
  const { data, error } = await supabase.rpc('list_billing_balances', {
    p_tenant_id: tenantId,
    p_search: search || null,
  });

  if (error) throw error;
  return data;
};

const listInvoiceOutstanding = async (tenantId: number, search?: string): Promise<any[]> => {
  const { data, error } = await supabase.rpc('list_invoice_outstanding', {
    p_tenant_id: tenantId,
    p_search: search || null,
  });

  if (error) throw error;
  return data;
};

export interface ParentDashboardResponse {
  totals: {
    revenue: number;
    cash_collected: number;
    active_ar: number;
    unallocated_payments: number;
    middleman_total: number;
    middleman_liability: number;
  };
  type_distribution: Array<{ name: string; amount: number }>;
}

const getParentDashboard = async (parentTenantId: number): Promise<ParentDashboardResponse> => {
  const { data, error } = await supabase.rpc('get_parent_dashboard', {
    p_parent_tenant_id: parentTenantId,
  });

  if (error) throw error;
  return data;
};

export const treasuryRepository = {
  listInvoiceMarginReport,
  getInvoiceMarginDetail,
  getShipmentPnL,
  getShipmentItemInvoices,
  listBillingBalances,
  listInvoiceOutstanding,
  getParentDashboard,
};
export type TreasuryRepository = typeof treasuryRepository;

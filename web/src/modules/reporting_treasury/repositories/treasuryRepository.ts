import { supabase } from 'src/boot/supabase'

export interface InvoiceMarginReportQuery {
  tenantId: number
  page?: number
  pageSize?: number
  startDate?: string
  endDate?: string
  search?: string
  invoiceType?: string
}

export interface InvoiceMarginReportMeta {
  total: number
  page: number
  page_size: number
  total_pages: number
}

export interface InvoiceMarginReportResponse {
  data: any[]
  meta: InvoiceMarginReportMeta
}

export interface ShipmentPnLResponse {
  shipment: any
  items: any[]
  totals: {
    landed_cost: number
    sold_cost: number
    revenue: number
    gross_profit: number
    unsold_value: number
  }
}

export interface InvoiceMarginDetailResponse {
  invoice: any
  lines: any[]
  returns: any[]
  gross_profit: number
}

/**
 * Repository to retrieve read-side financial reporting and treasury analytics from operational tables.
 */
const listInvoiceMarginReport = async (
  query: InvoiceMarginReportQuery
): Promise<InvoiceMarginReportResponse> => {
  const { data, error } = await supabase.rpc('list_invoice_margin_report', {
    p_tenant_id: query.tenantId,
    p_page: query.page ?? 1,
    p_page_size: query.pageSize ?? 20,
    p_start_date: query.startDate || null,
    p_end_date: query.endDate || null,
    p_search: query.search || null,
    p_invoice_type: query.invoiceType || null,
  })

  if (error) throw error
  return data as unknown as InvoiceMarginReportResponse
}

const getInvoiceMarginDetail = async (
  invoiceId: number
): Promise<InvoiceMarginDetailResponse> => {
  const { data, error } = await supabase.rpc('get_invoice_margin_detail', {
    p_invoice_id: invoiceId,
  })

  if (error) throw error
  return data as unknown as InvoiceMarginDetailResponse
}

const getShipmentPnL = async (
  tenantId: number,
  shipmentId: number
): Promise<ShipmentPnLResponse> => {
  const { data, error } = await supabase.rpc('get_shipment_pnl', {
    p_tenant_id: tenantId,
    p_shipment_id: shipmentId,
  })

  if (error) throw error
  return data as unknown as ShipmentPnLResponse
}

const listBillingBalances = async (
  tenantId: number,
  search?: string
): Promise<any[]> => {
  const { data, error } = await supabase.rpc('list_billing_balances', {
    p_tenant_id: tenantId,
    p_search: search || null,
  })

  if (error) throw error
  return data as unknown as any[]
}

const listInvoiceOutstanding = async (
  tenantId: number,
  search?: string
): Promise<any[]> => {
  const { data, error } = await supabase.rpc('list_invoice_outstanding', {
    p_tenant_id: tenantId,
    p_search: search || null,
  })

  if (error) throw error
  return data as unknown as any[]
}

export const treasuryRepository = {
  listInvoiceMarginReport,
  getInvoiceMarginDetail,
  getShipmentPnL,
  listBillingBalances,
  listInvoiceOutstanding,
}
export type TreasuryRepository = typeof treasuryRepository

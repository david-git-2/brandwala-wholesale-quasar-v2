export interface ShipmentProfitReportItem {
  item_id: number;
  product_name: string;
  barcode: string | null;
  inbound_qty: number;
  unit_cost_bdt: number | null;
  total_cost_bdt: number;
  sold_qty: number;
  sold_revenue: number;
  cogs: number;
  gross_profit: number;
  sellable_qty: number;
  unsold_stock_value: number;
  damaged_qty: number;
  damage_loss_value: number;
}

export interface ShipmentProfitReportRow {
  shipment_id: number;
  shipment_name: string;
  shipment_code: string | null;
  shipment_status: string;
  created_at: string;
  currency_id: number | null;
  inbound_quantity: number;
  total_landed_cost: number;
  sold_quantity: number;
  returned_quantity: number;
  net_sold_quantity: number;
  gross_sold_revenue: number;
  cogs_amount: number;
  realized_gross_profit: number;
  realized_gp_margin_pct: number;
  batch_sold_pct: number;
  sellable_stock_qty: number;
  held_stock_qty: number;
  damaged_stock_qty: number;
  unsold_stock_value: number;
  damage_loss_value: number;
  items?: ShipmentProfitReportItem[] | null;
}

export interface ShipmentProfitReportSummary {
  total_inbound_units: number;
  total_landed_cost: number;
  total_net_sold_units: number;
  total_gross_sold_revenue: number;
  total_cogs: number;
  total_realized_gross_profit: number;
  overall_realized_gp_margin_pct: number;
  total_unsold_stock_value: number;
  total_damage_loss_value: number;
  total_shipments_count: number;
}

export interface ShipmentProfitReportPagination {
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface ShipmentProfitReportPayload {
  summary: ShipmentProfitReportSummary;
  shipments: ShipmentProfitReportRow[];
  meta: ShipmentProfitReportPagination;
}

export interface ShipmentProfitReportQueryParams {
  tenantId: number;
  shipmentId?: number | null;
  search?: string | null;
  startDate?: string | null;
  endDate?: string | null;
  page?: number;
  pageSize?: number;
}

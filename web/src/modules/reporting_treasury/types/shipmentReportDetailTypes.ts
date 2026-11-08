import type { ShipmentProfitReportRow } from './shipmentProfitTypes';

export interface ShipmentReportDetailHeader {
  shipment_id: number;
  shipment_name: string;
  shipment_no: string | null;
  tenant_shipment_id: number | null;
  shipment_status: string;
  shipment_type: string;
  vendor_id: number | null;
  vendor_name: string | null;
  created_at: string;
  received_date: string | null;
}

export interface ShipmentReportQtySummary {
  should_arrive: number;
  arrived: number;
  loss_at_shipment: number;
  warehouse_stalled: number;
  warehouse_remaining: number;
  sold: number;
  warehouse_value_bdt: number;
}

export interface ShipmentReportForeignLeg {
  currency_code: string;
  amount: number;
}

export interface ShipmentReportCostBucket {
  ap_kind: string;
  label: string;
  foreign_amount: number | null;
  foreign_currency: string | null;
  foreign_legs: ShipmentReportForeignLeg[];
  bdt_amount: number;
}

export interface ShipmentReportSellLine {
  bill_id: number;
  invoice_no: string;
  invoice_item_id: number;
  product_name: string;
  qty: number;
  amount_bdt: number;
}

export interface ShipmentReportCostByCurrency {
  currency_code: string;
  amount: number;
}

export interface ShipmentReportProfitMatrix {
  total_cost_bdt: number;
  total_cost_by_currency: ShipmentReportCostByCurrency[];
  total_sell_bdt: number;
  receive_loss_bdt: number;
  unpaid_total_bdt: number;
  profit_loss_bdt: number;
  profit_loss_pct: number;
}

export interface ShipmentReportUnpaidCustomer {
  bill_id: number;
  invoice_no: string;
  customer_name: string;
  payment_status: string | null;
  open_bdt: number;
}

export interface ShipmentReportApBillRow {
  id: number;
  invoice_no: string;
  ap_kind: string | null;
  invoice_status: string;
  payment_status: string | null;
  currency_code: string | null;
  txn_currency_code: string | null;
  txn_total_amount: number | null;
  books_exchange_rate: number | null;
  total_amount: number;
  due_amount: number | null;
  open_books: number | null;
}

export interface ShipmentReportApCurrencyTotal {
  currency_code: string;
  bill_count: number;
  txn_total_amount: number;
  books_total_amount: number;
}

export interface ShipmentReportCustomerBillRow {
  id: number;
  invoice_no: string;
  invoice_date: string | null;
  invoice_type: string | null;
  currency_code: string | null;
  profile_id: number | null;
  customer_name: string;
  attributed_revenue_bdt: number;
  attributed_qty: number;
}

export interface ShipmentReportExchangeRates {
  product_rate: number;
  freight_rate: number;
  blended_rate: number;
  cargo_foreign_per_kg: number | null;
  material_payment_count: number;
  freight_payment_count: number;
}

export interface ShipmentReportDetailPayload {
  header: ShipmentReportDetailHeader;
  pnl: ShipmentProfitReportRow | null;
  qty_summary: ShipmentReportQtySummary | null;
  cost_buckets: ShipmentReportCostBucket[];
  sell_lines: ShipmentReportSellLine[];
  profit_matrix: ShipmentReportProfitMatrix | null;
  unpaid_customers: ShipmentReportUnpaidCustomer[];
  ap_bills: ShipmentReportApBillRow[];
  ap_totals_by_currency: ShipmentReportApCurrencyTotal[];
  customer_bills: ShipmentReportCustomerBillRow[];
  customer_attributed_revenue_bdt: number;
  exchange_rates: ShipmentReportExchangeRates | null;
}

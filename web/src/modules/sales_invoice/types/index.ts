import type { GlobalStockCostingInput } from 'src/modules/global/types';

export type InvoicePaymentHistoryInstrument = {
  id: number;
  payment_method_code: string;
  amount: number;
  reference: string | null;
  bd_bank_id: number | null;
  bank_name: string | null;
  cheque_number: string | null;
  cheque_date: string | null;
  sort_order: number;
};

export type InvoicePaymentHistoryEntry = {
  entry_type: 'allocation' | 'write_off';
  entry_id: number;
  payment_id: number | null;
  payment_date: string;
  /** BDT applied to this bill (allocation or write-off). */
  amount: number;
  /** Full payment receipt in BDT. */
  receipt_amount: number;
  voided_at: string | null;
  method: string | null;
  note: string | null;
  write_off_reason: string | null;
  settlement_currency_code?: string | null;
  foreign_amount?: number | null;
  exchange_rate?: number | null;
  instruments: InvoicePaymentHistoryInstrument[];
  /** pays.source — e.g. ap_payout, customer_cash */
  payment_source?: string | null;
  payment_reference?: string | null;
  cashbook_point_pot_id?: number | null;
  transaction_rate?: number | null;
  source_currency_code?: string | null;
  /** Child note when this row is rolled up onto the parent bill. */
  related_invoice_no?: string | null;
  related_document_kind?: string | null;
};

export type GlobalInvoiceRow = {
  id: number;
  tenant_id?: number;
  parent_tenant_id: number;
  issued_by_tenant_id: number;
  issued_by_tenant_name?: string | null;
  invoice_no: string;
  invoice_type: string;
  invoice_status: string;
  payment_status: string;
  invoice_date: string;
  due_date?: string | null;
  total_amount: number;
  due_amount: number;
  paid_amount: number;
  profile_id?: number | null;
  profile_name?: string | null;
  profile_email?: string | null;
  profile_accent_color?: string | null;
  profile_customer_group_id?: number | null;
  retail_billing_mode?: 'account' | 'direct' | null;
  recipient_name?: string | null;
  created_by?: string | null;
  created_at?: string;
  settlement_discount_amount?: number;
  channel_meta?: Record<string, unknown> | null;
  ap_kind?: string | null;
  ap_shipment_id?: number | null;
  shop_order_id?: number | null;
  source_type?: string | null;
  source_id?: string | null;
  source_key?: string | null;
  from_profile_id?: number | null;
  to_profile_id?: number | null;
  currency_code?: string | null;
  source_context_label?: string | null;
};

export type GlobalInvoiceType = 'retail' | 'wholesale' | 'dropship' | 'ap';
export type InvoiceCollectionSource = 'billing_profile' | 'profile' | 'recipient';

export type CreateGlobalInvoiceInput = {
  tenant_id: number;
  invoice_no: string;
  profile_id?: number | null;
  invoice_type?: GlobalInvoiceType;
  recipient_profile_id?: number | null;
  recipient_name?: string | null;
  recipient_phone?: string | null;
  recipient_address?: string | null;
  recipient_party_id?: number | null;
  retail_billing_mode?: 'account' | 'direct' | null;
  due_date?: string | null;
  invoice_date?: string | null;
  note?: string | null;
};

export type GlobalInvoiceCreated = GlobalInvoiceRow & {
  note: string | null;
  customer_group_id: number | null;
  profile_id: number | null;
  recipient_party_id: number | null;
  recipient_name: string | null;
  recipient_phone: string | null;
  recipient_address: string | null;
  source_module: string;
  sold_in_tenant_id: number | null;
  subtotal_amount: number;
  discount_amount: number;
};

export type GlobalInvoiceDetail = GlobalInvoiceCreated & {
  document_kind?: string | null;
  ordered_by_party_id: number | null;
  collection_source?: InvoiceCollectionSource | null;
  shipping_charge: number;
  cod_charge_amount?: number;
  wrapping_charge: number;
  print_charge: number;
  recipient_phone: string | null;
  recipient_address: string | null;
  profiles?: {
    id: number;
    name: string;
    email: string | null;
    phone: string | null;
    address: string | null;
    color: string | null;
  } | null;
  from_profile?: {
    id: number;
    name: string;
    email: string | null;
    phone: string | null;
    address: string | null;
  } | null;
  to_profile?: {
    id: number;
    name: string;
    email: string | null;
    phone: string | null;
    address: string | null;
  } | null;
};

export type GlobalInvoiceItemRow = {
  id: number;
  invoice_id: number;
  global_stock_id: number;
  name_snapshot: string;
  barcode_snapshot?: string | null;
  product_code_snapshot?: string | null;
  quantity: number;
  sell_price_amount: number;
  line_discount_amount: number;
  line_total_amount: number;
  unit_cost_price?: number | null;
  costing?: GlobalStockCostingInput | null;
  return_quantity: number;
  available_atp?: number | null;
  image_url?: string | null | undefined;
};


export type InvoiceChargeLineRow = {
  id: number;
  invoice_id: number;
  charge_type: string;
  amount: number;
  note: string | null;
};

export type BusinessPartyRow = {
  id: number;
  tenant_id: number;
  parent_tenant_id: number;
  name: string;
  party_type: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  is_active: boolean;
};

export interface WholesaleReturnItemInput {
  invoice_item_id: number;
  quantity: number;
  to_availability: 'held' | 'sellable' | 'unsellable';
  to_grade_tag_id: number | null;
  note?: string | null;
}

export interface WholesaleReturnPreviewSummary {
  originalSubtotal: number;
  originalTotal: number;
  originalPaid: number;
  originalDue: number;

  totalReturnValue: number;
  returnCharge: number;
  netReturnCredit: number;

  newSubtotal: number;
  newTotal: number;
  newDue: number;
  excessPaidRefund: number;

  settlementType: 'no_money_exchanged' | 'reduce_due_only' | 'refund_required';
  lineSummaries: Array<{
    invoice_item_id: number;
    invoiced_qty: number;
    return_qty: number;
    retained_qty: number;
    unit_price: number;
    line_return_value: number;
    new_line_total: number;
  }>;
}

export type WholesalePaymentInstrumentInput = {
  payment_method_code: string;
  amount: number;
  reference?: string | null;
  bd_bank_id?: number | null;
  cheque_number?: string | null;
  cheque_date?: string | null;
  cashbook_point_id?: number | null;
};

export type WholesaleCollectPaymentPayload = {
  instruments: WholesalePaymentInstrumentInput[];
  walletAmount: number;
  settlementAmount: number;
  note?: string | null;
  receivedOn?: string | null;
};


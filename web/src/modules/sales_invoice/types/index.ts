import type { GlobalStockCostingInput } from 'src/modules/global/types';

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
  billing_profile_id?: number | null;
  billing_profile_name?: string | null;
  billing_profile_email?: string | null;
  billing_profile_color?: string | null;
  billing_profile_customer_group_id?: number | null;
  recipient_name?: string | null;
  created_by?: string | null;
  created_at?: string;
  settlement_discount_amount?: number;
};

export type GlobalInvoiceType = 'retail' | 'wholesale' | 'dropship';
export type InvoiceCollectionSource = 'billing_profile' | 'recipient';

export type CreateGlobalInvoiceInput = {
  tenant_id: number;
  invoice_no: string;
  billing_profile_id?: number | null;
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
  billing_profile_id: number | null;
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
  ordered_by_party_id: number | null;
  collection_source?: InvoiceCollectionSource | null;
  shipping_charge: number;
  cod_charge?: number;
  wrapping_charge: number;
  print_charge: number;
  recipient_phone: string | null;
  recipient_address: string | null;
  billing_profiles?: {
    id: number;
    name: string;
    email: string | null;
    phone: string | null;
    address: string | null;
    color: string | null;
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


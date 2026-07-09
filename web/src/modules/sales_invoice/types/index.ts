import type { GlobalStockCostingInput } from 'src/modules/global/types';

export type GlobalInvoiceRow = {
  id: number;
  tenant_id: number;
  parent_tenant_id: number;
  invoice_no: string;
  invoice_type: string;
  invoice_status: string;
  payment_status: string;
  invoice_date: string;
  total_amount: number;
  due_amount: number;
  paid_amount: number;
  billing_profile_id?: number | null;
  billing_profile_name?: string | null;
  recipient_name?: string | null;
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
  middle_man_payout_amount?: number | null;
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
  face_subtotal_amount?: number;
  accounting_subtotal_amount?: number;
  collection_source?: InvoiceCollectionSource | null;
  middle_man_payout_amount?: number;
  middle_man_payout_status?: string | null;
  shipping_charge: number;
  cod_charge: number;
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
  quantity: number;
  sell_price_amount: number;
  recipient_price_amount?: number | null;
  line_face_total_amount?: number | null;
  line_discount_amount: number;
  line_total_amount: number;
  unit_cost_price?: number | null;
  costing?: GlobalStockCostingInput | null;
  return_quantity: number;
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

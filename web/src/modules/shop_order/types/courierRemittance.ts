export type CourierRemittanceBatchStatus = 'draft' | 'posted' | 'voided';
export type CourierRemittanceItemStatus = 'matched' | 'unmatched' | 'processed' | 'error';

export interface CourierRemittanceBatch {
  id: number;
  tenant_id: number;
  courier_service_id: string;
  batch_no: string;
  bank_trx_id: string | null;
  payment_date: string;
  gross_cod_amount: number;
  courier_charges_amount: number;
  net_deposited_amount: number;
  allocated_amount: number;
  variance_amount: number;
  status: CourierRemittanceBatchStatus;
  note: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  posted_at: string | null;
  posted_by: string | null;
  courier_service?: {
    id: string;
    name: string;
    code: string;
  } | null;
}

export interface CourierRemittanceItem {
  id: number;
  tenant_id: number;
  batch_id: number;
  shop_order_id: number | null;
  global_invoice_id: number | null;
  tracking_number: string | null;
  awb_number: string | null;
  cod_collected_amount: number;
  courier_charge_amount: number;
  net_remitted_amount: number;
  status: CourierRemittanceItemStatus;
  error_message: string | null;
  created_at: string;
  shop_order?: {
    id: number;
    order_no: string;
    recipient_name: string | null;
    status: string;
    courier_name: string | null;
    courier_awb_number: string | null;
    tracking_url: string | null;
  } | null;
}

export interface RemittanceItemInput {
  shop_order_id: number | null;
  global_invoice_id?: number | null;
  tracking_number?: string | null;
  awb_number?: string | null;
  cod_collected_amount: number;
  courier_charge_amount: number;
  net_remitted_amount: number;
}

export interface SaveCourierRemittanceBatchPayload {
  batch_id?: number | null;
  tenant_id: number;
  courier_service_id: string;
  batch_no: string;
  bank_trx_id?: string | null;
  payment_date?: string | null;
  gross_cod_amount?: number;
  courier_charges_amount?: number;
  net_deposited_amount?: number;
  note?: string | null;
  items: RemittanceItemInput[];
}

export interface SaveCourierRemittanceBatchResult {
  success: boolean;
  batch_id: number;
  allocated_amount: number;
  variance_amount: number;
}

export interface PostCourierRemittanceBatchResult {
  success: boolean;
  batch_id: number;
  processed_count: number;
  error_count: number;
  allocated_amount: number;
  status: 'posted';
}

export interface CourierUnremittedFinancialSummary {
  courier_service_id: string | null;
  courier_name: string;
  gross_cod_total: number;
  company_wholesale_total: number;
  middleman_margin_total: number;
  unremitted_order_count: number;
}

export interface ReconcileSingleOrderPayload {
  orderId: number;
  courierCharge?: number;
}

export interface ReconcileSingleOrderResult {
  success: boolean;
  order_id: number;
  new_status: string;
  net_remitted: number;
}

export interface DispensePayoutPayload {
  billingProfileId: number;
  amount: number;
  method?: string;
  trxId?: string;
}

export interface DispensePayoutResult {
  success: boolean;
  billing_profile_id: number;
  amount: number;
  new_balance: number;
}

export interface MerchantPayoutSummary {
  billing_profile_id: number;
  name: string;
  email: string | null;
  phone: string | null;
  customer_group_id: number | null;
  locked_margin: number;
  available_balance: number;
}



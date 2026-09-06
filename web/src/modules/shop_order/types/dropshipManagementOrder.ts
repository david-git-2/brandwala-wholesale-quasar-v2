import type { StockAvailability } from 'src/modules/procurement_stock/constants/stockAvailability';
import type { ShopOrderStatus } from './index';

export type DropshipSettlementChargeType = 'delivery' | 'print' | 'packing' | 'return' | 'cod';
export type DropshipSettlementChargePayer = 'recipient' | 'merchant' | 'company';
export type DropshipSettlementStatus = 'draft' | 'confirmed';

export interface DropshipSettlementChargeLine {
  charge_type: DropshipSettlementChargeType;
  amount: number;
  payer: DropshipSettlementChargePayer;
}

export interface DropshipManagementSettlementState {
  id: number | null;
  status: DropshipSettlementStatus;
  calculated_cod_amount: number;
  collected_cod_amount: number;
  reseller_unit_purchase_cost: number;
  reseller_purchase_cost: number;
  company_procurement_cost: number;
  discount_company_pay: number;
  return_reason_note: string;
  charge_lines: DropshipSettlementChargeLine[];
  total_cost: number | null;
  reseller_profit: number | null;
  company_profit: number | null;
  courier_cod_booked_at: string | null;
  remittance_at: string | null;
  merchant_payout_at: string | null;
}

export interface DropshipManagementInvoiceState {
  id: number;
  invoice_no: string;
  invoice_status: string;
  payment_status: string;
  total_amount: number;
  due_amount: number;
}

export interface DropshipManagementStepState {
  can_mark_returned: boolean;
  can_mark_delivered: boolean;
  can_issue_invoice: boolean;
  can_record_bank_transfer: boolean;
  can_transfer_to_reseller: boolean;
}

export interface DropshipManagementReturnLine {
  id: number;
  name: string;
  quantity: number;
  confirmed_quantity: number | null;
  returned_quantity: number;
  grade_tag_id: number | null;
  product_code?: string | null;
  image_url?: string | null;
  stock_picks?: Array<{ id: number; shipment_name?: string | null; quantity: number }>;
}

export interface DropshipReturnItemPayload {
  order_item_id: number;
  returned_qty: number;
  grade_tag_id: number;
  to_availability: StockAvailability;
}

export interface DropshipReturnFinalizePayload extends DropshipSettlementDraftPayload {
  return_items: DropshipReturnItemPayload[];
  deduct_from_middle_man: boolean;
  return_ref?: string;
}

export interface DropshipManagementCourierInfo {
  courier_name: string | null;
  courier_service_id: string | null;
  courier_awb_number: string | null;
  courier_tracking_number: string | null;
  courier_consignment_id: string | null;
  courier_order_ref: string | null;
  tracking_url: string | null;
  allow_open_box: boolean;
  delivery_zone_label: string | null;
  cod_collect_amount: number;
  courier_cod_booked_at: string | null;
  remittance_at: string | null;
}

export interface DropshipManagementOrderView {
  order: {
    id: number;
    order_no: string;
    status: ShopOrderStatus;
    customer_group_name: string | null;
    recipient_name: string | null;
    recipient_phone: string | null;
    courier_name: string | null;
    courier_awb_number: string | null;
    created_at: string;
    payout_settlement_status: string | null;
    cod_charge_amount: number;
    deduct_cod_from_margin: boolean;
    discount_amount: number;
    returned_at: string | null;
    return_charge_amount: number;
    deduct_return_charge_from_middle_man: boolean;
    return_override_reason: string | null;
  };
  items: DropshipManagementReturnLine[];
  computed: {
    items_resell_total: number;
    recipient_grand_total: number;
    order_item_quantity: number;
  };
  settlement: DropshipManagementSettlementState;
  courier: DropshipManagementCourierInfo;
  invoice: DropshipManagementInvoiceState | null;
  step_state: DropshipManagementStepState;
}

export interface DropshipSettlementDraftPayload {
  collected_cod_amount: number;
  discount_company_pay: number;
  return_reason_note: string;
  charge_lines: DropshipSettlementChargeLine[];
}

export interface DropshipCourierBankTransferPayload {
  net_amount: number;
  remittance_ref: string;
  bank_trx_id?: string | null;
}

export interface DropshipManagementOrderResponse {
  success: boolean;
  order: DropshipManagementOrderView['order'] & Record<string, unknown>;
  computed: DropshipManagementOrderView['computed'] & Record<string, unknown>;
  settlement: DropshipManagementSettlementState;
  invoice: DropshipManagementInvoiceState | null;
  step_state: DropshipManagementStepState;
  items?: DropshipManagementReturnLine[];
  fulfillment?: {
    courier?: Record<string, unknown>;
  };
}

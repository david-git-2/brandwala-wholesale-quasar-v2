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
  reseller_purchase_cost: number;
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

export interface DropshipManagementStepState {
  can_mark_delivered: boolean;
  can_record_bank_transfer: boolean;
  can_transfer_to_reseller: boolean;
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
  };
  computed: {
    items_resell_total: number;
    recipient_grand_total: number;
  };
  settlement: DropshipManagementSettlementState;
  step_state: DropshipManagementStepState;
}

export interface DropshipSettlementDraftPayload {
  collected_cod_amount: number;
  reseller_purchase_cost: number;
  discount_company_pay: number;
  return_reason_note: string;
  charge_lines: DropshipSettlementChargeLine[];
}

export interface DropshipCourierBankTransferPayload extends DropshipSettlementDraftPayload {
  net_amount: number;
  courier_charge: number;
  remittance_ref: string;
  bank_trx_id?: string | null;
}

export interface DropshipManagementOrderResponse {
  success: boolean;
  order: DropshipManagementOrderView['order'];
  computed: DropshipManagementOrderView['computed'];
  settlement: DropshipManagementSettlementState;
  step_state: DropshipManagementStepState;
}

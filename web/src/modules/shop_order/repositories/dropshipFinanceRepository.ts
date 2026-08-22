import { supabase } from 'src/boot/supabase';

export interface FinanceHubKpiSummary {
  courierOwedTotal: number;
  tenantCashTotal: number;
  middlemanPayableTotal: number;
}

export interface FinanceHubOrderQueueItem {
  id: number;
  orderNo: string;
  customerName: string | null;
  shopName: string | null;
  courierName: string | null;
  status: string;
  totalAmount: number;
  codCollectAmount: number;
  deliveryChargeAmount: number;
  codChargeAmount: number;
  courierNotes: string | null;
  courierRemittanceRef: string | null;
  courierBankTrxId: string | null;
  billingProfileId: number | null;
  billingProfileName: string | null;
  createdAt: string;
  nextStep: 'delivered_costing' | 'courier_remittance' | 'middleman_payout' | 'completed';
  collectionSource?: string | null;
  payoutSettlementStatus?: string | null;
  /** B2B invoice outstanding (total - paid); used for remittance allocation preview */
  invoiceOutstanding?: number | null;
}

export interface FinanceHubMerchantItem {
  id: number;
  name: string;
  payableBalance: number;
}

export interface FinanceHubData {
  kpis: FinanceHubKpiSummary;
  orders: FinanceHubOrderQueueItem[];
  merchants: FinanceHubMerchantItem[];
}

export const dropshipFinanceRepository = {
  async getHubData(tenantId: number): Promise<FinanceHubData> {
    const { data, error } = await supabase.rpc('get_dropship_finance_hub_data', {
      p_tenant_id: tenantId,
    });

    if (error) throw error;
    return data as FinanceHubData;
  },

  async confirmDeliveredCosting(params: {
    orderId: number;
    codAmount?: number;
    deliveryCharge?: number;
    courierNotes?: string;
  }) {
    const { data, error } = await supabase.rpc('confirm_dropship_delivered_costing', {
      p_order_id: params.orderId,
      p_cod_amount: params.codAmount ?? null,
      p_delivery_charge: params.deliveryCharge ?? null,
      p_courier_notes: params.courierNotes ?? null,
    });

    if (error) throw error;
    if (data && data.success === false) {
      throw new Error(data.error || 'Failed to confirm delivered costing');
    }
    return data;
  },

  async confirmCourierRemittance(params: {
    orderId: number;
    netAmount: number;
    courierCharge?: number;
    remittanceRef?: string;
    bankTrxId?: string;
  }) {
    if (!(params.netAmount > 0)) {
      throw new Error('Net remittance amount must be positive');
    }
    const { data, error } = await supabase.rpc('record_dropship_courier_remittance', {
      p_order_id: params.orderId,
      p_net_amount: params.netAmount,
      p_remittance_ref: params.remittanceRef ?? `REMIT-${params.orderId}`,
      p_bank_trx_id: params.bankTrxId ?? null,
      p_courier_charge: params.courierCharge ?? 0,
    });

    if (error) throw error;
    if (data && data.success === false) {
      throw new Error(data.error || 'Failed to confirm courier remittance');
    }
    return data;
  },

  async dispenseMiddlemanPayout(params: {
    tenantId: number;
    billingProfileId: number;
    amount: number;
    payoutMethod?: string;
    referenceNotes?: string;
  }) {
    const { data, error } = await supabase.rpc('dispense_middleman_payout_from_tenant', {
      p_tenant_id: params.tenantId,
      p_billing_profile_id: params.billingProfileId,
      p_amount: params.amount,
      p_payout_method: params.payoutMethod ?? 'bank_transfer',
      p_reference_notes: params.referenceNotes ?? null,
    });

    if (error) throw error;
    if (data && data.success === false) {
      throw new Error(data.error || 'Failed to dispense middleman payout');
    }
    return data;
  },
};

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
  courierNotes: string | null;
  courierRemittanceRef: string | null;
  courierBankTrxId: string | null;
  billingProfileId: number | null;
  billingProfileName: string | null;
  createdAt: string;
  nextStep: 'delivered_costing' | 'courier_remittance' | 'middleman_payout' | 'completed';
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
    // 1. Calculate Courier Owed (courier wallet credit total - debit total)
    const { data: ledgerRows, error: ledgerError } = await supabase
      .from('universal_wallet_ledger')
      .select('entity_type, type, amount')
      .eq('tenant_id', tenantId);

    if (ledgerError) throw ledgerError;

    let courierOwedTotal = 0;
    let tenantCashTotal = 0;
    let middlemanPayableTotal = 0;

    (ledgerRows || []).forEach((row) => {
      const amt = Number(row.amount || 0);
      if (row.entity_type === 'courier') {
        courierOwedTotal += row.type === 'credit' ? amt : -amt;
      } else if (row.entity_type === 'tenant') {
        tenantCashTotal += row.type === 'credit' ? amt : -amt;
      } else if (row.entity_type === 'middleman') {
        middlemanPayableTotal += row.type === 'credit' ? amt : -amt;
      }
    });

    // 2. Query dropship orders needing finance actions
    const { data: ordersData, error: ordersError } = await supabase
      .from('shop_orders')
      .select(`
        id,
        order_no,
        customer_name,
        shop_name,
        status,
        total_amount,
        cod_collect_amount,
        delivery_charge_amount,
        courier_notes,
        courier_remittance_ref,
        courier_bank_trx_id,
        billing_profile_id,
        created_at,
        courier_service_id,
        billing_profiles (
          id,
          name
        )
      `)
      .eq('tenant_id', tenantId)
      .eq('shop_type_snapshot', 'dropship')
      .in('status', ['delivered', 'payment_received'])
      .order('created_at', { ascending: false });

    if (ordersError) throw ordersError;

    // Check idempotency for delivered costing and remittance to calculate nextStep correctly
    const { data: hubLedgers, error: hubLedgersErr } = await supabase
      .from('universal_wallet_ledger')
      .select('source_id, metadata')
      .eq('tenant_id', tenantId)
      .eq('source_type', 'shop_order');

    if (hubLedgersErr) throw hubLedgersErr;

    const deliveredCostingOrderIds = new Set<string>();
    const remittedOrderIds = new Set<string>();

    (hubLedgers || []).forEach((l) => {
      const purpose = (l.metadata as Record<string, unknown> | null)?.purpose;
      if (purpose === 'delivered_costing' && l.source_id) {
        deliveredCostingOrderIds.add(l.source_id);
      } else if (purpose === 'courier_remittance' && l.source_id) {
        remittedOrderIds.add(l.source_id);
      }
    });

    const orders: FinanceHubOrderQueueItem[] = (ordersData || []).map((o: any) => {
      const orderIdStr = String(o.id);
      const hasDeliveredCosting = deliveredCostingOrderIds.has(orderIdStr);
      const hasRemitted = remittedOrderIds.has(orderIdStr) || o.status === 'payment_received';

      let nextStep: FinanceHubOrderQueueItem['nextStep'] = 'delivered_costing';
      if (!hasDeliveredCosting && o.status === 'delivered') {
        nextStep = 'delivered_costing';
      } else if (o.status === 'delivered' || !hasRemitted) {
        nextStep = 'courier_remittance';
      } else {
        nextStep = 'completed';
      }

      return {
        id: o.id,
        orderNo: o.order_no,
        customerName: o.customer_name,
        shopName: o.shop_name,
        courierName: null,
        status: o.status,
        totalAmount: Number(o.total_amount || 0),
        codCollectAmount: Number(o.cod_collect_amount || 0),
        deliveryChargeAmount: Number(o.delivery_charge_amount || 0),
        courierNotes: o.courier_notes,
        courierRemittanceRef: o.courier_remittance_ref,
        courierBankTrxId: o.courier_bank_trx_id,
        billingProfileId: o.billing_profile_id,
        billingProfileName: o.billing_profiles?.name ?? null,
        createdAt: o.created_at,
        nextStep,
      };
    });

    // 3. Fetch merchants (billing profiles) with payable balances
    const { data: profilesData, error: profilesError } = await supabase
      .from('billing_profiles')
      .select('id, name')
      .eq('tenant_id', tenantId);

    if (profilesError) throw profilesError;

    // Calculate per-merchant middleman balance
    const merchantBalanceMap = new Map<number, number>();
    (ledgerRows || []).forEach((r: any) => {
      if (r.entity_type === 'middleman') {
        // entity_id maps to billing_profile_id
        const entityId = Number(r.entity_id || 0);
        const current = merchantBalanceMap.get(entityId) || 0;
        merchantBalanceMap.set(entityId, current + (r.type === 'credit' ? Number(r.amount) : -Number(r.amount)));
      }
    });

    const merchants: FinanceHubMerchantItem[] = (profilesData || []).map((p: any) => ({
      id: p.id,
      name: p.name,
      payableBalance: merchantBalanceMap.get(p.id) || 0,
    }));

    return {
      kpis: {
        courierOwedTotal,
        tenantCashTotal,
        middlemanPayableTotal,
      },
      orders,
      merchants,
    };
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
    courierCharge?: number;
    remittanceRef?: string;
    bankTrxId?: string;
  }) {
    const { data, error } = await supabase.rpc('confirm_courier_remittance_to_tenant', {
      p_order_id: params.orderId,
      p_courier_charge: params.courierCharge ?? 0,
      p_remittance_ref: params.remittanceRef ?? null,
      p_bank_trx_id: params.bankTrxId ?? null,
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

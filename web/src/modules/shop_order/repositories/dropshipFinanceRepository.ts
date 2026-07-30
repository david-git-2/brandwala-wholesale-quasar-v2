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
    // 1. Calculate Courier Owed (courier wallet credit total - debit total)
    const { data: ledgerRows, error: ledgerError } = await supabase
      .from('universal_wallet_ledger')
      .select('entity_type, entity_id, type, amount, metadata')
      .eq('tenant_id', tenantId);

    if (ledgerError) throw ledgerError;

    let courierOwedTotal = 0;
    let tenantCashTotal = 0;
    let middlemanPayableTotal = 0;

    (ledgerRows || []).forEach((row) => {
      const amt = Number(row.amount || 0);
      const meta = (row.metadata || {}) as Record<string, any>;
      const section = typeof meta.section === 'string' ? meta.section : '';
      if (row.entity_type === 'courier') {
        courierOwedTotal += row.type === 'credit' ? amt : -amt;
      } else if (row.entity_type === 'tenant') {
        tenantCashTotal += row.type === 'credit' ? amt : -amt;
      } else if (
        (row.entity_type === 'middleman' || row.entity_type === 'customer')
        && section === 'payout_earned'
      ) {
        middlemanPayableTotal += row.type === 'credit' ? amt : -amt;
      }
    });

    // 2. Query dropship orders needing finance actions
    const { data: ordersData, error: ordersError } = await supabase
      .from('shop_orders')
      .select(`
        id,
        order_no,
        recipient_name,
        status,
        cod_collect_amount,
        delivery_charge_amount,
        cod_charge_amount,
        driver_notes,
        courier_name,
        courier_remittance_ref,
        courier_bank_trx_id,
        billing_profile_id,
        created_at,
        courier_service_id,
        global_invoice_id,
        is_prepaid_snapshot,
        collection_source,
        payout_settlement_status,
        billing_profiles (
          id,
          name
        ),
        shops (
          id,
          name
        ),
        global_invoices!shop_orders_global_invoice_id_fkey (
          collection_source,
          total_amount,
          paid_amount
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

      const inv = o.global_invoices;
      const invTotal = Number(inv?.total_amount ?? 0);
      const invPaid = Number(inv?.paid_amount ?? 0);
      const invoiceOutstanding = inv
        ? Math.max(invTotal - invPaid, 0)
        : null;
      const codCollect = Number(o.cod_collect_amount || 0);

      return {
        id: o.id,
        orderNo: o.order_no,
        customerName: o.recipient_name,
        shopName: o.shops?.name ?? null,
        courierName: o.courier_name ?? null,
        status: o.status,
        totalAmount: inv ? invTotal : codCollect,
        codCollectAmount: codCollect,
        deliveryChargeAmount: Number(o.delivery_charge_amount || 0),
        codChargeAmount: Number(o.cod_charge_amount || 0),
        courierNotes: o.driver_notes,
        courierRemittanceRef: o.courier_remittance_ref,
        courierBankTrxId: o.courier_bank_trx_id,
        billingProfileId: o.billing_profile_id,
        billingProfileName: o.billing_profiles?.name ?? null,
        createdAt: o.created_at,
        nextStep,
        collectionSource:
          o.collection_source
          ?? inv?.collection_source
          ?? (o.is_prepaid_snapshot ? 'billing_profile' : null),
        payoutSettlementStatus: o.payout_settlement_status || 'unpaid',
        invoiceOutstanding,
      };
    });

    // 3. Fetch merchants (billing profiles) with payable balances
    const { data: profilesData, error: profilesError } = await supabase
      .from('billing_profiles')
      .select('id, name')
      .eq('tenant_id', tenantId);

    if (profilesError) throw profilesError;

    // Payable = payout_earned section only (profit), not invoice AR
    const merchantBalanceMap = new Map<number, number>();
    (ledgerRows || []).forEach((r: any) => {
      const section = String(r.metadata?.section || '');
      if (
        (r.entity_type === 'middleman' || r.entity_type === 'customer')
        && section === 'payout_earned'
      ) {
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

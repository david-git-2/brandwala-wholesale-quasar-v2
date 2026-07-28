import { supabase } from 'src/boot/supabase';
import type {
  CourierRemittanceBatch,
  CourierRemittanceItem,
  SaveCourierRemittanceBatchPayload,
  SaveCourierRemittanceBatchResult,
  PostCourierRemittanceBatchResult,
  ShopOrder,
  CourierUnremittedFinancialSummary,
  ReconcileSingleOrderPayload,
  ReconcileSingleOrderResult,
  DispensePayoutPayload,
  DispensePayoutResult,
  MerchantPayoutSummary,
} from '../types';

export const courierRemittanceRepository = {
  async listBatches(
    tenantId: number,
    opts: { courierServiceId?: string | null; status?: string | null } = {},
  ): Promise<CourierRemittanceBatch[]> {
    let query = supabase
      .from('courier_remittance_batches')
      .select(`
        *,
        courier_service:courier_services(id, name, code)
      `)
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });

    if (opts.courierServiceId) {
      query = query.eq('courier_service_id', opts.courierServiceId);
    }
    if (opts.status) {
      query = query.eq('status', opts.status);
    }

    const { data, error } = await query;
    if (error) {
      console.error('[courierRemittanceRepository.listBatches error]:', error);
      throw error;
    }
    return (data as CourierRemittanceBatch[]) || [];
  },

  async getBatchById(
    tenantId: number,
    batchId: number,
  ): Promise<{ batch: CourierRemittanceBatch; items: CourierRemittanceItem[] }> {
    const { data: batchData, error: batchError } = await supabase
      .from('courier_remittance_batches')
      .select(`
        *,
        courier_service:courier_services(id, name, code)
      `)
      .eq('tenant_id', tenantId)
      .eq('id', batchId)
      .single();

    if (batchError) {
      console.error('[courierRemittanceRepository.getBatchById error]:', batchError);
      throw batchError;
    }

    const { data: itemsData, error: itemsError } = await supabase
      .from('courier_remittance_items')
      .select(`
        *,
        shop_order:shop_orders(id, order_no, recipient_name, status, courier_name, courier_awb_number, tracking_url)
      `)
      .eq('tenant_id', tenantId)
      .eq('batch_id', batchId)
      .order('id', { ascending: true });

    if (itemsError) {
      console.error('[courierRemittanceRepository.getBatchById items error]:', itemsError);
      throw itemsError;
    }

    return {
      batch: batchData as CourierRemittanceBatch,
      items: (itemsData as CourierRemittanceItem[]) || [],
    };
  },

  async listDeliveredOrdersForCourier(
    tenantId: number,
    courierServiceId: string,
  ): Promise<ShopOrder[]> {
    // 1. Fetch courier details to match courier_name or code
    const { data: courier, error: courierErr } = await supabase
      .from('courier_services')
      .select('name, code')
      .eq('id', courierServiceId)
      .single();

    if (courierErr) {
      console.error('[courierRemittanceRepository.listDeliveredOrdersForCourier courier fetch error]:', courierErr);
      throw courierErr;
    }

    const courierNames = [courier.name, courier.code].filter(Boolean);

    // 2. Fetch delivered orders for this tenant where status = delivered and courier_name matches
    const { data, error } = await supabase
      .from('shop_orders')
      .select('*')
      .eq('tenant_id', tenantId)
      .eq('status', 'delivered')
      .in('courier_name', courierNames)
      .order('placed_at', { ascending: false });

    if (error) {
      console.error('[courierRemittanceRepository.listDeliveredOrdersForCourier error]:', error);
      throw error;
    }

    return (data as ShopOrder[]) || [];
  },

  async saveBatchDraft(payload: SaveCourierRemittanceBatchPayload): Promise<SaveCourierRemittanceBatchResult> {
    const { data, error } = await supabase.rpc('create_or_update_courier_remittance_batch', {
      p_batch_id: payload.batch_id ?? null,
      p_tenant_id: payload.tenant_id,
      p_courier_service_id: payload.courier_service_id,
      p_batch_no: payload.batch_no,
      p_bank_trx_id: payload.bank_trx_id ?? null,
      p_payment_date: payload.payment_date ?? null,
      p_gross_cod_amount: payload.gross_cod_amount ?? 0.00,
      p_courier_charges_amount: payload.courier_charges_amount ?? 0.00,
      p_net_deposited_amount: payload.net_deposited_amount ?? 0.00,
      p_note: payload.note ?? null,
      p_items: payload.items ?? [],
    });

    if (error) {
      console.error('[courierRemittanceRepository.saveBatchDraft error]:', error);
      throw error;
    }

    return data as SaveCourierRemittanceBatchResult;
  },

  async postBatch(batchId: number): Promise<PostCourierRemittanceBatchResult> {
    const { data, error } = await supabase.rpc('process_courier_bulk_remittance_batch', {
      p_batch_id: batchId,
    });

    if (error) {
      console.error('[courierRemittanceRepository.postBatch error]:', error);
      throw error;
    }

    return data as PostCourierRemittanceBatchResult;
  },

  async fetchUnremittedSummary(tenantId: number): Promise<CourierUnremittedFinancialSummary[]> {
    const { data, error } = await supabase.rpc('get_courier_unremitted_financial_summary', {
      p_tenant_id: tenantId,
    });

    if (error) {
      console.error('[courierRemittanceRepository.fetchUnremittedSummary error]:', error);
      throw error;
    }

    return (data as CourierUnremittedFinancialSummary[]) || [];
  },

  async reconcileSingleOrder(payload: ReconcileSingleOrderPayload): Promise<ReconcileSingleOrderResult> {
    const { data, error } = await supabase.rpc('confirm_courier_remittance_to_tenant', {
      p_order_id: payload.orderId,
      p_courier_charge: payload.courierCharge ?? 0.00,
    });

    if (error) {
      console.error('[courierRemittanceRepository.reconcileSingleOrder error]:', error);
      throw error;
    }

    return data as ReconcileSingleOrderResult;
  },

  async dispensePayout(payload: DispensePayoutPayload): Promise<DispensePayoutResult> {
    const { data, error } = await supabase.rpc('dispense_middleman_payout_from_tenant', {
      p_tenant_id: payload.tenantId,
      p_billing_profile_id: payload.billingProfileId,
      p_amount: payload.amount,
      p_payout_method: payload.method ?? 'bank_transfer',
      p_reference_notes: payload.trxId ? `Trx: ${payload.trxId}` : null,
    });

    if (error) {
      console.error('[courierRemittanceRepository.dispensePayout error]:', error);
      throw error;
    }

    return data as DispensePayoutResult;
  },

  async fetchMerchantPayoutSummaries(tenantId: number): Promise<MerchantPayoutSummary[]> {
    const { data: profiles, error: profileErr } = await supabase
      .from('billing_profiles')
      .select('id, name, email, phone, customer_group_id')
      .eq('tenant_id', tenantId);

    if (profileErr) {
      console.error('[courierRemittanceRepository.fetchMerchantPayoutSummaries profile error]:', profileErr);
      throw profileErr;
    }

    if (!profiles || profiles.length === 0) return [];

    // Fetch wallet ledger balances & locked profits for all profiles
    const { data: ledger, error: ledgerErr } = await supabase
      .from('billing_profile_wallet_ledger')
      .select('billing_profile_id, transaction_type, amount')
      .eq('tenant_id', tenantId);

    if (ledgerErr) {
      console.error('[courierRemittanceRepository.fetchMerchantPayoutSummaries ledger error]:', ledgerErr);
      throw ledgerErr;
    }

    const summaryMap = new Map<number, MerchantPayoutSummary>();
    profiles.forEach((p) => {
      summaryMap.set(p.id, {
        billing_profile_id: p.id,
        name: p.name,
        email: p.email ?? null,
        phone: p.phone ?? null,
        customer_group_id: p.customer_group_id ?? null,
        locked_margin: 0.00,
        available_balance: 0.00,
      });
    });

    (ledger ?? []).forEach((entry) => {
      const item = summaryMap.get(entry.billing_profile_id);
      if (!item) return;

      const amt = Number(entry.amount || 0);
      switch (entry.transaction_type) {
        case 'dropship_profit':
          item.locked_margin += amt;
          break;
        case 'payment_received':
        case 'adjustment':
          item.available_balance += amt;
          break;
        case 'invoice_billed':
        case 'dropship_return_fee':
        case 'payout_paid':
          item.available_balance -= amt;
          break;
      }
    });

    return Array.from(summaryMap.values());
  },
};

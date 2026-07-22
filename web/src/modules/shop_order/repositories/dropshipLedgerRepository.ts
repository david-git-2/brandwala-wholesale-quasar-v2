import { supabase } from 'src/boot/supabase';

export type PayoutLedgerEntryType =
  | 'profit_credit'
  | 'return_fee_invoiced'
  | 'return_fee_uninvoiced'
  | 'clawback'
  | 'payout_paid';

export interface PayoutLedgerRow {
  id: string;
  tenant_id: number;
  customer_group_member_id: number;
  shop_order_id: number | null;
  global_invoice_id: number | null;
  entry_type: PayoutLedgerEntryType;
  amount: number;
  balance_after: number;
  reference_notes: string | null;
  created_by: string | null;
  created_at: string;
  shop_orders?: {
    order_no: string;
  } | null;
}

export interface LedgerListFilters {
  memberId?: number | null;
  from?: string | null;
  to?: string | null;
}

export interface RemittanceEligibleOrder {
  id: number;
  order_no: string;
  cod_collect_amount: number | null;
  global_invoice_id: number;
  billing_profile_id: number | null;
}

export interface RecordCourierRemittancePayload {
  order_id: number;
  net_amount: number;
  remittance_ref: string;
  bank_trx_id?: string | null;
  payment_date?: string | null;
  method?: string | null;
  note?: string | null;
}

export interface CreateMiddleManPayoutPayload {
  tenant_id: number;
  billing_profile_id: number;
  global_invoice_id: number;
  amount: number;
  note?: string | null;
}

export const dropshipLedgerRepository = {
  async listLedgerEntries(
    tenantId: number,
    filters: LedgerListFilters = {},
  ): Promise<PayoutLedgerRow[]> {
    let query = supabase
      .from('middle_man_payout_ledger')
      .select('*, shop_orders(order_no)')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });

    if (filters.memberId != null) {
      query = query.eq('customer_group_member_id', filters.memberId);
    }
    if (filters.from) {
      query = query.gte('created_at', filters.from);
    }
    if (filters.to) {
      query = query.lte('created_at', filters.to);
    }

    const { data, error } = await query;
    if (error) {
      console.error('[dropshipLedgerRepository.listLedgerEntries error]:', error);
      throw error;
    }
    return (data as PayoutLedgerRow[]) || [];
  },

  async listDeliveredOrdersForRemittance(tenantId: number): Promise<RemittanceEligibleOrder[]> {
    const { data, error } = await supabase
      .from('shop_orders')
      .select('id, order_no, cod_collect_amount, global_invoice_id, billing_profile_id')
      .eq('tenant_id', tenantId)
      .eq('shop_type_snapshot', 'dropship')
      .eq('status', 'delivered')
      .not('global_invoice_id', 'is', null)
      .order('updated_at', { ascending: false })
      .limit(50);

    if (error) {
      console.error('[dropshipLedgerRepository.listDeliveredOrdersForRemittance error]:', error);
      throw error;
    }
    return ((data as RemittanceEligibleOrder[]) || []).filter(
      (row) => row.global_invoice_id != null,
    );
  },

  async sumPendingCodRemittance(tenantId: number): Promise<number> {
    const { data, error } = await supabase
      .from('shop_orders')
      .select('cod_collect_amount')
      .eq('tenant_id', tenantId)
      .eq('shop_type_snapshot', 'dropship')
      .eq('status', 'delivered')
      .not('global_invoice_id', 'is', null);

    if (error) {
      console.error('[dropshipLedgerRepository.sumPendingCodRemittance error]:', error);
      throw error;
    }
    return (data || []).reduce(
      (sum, row) => sum + Number((row as { cod_collect_amount: number | null }).cod_collect_amount ?? 0),
      0,
    );
  },

  async getShopOrderRemittanceByInvoiceId(globalInvoiceId: number): Promise<{
    id: number;
    order_no: string;
    status: string;
    courier_remittance_ref: string | null;
    courier_bank_trx_id: string | null;
  } | null> {
    const { data, error } = await supabase
      .from('shop_orders')
      .select('id, order_no, status, courier_remittance_ref, courier_bank_trx_id')
      .eq('global_invoice_id', globalInvoiceId)
      .maybeSingle();

    if (error) {
      console.error('[dropshipLedgerRepository.getShopOrderRemittanceByInvoiceId error]:', error);
      throw error;
    }
    return data;
  },

  async recordCourierRemittance(payload: RecordCourierRemittancePayload): Promise<{
    success: boolean;
    invoice_id?: number;
    payment_id?: number;
    order_id?: number;
    status?: string;
  }> {
    const { data, error } = await supabase.rpc('record_dropship_courier_remittance', {
      p_order_id: payload.order_id,
      p_net_amount: payload.net_amount,
      p_remittance_ref: payload.remittance_ref,
      p_bank_trx_id: payload.bank_trx_id ?? null,
      p_payment_date: payload.payment_date ?? null,
      p_method: payload.method ?? 'cash',
      p_note: payload.note ?? null,
    });
    if (error) {
      console.error('[dropshipLedgerRepository.recordCourierRemittance error]:', error);
      throw error;
    }
    return (data as {
      success: boolean;
      invoice_id?: number;
      payment_id?: number;
      order_id?: number;
      status?: string;
    }) ?? { success: true };
  },

  async createMiddleManPayout(payload: CreateMiddleManPayoutPayload) {
    const { data, error } = await supabase.rpc('create_middle_man_payout', {
      p_tenant_id: payload.tenant_id,
      p_billing_profile_id: payload.billing_profile_id,
      p_global_invoice_id: payload.global_invoice_id,
      p_amount: payload.amount,
      p_note: payload.note ?? null,
    });
    if (error) {
      console.error('[dropshipLedgerRepository.createMiddleManPayout error]:', error);
      throw error;
    }
    return data;
  },

  async getInvoicePayoutContext(globalInvoiceId: number): Promise<{
    id: number;
    billing_profile_id: number | null;
    middle_man_payout_amount: number;
    middle_man_payout_status: string | null;
  }> {
    const { data, error } = await supabase
      .from('global_invoices')
      .select('id, billing_profile_id, middle_man_payout_amount, middle_man_payout_status')
      .eq('id', globalInvoiceId)
      .single();

    if (error) {
      console.error('[dropshipLedgerRepository.getInvoicePayoutContext error]:', error);
      throw error;
    }
    return data as {
      id: number;
      billing_profile_id: number | null;
      middle_man_payout_amount: number;
      middle_man_payout_status: string | null;
    };
  },
};

import { supabase } from 'src/boot/supabase';

export interface PayoutLedgerRow {
  id: string;
  tenant_id: number;
  customer_group_member_id: string;
  shop_order_id: number | null;
  global_invoice_id: number | null;
  entry_type: 'profit_credit' | 'return_fee_invoiced' | 'return_fee_uninvoiced' | 'clawback' | 'payout_paid';
  amount: number;
  balance_after: number;
  reference_notes: string | null;
  created_by: string | null;
  created_at: string;
  shop_orders?: {
    order_no: string;
  } | null;
}

export interface CreatePayoutLedgerPayload {
  tenant_id: number;
  customer_group_member_id: string;
  shop_order_id?: number | null;
  global_invoice_id?: number | null;
  entry_type: 'profit_credit' | 'return_fee_invoiced' | 'return_fee_uninvoiced' | 'clawback' | 'payout_paid';
  amount: number;
  balance_after: number;
  reference_notes?: string | null;
}

export const dropshipLedgerRepository = {
  async listLedgerEntries(tenantId: number): Promise<PayoutLedgerRow[]> {
    const { data, error } = await supabase
      .from('middle_man_payout_ledger')
      .select('*, shop_orders(order_no)')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('[dropshipLedgerRepository.listLedgerEntries error]:', error);
      throw error;
    }
    return (data as PayoutLedgerRow[]) || [];
  },

  async addLedgerEntry(payload: CreatePayoutLedgerPayload): Promise<PayoutLedgerRow> {
    const { data, error } = await supabase
      .from('middle_man_payout_ledger')
      .insert(payload)
      .select('*, shop_orders(order_no)')
      .single();

    if (error) {
      console.error('[dropshipLedgerRepository.addLedgerEntry error]:', error);
      throw error;
    }
    return data as PayoutLedgerRow;
  },
};

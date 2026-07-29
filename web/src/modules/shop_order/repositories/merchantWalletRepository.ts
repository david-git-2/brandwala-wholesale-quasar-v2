import { supabase } from 'src/boot/supabase';

export interface MerchantWalletSummary {
  billing_profile_id: number;
  available_balance: number;
  pending_balance: number;
  locked_balance: number;
  currency: string;
}

export interface MerchantWalletLedgerRow {
  id: string;
  created_at: string;
  transaction_type: string;
  amount: number;
  balance_after: number;
  source_id: string | null;
  order_id: number | null;
  note: string;
}

export const merchantWalletRepository = {
  async getMySummary(): Promise<MerchantWalletSummary> {
    const { data, error } = await supabase.rpc('get_my_dropship_wallet_summary');
    if (error) throw error;
    const row = Array.isArray(data) ? data[0] : data;
    if (!row) {
      throw new Error('No wallet summary returned');
    }
    return {
      billing_profile_id: Number(row.billing_profile_id),
      available_balance: Number(row.available_balance || 0),
      pending_balance: Number(row.pending_balance || 0),
      locked_balance: Number(row.locked_balance || 0),
      currency: String(row.currency || 'BDT'),
    };
  },

  async listMyLedger(opts: { limit?: number; offset?: number } = {}): Promise<MerchantWalletLedgerRow[]> {
    const { data, error } = await supabase.rpc('list_my_dropship_wallet_ledger', {
      p_limit: opts.limit ?? 50,
      p_offset: opts.offset ?? 0,
    });
    if (error) throw error;
    return ((data as MerchantWalletLedgerRow[] | null) || []).map((r) => ({
      id: String(r.id),
      created_at: r.created_at,
      transaction_type: r.transaction_type || '',
      amount: Number(r.amount || 0),
      balance_after: Number(r.balance_after || 0),
      source_id: r.source_id ?? null,
      order_id: r.order_id != null ? Number(r.order_id) : null,
      note: r.note || '',
    }));
  },
};

import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type {
  UniversalWalletLedgerEntry,
  RecordLedgerTransactionPayload,
  WalletLedgerQueryParams,
} from '../types';

export const walletRepository = {
  /**
   * Fetch ledger entries for a specific entity wallet ordered by creation date descending.
   */
  async fetchLedgerEntries(
    params: WalletLedgerQueryParams,
  ): Promise<UniversalWalletLedgerEntry[]> {
    let query = supabase
      .from('universal_wallet_ledger')
      .select('*')
      .eq('tenant_id', params.tenantId)
      .eq('entity_type', params.entityType)
      .eq('entity_id', params.entityId)
      .order('created_at', { ascending: false })
      .order('id', { ascending: false });

    if (params.limit && params.limit > 0) {
      const offset = params.offset || 0;
      query = query.range(offset, offset + params.limit - 1);
    }

    const { data, error } = await query;
    if (error) {
      console.error('[walletRepository.fetchLedgerEntries error]:', error);
      throw error;
    }

    return (data as UniversalWalletLedgerEntry[]) || [];
  },

  /**
   * Fetch latest balance_after for a specific entity wallet.
   */
  async fetchLatestBalance(
    params: Omit<WalletLedgerQueryParams, 'limit' | 'offset'>,
  ): Promise<number> {
    const { data, error } = await supabase
      .from('universal_wallet_ledger')
      .select('balance_after')
      .eq('tenant_id', params.tenantId)
      .eq('entity_type', params.entityType)
      .eq('entity_id', params.entityId)
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error('[walletRepository.fetchLatestBalance error]:', error);
      throw error;
    }

    return data?.balance_after ? Number(data.balance_after) : 0.0000;
  },

  /**
   * Record a new ledger transaction via atomic PostgreSQL RPC.
   */
  async recordTransaction(
    payload: RecordLedgerTransactionPayload,
  ): Promise<UniversalWalletLedgerEntry> {
    const authStore = useAuthStore();
    const tenantId = payload.tenant_id ?? authStore.selectedTenant?.id;

    if (!tenantId) {
      throw new Error('Tenant ID is required to record a wallet transaction.');
    }

    const { data, error } = await supabase.rpc('record_ledger_transaction', {
      p_tenant_id: tenantId,
      p_entity_type: payload.entity_type,
      p_entity_id: payload.entity_id,
      p_type: payload.type,
      p_amount: payload.amount,
      p_currency_code: payload.currency_code ?? 'BDT',
      p_exchange_rate: payload.exchange_rate ?? 1.000000,
      p_source_type: payload.source_type ?? 'adjustment',
      p_source_id: payload.source_id ?? null,
      p_metadata: payload.metadata ?? {},
      p_target_bucket: payload.target_bucket ?? 'available',
    });

    if (error) {
      console.error('[walletRepository.recordTransaction error]:', error);
      throw error;
    }

    return data as UniversalWalletLedgerEntry;
  },
};

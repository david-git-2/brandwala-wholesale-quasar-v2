import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type {
  WalletAccount,
  TransferWalletBalancePayload,
  WalletDashboardSummary,
  UniversalWalletEntityType,
} from '../types';

export const walletAccountRepository = {
  /**
   * Fetch 3-bucket materialized account balances for an entity.
   */
  async fetchAccountBalances(
    tenantId: number,
    entityType: UniversalWalletEntityType,
    entityId: number,
    currencyCode = 'BDT',
  ): Promise<WalletAccount> {
    const { data, error } = await supabase.rpc('get_wallet_account_balances', {
      p_tenant_id: tenantId,
      p_entity_type: entityType,
      p_entity_id: entityId,
      p_currency_code: currencyCode,
    });

    if (error) {
      console.error('[walletAccountRepository.fetchAccountBalances error]:', error);
      throw error;
    }

    return (data as unknown as WalletAccount) || {
      tenant_id: tenantId,
      entity_type: entityType,
      entity_id: entityId,
      currency_code: currencyCode,
      available_balance: 0,
      pending_balance: 0,
      locked_balance: 0,
      total_balance: 0,
    };
  },

  /**
   * Transfer balance between buckets (e.g. pending -> available, available -> locked).
   */
  async transferBalance(
    payload: TransferWalletBalancePayload,
  ): Promise<WalletAccount> {
    const authStore = useAuthStore();
    const tenantId = payload.tenant_id ?? authStore.selectedTenant?.id;

    if (!tenantId) {
      throw new Error('Tenant ID is required to transfer wallet balance.');
    }

    const { data, error } = await supabase.rpc('transfer_wallet_balance', {
      p_tenant_id: tenantId,
      p_entity_type: payload.entity_type,
      p_entity_id: payload.entity_id,
      p_from_bucket: payload.from_bucket,
      p_to_bucket: payload.to_bucket,
      p_amount: payload.amount,
      p_currency_code: payload.currency_code ?? 'BDT',
      p_notes: payload.notes ?? null,
      p_metadata: payload.metadata ?? {},
    });

    if (error) {
      console.error('[walletAccountRepository.transferBalance error]:', error);
      throw error;
    }

    return data as unknown as WalletAccount;
  },

  /**
   * Fetch aggregate wallet dashboard summary across entities.
   */
  async fetchDashboardSummary(tenantId: number): Promise<WalletDashboardSummary> {
    const { data, error } = await supabase.rpc('get_wallet_dashboard_summary', {
      p_tenant_id: tenantId,
    });

    if (error) {
      console.error('[walletAccountRepository.fetchDashboardSummary error]:', error);
      throw error;
    }

    return (data as unknown as WalletDashboardSummary) || {
      tenant_id: tenantId,
      tenant_cash_total: 0,
      courier_cod_holding_total: 0,
      merchant_pending_total: 0,
      merchant_available_total: 0,
      vendor_payables_total: 0,
      customer_deposits_total: 0,
    };
  },

  /**
   * List all wallet accounts for a tenant filtered by entity_type.
   */
  async listAccountsByType(
    tenantId: number,
    entityType: UniversalWalletEntityType,
  ): Promise<WalletAccount[]> {
    const { data, error } = await supabase
      .from('wallet_accounts')
      .select('*')
      .eq('tenant_id', tenantId)
      .eq('entity_type', entityType);

    if (error) {
      console.error('[walletAccountRepository.listAccountsByType error]:', error);
      throw error;
    }

    return (data || []).map((row) => ({
      ...row,
      entity_type: row.entity_type as UniversalWalletEntityType,
      available_balance: Number(row.available_balance || 0),
      pending_balance: Number(row.pending_balance || 0),
      locked_balance: Number(row.locked_balance || 0),
      total_balance:
        Number(row.available_balance || 0) +
        Number(row.pending_balance || 0) +
        Number(row.locked_balance || 0),
    }));
  },
};

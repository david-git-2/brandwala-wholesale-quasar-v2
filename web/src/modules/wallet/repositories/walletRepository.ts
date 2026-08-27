import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type {
  UniversalWalletLedgerEntry,
  UniversalWalletEntityType,
  WalletLedgerQueryParams,
  WalletDetailResponse,
  RecordManualTransactionPayload,
  ReverseLedgerPayload,
  WalletEntityListRow,
} from '../types';

export const walletRepository = {
  async listEntitiesForStaff(
    tenantId: number,
    entityType: UniversalWalletEntityType,
    search?: string | null,
    limit = 100,
    offset = 0,
    currencyCode = 'BDT',
  ): Promise<WalletEntityListRow[]> {
    const { data, error } = await supabase.rpc('list_wallet_entities_for_staff', {
      p_tenant_id: tenantId,
      p_entity_type: entityType,
      p_search: search ?? null,
      p_limit: limit,
      p_offset: offset,
      p_currency_code: currencyCode,
    });

    if (error) {
      console.error('[walletRepository.listEntitiesForStaff error]:', error);
      throw error;
    }

    return (data as WalletEntityListRow[]) || [];
  },

  async getDetailForStaff(
    tenantId: number,
    entityType: UniversalWalletEntityType,
    entityId: number,
    currencyCode = 'BDT',
  ): Promise<WalletDetailResponse> {
    const { data, error } = await supabase.rpc('get_wallet_detail_for_staff', {
      p_tenant_id: tenantId,
      p_entity_type: entityType,
      p_entity_id: entityId,
      p_currency_code: currencyCode,
    });

    if (error) {
      console.error('[walletRepository.getDetailForStaff error]:', error);
      throw error;
    }

    return data as unknown as WalletDetailResponse;
  },

  async listLedgerForStaff(
    params: WalletLedgerQueryParams & { search?: string | null; operatingTenantId?: number | null },
  ): Promise<UniversalWalletLedgerEntry[]> {
    const authStore = useAuthStore();
    const tenantId = params.tenantId || authStore.selectedTenant?.id;
    if (!tenantId) return [];

    const { data, error } = await supabase.rpc('list_wallet_ledger_for_staff', {
      p_tenant_id: tenantId,
      p_entity_type: params.entityType,
      p_entity_id: params.entityId,
      p_search: params.search ?? null,
      p_operating_tenant_id: params.operatingTenantId ?? null,
      p_limit: params.limit ?? 50,
      p_offset: params.offset ?? 0,
    });

    if (error) {
      console.error('[walletRepository.listLedgerForStaff error]:', error);
      throw error;
    }

    return ((data as UniversalWalletLedgerEntry[]) || []).map((row) => ({
      ...row,
      tenant_id: row.parent_tenant_id ?? row.tenant_id,
    }));
  },

  async recordManualTransaction(payload: RecordManualTransactionPayload): Promise<Record<string, unknown>> {
    const authStore = useAuthStore();
    const tenantId = payload.tenant_id ?? authStore.selectedTenant?.id;
    if (!tenantId) throw new Error('Tenant ID is required.');

    const { data, error } = await supabase.rpc('record_wallet_manual_transaction_for_staff', {
      p_tenant_id: tenantId,
      p_action_type: payload.action_type,
      p_primary_entity_type: payload.primary_entity_type,
      p_primary_entity_id: payload.primary_entity_id,
      p_amount: payload.amount,
      p_currency_code: payload.currency_code ?? 'BDT',
      p_exchange_rate: payload.exchange_rate ?? 1,
      p_category: payload.category ?? null,
      p_payment_method: payload.payment_method ?? null,
      p_reference_id: payload.reference_id ?? null,
      p_note: payload.note ?? null,
      p_counterparty_entity_type: payload.counterparty_entity_type ?? null,
      p_counterparty_entity_id: payload.counterparty_entity_id ?? null,
      p_target_bucket: payload.target_bucket ?? 'available',
    });

    if (error) {
      console.error('[walletRepository.recordManualTransaction error]:', error);
      throw error;
    }

    return data as Record<string, unknown>;
  },

  async reverseLedgerEntry(payload: ReverseLedgerPayload): Promise<Record<string, unknown>> {
    const authStore = useAuthStore();
    const tenantId = payload.tenant_id ?? authStore.selectedTenant?.id;
    if (!tenantId) throw new Error('Tenant ID is required.');

    const { data, error } = await supabase.rpc('reverse_wallet_ledger_entry_for_staff', {
      p_tenant_id: tenantId,
      p_ledger_entry_id: payload.ledger_entry_id,
      p_reason: payload.reason,
      p_reference_id: payload.reference_id ?? null,
    });

    if (error) {
      console.error('[walletRepository.reverseLedgerEntry error]:', error);
      throw error;
    }

    return data as Record<string, unknown>;
  },
};

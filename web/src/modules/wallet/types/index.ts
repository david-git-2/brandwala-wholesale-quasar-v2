export type UniversalWalletEntityType = 'customer' | 'vendor' | 'courier' | 'middleman' | 'tenant';
export type UniversalWalletTransactionType = 'credit' | 'debit';
export type UniversalWalletSourceType = 'shop_order' | 'vendor_purchase' | 'payout' | 'adjustment';

export interface UniversalWalletLedgerEntry {
  id: string;
  tenant_id: number;
  entity_type: UniversalWalletEntityType;
  entity_id: number;
  type: UniversalWalletTransactionType;
  amount: number;
  currency_code: string;
  exchange_rate: number;
  base_amount: number;
  balance_after: number;
  source_type: UniversalWalletSourceType;
  source_id: string | null;
  metadata: Record<string, any>;
  created_at: string;
}

export interface RecordLedgerTransactionPayload {
  tenant_id?: number;
  entity_type: UniversalWalletEntityType;
  entity_id: number;
  type: UniversalWalletTransactionType;
  amount: number;
  currency_code?: string;
  exchange_rate?: number;
  source_type?: UniversalWalletSourceType;
  source_id?: string | null;
  metadata?: Record<string, any>;
}

export interface WalletLedgerQueryParams {
  tenantId: number;
  entityType: UniversalWalletEntityType;
  entityId: number;
  limit?: number;
  offset?: number;
}

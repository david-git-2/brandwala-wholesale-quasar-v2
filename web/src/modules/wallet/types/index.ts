export type UniversalWalletEntityType =
  | 'customer'
  | 'vendor'
  | 'courier'
  | 'middleman'
  | 'tenant'
  | 'investor'
  | 'cargo_company';
export type UniversalWalletTransactionType = 'credit' | 'debit';
export type UniversalWalletSourceType = 'shop_order' | 'vendor_purchase' | 'payout' | 'adjustment' | 'bucket_transfer';
export type WalletBucket = 'available' | 'pending' | 'locked';
export type UniversalWalletSection =
  | 'receivable'
  | 'payout_earned'
  | 'cod_holding'
  | 'delivery_fee'
  | 'revenue'
  | 'adjustment'
  | 'payment_received'
  | 'intercompany';

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
  target_bucket?: WalletBucket;
}

export interface WalletLedgerQueryParams {
  tenantId: number;
  entityType: UniversalWalletEntityType;
  entityId: number;
  limit?: number;
  offset?: number;
}

export interface WalletAccount {
  id?: number;
  tenant_id: number;
  entity_type: UniversalWalletEntityType;
  entity_id: number;
  currency_code: string;
  available_balance: number;
  pending_balance: number;
  locked_balance: number;
  total_balance: number;
}

export interface TransferWalletBalancePayload {
  tenant_id?: number | undefined;
  entity_type: UniversalWalletEntityType;
  entity_id: number;
  from_bucket: WalletBucket;
  to_bucket: WalletBucket;
  amount: number;
  currency_code?: string | undefined;
  notes?: string | undefined;
  metadata?: Record<string, any> | undefined;
}

export interface WalletDashboardSummary {
  tenant_id: number;
  tenant_cash_total: number;
  courier_cod_holding_total: number;
  merchant_pending_total: number;
  merchant_available_total: number;
  vendor_payables_total: number;
  customer_deposits_total: number;
}

export interface WalletStatementParams {
  tenantId: number;
  entityType: UniversalWalletEntityType;
  entityId: number;
  startDate?: string | null;
  endDate?: string | null;
}

export interface WalletEntityStatement {
  tenant_id: number;
  entity_type: UniversalWalletEntityType;
  entity_id: number;
  start_date: string | null;
  end_date: string | null;
  opening_balance: number;
  total_credits: number;
  total_debits: number;
  closing_balance: number;
  entries: UniversalWalletLedgerEntry[];
}

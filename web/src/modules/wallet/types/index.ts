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
  parent_tenant_id?: number;
  operating_tenant_id?: number;
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
  is_reversal?: boolean;
  reversed_entry_id?: string | null;
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

export interface CashInReportParams {
  tenantId: number;
  startDate?: string | null;
  endDate?: string | null;
}

export interface CashInByMethodSummary {
  method: string;
  amount: number;
  count: number;
}

export interface CashInReportEntry {
  id: string;
  amount: number;
  method: string;
  source_type: string;
  source_id: string | null;
  label: string | null;
  invoice_id: number | null;
  created_at: string;
}

export interface TenantCashInReport {
  tenant_id: number;
  start_date: string | null;
  end_date: string | null;
  cash_in_total: number;
  entry_count: number;
  by_method: CashInByMethodSummary[];
  entries: CashInReportEntry[];
}


export interface WalletEntityListRow {
  entity_id: number;
  entity_type: string;
  name: string;
  code: string | null;
  caption: string | null;
  available_balance: number;
  pending_balance: number;
  locked_balance: number;
  total_balance: number;
  source_uuid: string | null;
  operating_tenant_id: number | null;
  has_wallet_activity: boolean;
}

export interface WalletDetailResponse {
  success: boolean;
  error?: string;
  books_tenant_id?: number;
  operating_tenant_id?: number;
  entity?: {
    entity_type: UniversalWalletEntityType;
    entity_id: number;
    name: string;
    code?: string | null;
    caption?: string | null;
    source_uuid?: string | null;
  };
  account?: {
    currency_code: string;
    available_balance: number;
    pending_balance: number;
    locked_balance: number;
    total_balance: number;
  };
  permissions?: {
    can_record_manual: boolean;
    can_reverse: boolean;
  };
}

export interface RecordManualTransactionPayload {
  tenant_id?: number;
  action_type: 'pay' | 'deposit' | 'credit' | 'withdraw';
  primary_entity_type: UniversalWalletEntityType;
  primary_entity_id: number;
  amount: number;
  currency_code?: string;
  exchange_rate?: number;
  category?: string | null;
  payment_method?: string | null;
  reference_id?: string | null;
  note?: string | null;
  counterparty_entity_type?: UniversalWalletEntityType | null;
  counterparty_entity_id?: number | null;
  target_bucket?: WalletBucket;
}

export interface ReverseLedgerPayload {
  tenant_id?: number;
  ledger_entry_id: string;
  reason: string;
  reference_id?: string | null;
}

/**
 * Universal Wallet & Ledger Stubs & Mock Data Provider
 * Used for isolated financial ledger testing and wallet UI verification.
 */

export interface WalletEntityStub {
  entity_id: string;
  entity_name: string;
  entity_type: 'tenant' | 'vendor' | 'courier' | 'customer' | 'middleman' | 'cargo_company' | 'investor';
  currency_code: string;
  current_balance: number;
  unsettled_balance: number;
  last_transaction_at: string;
}

export const mockWalletEntities: WalletEntityStub[] = [
  {
    entity_id: 'wal-ent-001',
    entity_name: 'Metro Mega Mart (Dhanmondi)',
    entity_type: 'customer',
    currency_code: 'BDT',
    current_balance: 45000.0,
    unsettled_balance: 0.0,
    last_transaction_at: new Date(Date.now() - 3600000 * 2).toISOString(),
  },
  {
    entity_id: 'wal-ent-002',
    entity_name: 'Steadfast Courier Logistics',
    entity_type: 'courier',
    currency_code: 'BDT',
    current_balance: 124500.0,
    unsettled_balance: 18200.0,
    last_transaction_at: new Date(Date.now() - 3600000 * 5).toISOString(),
  },
  {
    entity_id: 'wal-ent-003',
    entity_name: 'Yiwu Direct Sourcing Co.',
    entity_type: 'vendor',
    currency_code: 'CNY',
    current_balance: 35000.0,
    unsettled_balance: 0.0,
    last_transaction_at: new Date(Date.now() - 86400000).toISOString(),
  },
];

export async function fetchMockWalletEntities(): Promise<WalletEntityStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockWalletEntities];
}

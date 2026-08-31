import type { UniversalWalletEntityType } from '../../types';

export const walletQueryKeys = {
  all: ['wallet'] as const,
  entityDirectory: (params: {
    booksTenantId: number;
    entityType: UniversalWalletEntityType;
    search?: string | null;
    limit?: number;
    offset?: number;
  }) => ['wallet', 'entityDirectory', params] as const,
  detail: (params: {
    booksTenantId: number;
    entityType: UniversalWalletEntityType;
    entityId: number;
  }) => ['wallet', 'detail', params] as const,
  ledger: (params: {
    booksTenantId: number;
    entityType: UniversalWalletEntityType;
    entityId: number;
    search?: string | null;
    offset?: number;
  }) => ['wallet', 'ledger', params] as const,
  ledgerList: (params: { tenantId: number; entityType: UniversalWalletEntityType; entityId: number }) =>
    ['wallet', 'ledgerList', params] as const,
  balance: (params: { tenantId: number; entityType: UniversalWalletEntityType; entityId: number }) =>
    ['wallet', 'balance', params] as const,
  accountBalances: (params: { tenantId: number; entityType: UniversalWalletEntityType; entityId: number }) =>
    ['wallet', 'accountBalances', params] as const,
  dashboardSummary: (tenantId: number) =>
    ['wallet', 'dashboardSummary', tenantId] as const,
  statement: (params: { tenantId: number; entityType: UniversalWalletEntityType; entityId: number; startDate?: string | null; endDate?: string | null }) =>
    ['wallet', 'statement', params] as const,
  cashIn: (params: { tenantId: number; startDate?: string | null; endDate?: string | null }) =>
    ['wallet', 'cashIn', params] as const,
};


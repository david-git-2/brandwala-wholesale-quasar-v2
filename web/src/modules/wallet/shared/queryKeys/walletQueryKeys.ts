import type { UniversalWalletEntityType } from '../../types';

export const walletQueryKeys = {
  all: ['wallet'] as const,
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
};

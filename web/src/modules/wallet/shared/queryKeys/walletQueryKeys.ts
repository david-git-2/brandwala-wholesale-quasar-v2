import type { UniversalWalletEntityType } from '../../types';

export const walletQueryKeys = {
  all: ['wallet'] as const,
  ledgerList: (params: { tenantId: number; entityType: UniversalWalletEntityType; entityId: number }) =>
    ['wallet', 'ledgerList', params] as const,
  balance: (params: { tenantId: number; entityType: UniversalWalletEntityType; entityId: number }) =>
    ['wallet', 'balance', params] as const,
};

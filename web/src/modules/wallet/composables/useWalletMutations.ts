import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { walletRepository } from '../repositories/walletRepository';
import { walletQueryKeys } from '../shared/queryKeys/walletQueryKeys';
import { showSuccessNotification, showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';
import type { RecordLedgerTransactionPayload, UniversalWalletLedgerEntry } from '../types';

export function useRecordLedgerTransactionMutation() {
  const queryClient = useQueryClient();

  return useMutation<UniversalWalletLedgerEntry, Error, RecordLedgerTransactionPayload>({
    mutationFn: async (payload: RecordLedgerTransactionPayload) => {
      return walletRepository.recordTransaction(payload);
    },
    onSuccess: async () => {
      showSuccessNotification('Wallet transaction recorded successfully.');
      await queryClient.invalidateQueries({ queryKey: walletQueryKeys.all });
    },
    onError: (error: unknown) => {
      showErrorNotification(parseSupabaseError(error, 'Failed to record wallet transaction.'));
    },
  });
}

export function useAdjustWalletBalanceMutation() {
  const queryClient = useQueryClient();

  return useMutation<UniversalWalletLedgerEntry, Error, RecordLedgerTransactionPayload>({
    mutationFn: async (payload: RecordLedgerTransactionPayload) => {
      return walletRepository.recordTransaction({
        ...payload,
        source_type: payload.source_type ?? 'adjustment',
      });
    },
    onSuccess: async () => {
      showSuccessNotification('Wallet balance adjusted successfully.');
      await queryClient.invalidateQueries({ queryKey: walletQueryKeys.all });
    },
    onError: (error: unknown) => {
      showErrorNotification(parseSupabaseError(error, 'Failed to adjust wallet balance.'));
    },
  });
}

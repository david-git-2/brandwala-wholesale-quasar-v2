import { type ComputedRef, type Ref } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { MoneyPayKind, MoneyPaySubmitPayload } from 'src/modules/bills_pays/types/moneyPayDialog';
import { ProfileDepositPartialError } from '../utils/profileDepositPartialError';
import {
  afterProfileCashMovementSuccess,
  executeProfileCashMovement,
  type ProfileCashMovementSuccess,
} from '../utils/executeProfileCashMovement';

export function useProfileCashMovementSubmit(options: {
  kind: Ref<MoneyPayKind>;
  profileId: Ref<number | null>;
  tenantId: ComputedRef<number>;
  booksTenantId: ComputedRef<number>;
  entityType: ComputedRef<string>;
  entityId: ComputedRef<number>;
  onMovementSuccess?: (result: ProfileCashMovementSuccess) => void;
}) {
  const queryClient = useQueryClient();

  const movementMutation = useMutation({
    mutationFn: async (payload: MoneyPaySubmitPayload) => {
      const pid = options.profileId.value;
      if (pid == null) throw new Error('Cash profile not ready.');
      return executeProfileCashMovement(
        {
          kind: options.kind.value,
          profileId: pid,
          booksTenantId: options.booksTenantId.value,
          payload,
        },
        queryClient,
      );
    },
    onSuccess: (result) => {
      if (options.kind.value === 'deposit') {
        const batch = result.kind === 'deposit' && result.batch === true;
        const postedCount =
          batch && result.kind === 'deposit' ? Number(result.postedCount) || 0 : 1;
        showSuccessNotification(
          batch && postedCount > 1 ? `Posted ${postedCount} deposits.` : 'Deposit posted.',
        );
      } else {
        showSuccessNotification('Withdrawal posted.');
      }
      afterProfileCashMovementSuccess(queryClient, {
        kind: options.kind.value,
        result,
        operatingTenantId: options.tenantId.value,
        booksTenantId: options.booksTenantId.value,
        entityType: options.entityType.value,
        entityId: options.entityId.value,
        profileId: options.profileId.value,
      });
      options.onMovementSuccess?.(result);
    },
    onError: (error: unknown) => {
      if (error instanceof ProfileDepositPartialError) {
        showErrorNotification(error.message);
        afterProfileCashMovementSuccess(queryClient, {
          kind: options.kind.value,
          result: undefined,
          operatingTenantId: options.tenantId.value,
          booksTenantId: options.booksTenantId.value,
          entityType: options.entityType.value,
          entityId: options.entityId.value,
          profileId: options.profileId.value,
        });
        return;
      }
      showErrorNotification(error instanceof Error ? error.message : 'Could not post cash movement.');
    },
  });

  const submitMovement = (
    payload: MoneyPaySubmitPayload,
    hooks?: { onPartialDeposit?: (postedCount: number) => void },
  ) => {
    void movementMutation.mutateAsync(payload).catch((error: unknown) => {
      if (error instanceof ProfileDepositPartialError) {
        hooks?.onPartialDeposit?.(error.postedCount);
      }
    });
  };

  return {
    movementMutation,
    submitMovement,
  };
}
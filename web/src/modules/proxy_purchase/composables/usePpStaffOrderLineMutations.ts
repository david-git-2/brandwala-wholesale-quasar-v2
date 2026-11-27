import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import { ppPurchaseQueryKeys } from '../shared/queryKeys/ppPurchaseQueryKeys';
import type { PpStaffOrderLineUpdatePayload } from '../types/ppPurchaseRequest';

export function usePpStaffOrderLineMutations() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);

  const invalidateStaffLines = () => {
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.staffOrderLines(tenantId.value),
    });
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.staffRequests(tenantId.value),
    });
  };

  const updateLine = useMutation({
    mutationFn: async (payload: PpStaffOrderLineUpdatePayload) => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      return ppPurchaseRequestRepository.updateLineForStaff(tid, payload);
    },
    onSuccess: () => {
      showSuccessNotification('Item updated.');
      invalidateStaffLines();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not update item.';
      showErrorNotification(message);
    },
  });

  const deleteLine = useMutation({
    mutationFn: async (lineId: number) => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      await ppPurchaseRequestRepository.deleteLineForStaff(tid, lineId);
    },
    onSuccess: () => {
      showSuccessNotification('Item removed.');
      invalidateStaffLines();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not remove item.';
      showErrorNotification(message);
    },
  });

  return { updateLine, deleteLine };
}
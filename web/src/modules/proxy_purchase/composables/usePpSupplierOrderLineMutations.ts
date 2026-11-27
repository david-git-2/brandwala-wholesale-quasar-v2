import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import { ppPurchaseQueryKeys } from '../shared/queryKeys/ppPurchaseQueryKeys';
import type { PpSupplierOrderLineUpdatePayload } from '../types/ppPurchaseRequest';

export function usePpSupplierOrderLineMutations() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);
  const peopleGroupMemberId = computed(() => authStore.customerGroupMemberId);

  const invalidateSupplierLines = () => {
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.supplierOrderLines(
        tenantId.value,
        peopleGroupMemberId.value,
      ),
    });
  };

  const updateLine = useMutation({
    mutationFn: async (payload: PpSupplierOrderLineUpdatePayload) => {
      const tid = tenantId.value;
      const memberId = peopleGroupMemberId.value;
      if (tid == null || memberId == null) throw new Error('Proxy supplier session not ready.');
      return ppPurchaseRequestRepository.updateLineForSupplier(tid, memberId, payload);
    },
    onSuccess: () => {
      showSuccessNotification('Line updated.');
      invalidateSupplierLines();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not update line.';
      showErrorNotification(message);
    },
  });

  return { updateLine };
}
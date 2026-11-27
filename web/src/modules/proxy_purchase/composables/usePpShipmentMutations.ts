import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { ppShipmentRepository } from '../repositories/ppShipmentRepository';
import { ppShipmentQueryKeys } from '../shared/queryKeys/ppShipmentQueryKeys';

export function usePpShipmentMutations() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const invalidateList = () => {
    void queryClient.invalidateQueries({
      queryKey: ppShipmentQueryKeys.list(tenantId.value),
    });
  };

  const createShipment = useMutation({
    mutationFn: async (payload: { name: string }) => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      return ppShipmentRepository.createShipment(tid, payload.name);
    },
    onSuccess: () => {
      showSuccessNotification('Shipment created.');
      invalidateList();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not create shipment.';
      showErrorNotification(message);
    },
  });

  return { createShipment };
}
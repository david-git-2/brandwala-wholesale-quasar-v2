import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import { ppPurchaseQueryKeys } from '../shared/queryKeys/ppPurchaseQueryKeys';
import type {
  PpStaffOrderLineBulkPatch,
  PpStaffOrderLineUpdatePayload,
  PpStaffOrderLineWritePayload,
} from '../types/ppPurchaseRequest';

export function usePpStaffOrderLineMutations() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);

  const invalidateStaffLines = () => {
    void queryClient.invalidateQueries({
      queryKey: ['pp-purchase-staff-order-lines', tenantId.value],
    });
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.staffOrderLineFilterOptions(tenantId.value),
    });
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.staffRequests(tenantId.value),
    });
  };

  const addLine = useMutation({
    mutationFn: async (payload: { requestId: number; line: PpStaffOrderLineWritePayload }) => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      return ppPurchaseRequestRepository.addLineForStaff(tid, payload.requestId, payload.line);
    },
    onSuccess: () => {
      showSuccessNotification('Item added.');
      invalidateStaffLines();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not add item.';
      showErrorNotification(message);
    },
  });

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

  const deleteLines = useMutation({
    mutationFn: async (lineIds: number[]) => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      const uniqueIds = [...new Set(lineIds.filter((id) => Number.isFinite(id) && id > 0))];
      if (uniqueIds.length === 0) return 0;
      for (const lineId of uniqueIds) {
        await ppPurchaseRequestRepository.deleteLineForStaff(tid, lineId);
      }
      return uniqueIds.length;
    },
    onSuccess: (count) => {
      showSuccessNotification(count === 1 ? 'Item removed.' : `${count} items removed.`);
      invalidateStaffLines();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not remove items.';
      showErrorNotification(message);
      invalidateStaffLines();
    },
  });

  const updateLines = useMutation({
    mutationFn: async (payload: { lineIds: number[]; patch: PpStaffOrderLineBulkPatch }) => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      return ppPurchaseRequestRepository.bulkUpdateLinesForStaff(
        tid,
        payload.lineIds,
        payload.patch,
      );
    },
    onSuccess: (result) => {
      const count = result.updated_count;
      showSuccessNotification(count === 1 ? 'Item updated.' : `${count} items updated.`);
      invalidateStaffLines();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not update items.';
      showErrorNotification(message);
      invalidateStaffLines();
    },
  });

  return { addLine, updateLine, updateLines, deleteLine, deleteLines };
}
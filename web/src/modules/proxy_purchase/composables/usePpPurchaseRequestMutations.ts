import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import { ppPurchaseQueryKeys } from '../shared/queryKeys/ppPurchaseQueryKeys';
import type { PpBucketInstruction, PpPurchaseRequest } from '../types/ppPurchaseRequest';

export function usePpPurchaseRequestMutations(requestId: Ref<number | null>) {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);

  const invalidateCustomerRequests = () => {
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.customerRequests(tenantId.value),
    });
  };

  const invalidateCustomerOrderLines = () => {
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.customerOrderLines(tenantId.value),
    });
  };

  const invalidate = () => {
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.request(tenantId.value, requestId.value),
    });
    void queryClient.invalidateQueries({
      queryKey: ppPurchaseQueryKeys.requestLines(tenantId.value, requestId.value),
    });
    invalidateCustomerRequests();
    invalidateCustomerOrderLines();
  };

  const createDraft = useMutation({
    mutationFn: async () => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      return ppPurchaseRequestRepository.createDraft(tid);
    },
    onSuccess: () => {
      invalidateCustomerRequests();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not create request.';
      showErrorNotification(message);
    },
  });

  const addLine = useMutation({
    mutationFn: async (payload: { url: string; needed_qty: number; description?: string }) => {
      const tid = tenantId.value;
      const rid = requestId.value;
      if (!tid || !rid) throw new Error('Request not ready.');
      return ppPurchaseRequestRepository.addLine(tid, rid, payload);
    },
    onSuccess: () => {
      showSuccessNotification('Item added.');
      invalidate();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not add item.';
      showErrorNotification(message);
    },
  });

  const updateLine = useMutation({
    mutationFn: async (payload: {
      lineId: number;
      url: string;
      needed_qty: number;
      description?: string;
    }) => {
      const tid = tenantId.value;
      const rid = requestId.value;
      if (!tid || !rid) throw new Error('Request not ready.');
      return ppPurchaseRequestRepository.updateLine(tid, rid, payload.lineId, payload);
    },
    onSuccess: () => {
      showSuccessNotification('Item updated.');
      invalidate();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not update item.';
      showErrorNotification(message);
    },
  });

  const deleteLine = useMutation({
    mutationFn: async (lineId: number) => {
      const tid = tenantId.value;
      const rid = requestId.value;
      if (!tid || !rid) throw new Error('Request not ready.');
      await ppPurchaseRequestRepository.deleteLine(tid, rid, lineId);
    },
    onSuccess: () => {
      showSuccessNotification('Item removed.');
      invalidate();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not remove item.';
      showErrorNotification(message);
    },
  });

  const saveInstructions = useMutation({
    mutationFn: async (bucketInstructions: PpBucketInstruction[]) => {
      const tid = tenantId.value;
      const rid = requestId.value;
      if (!tid || !rid) throw new Error('Request not ready.');
      await ppPurchaseRequestRepository.updateInstructions(tid, rid, bucketInstructions);
    },
    onSuccess: () => {
      showSuccessNotification('Instructions saved.');
      invalidate();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not save instructions.';
      showErrorNotification(message);
    },
  });

  const deleteDraft = useMutation({
    mutationFn: async () => {
      const tid = tenantId.value;
      const rid = requestId.value;
      if (!tid || !rid) throw new Error('Request not ready.');
      await ppPurchaseRequestRepository.deleteDraft(tid, rid);
    },
    onSuccess: () => {
      showSuccessNotification('Request deleted.');
      invalidateCustomerRequests();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not delete request.';
      showErrorNotification(message);
    },
  });

  const postRequest = useMutation({
    mutationFn: async () => {
      const tid = tenantId.value;
      const rid = requestId.value;
      if (!tid || !rid) throw new Error('Request not ready.');
      return ppPurchaseRequestRepository.postRequest(tid, rid);
    },
    onSuccess: (posted) => {
      showSuccessNotification('Request posted to admin.');
      const tid = tenantId.value;
      const rid = requestId.value;
      if (tid != null && rid != null) {
        queryClient.setQueryData<PpPurchaseRequest | undefined>(
          ppPurchaseQueryKeys.request(tid, rid),
          (prev) =>
            prev
              ? {
                  ...prev,
                  status: 'requested',
                  request_number: posted.request_number ?? prev.request_number,
                  bucket_instructions: posted.bucket_instructions ?? prev.bucket_instructions,
                  updated_at: posted.updated_at || prev.updated_at,
                }
              : prev,
        );
      }
      invalidate();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not post request.';
      showErrorNotification(message);
    },
  });

  return { createDraft, addLine, updateLine, deleteLine, saveInstructions, postRequest, deleteDraft };
}
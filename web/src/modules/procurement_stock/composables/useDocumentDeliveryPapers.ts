import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, unref, type MaybeRef } from 'vue';
import { parseSupabaseError, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import {
  procurementDemandRepository,
  type ProcurementDemandDocumentType,
} from '../repositories/procurementDemandRepository';

export function useDocumentDeliveryPapers(options: {
  tenantId: MaybeRef<number | null>;
  documentType: MaybeRef<ProcurementDemandDocumentType | null>;
  documentId: MaybeRef<number | null>;
  enabled?: MaybeRef<boolean>;
}) {
  const queryClient = useQueryClient();
  const tenantId = computed(() => unref(options.tenantId));
  const documentType = computed(() => unref(options.documentType));
  const documentId = computed(() => unref(options.documentId));
  const enabled = computed(
    () =>
      (unref(options.enabled) ?? true) &&
      tenantId.value != null &&
      documentType.value != null &&
      documentId.value != null,
  );

  const listQuery = useQuery({
    queryKey: computed(() =>
      procurementStockQueryKeys.deliveryPapersForDocument({
        tenantId: tenantId.value ?? 0,
        documentType: documentType.value ?? '',
        documentId: documentId.value ?? 0,
      }),
    ),
    queryFn: () =>
      procurementDemandRepository.listDeliveryPapersForDocument({
        tenantId: tenantId.value!,
        documentType: documentType.value!,
        documentId: documentId.value!,
      }),
    enabled,
  });

  const createMutation = useMutation({
    mutationFn: () =>
      procurementDemandRepository.createDeliveryPaperForDocument({
        tenantId: tenantId.value!,
        documentType: documentType.value!,
        documentId: documentId.value!,
      }),
    onSuccess: async () => {
      showSuccessNotification('Delivery paper created');
      await queryClient.invalidateQueries({
        queryKey: procurementStockQueryKeys.deliveryPapersForDocument({
          tenantId: tenantId.value!,
          documentType: documentType.value!,
          documentId: documentId.value!,
        }),
      });
    },
    onError: (err) => {
      showErrorNotification(parseSupabaseError(err, 'Failed to create delivery paper'));
    },
  });

  return {
    papers: computed(() => listQuery.data.value ?? []),
    isLoading: listQuery.isLoading,
    isCreating: createMutation.isPending,
    createPaper: createMutation.mutateAsync,
    refetch: listQuery.refetch,
  };
}

import { computed, type Ref } from 'vue';
import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import { parseSupabaseError, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { tenantRepository, type TenantPurgePreviewCounts, type TenantPurgeResult } from '../repositories/tenantRepository';

export const useTenantPurgePreviewQuery = (
  parentTenantId: Ref<number | undefined>,
  scope: Ref<'all_hierarchy' | 'child_only'>,
  targetChildId: Ref<number | null>,
  enabled: Ref<boolean>,
) => {
  return useQuery<TenantPurgePreviewCounts>({
    queryKey: computed(() => [
      'tenant',
      'purge_preview',
      parentTenantId.value,
      scope.value,
      targetChildId.value,
    ]),
    queryFn: async () => {
      if (!parentTenantId.value) {
        return {
          shipments: 0,
          stocks: 0,
          invoices: 0,
          orders: 0,
          carts: 0,
          ledgers: 0,
          wallets_to_reset: 0,
        };
      }
      return await tenantRepository.previewPurgeData({
        parentTenantId: parentTenantId.value,
        scope: scope.value,
        targetChildId: targetChildId.value,
      });
    },
    enabled: computed(() => enabled.value && Boolean(parentTenantId.value)),
    staleTime: 5000,
  });
};

export const useTenantPurgeMutation = () => {
  const queryClient = useQueryClient();

  return useMutation<
    TenantPurgeResult,
    Error,
    {
      parentTenantId: number;
      scope: 'all_hierarchy' | 'child_only';
      confirmationSlug: string;
      targetChildId: number | null;
      targetName: string;
    }
  >({
    mutationFn: async (payload) => {
      return await tenantRepository.purgeOperationalData({
        parentTenantId: payload.parentTenantId,
        scope: payload.scope,
        confirmationSlug: payload.confirmationSlug,
        targetChildId: payload.targetChildId,
      });
    },
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries();
      const targetLabel = variables.targetName ? `"${variables.targetName}"` : 'organization';
      showSuccessNotification(`Operational data for ${targetLabel} wiped successfully. System reset to clean state.`);
    },
    onError: (error) => {
      showErrorNotification(parseSupabaseError(error, 'Failed to wipe operational data'));
    },
  });
};

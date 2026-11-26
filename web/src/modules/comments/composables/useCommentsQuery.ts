import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { commentsRepository } from '../repositories/commentsRepository';
import { commentsQueryKeys } from '../shared/queryKeys/commentsQueryKeys';

export function useCommentsQuery(
  entityType: Ref<string>,
  entityId: Ref<string | null>,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  return useQuery({
    queryKey: computed(() =>
      commentsQueryKeys.list(tenantId.value, entityType.value, entityId.value),
    ),
    queryFn: () =>
      commentsRepository.listComments({
        tenantId: tenantId.value!,
        entityType: entityType.value,
        entityId: entityId.value!,
      }),
    enabled: computed(
      () =>
        tenantId.value != null
        && tenantId.value > 0
        && entityType.value.trim().length > 0
        && entityId.value != null
        && entityId.value.trim().length > 0,
    ),
    staleTime: 0,
    gcTime: 10 * 60_000,
  });
}
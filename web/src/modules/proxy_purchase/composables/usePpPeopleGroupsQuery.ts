import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { ppPeopleRepository } from '../repositories/ppPeopleRepository';
import { ppPeopleQueryKeys } from '../shared/queryKeys/ppPeopleQueryKeys';
import type { PpPeopleGroupType } from '../types/ppPeople';

export function usePpPeopleGroupsQuery(type: Ref<PpPeopleGroupType>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  return useQuery({
    queryKey: computed(() => ppPeopleQueryKeys.groups(tenantId.value, type.value)),
    queryFn: () => ppPeopleRepository.listGroups(tenantId.value!, type.value),
    enabled: computed(() => tenantId.value != null && tenantId.value > 0),
    staleTime: 0,
    gcTime: 10 * 60_000,
  });
}
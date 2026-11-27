import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { ppPeopleRepository } from '../repositories/ppPeopleRepository';
import { ppPeopleQueryKeys } from '../shared/queryKeys/ppPeopleQueryKeys';

export function usePpPeopleGroupMembersQuery(groupId: Ref<number | null>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  return useQuery({
    queryKey: computed(() => ppPeopleQueryKeys.members(tenantId.value, groupId.value)),
    queryFn: () => ppPeopleRepository.listMembers(tenantId.value!, groupId.value!),
    enabled: computed(
      () => tenantId.value != null && tenantId.value > 0 && groupId.value != null && groupId.value > 0,
    ),
    staleTime: 0,
    gcTime: 10 * 60_000,
  });
}
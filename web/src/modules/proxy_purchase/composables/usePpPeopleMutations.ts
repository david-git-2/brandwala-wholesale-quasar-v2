import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { ppPeopleRepository } from '../repositories/ppPeopleRepository';
import { ppPeopleQueryKeys } from '../shared/queryKeys/ppPeopleQueryKeys';
import type { PpPeopleGroupType, PpPeopleMemberRole } from '../types/ppPeople';

export function usePpPeopleMutations(
  peopleTab: Ref<PpPeopleGroupType>,
  selectedGroupId: Ref<number | null>,
) {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const invalidateGroups = () => {
    void queryClient.invalidateQueries({
      queryKey: ppPeopleQueryKeys.groups(tenantId.value, peopleTab.value),
    });
  };

  const invalidateMembers = () => {
    void queryClient.invalidateQueries({
      queryKey: ppPeopleQueryKeys.members(tenantId.value, selectedGroupId.value),
    });
    invalidateGroups();
  };

  const createGroup = useMutation({
    mutationFn: async (payload: { name: string; type: PpPeopleGroupType }) => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      return ppPeopleRepository.createGroup(tid, payload.name, payload.type);
    },
    onSuccess: () => {
      showSuccessNotification('Group created.');
      invalidateGroups();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not create group.';
      showErrorNotification(message);
    },
  });

  const createMember = useMutation({
    mutationFn: async (payload: {
      name: string;
      email: string;
      role: PpPeopleMemberRole;
    }) => {
      const tid = tenantId.value;
      const gid = selectedGroupId.value;
      if (!tid || !gid) throw new Error('Group not ready.');
      return ppPeopleRepository.createMember({
        tenantId: tid,
        peopleGroupId: gid,
        name: payload.name,
        email: payload.email,
        role: payload.role,
      });
    },
    onSuccess: () => {
      showSuccessNotification('Member added.');
      invalidateMembers();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not add member.';
      showErrorNotification(message);
    },
  });

  return { createGroup, createMember };
}
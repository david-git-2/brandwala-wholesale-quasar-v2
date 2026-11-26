import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { commentsRepository } from '../repositories/commentsRepository';
import { commentsQueryKeys } from '../shared/queryKeys/commentsQueryKeys';

export function useCommentMutations(
  entityType: Ref<string>,
  entityId: Ref<string | null>,
) {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const invalidateList = () => {
    void queryClient.invalidateQueries({
      queryKey: commentsQueryKeys.list(tenantId.value, entityType.value, entityId.value),
    });
  };

  const addComment = useMutation({
    mutationFn: async (body: string) => {
      const tid = tenantId.value;
      const eid = entityId.value;
      if (!tid || !eid?.trim()) throw new Error('Tenant or entity not ready.');
      await commentsRepository.addComment({
        tenantId: tid,
        entityType: entityType.value,
        entityId: eid,
        body,
      });
    },
    onSuccess: () => {
      showSuccessNotification('Comment added.');
      invalidateList();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not add comment.';
      showErrorNotification(message);
    },
  });

  const deleteComment = useMutation({
    mutationFn: async (commentId: number) => {
      const tid = tenantId.value;
      if (!tid) throw new Error('Tenant not ready.');
      await commentsRepository.softDeleteComment({ tenantId: tid, commentId });
    },
    onSuccess: () => {
      showSuccessNotification('Comment removed.');
      invalidateList();
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not remove comment.';
      showErrorNotification(message);
    },
  });

  return { addComment, deleteComment };
}
<script setup lang="ts">
import { date } from 'quasar';
import { computed, ref, toRef } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { useCommentMutations } from '../composables/useCommentMutations';
import { useCommentsQuery } from '../composables/useCommentsQuery';

const props = withDefaults(
  defineProps<{
    entityType: string;
    entityId: string;
    readonly?: boolean;
    emptyLabel?: string;
  }>(),
  {
    readonly: false,
    emptyLabel: 'No comments yet.',
  },
);

const authStore = useAuthStore();
const entityType = toRef(props, 'entityType');
const entityId = toRef(props, 'entityId');

const draft = ref('');
const { data: comments, isPending, isError } = useCommentsQuery(entityType, entityId);
const { addComment, deleteComment } = useCommentMutations(entityType, entityId);

const currentEmail = computed(() => (authStore.user?.email ?? '').trim().toLowerCase());

const canSubmit = computed(
  () =>
    !props.readonly
    && draft.value.trim().length > 0
    && !addComment.isPending.value,
);

const formatCreatedAt = (value: string) => date.formatDate(value, 'D MMM YYYY, HH:mm');

const submit = async () => {
  const body = draft.value.trim();
  if (!body) return;
  await addComment.mutateAsync(body);
  draft.value = '';
};

const remove = (commentId: number) => {
  void deleteComment.mutateAsync(commentId);
};

const isAuthor = (createdBy: string) =>
  createdBy.trim().toLowerCase() === currentEmail.value;
</script>

<template>
  <div class="comment-panel">
    <div class="text-subtitle2 text-weight-medium q-mb-sm">
      Comments
    </div>

    <div v-if="isPending" class="text-caption text-grey-7 q-py-sm">
      Loading comments…
    </div>
    <div v-else-if="isError" class="text-caption text-negative q-py-sm">
      Could not load comments.
    </div>
    <div
      v-else-if="!comments?.length"
      class="text-caption text-grey-7 q-py-sm"
    >
      {{ emptyLabel }}
    </div>

    <ul v-else class="comment-panel__list q-gutter-y-sm q-mt-sm q-pl-none">
      <li
        v-for="comment in comments"
        :key="comment.id"
        class="comment-panel__item"
      >
        <div class="row items-center justify-between no-wrap">
          <p class="text-caption text-grey-7 q-ma-none">
            <span class="text-weight-medium text-grey-8">{{ comment.created_by }}</span>
            · {{ formatCreatedAt(comment.created_at) }}
          </p>
          <q-btn
            v-if="!readonly && isAuthor(comment.created_by)"
            flat
            dense
            round
            icon="delete_outline"
            color="grey-7"
            size="sm"
            :loading="deleteComment.isPending.value"
            aria-label="Delete comment"
            @click="remove(comment.id)"
          />
        </div>
        <p class="text-body2 q-ma-none q-mt-xs text-grey-9 comment-panel__body">
          {{ comment.body }}
        </p>
      </li>
    </ul>

    <div v-if="!readonly" class="q-mt-md">
      <q-input
        v-model="draft"
        type="textarea"
        autogrow
        outlined
        dense
        label="Add a comment"
        :disable="addComment.isPending.value"
        @keyup.ctrl.enter="submit"
      />
      <div class="row justify-end q-mt-sm">
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Post"
          :disable="!canSubmit"
          :loading="addComment.isPending.value"
          @click="submit"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.comment-panel__list {
  list-style: none;
  margin: 0;
}

.comment-panel__item {
  padding-bottom: 0.5rem;
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
}

.body--dark .comment-panel__item {
  border-bottom-color: rgba(255, 255, 255, 0.08);
}

.comment-panel__body {
  white-space: pre-wrap;
}
</style>
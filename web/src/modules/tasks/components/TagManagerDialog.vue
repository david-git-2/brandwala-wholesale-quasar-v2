<template>
  <q-dialog v-model="isOpen" backdrop-filter="blur(4px)">
    <q-card class="tag-card floating-surface shadow-2">
      <q-card-section class="q-py-md row items-center justify-between border-bottom">
        <div class="row items-center q-gutter-sm">
          <q-icon name="local_offer" size="24px" color="primary" />
          <div class="text-h6 text-weight-bold">Manage Tags</div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pb-none">
        <div class="text-subtitle2 text-weight-bold q-mb-xs">{{ editingTagId !== null ? 'Edit Tag' : 'Create New Tag' }}</div>
        <q-form @submit.prevent="onCreateOrUpdateTag" class="row q-col-gutter-sm items-center">
          <div class="col-12 col-sm-4">
            <q-input
              v-model="newTag.name"
              label="Tag Name"
              outlined
              dense
              hide-bottom-space
              :rules="[val => !!val || 'Required']"
              @update:model-value="onNameChange"
            />
          </div>
          <div class="col-12 col-sm-3">
            <q-select
              v-model="newTag.type"
              :options="tagTypeOptions"
              label="Tag Type"
              outlined
              dense
              emit-value
              map-options
            />
          </div>
          <div class="col-12 col-sm-3">
            <q-input
              v-model="newTag.color"
              label="Color"
              outlined
              dense
              class="color-input"
            >
              <template #append>
                <q-icon name="colorize" class="cursor-pointer" color="grey-8">
                  <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                    <q-color v-model="newTag.color" />
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-2 text-right row justify-end items-center q-gutter-x-xs no-wrap">
            <q-btn
              v-if="editingTagId !== null"
              flat
              round
              dense
              color="grey-7"
              icon="close"
              @click="cancelEdit"
            >
              <q-tooltip>Cancel Edit</q-tooltip>
            </q-btn>
            <q-btn
              type="submit"
              :color="editingTagId !== null ? 'secondary' : 'primary'"
              :icon="editingTagId !== null ? 'check' : 'add'"
              unelevated
              round
              dense
            >
              <q-tooltip>{{ editingTagId !== null ? 'Save Changes' : 'Create Tag' }}</q-tooltip>
            </q-btn>
          </div>

          <!-- Global Tag Toggle -->
          <div class="col-12 q-mt-xs">
            <q-checkbox
              v-model="newTag.isGlobal"
              label="Global Tag (Share this tag across all my tenants)"
              dense
              color="primary"
            />
          </div>
        </q-form>
      </q-card-section>

      <q-card-section class="scroll-area">
        <div class="text-subtitle2 text-weight-bold q-mb-sm">Existing Tags</div>
        <q-list separator v-if="tags.length">
          <q-item v-for="tag in tags" :key="tag.id" class="q-py-sm">
            <q-item-section avatar>
              <q-chip
                dense
                square
                text-color="white"
                :style="{ backgroundColor: tag.color || '#6366f1' }"
                class="text-weight-bold square-chip"
              >
                {{ tag.name }}
              </q-chip>
            </q-item-section>

            <q-item-section>
              <div class="row items-center q-gutter-x-sm wrap">
                <q-item-label caption>Type: {{ tag.type }}</q-item-label>
                <q-item-label caption class="text-grey-4">•</q-item-label>
                <q-item-label caption>Slug: {{ tag.slug }}</q-item-label>
                <q-item-label caption class="text-grey-4">•</q-item-label>
                <q-badge
                  :color="tag.tenant_id === null ? 'accent' : 'grey-7'"
                  :label="tag.tenant_id === null ? 'Global' : 'Private'"
                  dense
                  class="q-px-sm"
                />
              </div>
            </q-item-section>

            <q-item-section side>
              <div class="row items-center q-gutter-x-xs">
                <q-btn
                  flat
                  round
                  dense
                  color="primary"
                  icon="edit"
                  size="sm"
                  @click="onEditTag(tag)"
                >
                  <q-tooltip>Edit Tag</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  round
                  dense
                  color="negative"
                  icon="o_delete"
                  size="sm"
                  @click="onDeleteTag(tag.id)"
                >
                  <q-tooltip>Delete Tag</q-tooltip>
                </q-btn>
              </div>
            </q-item-section>
          </q-item>
        </q-list>

        <div v-else class="text-center q-pa-xl text-grey-5">
          <q-icon name="info" size="36px" class="q-mb-xs" />
          <div>No custom tags created yet. Create your first tag above!</div>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useTasksStore } from '../stores/tasksStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { requestConfirmation } from 'src/utils/appFeedback';
import type { Tag } from '../types';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const tasksStore = useTasksStore();
const authStore = useAuthStore();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const tags = computed(() => tasksStore.tags);

const tagTypeOptions = [
  { label: 'General', value: 'general' },
  { label: 'Department', value: 'department' },
  { label: 'Client', value: 'client' },
  { label: 'Sprint', value: 'sprint' },
  { label: 'Topic', value: 'topic' },
  { label: 'Technology', value: 'technology' },
];

const newTag = ref({
  name: '',
  slug: '',
  color: '#6366f1',
  type: 'general',
  isGlobal: false,
});

const onNameChange = (val: string | number | null) => {
  newTag.value.slug = String(val || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-');
};

const editingTagId = ref<number | null>(null);

const onEditTag = (tag: Tag) => {
  editingTagId.value = tag.id;
  newTag.value = {
    name: tag.name,
    slug: tag.slug,
    color: tag.color || '#6366f1',
    type: tag.type || 'general',
    isGlobal: tag.tenant_id === null,
  };
};

const cancelEdit = () => {
  editingTagId.value = null;
  newTag.value = {
    name: '',
    slug: '',
    color: '#6366f1',
    type: 'general',
    isGlobal: false,
  };
};

const onCreateOrUpdateTag = async () => {
  if (editingTagId.value !== null) {
    try {
      await tasksStore.updateTag(editingTagId.value, {
        name: newTag.value.name,
        slug: newTag.value.slug,
        color: newTag.value.color,
        type: newTag.value.type,
        tenant_id: newTag.value.isGlobal ? null : authStore.tenantId,
      });
      cancelEdit();
    } catch (err) {
      console.error('Failed to update tag', err);
    }
  } else {
    try {
      await tasksStore.createTag({
        tenant_id: newTag.value.isGlobal ? null : authStore.tenantId,
        name: newTag.value.name,
        slug: newTag.value.slug,
        color: newTag.value.color,
        type: newTag.value.type,
      });
      // Reset Form
      newTag.value = {
        name: '',
        slug: '',
        color: '#6366f1',
        type: 'general',
        isGlobal: false,
      };
    } catch (err) {
      console.error('Failed to create tag', err);
    }
  }
};

const onDeleteTag = async (tagId: number) => {
  if (editingTagId.value === tagId) {
    cancelEdit();
  }

  const confirmed = await requestConfirmation(
    'Are you sure you want to delete this tag? It will be removed from all tasks.',
    'Delete Tag',
    'Delete',
  );

  if (confirmed) {
    try {
      await tasksStore.deleteTag(tagId);
    } catch (err) {
      console.error('Failed to delete tag', err);
    }
  }
};
</script>

<style scoped>
.tag-card {
  width: 90vw;
  max-width: 550px;
  background: #ffffff;
  border-radius: 14px;
}

.scroll-area {
  max-height: 350px;
  overflow-y: auto;
  padding-bottom: 12px;
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
</style>


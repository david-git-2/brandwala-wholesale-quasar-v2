<template>
  <q-dialog v-model="isOpen" backdrop-filter="blur(4px)">
    <q-card class="search-card floating-surface shadow-2">
      <q-card-section class="q-py-md row items-center justify-between">
        <div class="row items-center q-gutter-sm">
          <q-icon name="search" size="24px" color="primary" />
          <div class="text-h6 text-weight-bold">Search Tasks Cross-Tenants</div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-none">
        <q-input
          v-model="searchQuery"
          placeholder="Type to search title, description, tags, comments..."
          outlined
          dense
          autofocus
          class="search-input"
          @update:model-value="onSearchInput"
        >
          <template #append>
            <q-spinner v-if="searchLoading" size="20px" color="primary" />
          </template>
        </q-input>
      </q-card-section>

      <q-card-section class="q-py-none scroll-area">
        <q-list separator v-if="searchResults.length">
          <q-item
            v-for="item in searchResults"
            :key="item.id"
            clickable
            v-close-popup
            @click="onSelectResult(item)"
            class="search-result-item"
          >
            <q-item-section avatar>
              <q-avatar :color="getTypeColor(item.type)" text-color="white" size="36px">
                <q-icon :name="getTypeIcon(item.type)" size="20px" />
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <q-item-label class="text-subtitle2 text-weight-bold">
                {{ item.title }}
              </q-item-label>
              <q-item-label caption class="ellipsis-2-lines text-grey-7">
                {{ item.content || 'No description' }}
              </q-item-label>
              <div class="row items-center q-gutter-xs q-mt-xs">
                <q-chip dense square color="blue-1" text-color="blue-8" class="text-overline">
                  {{ item.type }}
                </q-chip>
                <q-chip dense square color="amber-1" text-color="amber-9" class="text-overline">
                  {{ item.status }}
                </q-chip>
                <q-chip v-if="item.tenant_name" dense square color="purple-1" text-color="purple-8" class="text-overline">
                  Tenant: {{ item.tenant_name }}
                </q-chip>
              </div>
            </q-item-section>
          </q-item>
        </q-list>

        <div v-else-if="searchQuery.trim()" class="text-center q-pa-xl text-grey-6">
          <q-icon name="info" size="36px" class="q-mb-xs" />
          <div>No tasks found matching your search.</div>
        </div>

        <div v-else class="text-center q-pa-xl text-grey-5">
          <q-icon name="manage_search" size="48px" class="q-mb-sm" />
          <div>Search for tickets, notes, bugs, and discussions across all workspaces you belong to.</div>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>

  <!-- Open details modal directly if a search result is clicked -->
  <TaskDetailsDialog
    v-model="detailsOpen"
    v-model:item-id="selectedItemId"
    @updated="onTaskUpdated"
  />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useTasksStore } from '../stores/tasksStore';
import type { GlobalSearchResult } from '../types';
import TaskDetailsDialog from './TaskDetailsDialog.vue';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'select-task', itemId: number, tenantId: number | null): void;
}>();

const tasksStore = useTasksStore();
const searchQuery = ref('');
const detailsOpen = ref(false);
const selectedItemId = ref<number | null>(null);

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const searchResults = computed(() => tasksStore.searchResults);
const searchLoading = computed(() => tasksStore.searchLoading);

let debounceTimer: ReturnType<typeof setTimeout> | null = null;
const onSearchInput = (val: string | number | null) => {
  if (debounceTimer) clearTimeout(debounceTimer);
  const q = String(val || '');
  debounceTimer = setTimeout(() => {
    void tasksStore.runGlobalSearch(q);
  }, 350);
};

const onSelectResult = (item: GlobalSearchResult) => {
  selectedItemId.value = item.id;
  detailsOpen.value = true;
  emit('select-task', item.id, item.tenant_id);
};

const onTaskUpdated = () => {
  // Re-run search if active query exists
  if (searchQuery.value) {
    void tasksStore.runGlobalSearch(searchQuery.value);
  }
};

const getTypeIcon = (type: string) => {
  switch (type) {
    case 'project': return 'folder';
    case 'module': return 'view_module';
    case 'submodule': return 'layers';
    case 'task': return 'assignment';
    case 'note': return 'note';
    case 'discussion': return 'forum';
    case 'bug': return 'bug_report';
    case 'feature': return 'star';
    default: return 'help_outline';
  }
};

const getTypeColor = (type: string) => {
  switch (type) {
    case 'project': return 'indigo';
    case 'module': return 'blue';
    case 'submodule': return 'cyan';
    case 'task': return 'green';
    case 'note': return 'orange';
    case 'discussion': return 'teal';
    case 'bug': return 'red';
    case 'feature': return 'purple';
    default: return 'grey';
  }
};
</script>

<style scoped>
.search-card {
  width: 90vw;
  max-width: 650px;
  background: rgba(255, 255, 255, 0.94);
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(10px);
}

.search-input {
  border-radius: 8px;
}

.scroll-area {
  max-height: 400px;
  overflow-y: auto;
  padding-bottom: 12px;
}

.search-result-item {
  border-radius: 8px;
  margin: 4px 8px;
  transition: background 0.15s ease;
}

.search-result-item:hover {
  background: rgba(37, 99, 235, 0.05);
}
</style>

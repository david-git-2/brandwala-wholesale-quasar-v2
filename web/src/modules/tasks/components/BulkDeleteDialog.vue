<template>
  <q-dialog v-model="isOpen" backdrop-filter="blur(4px)" persistent>
    <q-card class="bulk-delete-card floating-surface shadow-2">
      <!-- Header -->
      <q-card-section class="q-py-md row items-center justify-between border-bottom">
        <div class="row items-center q-gutter-sm">
          <q-icon name="delete_sweep" size="28px" color="negative" />
          <div>
            <div class="text-h6 text-weight-bold text-grey-9">Bulk Delete Items</div>
            <div class="text-caption text-grey-6">Filter, select, and delete multiple items at once</div>
          </div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <!-- Filters Section -->
      <q-card-section class="q-pb-sm q-pt-md">
        <div class="row q-col-gutter-sm">
          <!-- Text Search -->
          <div class="col-12 col-sm-4">
            <q-input
              v-model="filters.search"
              placeholder="Search title or content..."
              outlined
              dense
              clearable
              class="soft-input"
            >
              <template #prepend>
                <q-icon name="search" size="18px" />
              </template>
            </q-input>
          </div>

          <!-- Type Select -->
          <div class="col-6 col-sm-2">
            <q-select
              v-model="filters.type"
              :options="typeFilterOptions"
              label="Type"
              outlined
              dense
              clearable
              emit-value
              map-options
              class="soft-input"
            />
          </div>

          <!-- Status Select -->
          <div class="col-6 col-sm-2">
            <q-select
              v-model="filters.status"
              :options="statusFilterOptions"
              label="Status"
              outlined
              dense
              clearable
              emit-value
              map-options
              class="soft-input"
            />
          </div>

          <!-- Priority Select -->
          <div class="col-6 col-sm-2">
            <q-select
              v-model="filters.priority"
              :options="priorityFilterOptions"
              label="Priority"
              outlined
              dense
              clearable
              emit-value
              map-options
              class="soft-input"
            />
          </div>

          <!-- Tag Select -->
          <div class="col-6 col-sm-2">
            <q-select
              v-model="filters.tagId"
              :options="tagFilterOptions"
              label="Tag"
              outlined
              dense
              clearable
              emit-value
              map-options
              class="soft-input"
            />
          </div>
        </div>

        <div class="row justify-between items-center q-mt-sm">
          <div class="text-caption text-grey-6">
            Matching Items: <span class="text-weight-bold">{{ matchingItems.length }}</span>
          </div>
          <q-btn flat no-caps dense label="Reset Filters" color="primary" @click="resetFilters" />
        </div>
      </q-card-section>

      <!-- Table Section -->
      <q-card-section class="q-py-none table-section scroll">
        <q-table
          :rows="matchingItems"
          :columns="columns"
          row-key="id"
          selection="multiple"
          v-model:selected="selected"
          flat
          bordered
          dense
          :loading="loadingItems"
          :pagination="{ rowsPerPage: 50 }"
          class="bulk-delete-table"
        >
          <!-- ID Column -->
          <template #body-cell-id="cellProps">
            <q-td :props="cellProps">
              <span v-if="cellProps.row.type === 'task'" class="text-primary text-weight-bold">#{{ cellProps.value }}</span>
              <span v-else class="text-grey-7">#{{ cellProps.value }}</span>
            </q-td>
          </template>

          <!-- Title Column -->
          <template #body-cell-title="cellProps">
            <q-td :props="cellProps" class="text-weight-medium">
              {{ cellProps.value }}
            </q-td>
          </template>

          <!-- Type Column -->
          <template #body-cell-type="cellProps">
            <q-td :props="cellProps">
              <q-chip
                square
                dense
                :style="typeChipStyle(cellProps.value)"
                class="status-chip text-weight-bold text-uppercase"
              >
                {{ cellProps.value }}
              </q-chip>
            </q-td>
          </template>

          <!-- Status Column -->
          <template #body-cell-status="cellProps">
            <q-td :props="cellProps">
              <q-chip
                square
                dense
                :style="statusChipStyle(cellProps.value)"
                class="status-chip text-weight-bold text-uppercase"
              >
                {{ cellProps.value }}
              </q-chip>
            </q-td>
          </template>

          <!-- Priority Column -->
          <template #body-cell-priority="cellProps">
            <q-td :props="cellProps">
              <q-chip
                square
                dense
                :style="priorityChipStyle(cellProps.value)"
                class="status-chip text-weight-bold text-uppercase"
              >
                {{ cellProps.value }}
              </q-chip>
            </q-td>
          </template>
        </q-table>
      </q-card-section>

      <!-- Footer/Actions -->
      <q-card-section class="q-py-md row items-center justify-between border-top">
        <div>
          <span class="text-subtitle2 text-grey-8">Selected: </span>
          <span class="text-subtitle1 text-weight-bold text-negative">{{ selected.length }}</span>
        </div>
        <div class="row q-gutter-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            no-caps
            label="Delete Selected"
            icon="delete"
            :disable="selected.length === 0"
            :loading="deleting"
            @click="confirmDelete"
          />
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useTasksStore } from '../stores/tasksStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { tasksRepository } from '../repositories/tasksRepository';
import type { Item } from '../types';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'deleted'): void;
}>();

const $q = useQuasar();
const tasksStore = useTasksStore();
const authStore = useAuthStore();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const filters = ref({
  search: '',
  type: null as string | null,
  status: null as string | null,
  priority: null as string | null,
  tagId: null as number | null,
});

const matchingItems = ref<Item[]>([]);
const selected = ref<Item[]>([]);
const loadingItems = ref(false);
const deleting = ref(false);

const columns = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' as const, sortable: true },
  { name: 'title', label: 'Title', field: 'title', align: 'left' as const, sortable: true },
  { name: 'type', label: 'Type', field: 'type', align: 'left' as const, sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const, sortable: true },
  { name: 'priority', label: 'Priority', field: 'priority', align: 'left' as const, sortable: true },
];

const typeFilterOptions = [
  { label: 'Project', value: 'project' },
  { label: 'Module', value: 'module' },
  { label: 'Submodule', value: 'submodule' },
  { label: 'Task / Ticket', value: 'task' },
  { label: 'Feature Request', value: 'feature' },
  { label: 'Bug Report', value: 'bug' },
  { label: 'Note', value: 'note' },
  { label: 'Discussion', value: 'discussion' },
];

const statusFilterOptions = [
  { label: 'Todo', value: 'todo' },
  { label: 'In Progress', value: 'in_progress' },
  { label: 'Review', value: 'review' },
  { label: 'Done', value: 'done' },
  { label: 'Blocked', value: 'blocked' },
  { label: 'Archived', value: 'archived' },
];

const priorityFilterOptions = [
  { label: 'Low', value: 'low' },
  { label: 'Medium', value: 'medium' },
  { label: 'High', value: 'high' },
  { label: 'Urgent', value: 'urgent' },
];

const tagFilterOptions = computed(() =>
  tasksStore.tags.map((t) => ({ label: t.name, value: t.id }))
);

const typeChipStyle = (type: string) => {
  switch (type) {
    case 'project':
      return { backgroundColor: '#f5f3ff', color: '#7c3aed', border: '1px solid #ddd6fe' };
    case 'module':
      return { backgroundColor: '#ecfdf5', color: '#059669', border: '1px solid #a7f3d0' };
    case 'submodule':
      return { backgroundColor: '#ecfeff', color: '#0891b2', border: '1px solid #c5f6fa' };
    case 'task':
      return { backgroundColor: '#eff6ff', color: '#2563eb', border: '1px solid #bfdbfe' };
    case 'note':
      return { backgroundColor: '#fffbeb', color: '#d97706', border: '1px solid #fde68a' };
    case 'discussion':
      return { backgroundColor: '#f0fdfa', color: '#0d9488', border: '1px solid #ccfbf1' };
    case 'bug':
      return { backgroundColor: '#fef2f2', color: '#dc2626', border: '1px solid #fecaca' };
    case 'feature':
      return { backgroundColor: '#fdf2f8', color: '#db2777', border: '1px solid #fbcfe8' };
    default:
      return { backgroundColor: '#f4f4f5', color: '#71717a', border: '1px solid #e4e4e7' };
  }
};

const statusChipStyle = (status: string) => {
  switch (status) {
    case 'todo':
      return { backgroundColor: '#eff6ff', color: '#2563eb', border: '1px solid #bfdbfe' };
    case 'in_progress':
      return { backgroundColor: '#fffbeb', color: '#d97706', border: '1px solid #fde68a' };
    case 'review':
      return { backgroundColor: '#f5f3ff', color: '#7c3aed', border: '1px solid #ddd6fe' };
    case 'done':
      return { backgroundColor: '#f0fdf4', color: '#16a34a', border: '1px solid #bbf7d0' };
    case 'blocked':
      return { backgroundColor: '#fef2f2', color: '#dc2626', border: '1px solid #fecaca' };
    case 'archived':
      return { backgroundColor: '#f4f4f5', color: '#71717a', border: '1px solid #e4e4e7' };
    default:
      return { backgroundColor: '#f4f4f5', color: '#71717a', border: '1px solid #e4e4e7' };
  }
};

const priorityChipStyle = (priority: string) => {
  switch (priority) {
    case 'low':
      return { backgroundColor: '#f0fdf4', color: '#16a34a', border: '1px solid #bbf7d0' };
    case 'medium':
      return { backgroundColor: '#eff6ff', color: '#2563eb', border: '1px solid #bfdbfe' };
    case 'high':
      return { backgroundColor: '#fff7ed', color: '#ea580c', border: '1px solid #fed7aa' };
    case 'urgent':
      return { backgroundColor: '#fef2f2', color: '#dc2626', border: '1px solid #fecaca' };
    default:
      return { backgroundColor: '#f4f4f5', color: '#71717a', border: '1px solid #e4e4e7' };
  }
};

const fetchMatchingItems = async () => {
  loadingItems.value = true;
  try {
    const result = await tasksRepository.fetchItems(
      authStore.tenantId,
      {
        search: filters.value.search,
        type: filters.value.type,
        status: filters.value.status,
        priority: filters.value.priority,
        tagId: filters.value.tagId,
        includeParents: false,
      },
      1,
      1000
    );
    matchingItems.value = result.data;
  } catch (err: unknown) {
    console.error('Failed to fetch items for bulk delete:', err);
    $q.notify({
      type: 'negative',
      message: 'Failed to fetch items matching filters.',
    });
  } finally {
    loadingItems.value = false;
  }
};

let debounceTimer: ReturnType<typeof setTimeout> | null = null;
const debouncedFetch = () => {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    void fetchMatchingItems();
  }, 300);
};

watch(
  filters,
  () => {
    debouncedFetch();
  },
  { deep: true }
);

watch(isOpen, (newVal) => {
  if (newVal) {
    selected.value = [];
    resetFilters();
    void fetchMatchingItems();
  }
});

const resetFilters = () => {
  filters.value = {
    search: '',
    type: null,
    status: null,
    priority: null,
    tagId: null,
  };
};

const executeBulkDelete = async () => {
  const count = selected.value.length;
  deleting.value = true;
  try {
    const ids = selected.value.map((item) => item.id);
    await tasksStore.deleteItemsBulk(ids);
    $q.notify({
      type: 'positive',
      message: `Successfully deleted ${count} item(s) and their descendants.`,
    });
    selected.value = [];
    emit('deleted');
    isOpen.value = false;
  } catch (err: unknown) {
    console.error(err);
    $q.notify({
      type: 'negative',
      message: 'Failed to bulk delete selected items.',
    });
  } finally {
    deleting.value = false;
  }
};

const confirmDelete = () => {
  const count = selected.value.length;
  $q.dialog({
    title: 'Confirm Bulk Deletion',
    message: `Are you sure you want to delete ${count} selected item(s)? This action is permanent and will cascade delete all descendant items.`,
    cancel: true,
    persistent: true,
    ok: {
      color: 'negative',
      label: 'Yes, Delete',
      flat: false,
    },
  }).onOk(() => {
    void executeBulkDelete();
  });
};

onMounted(() => {
  if (isOpen.value) {
    void fetchMatchingItems();
  }
});
</script>

<style scoped>
.bulk-delete-card {
  width: 95vw;
  max-width: 900px;
  background: rgba(255, 255, 255, 0.94);
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(10px);
}

.table-section {
  max-height: 450px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.82);
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}
</style>

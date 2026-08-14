<template>
  <q-page class="q-pa-md thrift-courier-page">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift Sales</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Courier Providers</h1>
          <div class="text-caption text-grey-7 q-mt-xs">
            System couriers are read-only. Add custom couriers for your shop Online sales.
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            v-if="canManage"
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Add Courier"
            @click="openDialog()"
          />
        </div>
      </section>

      <q-tabs
        v-model="tab"
        dense
        align="left"
        class="text-primary"
        active-color="primary"
        narrow-indicator
      >
        <q-tab name="all" label="All" no-caps />
        <q-tab name="system" label="System" no-caps />
        <q-tab name="custom" label="My Couriers" no-caps />
      </q-tabs>

      <div v-if="isLoading" class="row q-col-gutter-md">
        <div v-for="n in 6" :key="n" class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="rounded-borders">
            <q-card-section>
              <q-skeleton type="text" width="60%" />
              <q-skeleton type="text" width="40%" class="q-mt-sm" />
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div
        v-else-if="filteredRows.length === 0"
        class="q-pa-xl text-center text-grey-6 bg-grey-1 rounded-borders"
      >
        No couriers in this list.
      </div>

      <div v-else class="row q-col-gutter-md">
        <div
          v-for="row in filteredRows"
          :key="row.id"
          class="col-12 col-sm-6 col-md-4"
        >
          <q-card flat bordered class="rounded-borders courier-card full-height">
            <q-card-section class="row items-start justify-between q-pb-none">
              <div class="col">
                <div class="text-subtitle1 text-weight-bold">{{ row.name }}</div>
                <div class="text-caption text-grey-7">{{ row.code }}</div>
              </div>
              <div class="col-auto q-gutter-xs">
                <q-badge
                  :color="row.isSystem ? 'grey-7' : 'primary'"
                  :label="row.isSystem ? 'System' : 'Custom'"
                  outline
                />
                <q-badge
                  :color="row.isActive ? 'positive' : 'grey-5'"
                  :label="row.isActive ? 'Active' : 'Inactive'"
                />
              </div>
            </q-card-section>

            <q-card-section v-if="notesOf(row)" class="q-pt-sm text-body2 text-grey-8">
              {{ notesOf(row) }}
            </q-card-section>

            <q-card-actions v-if="!row.isSystem && canManage" align="right">
              <q-btn
                flat
                dense
                no-caps
                color="warning"
                icon="ph ph-pencil-simple"
                label="Edit"
                @click="openDialog(row)"
              />
              <q-btn
                flat
                dense
                no-caps
                color="negative"
                icon="ph ph-trash"
                label="Delete"
                @click="confirmDelete(row)"
              />
            </q-card-actions>
            <q-card-section v-else-if="row.isSystem" class="q-pt-none">
              <div class="text-caption text-grey-6">Locked — system catalog</div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>

    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 420px; max-width: 95vw" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">
            {{ editingId ? 'Edit Courier' : 'New Courier' }}
          </div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-pt-md q-gutter-md">
          <q-input v-model="form.name" outlined dense label="Name *" autofocus />
          <q-input
            v-model="form.code"
            outlined
            dense
            label="Code"
            hint="Optional slug; auto from name if empty"
          />
          <q-input
            v-model="form.notes"
            outlined
            dense
            type="textarea"
            autogrow
            label="Notes (optional)"
            hint="Stored in meta.notes"
          />
          <q-toggle v-model="form.isActive" label="Active (shown in Online create)" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            unelevated
            no-caps
            color="primary"
            :label="editingId ? 'Save' : 'Create'"
            :loading="saving"
            @click="save"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import { formatThriftActionableError } from 'src/modules/thrift/shared/utils/formatThriftActionableError';
import {
  useThriftCourierManageQuery,
  useThriftCourierMutations,
} from '../composables/useThriftCourierQuery';
import type { ThriftCourierProvider } from '../repositories/thriftCourierRepository';

const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const { hasModuleAccess } = useModulePermissions();

const canManage = computed(
  () =>
    hasModuleAccess('thrift_sales', 'create') ||
    hasModuleAccess('thrift_sales', 'edit') ||
    hasModuleAccess('thrift_settings', 'edit'),
);

const tab = ref<'all' | 'system' | 'custom'>('all');
const { data, isFetching: isLoading } = useThriftCourierManageQuery(tenantId);
const { createMutation, updateMutation, deleteMutation } = useThriftCourierMutations(tenantId);

const rows = computed(() => data.value ?? []);
const filteredRows = computed(() => {
  if (tab.value === 'system') return rows.value.filter((r) => r.isSystem);
  if (tab.value === 'custom') return rows.value.filter((r) => !r.isSystem);
  return rows.value;
});

function notesOf(row: ThriftCourierProvider): string {
  return typeof row.meta?.notes === 'string' ? row.meta.notes : '';
}

/** Next sort_order for a new custom courier (append after existing customs). */
function nextCustomSortOrder(): number {
  const customs = rows.value.filter((r) => !r.isSystem);
  if (customs.length === 0) return 200;
  const max = Math.max(...customs.map((r) => r.sortOrder || 0));
  return max + 10;
}

const dialogOpen = ref(false);
const editingId = ref<number | null>(null);
const saving = ref(false);
const form = ref({
  name: '',
  code: '',
  isActive: true,
  notes: '',
});

function openDialog(row?: ThriftCourierProvider) {
  if (row?.isSystem) return;
  editingId.value = row?.id ?? null;
  form.value = {
    name: row?.name ?? '',
    code: row?.code ?? '',
    isActive: row?.isActive ?? true,
    notes: notesOf(row ?? ({ meta: {} } as ThriftCourierProvider)),
  };
  dialogOpen.value = true;
}

async function save() {
  if (!form.value.name.trim()) {
    showErrorNotification('Name is required');
    return;
  }
  saving.value = true;
  try {
    const existing = editingId.value
      ? rows.value.find((r) => r.id === editingId.value)
      : undefined;
    const meta: Record<string, any> = {
      ...(existing?.meta ?? {}),
      notes: form.value.notes.trim() || undefined,
    };
    if (!meta.notes) delete meta.notes;

    if (editingId.value) {
      await updateMutation.mutateAsync({
        id: editingId.value,
        input: {
          name: form.value.name,
          code: form.value.code || undefined,
          isActive: form.value.isActive,
          meta,
        },
      });
      showSuccessNotification('Courier updated');
    } else {
      await createMutation.mutateAsync({
        name: form.value.name,
        code: form.value.code || undefined,
        sortOrder: nextCustomSortOrder(),
        isActive: form.value.isActive,
        meta,
      });
      showSuccessNotification('Courier created');
    }
    dialogOpen.value = false;
  } catch (err) {
    showErrorNotification(formatThriftActionableError(err, 'Failed to save courier'));
  } finally {
    saving.value = false;
  }
}

async function confirmDelete(row: ThriftCourierProvider) {
  if (row.isSystem) return;
  const ok = await requestConfirmation(
    `Delete custom courier “${row.name}”? Invoices keep their name snapshot.`,
    'Delete courier?',
    'Delete',
  );
  if (!ok) return;
  try {
    await deleteMutation.mutateAsync(row.id);
    showSuccessNotification('Courier deleted');
  } catch (err) {
    showErrorNotification(formatThriftActionableError(err, 'Failed to delete courier'));
  }
}
</script>

<style scoped>
.courier-card {
  min-height: 120px;
}

.full-height {
  height: 100%;
}
</style>

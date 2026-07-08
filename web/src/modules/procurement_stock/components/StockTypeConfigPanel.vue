<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin" style="width: 700px; max-width: 90vw">
      <q-card-section class="row items-center q-pb-none">
        <div>
          <div class="text-h6 text-primary text-weight-bold">Stock Types Configuration</div>
          <div class="text-caption text-grey-7">
            Manage usability labels and sellable state for inventory batches
          </div>
        </div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md">
        <!-- Error Banner -->
        <q-banner v-if="store.error" class="bg-negative text-white rounded-borders q-mb-md q-py-sm">
          {{ store.error }}
        </q-banner>

        <!-- Form Inline / Top Section for creating/updating -->
        <q-card flat bordered class="q-pa-md q-mb-md bg-grey-1">
          <div class="text-subtitle2 q-mb-md text-weight-bold">
            {{ editingId ? 'Edit Stock Type' : 'Add New Stock Type' }}
          </div>
          <q-form @submit.prevent="onSave" class="row q-col-gutter-sm items-end">
            <div class="col-12 col-sm-5">
              <q-input
                v-model="form.description"
                label="Description *"
                filled
                dense
                :rules="[(val) => !!val || 'Description is required']"
              />
            </div>
            <div class="col-12 col-sm-3">
              <q-input
                v-model.number="form.sort_order"
                type="number"
                label="Sort Order"
                filled
                dense
              />
            </div>
            <div class="col-6 col-sm-2 q-pb-sm">
              <q-checkbox v-model="form.is_sellable" label="Sellable" />
            </div>
            <div class="col-6 col-sm-2 q-pb-sm text-right">
              <q-btn
                type="submit"
                color="primary"
                unelevated
                dense
                :label="editingId ? 'Save' : 'Add'"
                :loading="store.saving"
                no-caps
                class="q-px-md"
              />
              <q-btn
                v-if="editingId"
                flat
                color="grey-8"
                label="Cancel"
                dense
                no-caps
                @click="resetForm"
                class="q-ml-sm"
              />
            </div>
          </q-form>
        </q-card>

        <!-- Stock Types Table -->
        <q-table
          flat
          bordered
          :rows="store.items"
          :columns="columns"
          row-key="id"
          :loading="store.loading"
          :pagination="{ rowsPerPage: 10 }"
        >
          <template #body-cell-parent_tenant_id="props">
            <q-td :props="props">
              <q-chip
                dense
                square
                :color="props.row.parent_tenant_id ? 'blue-1' : 'orange-1'"
                :text-color="props.row.parent_tenant_id ? 'blue-9' : 'orange-9'"
                class="text-weight-bold text-caption"
              >
                {{ props.row.parent_tenant_id ? 'Custom' : 'System' }}
              </q-chip>
            </q-td>
          </template>

          <template #body-cell-is_sellable="props">
            <q-td :props="props">
              <q-icon
                :name="props.row.is_sellable ? 'check_circle' : 'cancel'"
                :color="props.row.is_sellable ? 'positive' : 'negative'"
                size="20px"
              />
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" align="right">
              <template v-if="props.row.parent_tenant_id !== null">
                <q-btn
                  flat
                  round
                  dense
                  color="primary"
                  icon="edit"
                  @click="onStartEdit(props.row)"
                />
                <q-btn
                  flat
                  round
                  dense
                  color="negative"
                  icon="delete"
                  @click="onDelete(props.row.id)"
                />
              </template>
              <template v-else>
                <span class="text-caption text-grey-6 italic q-pr-sm">Protected</span>
              </template>
            </q-td>
          </template>
        </q-table>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1">
        <q-btn flat label="Close" color="primary" v-close-popup no-caps />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useDialogPluginComponent, useQuasar, type QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalStockTypeStore } from '../stores/globalStockTypeStore';
import type { GlobalStockType } from '../repositories/globalStockTypeRepository';

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide } = useDialogPluginComponent();

const $q = useQuasar();
const authStore = useAuthStore();
const store = useGlobalStockTypeStore();

const columns: QTableColumn[] = [
  {
    name: 'description',
    label: 'Description',
    field: 'description',
    align: 'left',
    sortable: true,
  },
  {
    name: 'parent_tenant_id',
    label: 'Scope',
    field: 'parent_tenant_id',
    align: 'left',
    sortable: true,
  },
  { name: 'is_sellable', label: 'Sellable', field: 'is_sellable', align: 'center', sortable: true },
  { name: 'sort_order', label: 'Sort Order', field: 'sort_order', align: 'center', sortable: true },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
];

const form = ref({
  description: '',
  is_sellable: true,
  sort_order: 10,
});

const editingId = ref<number | null>(null);

const resetForm = () => {
  form.value = {
    description: '',
    is_sellable: true,
    sort_order: 10,
  };
  editingId.value = null;
};

const loadTypes = () => {
  void store.fetchStockTypes(authStore.tenantId);
};

onMounted(() => {
  loadTypes();
});

const onStartEdit = (row: GlobalStockType) => {
  editingId.value = row.id;
  form.value = {
    description: row.description,
    is_sellable: row.is_sellable,
    sort_order: row.sort_order,
  };
};

const onSave = async () => {
  try {
    if (editingId.value) {
      await store.updateStockType(editingId.value, form.value);
      $q.notify({ type: 'positive', message: 'Stock type updated successfully' });
    } else {
      await store.createStockType(authStore.tenantId, form.value);
      $q.notify({ type: 'positive', message: 'Stock type created successfully' });
    }
    resetForm();
  } catch {
    // Error is set in store and rendered on screen
  }
};

const onDelete = (id: number) => {
  $q.dialog({
    title: 'Confirm Deletion',
    message:
      'Are you sure you want to delete this custom stock type? This action cannot be undone.',
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      try {
        await store.deleteStockType(id);
        $q.notify({ type: 'positive', message: 'Stock type deleted successfully' });
        resetForm();
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        $q.notify({ type: 'negative', message: msg || 'Failed to delete stock type' });
      }
    })();
  });
};
</script>

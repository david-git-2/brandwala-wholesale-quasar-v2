<template>
  <ReferenceCatalogPage
    title="Payment Methods"
    description="Bangladesh and international payment methods. System rows are protected."
    entity-label="Payment Method"
    :columns="columns"
    :rows="items"
    :loading="loading"
    :error="error"
    @add="openCreate"
    @edit="(row) => openEdit(row as PaymentMethod)"
    @delete="(row) => openDelete(row as PaymentMethod)"
  />

  <AddPaymentMethodDialog v-model="dialogOpen" :initial-data="selected" @save="handleSave" />

  <q-dialog v-model="deleteOpen" persistent>
    <q-card style="min-width: 350px">
      <q-card-section><div class="text-h6">Confirm Delete</div></q-card-section>
      <q-card-section
        >Delete <strong>{{ selected?.name }}</strong
        >?</q-card-section
      >
      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="deleteOpen = false" />
        <q-btn color="negative" label="Delete" @click="confirmDelete" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import type { QTableColumn } from 'quasar';
import {
  handleApiFailure,
  showSuccessNotification,
  showWarningDialog,
} from 'src/utils/appFeedback';
import ReferenceCatalogPage from '../components/ReferenceCatalogPage.vue';
import AddPaymentMethodDialog from '../components/AddPaymentMethodDialog.vue';
import { globalReferenceRepository } from '../repositories/globalReferenceRepository';
import type { PaymentMethod, PaymentMethodCreateInput, PaymentMethodUpdateInput } from '../types';

const items = ref<PaymentMethod[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);
const dialogOpen = ref(false);
const deleteOpen = ref(false);
const selected = ref<PaymentMethod | null>(null);

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'category', label: 'Category', field: 'category', align: 'left', sortable: true },
  { name: 'scope', label: 'Scope', field: 'scope', align: 'left', sortable: true },
  { name: 'sort_order', label: 'Order', field: 'sort_order', align: 'left', sortable: true },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'left', sortable: true },
  { name: 'is_system', label: 'Type', field: 'is_system', align: 'left', sortable: true },
  { name: 'actions', label: 'Actions', field: 'id', align: 'right' },
];

const load = async () => {
  loading.value = true;
  error.value = null;
  try {
    items.value = await globalReferenceRepository.listPaymentMethods();
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to load payment methods.';
  } finally {
    loading.value = false;
  }
};

const openCreate = () => {
  selected.value = null;
  dialogOpen.value = true;
};
const openEdit = (row: PaymentMethod) => {
  if (row.is_system) {
    showWarningDialog('System payment methods cannot be edited.', 'Protected row');
    return;
  }
  selected.value = { ...row };
  dialogOpen.value = true;
};
const openDelete = (row: PaymentMethod) => {
  if (row.is_system) {
    showWarningDialog('System payment methods cannot be deleted.', 'Protected row');
    return;
  }
  selected.value = row;
  deleteOpen.value = true;
};

const handleSave = async (payload: PaymentMethodCreateInput & { id?: number }) => {
  try {
    if (payload.id !== undefined) {
      await globalReferenceRepository.updatePaymentMethod(payload as PaymentMethodUpdateInput);
      showSuccessNotification('Payment method updated.');
    } else {
      await globalReferenceRepository.createPaymentMethod(payload);
      showSuccessNotification('Payment method created.');
    }
    dialogOpen.value = false;
    await load();
  } catch (err: unknown) {
    handleApiFailure({ success: false, error: (err as Error).message }, 'Save failed');
  }
};

const confirmDelete = async () => {
  if (!selected.value) return;
  try {
    await globalReferenceRepository.deletePaymentMethod(selected.value.id);
    showSuccessNotification('Payment method deleted.');
    deleteOpen.value = false;
    await load();
  } catch (err: unknown) {
    handleApiFailure({ success: false, error: (err as Error).message }, 'Delete failed');
  }
};

onMounted(() => void load());
</script>

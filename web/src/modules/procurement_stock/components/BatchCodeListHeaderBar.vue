<template>
  <div class="batch-list-header shrink-0">
    <div class="row items-start q-col-gutter-xs">
      <div v-if="showBack" class="col-auto row items-center" style="height: 40px">
        <q-btn icon="ph ph-arrow-left" flat round dense size="sm" color="grey-8" @click="emit('back')">
          <q-tooltip>Back</q-tooltip>
        </q-btn>
      </div>

      <div class="col-12 col-md">
        <q-input
          v-model="name"
          label="Name *"
          dense
          outlined
          :loading="isSavingList"
          :disable="isListLoading"
          @blur="saveHeader"
        />
      </div>

      <div class="col-12 col-sm-6 col-md">
        <q-select
          v-model="vendorId"
          :options="vendorOptions"
          label="Vendor *"
          dense
          outlined
          emit-value
          map-options
          :loading="vendorsLoading || isSavingList"
          :disable="isListLoading || vendorLocked"
          @update:model-value="saveHeader"
        >
          <template #no-option>
            <q-item>
              <q-item-section class="text-grey">No vendors found</q-item-section>
            </q-item>
          </template>
        </q-select>
      </div>

      <div class="col-12 col-sm-6 col-md">
        <q-select
          v-model="shipmentId"
          :options="shipmentOptions"
          label="Shipment"
          dense
          outlined
          emit-value
          map-options
          clearable
          use-input
          input-debounce="300"
          :loading="shipmentsLoading || isSavingList"
          :disable="isListLoading"
          @filter="onFilterShipments"
          @update:model-value="onShipmentChange"
        >
          <template #no-option>
            <q-item>
              <q-item-section class="text-grey">
                {{ shipmentsLoading ? 'Loading…' : 'No shipments found' }}
              </q-item-section>
            </q-item>
          </template>
          <template #option="scope">
            <q-item v-bind="scope.itemProps">
              <q-item-section>
                <q-item-label>{{ scope.opt.label }}</q-item-label>
                <q-item-label v-if="scope.opt.caption" caption>{{ scope.opt.caption }}</q-item-label>
              </q-item-section>
              <q-item-section v-if="scope.opt.hasBatchFile" side>
                <q-chip dense size="sm" color="grey-3" text-color="grey-8">Has file</q-chip>
              </q-item-section>
            </q-item>
          </template>
        </q-select>
      </div>

      <div v-if="showDelete" class="col-auto row items-center" style="height: 40px">
        <q-btn
          flat
          dense
          no-caps
          color="negative"
          icon="ph ph-trash"
          label="Delete file"
          class="rounded-sq-btn"
          :loading="isDeletingList"
          :disable="isListLoading"
          @click="onDeleteFile"
        />
      </div>
    </div>

    <q-banner
      v-if="selectedShipment && !selectedShipment.vendor_id"
      dense
      rounded
      class="bg-amber-1 text-amber-10 q-mt-xs"
    >
      Set a vendor on this shipment before saving.
    </q-banner>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import {
  globalShipmentRepository,
  type GlobalShipment,
} from '../repositories/globalShipmentRepository';
import { batchCodeRepository, type BatchCodeListRow } from '../repositories/batchCodeRepository';
import {
  useDeleteBatchCodeListMutation,
  useUpdateBatchCodeListMutation,
} from '../composables/useBatchCodeMutations';
import { useBatchCodeListQuery, useBatchCodeListsQuery } from '../composables/useBatchCodeQueries';

type ShipmentOption = {
  label: string;
  value: number;
  caption?: string;
  hasBatchFile?: boolean;
  vendorId: number | null;
};

type SavedSnapshot = {
  name: string;
  vendorId: number | null;
  shipmentId: number | null;
};

const props = withDefaults(
  defineProps<{
    listId: number;
    parentTenantId: number;
    showBack?: boolean;
    showDelete?: boolean;
  }>(),
  {
    showBack: false,
    showDelete: false,
  },
);

const emit = defineEmits<{
  back: [];
  updated: [BatchCodeListRow];
  deleted: [];
  'load-error': [message: string];
}>();

const authStore = useAuthStore();
const listIdRef = computed(() => props.listId);
const parentTenantIdRef = computed(() => props.parentTenantId);

const listQuery = useBatchCodeListQuery(listIdRef);
const listsQuery = useBatchCodeListsQuery(parentTenantIdRef);
const updateListMutation = useUpdateBatchCodeListMutation();
const deleteListMutation = useDeleteBatchCodeListMutation();

const isListLoading = computed(
  () => listQuery.isPending.value && listQuery.isFetching.value,
);
const isSavingList = computed(() => updateListMutation.isPending.value);
const isDeletingList = computed(() => deleteListMutation.isPending.value);

const vendorsLoading = ref(false);
const shipmentsLoading = ref(false);
const vendors = ref<Array<{ id: number; name: string }>>([]);
const shipments = ref<GlobalShipment[]>([]);

const name = ref('');
const vendorId = ref<number | null>(null);
const shipmentId = ref<number | null>(null);
const lastSaved = ref<SavedSnapshot | null>(null);

const listMeta = computed(() => listQuery.data.value ?? null);

const shipmentIdsWithList = computed(() =>
  (listsQuery.data.value ?? [])
    .map((row) => row.shipment_id)
    .filter((id): id is number => id != null),
);

const vendorOptions = computed(() =>
  vendors.value.map((vendor) => ({
    label: vendor.name,
    value: vendor.id,
  })),
);

const shipmentOptions = computed<ShipmentOption[]>(() => {
  const options = shipments.value.map((shipment) => ({
    value: shipment.id,
    label: shipment.name,
    caption: shipment.vendor_name
      ? `${shipment.vendor_name}${shipment.status ? ` · ${shipment.status}` : ''}`
      : 'No vendor set',
    hasBatchFile:
      shipmentIdsWithList.value.includes(shipment.id) && shipment.id !== shipmentId.value,
    vendorId: shipment.vendor_id ?? null,
  }));

  const linked = listMeta.value?.shipment;
  if (linked && !options.some((row) => row.value === linked.id)) {
    options.unshift({
      value: linked.id,
      label: linked.name,
      caption: listMeta.value?.vendor?.name ?? undefined,
      hasBatchFile: false,
      vendorId: listMeta.value?.vendor_id ?? null,
    });
  }

  return options;
});

const selectedShipment = computed(() =>
  shipments.value.find((row) => row.id === shipmentId.value) ?? null,
);

const vendorLocked = computed(
  () => !!selectedShipment.value && !!selectedShipment.value.vendor_id,
);

const applyForm = (row: BatchCodeListRow) => {
  name.value = row.name;
  vendorId.value = row.vendor_id;
  shipmentId.value = row.shipment_id;
  lastSaved.value = {
    name: row.name,
    vendorId: row.vendor_id,
    shipmentId: row.shipment_id,
  };
};

watch(
  listMeta,
  (row) => {
    if (row) applyForm(row);
  },
  { immediate: true },
);

watch(
  () => listQuery.error.value,
  (error) => {
    if (error) {
      emit('load-error', (error as Error).message || 'Failed to load batch list.');
    }
  },
  { immediate: true },
);

const loadVendors = async () => {
  vendorsLoading.value = true;
  try {
    const rows = await vendorRepository.listVendors(props.parentTenantId);
    vendors.value = rows.map((row) => ({ id: row.id, name: row.name }));
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to load vendors');
  } finally {
    vendorsLoading.value = false;
  }
};

const loadShipments = async (search?: string) => {
  shipmentsLoading.value = true;
  try {
    const result = await globalShipmentRepository.listPaginated(
      authStore.tenantId,
      1,
      50,
      search || undefined,
      undefined,
      false,
    );
    shipments.value = result.data;
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to load shipments');
  } finally {
    shipmentsLoading.value = false;
  }
};

watch(
  () => props.parentTenantId,
  () => {
    void loadVendors();
    void loadShipments();
  },
  { immediate: true },
);

const onFilterShipments = (value: string, update: (callback: () => void) => void) => {
  update(() => {
    void loadShipments(value);
  });
};

const isUnchanged = (snapshot: SavedSnapshot): boolean => {
  const saved = lastSaved.value;
  if (!saved) return false;
  return (
    saved.name === snapshot.name &&
    saved.vendorId === snapshot.vendorId &&
    saved.shipmentId === snapshot.shipmentId
  );
};

const resolveRelations = () => {
  const vendor = vendors.value.find((row) => row.id === vendorId.value);
  const shipment = shipments.value.find((row) => row.id === shipmentId.value);
  return {
    vendor: vendor ? { id: vendor.id, name: vendor.name } : listMeta.value?.vendor ?? null,
    shipment: shipment
      ? {
          id: shipment.id,
          name: shipment.name,
          tenant_shipment_id: shipment.tenant_shipment_id ?? null,
        }
      : listMeta.value?.shipment ?? null,
  };
};

const saveHeader = async () => {
  if (isListLoading.value || isSavingList.value || !listMeta.value) return;

  const trimmedName = name.value.trim();
  if (!trimmedName) {
    showErrorNotification('Name is required.');
    name.value = lastSaved.value?.name ?? '';
    return;
  }
  if (!vendorId.value) {
    showErrorNotification('Vendor is required.');
    return;
  }

  const snapshot: SavedSnapshot = {
    name: trimmedName,
    vendorId: vendorId.value,
    shipmentId: shipmentId.value,
  };

  if (isUnchanged(snapshot)) return;

  if (selectedShipment.value && !selectedShipment.value.vendor_id) {
    showErrorNotification('Set a vendor on the shipment first.');
    shipmentId.value = lastSaved.value?.shipmentId ?? null;
    return;
  }

  if (snapshot.shipmentId) {
    const existing = await batchCodeRepository.getByShipmentId(snapshot.shipmentId);
    if (existing && existing.id !== props.listId) {
      showErrorNotification('That shipment already has a batch file.');
      shipmentId.value = lastSaved.value?.shipmentId ?? null;
      return;
    }
  }

  try {
    const relations = resolveRelations();
    const updated = await updateListMutation.mutateAsync({
      listId: props.listId,
      parentTenantId: props.parentTenantId,
      payload: {
        name: snapshot.name,
        vendor_id: snapshot.vendorId,
        shipment_id: snapshot.shipmentId,
      },
      relations,
    });
    applyForm({ ...listMeta.value, ...updated, ...relations });
    emit('updated', { ...listMeta.value, ...updated, ...relations });
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to update batch file.');
    if (lastSaved.value) {
      name.value = lastSaved.value.name;
      vendorId.value = lastSaved.value.vendorId;
      shipmentId.value = lastSaved.value.shipmentId;
    }
  }
};

const onShipmentChange = async (nextShipmentId: number | null) => {
  if (!nextShipmentId) {
    await saveHeader();
    return;
  }

  const shipment =
    shipments.value.find((row) => row.id === nextShipmentId) ??
    (listMeta.value?.shipment?.id === nextShipmentId
      ? {
          id: nextShipmentId,
          vendor_id: listMeta.value.vendor_id,
        }
      : null);

  if (shipment?.vendor_id) {
    vendorId.value = shipment.vendor_id;
  }

  await saveHeader();
};

const onDeleteFile = async () => {
  if (!listMeta.value) return;

  const lineCount = listMeta.value.batch_code_items?.[0]?.count ?? 0;
  const lineNote =
    lineCount > 0
      ? ` This will also delete ${lineCount} line${lineCount === 1 ? '' : 's'}.`
      : '';

  const ok = await requestConfirmation(
    `Delete “${listMeta.value.name}”?${lineNote} This cannot be undone.`,
    'Delete batch file',
    'Delete',
  );
  if (!ok) return;

  try {
    await deleteListMutation.mutateAsync({
      listId: props.listId,
      parentTenantId: props.parentTenantId,
      shipmentId: listMeta.value.shipment_id,
    });
    showSuccessNotification('Batch file deleted');
    emit('deleted');
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to delete batch file.');
  }
};
</script>

<style scoped>
.batch-list-header {
  padding: 2px 4px 0;
}
</style>

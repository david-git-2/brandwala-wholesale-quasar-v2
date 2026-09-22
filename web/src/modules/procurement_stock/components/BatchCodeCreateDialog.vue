<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card style="width: 520px; max-width: 92vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-subtitle1 text-weight-bold">New batch file</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-xs">
        <div class="text-caption text-grey-7">
          Name is required. Link a shipment if you want vendor details filled in automatically.
        </div>
      </q-card-section>

      <q-form @submit.prevent="onSubmit">
        <q-card-section class="q-gutter-y-md q-pt-none">
          <q-input
            v-model="name"
            label="Name *"
            dense
            outlined
            autofocus
            :rules="[(value) => !!String(value ?? '').trim() || 'Name is required']"
            @update:model-value="nameTouched = true"
          />

          <q-select
            v-model="selectedVendorId"
            :options="vendorOptions"
            label="Vendor *"
            dense
            outlined
            emit-value
            map-options
            :loading="vendorsLoading"
            :disable="vendorLocked"
            :rules="[(value) => !!value || 'Select a vendor']"
          >
            <template #no-option>
              <q-item>
                <q-item-section class="text-grey">No vendors found</q-item-section>
              </q-item>
            </template>
          </q-select>

          <q-select
            v-model="selectedShipmentId"
            :options="shipmentOptions"
            label="Shipment (optional)"
            dense
            outlined
            emit-value
            map-options
            use-input
            input-debounce="300"
            clearable
            :loading="shipmentsLoading"
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

          <q-banner
            v-if="selectedShipment && !selectedShipment.vendor_id"
            dense
            rounded
            class="bg-amber-1 text-amber-10"
          >
            Set a vendor on this shipment before creating a batch file.
          </q-banner>
        </q-card-section>

        <q-card-actions align="right" class="q-pt-none">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Create"
            type="submit"
            :loading="submitting"
            :disable="!canSubmit"
            style="border-radius: 8px"
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';
import { showErrorNotification } from 'src/utils/appFeedback';
import {
  globalShipmentRepository,
  type GlobalShipment,
} from '../repositories/globalShipmentRepository';
import { batchCodeRepository } from '../repositories/batchCodeRepository';
import { useCreateBatchCodeListMutation } from '../composables/useBatchCodeMutations';

type ShipmentOption = {
  label: string;
  value: number;
  caption?: string;
  hasBatchFile?: boolean;
  vendorId: number | null;
};

const props = defineProps<{
  modelValue: boolean;
  parentTenantId: number;
  shipmentIdsWithList: number[];
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  created: [listId: number];
}>();

const authStore = useAuthStore();
const createListMutation = useCreateBatchCodeListMutation();

const vendorsLoading = ref(false);
const shipmentsLoading = ref(false);
const submitting = ref(false);
const vendors = ref<Array<{ id: number; name: string }>>([]);
const shipments = ref<GlobalShipment[]>([]);
const name = ref('');
const selectedVendorId = ref<number | null>(null);
const selectedShipmentId = ref<number | null>(null);
const shipmentSearch = ref('');
const nameTouched = ref(false);

const vendorOptions = computed(() =>
  vendors.value.map((vendor) => ({
    label: vendor.name,
    value: vendor.id,
  })),
);

const shipmentOptions = computed<ShipmentOption[]>(() =>
  shipments.value.map((shipment) => ({
    value: shipment.id,
    label: shipment.name,
    caption: shipment.vendor_name
      ? `${shipment.vendor_name}${shipment.status ? ` · ${shipment.status}` : ''}`
      : 'No vendor set',
    hasBatchFile: props.shipmentIdsWithList.includes(shipment.id),
    vendorId: shipment.vendor_id ?? null,
  })),
);

const selectedShipment = computed(() =>
  shipments.value.find((row) => row.id === selectedShipmentId.value) ?? null,
);

const vendorLocked = computed(
  () => !!selectedShipment.value && !!selectedShipment.value.vendor_id,
);

const canSubmit = computed(() => {
  if (submitting.value) return false;
  if (!name.value.trim()) return false;
  if (!selectedVendorId.value) return false;
  if (selectedShipment.value && !selectedShipment.value.vendor_id) return false;
  return true;
});

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

const onFilterShipments = (value: string, update: (callback: () => void) => void) => {
  shipmentSearch.value = value;
  update(() => {
    void loadShipments(value);
  });
};

const onShipmentChange = (shipmentId: number | null) => {
  if (!shipmentId) {
    return;
  }
  const shipment = shipments.value.find((row) => row.id === shipmentId);
  if (!shipment) {
    return;
  }
  if (shipment.vendor_id) {
    selectedVendorId.value = shipment.vendor_id;
  }
  if (!nameTouched.value && shipment.name) {
    name.value = shipment.name;
  }
};

const resetForm = () => {
  name.value = '';
  selectedVendorId.value = null;
  selectedShipmentId.value = null;
  shipmentSearch.value = '';
  nameTouched.value = false;
};

watch(
  () => props.modelValue,
  (open) => {
    if (!open) {
      resetForm();
      return;
    }
    void loadVendors();
    void loadShipments();
  },
);

const onSubmit = async () => {
  const trimmedName = name.value.trim();
  if (!trimmedName || !selectedVendorId.value) {
    return;
  }
  if (selectedShipment.value && !selectedShipment.value.vendor_id) {
    return;
  }

  submitting.value = true;
  try {
    if (selectedShipmentId.value) {
      const existing = await batchCodeRepository.getByShipmentId(selectedShipmentId.value);
      if (existing) {
        emit('created', existing.id);
        emit('update:modelValue', false);
        return;
      }
    }

    const shipment = selectedShipment.value;
    const vendor = vendors.value.find((row) => row.id === selectedVendorId.value);
    const created = await createListMutation.mutateAsync({
      parentTenantId: props.parentTenantId,
      payload: {
        parent_tenant_id: props.parentTenantId,
        name: trimmedName,
        shipment_id: selectedShipmentId.value,
        vendor_id: selectedVendorId.value,
      },
      relations: {
        vendor: vendor ? { id: vendor.id, name: vendor.name } : null,
        shipment: shipment
          ? {
              id: shipment.id,
              name: shipment.name,
              tenant_shipment_id: shipment.tenant_shipment_id ?? null,
            }
          : null,
      },
    });
    emit('created', created.id);
    emit('update:modelValue', false);
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to create batch file');
  } finally {
    submitting.value = false;
  }
};
</script>

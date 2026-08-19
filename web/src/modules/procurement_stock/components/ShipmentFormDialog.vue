<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin" style="width: 600px; max-width: 90vw">
      <q-form @submit="onSubmit">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-primary text-weight-bold">
            {{ isEdit ? 'Edit Shipment Details' : 'Create New Inbound Shipment' }}
          </div>
          <q-space />
          <q-btn icon="ph ph-x" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-md q-gutter-y-md">
          <!-- Error banner -->
          <q-banner v-if="error" class="bg-negative text-white rounded-borders q-py-sm">
            {{ error }}
          </q-banner>

          <!-- Core Details -->
          <div class="text-subtitle2 text-grey-8 q-mb-xs">Core Information</div>
          <q-input
            v-model="form.name"
            label="Shipment Name *"
            outlined
            dense
            :rules="[
              (val) => !!val || 'Name is required',
              (val) => val.trim().length > 0 || 'Name cannot be blank',
            ]"
          />

          <div class="row q-col-gutter-sm">
            <div class="col-12">
              <q-select
                v-model="form.type"
                :options="typeOptions"
                label="Shipment Type *"
                outlined
                dense
                emit-value
                map-options
              />
            </div>
          </div>

          <!-- Cargo Company (only on create) -->
          <q-select
            v-if="!isEdit"
            v-model="form.cargo_company_id"
            :options="cargoOptions"
            label="Cargo Company"
            outlined
            dense
            emit-value
            map-options
            clearable
            :loading="loadingCargo"
          >
            <template #prepend>
              <q-icon name="ph ph-airplane-tilt" size="18px" color="grey-6" />
            </template>
          </q-select>

          <!-- Vendor Details (Required on create & edit) -->
          <div class="text-subtitle2 text-grey-8 q-mt-md q-mb-xs">
            {{ isEdit ? 'Default Vendor' : 'Primary Vendor' }}
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12">
              <q-select
                v-model="form.vendor_id"
                :options="vendorOptions"
                label="Primary Vendor *"
                outlined
                dense
                emit-value
                map-options
                :loading="loadingVendors"
                :rules="[(val) => val != null || 'Vendor is required']"
              >
                <template #prepend>
                  <q-icon name="ph ph-buildings" size="18px" color="grey-6" />
                </template>
              </q-select>
            </div>
          </div>

          <!-- Currencies (edit only — not on create Stage 1) -->
          <template v-if="isEdit">
            <div class="text-subtitle2 text-grey-8 q-mt-md q-mb-xs">Currencies</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="form.shipment_purchase_currency_id"
                  :options="currencyOptions"
                  label="Purchase Currency"
                  outlined
                  dense
                  emit-value
                  map-options
                  clearable
                  :loading="loadingCurrencies"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="form.shipment_cost_currency_id"
                  :options="currencyOptions"
                  label="Cost Currency"
                  outlined
                  dense
                  emit-value
                  map-options
                  clearable
                  :loading="loadingCurrencies"
                />
              </div>
            </div>
          </template>

          <!-- Rates (only shown or prioritized during Edit or advanced toggle) -->
          <div v-if="isEdit" class="q-gutter-y-md">
            <div class="text-subtitle2 text-grey-8 q-mt-md q-mb-xs">Costing & Conversion Rates</div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="form.status"
                  :options="statusOptions"
                  label="Shipment Status *"
                  outlined
                  dense
                  emit-value
                  map-options
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="form.received_date"
                  label="Received Date"
                  outlined
                  dense
                  readonly
                  clearable
                >
                  <template #append>
                    <q-icon name="ph ph-calendar" class="cursor-pointer">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-date v-model="form.received_date" mask="YYYY-MM-DD">
                          <div class="row items-center justify-end">
                            <q-btn v-close-popup label="Close" color="primary" flat />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="form.purchase_invoice_total"
                  type="number"
                  step="0.01"
                  label="Purchase Invoice Total"
                  outlined
                  dense
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="form.cargo_invoice_total"
                  type="number"
                  step="0.01"
                  label="Cargo Invoice Total"
                  outlined
                  dense
                />
              </div>
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="form.received_weight"
                  type="number"
                  step="0.01"
                  label="Cargo Weight (kg)"
                  outlined
                  dense
                  suffix="kg"
                />
              </div>
              <div class="col-12 col-sm-6 items-center flex">
                  <q-checkbox v-model="form.stock_ready" label="Inventory added" />
              </div>
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md bg-grey-1">
          <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
          <q-btn
            type="submit"
            color="primary"
            unelevated
            :label="isEdit ? 'Save Changes' : 'Create Shipment'"
            :loading="submitting"
            no-caps
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import {
  globalShipmentRepository,
  type GlobalShipment,
} from '../repositories/globalShipmentRepository';

const props = defineProps<{
  shipment?: GlobalShipment;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const shipmentStore = useGlobalShipmentStore();

const isEdit = computed(() => !!props.shipment);
const submitting = ref(false);
const error = ref<string | null>(null);

const typeOptions = [
  { label: 'International', value: 'international' },
  { label: 'Local', value: 'local' },
  { label: 'Transfer', value: 'transfer' },
];

const statusOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'In transit', value: 'in_transit' },
  { label: 'Received', value: 'received' },
  { label: 'Cancelled', value: 'cancelled' },
];

const form = ref({
  name: '',
  type: 'international' as 'international' | 'local' | 'transfer',
  vendor_id: null as number | null,
  cargo_company_id: null as number | null,
  shipment_purchase_currency_id: null as number | null,
  shipment_cost_currency_id: null as number | null,
  status: 'draft',
  cargo_invoice_total: null as number | null,
  purchase_invoice_total: null as number | null,
  received_weight: null as number | null,
  received_date: null as string | null,
  stock_ready: false,
});

const currencyOptions = ref<Array<{ label: string; value: number }>>([]);
const loadingCurrencies = ref(false);
const loadingVendors = ref(false);
const loadingCargo = ref(false);
const cargoOptions = ref<Array<{ label: string; value: number }>>([]);

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({
    label: v.is_default ? `${v.name} (default)` : v.name,
    value: v.id,
  })),
);

onMounted(async () => {
  if (authStore.tenantId) {
    loadingVendors.value = true;
    try {
      await vendorStore.fetchVendors(authStore.tenantId, true);
      if (!isEdit.value) {
        const defaultVendor = vendorStore.items.find((v) => v.is_default);
        if (defaultVendor) {
          form.value.vendor_id = defaultVendor.id;
        }
      }
    } catch (err: unknown) {
      console.error('Failed to load vendors', err);
    } finally {
      loadingVendors.value = false;
    }
  }

  if (isEdit.value) {
    loadingCurrencies.value = true;
    try {
      const list = await globalReferenceRepository.listCurrencies();
      currencyOptions.value = list.map((c) => ({
        label: `${c.code} (${c.symbol}) - ${c.name}`,
        value: c.id,
      }));
    } catch (err: unknown) {
      console.error('Failed to load currencies', err);
    } finally {
      loadingCurrencies.value = false;
    }
  } else if (authStore.tenantId) {
    loadingCargo.value = true;
    try {
      const cargo = await globalShipmentRepository.listCargoCompaniesForTenant(authStore.tenantId);
      cargoOptions.value = cargo.map((c) => ({
        label: `${c.name} (${c.code})`,
        value: c.id,
      }));
      const defaultCargo = cargo.find((c) => c.is_default);
      if (defaultCargo) {
        form.value.cargo_company_id = defaultCargo.id;
      }
    } catch (err: unknown) {
      console.error('Failed to load cargo companies', err);
    } finally {
      loadingCargo.value = false;
    }
  }

  if (props.shipment) {
    form.value = {
      name: props.shipment.name,
      type: props.shipment.type,
      vendor_id: props.shipment.vendor_id,
      cargo_company_id: props.shipment.cargo_company_id,
      shipment_purchase_currency_id: props.shipment.shipment_purchase_currency_id,
      shipment_cost_currency_id: props.shipment.shipment_cost_currency_id,
      status: props.shipment.status,
      cargo_invoice_total: props.shipment.cargo_invoice_total,
      purchase_invoice_total: props.shipment.purchase_invoice_total,
      received_weight: props.shipment.received_weight,
      received_date: props.shipment.received_date,
      stock_ready: props.shipment.stock_ready,
    };
  }
});

const onSubmit = async () => {
  error.value = null;
  submitting.value = true;

  try {
    if (!authStore.tenantId) {
      throw new Error('Tenant context missing.');
    }

    if (isEdit.value && props.shipment) {
      const { cargo_company_id: _cargoCompanyId, ...editPayload } = form.value;
      const updated = await shipmentStore.updateShipment(props.shipment.id, {
        ...editPayload,
        vendor_id: form.value.vendor_id!,
      });
      onDialogOK(updated);
    } else {
      const created = await shipmentStore.createShipmentDraft(authStore.tenantId, {
        name: form.value.name,
        type: form.value.type,
        vendor_id: form.value.vendor_id,
        cargo_company_id: form.value.cargo_company_id,
      });

      onDialogOK(created);
    }
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to save shipment.';
  } finally {
    submitting.value = false;
  }
};
</script>

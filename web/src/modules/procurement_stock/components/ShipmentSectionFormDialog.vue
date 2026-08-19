<template>
  <q-dialog ref="dialogRef" persistent @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 540px; max-width: 95vw; border-radius: 8px">
      <q-form @submit="onSubmit">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-primary text-weight-bold">
            {{ isEdit ? 'Edit Section' : 'Add New Section' }}
          </div>
          <q-space />
          <q-btn icon="ph ph-x" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-md q-gutter-y-sm">
          <!-- Error banner -->
          <q-banner v-if="error" class="bg-negative text-white rounded-borders q-py-xs" dense>
            {{ error }}
          </q-banner>

          <!-- Vendor Picker -->
          <q-select
            v-model="form.vendor_id"
            :options="vendorOptions"
            label="Vendor *"
            outlined
            dense
            emit-value
            map-options
            use-input
            input-debounce="0"
            :loading="loadingVendors"
            :rules="[(val) => val != null || 'Vendor is required']"
            @filter="filterVendors"
          >
            <template #prepend>
              <q-icon name="ph ph-buildings" size="18px" color="grey-6" />
            </template>
            <template #no-option>
              <q-item dense>
                <q-item-section class="text-grey-6">No matching vendors</q-item-section>
              </q-item>
            </template>
          </q-select>

          <!-- Section Title -->
          <q-input
            v-model="form.title"
            label="Section Title / Identifier *"
            outlined
            dense
            placeholder="e.g. Zara Primary Order / Box Set A"
            :rules="[
              (val) => !!val || 'Title is required',
              (val) => val.trim().length > 0 || 'Title cannot be blank',
            ]"
          >
            <template #prepend>
              <q-icon name="ph ph-folder" size="18px" color="grey-6" />
            </template>
          </q-input>

          <!-- Invoice Number & Invoice Date -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.invoice_number"
                label="Invoice Number"
                outlined
                dense
                placeholder="e.g. INV-2026-901"
              >
                <template #prepend>
                  <q-icon name="ph ph-receipt" size="18px" color="grey-6" />
                </template>
              </q-input>
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.invoice_date"
                label="Invoice Date"
                outlined
                dense
                readonly
                clearable
              >
                <template #prepend>
                  <q-icon name="ph ph-calendar" size="18px" color="grey-6" />
                </template>
                <template #append>
                  <q-icon name="ph ph-calendar-plus" class="cursor-pointer" size="18px">
                    <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                      <q-date v-model="form.invoice_date" mask="YYYY-MM-DD">
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

          <!-- Notes -->
          <q-input
            v-model="form.notes"
            label="Notes / Comments"
            outlined
            dense
            type="textarea"
            rows="3"
            placeholder="Additional details, packing comments, or custom carton refs..."
          />
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md bg-grey-1">
          <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
          <q-btn
            type="submit"
            color="primary"
            unelevated
            :label="isEdit ? 'Save Changes' : 'Create Section'"
            :loading="submitting"
            no-caps
            class="rounded-sq-btn"
            style="border-radius: 8px"
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { ShipmentSection } from '../types/shipmentSection';

const props = defineProps<{
  shipmentId: number;
  section?: ShipmentSection | null;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const shipmentStore = useGlobalShipmentStore();

const isEdit = computed(() => !!props.section);
const submitting = ref(false);
const error = ref<string | null>(null);
const loadingVendors = ref(false);

const form = ref({
  vendor_id: props.section?.vendor_id ?? (null as number | null),
  title: props.section?.title ?? '',
  invoice_number: props.section?.metadata?.invoice_number ?? '',
  invoice_date: props.section?.metadata?.invoice_date ?? '',
  notes: props.section?.metadata?.notes ?? '',
});

const vendorFilterText = ref('');

const allVendorOptions = computed(() =>
  vendorStore.items.map((v) => ({
    label: v.is_default ? `${v.name} (default)` : v.name,
    value: v.id,
  })),
);

const vendorOptions = computed(() => {
  if (!vendorFilterText.value) return allVendorOptions.value;
  const needle = vendorFilterText.value.toLowerCase();
  return allVendorOptions.value.filter((v) => v.label.toLowerCase().includes(needle));
});

const filterVendors = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    vendorFilterText.value = val;
  });
};

onMounted(async () => {
  if (authStore.tenantId && vendorStore.items.length === 0) {
    loadingVendors.value = true;
    try {
      await vendorStore.fetchVendors(authStore.tenantId);
    } catch (err) {
      console.error('Failed to load vendors', err);
    } finally {
      loadingVendors.value = false;
    }
  }

  if (!isEdit.value && form.value.vendor_id == null) {
    const fallbackVendorId =
      shipmentStore.currentShipment?.vendor_id ??
      vendorStore.items.find((v) => v.is_default)?.id ??
      vendorStore.items[0]?.id ??
      null;
    if (fallbackVendorId) {
      form.value.vendor_id = fallbackVendorId;
    }
  }
});

const onSubmit = async () => {
  if (!authStore.tenantId) return;
  if (form.value.vendor_id == null) {
    error.value = 'Vendor is required.';
    return;
  }
  if (!form.value.title.trim()) {
    error.value = 'Title is required.';
    return;
  }

  submitting.value = true;
  error.value = null;

  const metadata = {
    ...(props.section?.metadata ?? {}),
    invoice_number: form.value.invoice_number.trim() || undefined,
    invoice_date: form.value.invoice_date || undefined,
    notes: form.value.notes.trim() || undefined,
  };

  try {
    if (isEdit.value && props.section) {
      const updated = await shipmentStore.updateSection(props.section.id, {
        vendor_id: form.value.vendor_id,
        title: form.value.title.trim(),
        metadata,
      });
      onDialogOK(updated);
    } else {
      const created = await shipmentStore.createSection({
        parent_tenant_id: authStore.tenantId,
        shipment_id: props.shipmentId,
        vendor_id: form.value.vendor_id,
        title: form.value.title.trim(),
        sort_order: (shipmentStore.currentShipmentSections?.length ?? 0) + 1,
        metadata,
      });
      onDialogOK(created);
    }
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to save section.';
  } finally {
    submitting.value = false;
  }
};
</script>

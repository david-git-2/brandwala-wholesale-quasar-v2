<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 360px; max-width: 440px" class="rounded-borders">
      <q-card-section class="q-pb-sm">
        <div class="text-subtitle1 text-weight-medium">Record vendor order</div>
        <div v-if="target" class="text-caption text-grey-7 q-mt-xs">
          {{ target.productName }}
          <span v-if="target.remainingQuantity > 0">
            · {{ target.remainingQuantity }} remaining
          </span>
        </div>
      </q-card-section>

      <q-card-section class="q-pt-none q-gutter-y-sm">
        <q-select
          v-model="selectedVendorId"
          :options="vendorOptions"
          option-value="id"
          option-label="label"
          emit-value
          map-options
          outlined
          dense
          clearable
          use-input
          input-debounce="200"
          label="Vendor (optional)"
          :loading="vendorsLoading"
          data-test="placement-vendor-select"
          @filter="filterVendors"
        />

        <q-input
          v-model="vendorCode"
          outlined
          dense
          label="Vendor code (optional override)"
          :disable="!!selectedVendorId"
          data-test="placement-vendor-code"
        />

        <q-input
          v-model.number="quantity"
          type="number"
          min="1"
          outlined
          dense
          label="Quantity ordered"
          data-test="placement-quantity"
        />

        <q-input
          v-model="notes"
          type="textarea"
          autogrow
          outlined
          dense
          label="Notes (optional)"
          placeholder="PO reference, urgency, substitute info..."
          data-test="placement-notes"
        />
      </q-card-section>

      <q-card-actions align="right" class="q-pt-none">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Save placement"
          :loading="saving"
          :disable="!canSubmit"
          data-test="placement-save-btn"
          @click="submit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';
import type { Vendor } from 'src/modules/vendor/types';
import type { PlacementDialogTarget } from '../composables/useProcurementPlacementMutations';

const props = defineProps<{
  modelValue: boolean;
  tenantId: number | null;
  target: PlacementDialogTarget | null;
  saving?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: { vendorId: number | null; vendorCode: string | null; quantity: number; notes: string | null }];
}>();

const selectedVendorId = ref<number | null>(null);
const vendorCode = ref('');
const quantity = ref(1);
const notes = ref('');
const vendorFilter = ref('');

const { data: vendors = [], isLoading: vendorsLoading } = useQuery({
  queryKey: computed(() => ['vendors', 'forPlacement', props.tenantId]),
  queryFn: () => vendorRepository.listVendors(props.tenantId),
  enabled: computed(() => props.modelValue && props.tenantId !== null),
  staleTime: 60_000,
});

const vendorOptions = computed(() => {
  const needle = vendorFilter.value.trim().toLowerCase();
  return (vendors.value as Vendor[])
    .filter((v) => {
      if (!needle) return true;
      return (
        v.name.toLowerCase().includes(needle) ||
        v.code.toLowerCase().includes(needle)
      );
    })
    .map((v) => ({
      id: v.id,
      label: `${v.name} (${v.code})`,
      code: v.code,
    }));
});

const canSubmit = computed(() => {
  const qty = Number(quantity.value);
  return Number.isFinite(qty) && qty > 0;
});

const resetForm = () => {
  selectedVendorId.value = props.target?.defaultVendorId ?? null;
  vendorCode.value = props.target?.defaultVendorCode ?? '';
  quantity.value = Math.max(props.target?.remainingQuantity ?? 1, 1);
  notes.value = '';
  vendorFilter.value = '';
};

watch(
  () => [props.modelValue, props.target] as const,
  ([open]) => {
    if (open) resetForm();
  },
);

watch(selectedVendorId, (id) => {
  if (!id) return;
  const match = (vendors.value as Vendor[]).find((v) => v.id === id);
  if (match) vendorCode.value = match.code;
});

const filterVendors = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    vendorFilter.value = val;
  });
};

const close = () => {
  emit('update:modelValue', false);
};

const submit = () => {
  if (!canSubmit.value) return;
  emit('submit', {
    vendorId: selectedVendorId.value,
    vendorCode: vendorCode.value.trim() || null,
    quantity: Number(quantity.value),
    notes: notes.value.trim() || null,
  });
};
</script>

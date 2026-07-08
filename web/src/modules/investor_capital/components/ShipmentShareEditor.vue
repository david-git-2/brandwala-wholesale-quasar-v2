<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 400px; max-width: 95vw">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Cost Share' : 'Add Cost Share' }}</div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-select
          v-model="form.investor_id"
          outlined
          dense
          emit-value
          map-options
          label="Investor"
          :options="investorOptions"
          :disable="isEdit"
        />

        <q-input
          v-model.number="form.cost_share_pct"
          type="number"
          min="0.01"
          max="100"
          step="0.01"
          label="Cost Share %"
          outlined
          dense
          :rules="[
            (val) => val >= 0 || 'Must be positive',
            (val) =>
              val <= maxAllowedPct ||
              `Cannot exceed remaining allowable share of ${maxAllowedPct}%`,
          ]"
        />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="localModelValue = false" />
        <q-btn color="primary" :disable="!canSave" label="Save" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import type { ShipmentInvestment, InvestorBalance } from '../types';

const props = defineProps<{
  modelValue: boolean;
  initialData?: ShipmentInvestment | null;
  investors: InvestorBalance[];
  remainingPct: number;
  tenantId: number;
  globalShipmentId: number;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save', value: { id: number | null; investor_id: number; cost_share_pct: number }): void;
}>();

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const isEdit = computed(() => Boolean(props.initialData));

const maxAllowedPct = computed(() => {
  const currentVal = props.initialData ? Number(props.initialData.cost_share_pct ?? 0) : 0;
  return Number((props.remainingPct + currentVal).toFixed(2));
});

const form = reactive({
  id: null as number | null,
  investor_id: 0,
  cost_share_pct: 0,
});

const investorOptions = computed(() =>
  props.investors.map((item) => ({
    label: item.name,
    value: item.investor_id,
  })),
);

const canSave = computed(
  () =>
    form.investor_id > 0 && form.cost_share_pct > 0 && form.cost_share_pct <= maxAllowedPct.value,
);

watch(
  [() => props.modelValue, () => props.initialData, () => props.investors],
  ([opened, initialData, investors]) => {
    if (!opened) return;

    if (initialData) {
      form.id = initialData.id;
      form.investor_id = initialData.investor_id;
      form.cost_share_pct = Number(initialData.cost_share_pct ?? 0);
    } else {
      form.id = null;
      form.investor_id = investors[0]?.investor_id ?? 0;
      form.cost_share_pct = Math.min(10, maxAllowedPct.value);
    }
  },
  { immediate: true },
);

const onSave = () => {
  if (!canSave.value) return;

  emit('save', {
    id: form.id,
    investor_id: form.investor_id,
    cost_share_pct: form.cost_share_pct,
  });
  localModelValue.value = false;
};
</script>

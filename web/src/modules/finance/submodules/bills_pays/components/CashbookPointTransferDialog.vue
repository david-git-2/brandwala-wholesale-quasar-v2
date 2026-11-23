<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: min(440px, 92vw)">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">Move cash</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-card-section class="column q-gutter-y-sm q-pt-sm">
        <div class="text-body2 text-grey-8">
          From <span class="text-weight-medium">{{ fromPoint?.name ?? '—' }}</span>
        </div>
        <q-select
          v-model="toPointId"
          :options="toPointOptions"
          emit-value
          map-options
          outlined
          dense
          label="To location"
        />
        <q-select
          v-model="currencyCode"
          :options="currencyOptions"
          emit-value
          map-options
          outlined
          dense
          label="Currency"
        />
        <q-input
          v-model.number="amount"
          type="number"
          min="0"
          step="0.01"
          outlined
          dense
          label="Amount"
        />
        <q-input v-model="note" outlined dense label="Note (optional)" autogrow />
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Move"
          :loading="mutation.isPending.value"
          :disable="!canSubmit"
          @click="submit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { CashbookPointPotRow, CashbookPointRow } from '../repositories/cashbookRepository';
import { useTransferCashbookPointMutation } from '../composables/useTransferCashbookPointMutation';

const props = defineProps<{
  modelValue: boolean;
  tenantId: number;
  fromPoint: CashbookPointRow | null;
  points: CashbookPointRow[];
  pots: CashbookPointPotRow[];
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  transferred: [];
}>();

const mutation = useTransferCashbookPointMutation();

const toPointId = ref<number | null>(null);
const currencyCode = ref<string>('BDT');
const amount = ref<number | null>(null);
const note = ref('');

const toPointOptions = computed(() =>
  props.points
    .filter((p) => p.is_active && p.id !== props.fromPoint?.id)
    .map((p) => ({ label: p.name, value: p.id })),
);

const currencyOptions = computed(() =>
  props.pots.map((p) => ({ label: p.currency_code, value: p.currency_code })),
);

const canSubmit = computed(() => {
  if (!props.fromPoint || !toPointId.value || !currencyCode.value) return false;
  const amt = amount.value;
  return typeof amt === 'number' && Number.isFinite(amt) && amt > 0;
});

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return;
    toPointId.value = toPointOptions.value[0]?.value ?? null;
    const codes = currencyOptions.value.map((o) => o.value);
    currencyCode.value = codes.includes('BDT') ? 'BDT' : codes[0] ?? 'BDT';
    amount.value = null;
    note.value = '';
  },
);

const close = () => emit('update:modelValue', false);

const submit = async () => {
  if (!props.fromPoint || !toPointId.value || !canSubmit.value) return;
  await mutation.mutateAsync({
    tenantId: props.tenantId,
    fromPointId: props.fromPoint.id,
    toPointId: toPointId.value,
    currencyCode: currencyCode.value,
    amount: amount.value as number,
    note: note.value.trim() || null,
  });
  emit('transferred');
  close();
};
</script>

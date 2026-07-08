<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 560px; max-width: 95vw">
      <q-card-section>
        <div class="text-h6">Record Capital Ledger Entry</div>
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
        />

        <q-input
          v-model.number="form.amount"
          type="number"
          min="0.01"
          step="0.01"
          label="Amount"
          outlined
          dense
        />

        <q-input v-model="form.date" label="Date" outlined dense readonly>
          <template #append>
            <q-icon name="event" class="cursor-pointer">
              <q-popup-proxy
                ref="datePopupRef"
                cover
                transition-show="scale"
                transition-hide="scale"
              >
                <q-date v-model="form.date" mask="YYYY-MM-DD" @update:model-value="onDateSelected">
                  <div class="row items-center justify-end">
                    <q-btn v-close-popup label="Close" color="primary" flat />
                  </div>
                </q-date>
              </q-popup-proxy>
            </q-icon>
          </template>
        </q-input>

        <q-select
          v-model="form.type"
          outlined
          dense
          emit-value
          map-options
          label="Type"
          :options="transactionTypeOptions"
        />

        <q-select
          v-model="form.method"
          outlined
          dense
          emit-value
          map-options
          label="Method"
          :options="transactionMethodOptions"
        />

        <q-input v-model="form.note" label="Note" type="textarea" autogrow outlined />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="localModelValue = false" />
        <q-btn color="primary" :disable="!canSave" label="Save" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import type { QPopupProxy } from 'quasar';

import type {
  Investor,
  InvestorTransactionCreateInput,
  InvestorTransactionMethod,
} from 'src/modules/investor_capital/types';

const props = defineProps<{
  modelValue: boolean;
  tenantId: number;
  investors: Investor[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save', value: InvestorTransactionCreateInput): void;
}>();

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});
const datePopupRef = ref<QPopupProxy | null>(null);

const today = () => new Date().toISOString().slice(0, 10);

const form = reactive<
  Omit<InvestorTransactionCreateInput, 'amount' | 'type'> & { amount: number | null; type: string }
>({
  tenant_id: props.tenantId,
  investor_id: 0,
  amount: null,
  date: today(),
  method: 'cash',
  type: 'capital_in',
  note: null,
});

const investorOptions = computed(() =>
  props.investors.map((item) => ({
    label: item.name,
    value: item.id,
  })),
);

const transactionTypeOptions = [
  { label: 'Capital In (Deposit)', value: 'capital_in' },
  { label: 'Withdrawal Paid', value: 'withdrawal_paid' },
  { label: 'Capital Adjustment', value: 'capital_adjustment' },
];

const transactionMethodOptions: { label: string; value: InvestorTransactionMethod }[] = [
  { label: 'Cash', value: 'cash' },
  { label: 'Bank', value: 'bank' },
  { label: 'Mobile Banking', value: 'mobile_banking' },
  { label: 'Other', value: 'other' },
];

const canSave = computed(
  () =>
    form.tenant_id > 0 &&
    form.investor_id > 0 &&
    Number(form.amount ?? 0) > 0 &&
    Boolean(form.date),
);

watch(
  [() => props.modelValue, () => props.tenantId],
  ([opened, tenantId]) => {
    if (!opened) {
      return;
    }

    form.tenant_id = tenantId;
    form.investor_id = props.investors[0]?.id ?? 0;
    form.amount = null;
    form.date = today();
    form.method = 'cash';
    form.type = 'capital_in';
    form.note = null;
  },
  { immediate: true },
);

const onSave = () => {
  if (!canSave.value) {
    return;
  }

  emit('save', {
    tenant_id: form.tenant_id,
    investor_id: form.investor_id,
    amount: Number(form.amount ?? 0),
    date: form.date,
    method: form.method,
    type: form.type as any,
    note: form.note?.trim() || null,
  });

  localModelValue.value = false;
};

const onDateSelected = () => {
  datePopupRef.value?.hide();
};
</script>

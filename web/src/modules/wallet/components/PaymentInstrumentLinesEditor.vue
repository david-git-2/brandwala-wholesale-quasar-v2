<template>
  <div class="column q-gutter-sm">
    <div class="row items-center justify-between">
      <div class="text-subtitle2 text-weight-bold">{{ title }}</div>
      <q-btn flat dense color="primary" icon="add" label="Add another payment" class="q-px-none" @click="addLine" />
    </div>

    <div
      v-for="(line, index) in lines"
      :key="line.key"
      class="q-pa-sm rounded-borders bg-grey-1 column q-gutter-sm"
    >
      <div class="row items-center justify-between">
        <div class="column">
          <span class="text-caption text-weight-medium text-grey-8">Payment {{ index + 1 }}</span>
          <span v-if="lineAmount(line) > 0" class="text-body2 text-weight-bold text-primary">
            {{ formatBdtAmount(lineAmount(line)) }}
          </span>
        </div>
        <q-btn
          v-if="lines.length > 1"
          flat
          dense
          round
          icon="close"
          color="grey-7"
          aria-label="Remove payment"
          @click="removeLine(line.key)"
        />
      </div>

      <q-input
        v-model.number="line.amount"
        type="number"
        label="This payment amount (৳) *"
        outlined
        dense
        min="0"
        step="0.01"
        class="soft-input"
        input-class="text-weight-bold"
      />

      <q-select
        v-model="line.payment_method_code"
        :options="methodOptions"
        label="Paid by *"
        outlined
        dense
        emit-value
        map-options
        class="soft-input"
        @update:model-value="onMethodChange(line)"
      />

      <q-select
        v-if="needsPaymentBank(line.payment_method_code)"
        v-model="line.bd_bank_id"
        :options="filteredBankOptions"
        label="Bank *"
        outlined
        dense
        emit-value
        map-options
        use-input
        fill-input
        hide-selected
        input-debounce="200"
        class="soft-input"
        @filter="filterBanks"
      >
        <template #no-option>
          <q-item>
            <q-item-section class="text-grey">No matching bank</q-item-section>
          </q-item>
        </template>
      </q-select>

      <q-input
        v-if="line.payment_method_code === 'CHEQUE'"
        v-model="line.cheque_number"
        label="Cheque number *"
        outlined
        dense
        class="soft-input"
      />

      <q-input
        v-if="line.payment_method_code === 'CHEQUE'"
        v-model="line.cheque_date"
        label="Cheque date *"
        outlined
        dense
        readonly
        class="soft-input"
      >
        <template #append>
          <q-icon name="ph ph-calendar" class="cursor-pointer">
            <q-popup-proxy cover transition-show="scale" transition-hide="scale">
              <q-date v-model="line.cheque_date" mask="YYYY-MM-DD">
                <div class="row items-center justify-end">
                  <q-btn v-close-popup label="Close" color="primary" flat />
                </div>
              </q-date>
            </q-popup-proxy>
          </q-icon>
        </template>
      </q-input>

      <q-input
        v-if="line.payment_method_code === 'BANK_TRANSFER'"
        v-model="line.cheque_date"
        label="Transfer date"
        outlined
        dense
        readonly
        class="soft-input"
      >
        <template #append>
          <q-icon name="ph ph-calendar" class="cursor-pointer">
            <q-popup-proxy cover transition-show="scale" transition-hide="scale">
              <q-date v-model="line.cheque_date" mask="YYYY-MM-DD">
                <div class="row items-center justify-end">
                  <q-btn v-close-popup label="Close" color="primary" flat />
                </div>
              </q-date>
            </q-popup-proxy>
          </q-icon>
        </template>
      </q-input>

      <q-input
        v-if="needsPaymentReference(line.payment_method_code)"
        v-model="line.reference"
        :label="referenceLabel(line.payment_method_code)"
        outlined
        dense
        class="soft-input"
      />

      <q-input
        v-if="line.payment_method_code === 'CASH'"
        v-model="line.reference"
        label="Till note (optional)"
        outlined
        dense
        class="soft-input"
      />
    </div>

    <div v-if="activeLines.length > 0" class="q-pa-sm rounded-borders bg-blue-1">
      <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Separate amounts (this visit)</div>
      <div
        v-for="(line, index) in activeLines"
        :key="line.key"
        class="row justify-between text-caption q-py-3xs"
      >
        <span>{{ methodLabel(line.payment_method_code) }} {{ activeLines.length > 1 ? `#${index + 1}` : '' }}</span>
        <span class="text-weight-bold font-mono">{{ formatBdtAmount(lineAmount(line)) }}</span>
      </div>
      <q-separator class="q-my-xs" />
      <div class="row justify-between text-body2">
        <span class="text-weight-medium">Total money received</span>
        <span class="text-weight-bold text-primary font-mono">{{ formatBdtAmount(activeTotal) }}</span>
      </div>
    </div>

    <div v-if="validationMessage" class="text-caption text-negative">{{ validationMessage }}</div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useBdBanksQuery, useGlobalPaymentMethodsQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import {
  createPaymentInstrumentLine,
  formatBdtAmount,
  needsPaymentBank,
  needsPaymentReference,
  paymentMethodFallbackLabel,
  type PaymentInstrumentLineForm,
} from '../utils/paymentInstruments';

const props = withDefaults(
  defineProps<{
    modelValue: PaymentInstrumentLineForm[];
    title?: string;
  }>(),
  { title: 'Each payment (separate amount)' },
);

const emit = defineEmits<{
  'update:modelValue': [PaymentInstrumentLineForm[]];
  'validation-change': [{ valid: boolean; message: string | null; total: number }];
}>();

const { data: paymentMethods } = useGlobalPaymentMethodsQuery();
const { data: bdBanks } = useBdBanksQuery();

const lines = ref<PaymentInstrumentLineForm[]>([]);
const syncing = ref(false);

watch(
  () => props.modelValue,
  (value) => {
    syncing.value = true;
    lines.value = value.length > 0 ? value.map((line) => ({ ...line })) : [createPaymentInstrumentLine()];
    syncing.value = false;
  },
  { immediate: true, deep: true },
);

watch(
  lines,
  (value) => {
    if (syncing.value) return;
    emit('update:modelValue', value.map((line) => ({ ...line })));
    emit('validation-change', {
      valid: !validationMessage.value,
      message: validationMessage.value,
      total: activeTotal.value,
    });
  },
  { deep: true },
);

const methodOptions = computed(() => {
  const fromCatalog = (paymentMethods.value ?? [])
    .filter(
      (method) =>
        method.is_active &&
        ['bd_cash', 'bd_bank', 'bd_mobile_wallet'].includes(method.category) &&
        method.code !== 'COD',
    )
    .map((method) => ({ label: method.name, value: method.code }));

  if (fromCatalog.length > 0) return fromCatalog;

  return [
    { label: 'Cash', value: 'CASH' },
    { label: 'Cheque', value: 'CHEQUE' },
    { label: 'bKash', value: 'BKASH' },
    { label: 'Nagad', value: 'NAGAD' },
    { label: 'Bank transfer', value: 'BANK_TRANSFER' },
  ];
});

const bankOptions = computed(() =>
  (bdBanks.value ?? []).map((bank) => ({
    label: bank.name,
    value: bank.id,
    code: bank.code,
    swift: bank.swift_code ?? '',
  })),
);

const filteredBankOptions = ref<{ label: string; value: number }[]>([]);

watch(
  bankOptions,
  (options) => {
    filteredBankOptions.value = options.map(({ label, value }) => ({ label, value }));
  },
  { immediate: true },
);

const filterBanks = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    if (!needle) {
      filteredBankOptions.value = bankOptions.value.map(({ label, value }) => ({ label, value }));
      return;
    }
    filteredBankOptions.value = bankOptions.value
      .filter(
        (bank) =>
          bank.label.toLowerCase().includes(needle) ||
          bank.code.toLowerCase().includes(needle) ||
          bank.swift.toLowerCase().includes(needle),
      )
      .map(({ label, value }) => ({ label, value }));
  });
};

const lineAmount = (line: PaymentInstrumentLineForm) => Math.max(Number(line.amount) || 0, 0);

const activeLines = computed(() => lines.value.filter((line) => lineAmount(line) > 0));

const activeTotal = computed(() =>
  activeLines.value.reduce((sum, line) => sum + lineAmount(line), 0),
);

const methodLabel = (code: string) =>
  methodOptions.value.find((option) => option.value === code)?.label ?? paymentMethodFallbackLabel(code);

const validationMessage = computed((): string | null => {
  if (activeLines.value.length === 0) return null;
  for (const line of activeLines.value) {
    if (line.payment_method_code === 'CHEQUE') {
      if (!line.bd_bank_id || !line.cheque_number.trim() || !line.cheque_date) {
        return 'Each cheque payment needs bank, cheque number, and cheque date.';
      }
    }
    if (line.payment_method_code === 'BANK_TRANSFER' && !line.bd_bank_id) {
      return 'Each bank transfer payment needs a bank.';
    }
    if (needsPaymentReference(line.payment_method_code) && !line.reference.trim()) {
      return `${referenceLabel(line.payment_method_code)} is required.`;
    }
  }
  return null;
});

const addLine = () => {
  lines.value.push(createPaymentInstrumentLine());
};

const removeLine = (key: string) => {
  lines.value = lines.value.filter((line) => line.key !== key);
  if (lines.value.length === 0) lines.value = [createPaymentInstrumentLine()];
};

const referenceLabel = (code: string) => {
  if (code === 'BKASH') return 'bKash trx ID *';
  if (code === 'NAGAD') return 'Nagad trx ID *';
  return 'Trx ID / reference *';
};

const onMethodChange = (line: PaymentInstrumentLineForm) => {
  if (['CHEQUE', 'BANK_TRANSFER'].includes(line.payment_method_code) && !line.cheque_date) {
    line.cheque_date = createPaymentInstrumentLine().cheque_date;
  }
};
</script>

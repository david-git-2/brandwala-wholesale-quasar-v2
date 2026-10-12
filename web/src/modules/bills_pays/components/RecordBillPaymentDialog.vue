<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="record-bill-payment-card" style="width: min(480px, 92vw)">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">{{ isAp ? 'Pay out' : 'Collect payment' }}</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-card-section class="q-gutter-y-md q-pt-sm">
        <div class="text-caption text-grey-7">
          Due on this bill: <strong>{{ formatAmountBdt(dueAmount) }}</strong>
        </div>
        <div v-if="paymentOverDue" class="text-caption text-grey-8">
          {{ formatAmountBdt(allocToBill) }} applies to this bill.
          {{ formatAmountBdt(paymentLeftover) }} stays unallocated on the payment.
        </div>

        <q-input v-model="paidOn" outlined dense label="Payment date" mask="####-##-##">
          <template #append>
            <q-icon name="ph ph-calendar" class="cursor-pointer">
              <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                <q-date v-model="paidOn" mask="YYYY-MM-DD" />
              </q-popup-proxy>
            </q-icon>
          </template>
        </q-input>

        <q-select
          v-model="settlementCurrency"
          :options="settlementCurrencyOptions"
          emit-value
          map-options
          outlined
          dense
          label="Settlement currency"
        />

        <template v-if="settlementCurrency !== 'BDT'">
          <q-input
            v-model.number="foreignAmount"
            outlined
            dense
            :label="`Amount (${settlementCurrency})`"
            type="number"
            step="0.01"
          />
          <q-input
            v-model.number="exchangeRate"
            outlined
            dense
            label="Exchange rate (BDT per 1 unit)"
            type="number"
            step="0.0001"
          />
          <div v-if="computedBdtAmount != null" class="text-caption text-grey-8">
            BDT equivalent: {{ formatAmountBdt(computedBdtAmount) }}
          </div>
        </template>

        <q-input
          v-model.number="amountBdt"
          outlined
          dense
          :label="settlementCurrency === 'BDT' ? 'Payment amount (BDT)' : 'Payment amount (BDT, from FX)'"
          type="number"
          step="0.01"
          :readonly="settlementCurrency !== 'BDT'"
        />

        <q-select
          v-model="methodCode"
          :options="methodOptions"
          emit-value
          map-options
          outlined
          dense
          label="Method"
          :loading="loadingPaymentMeta"
        />

        <PaymentInstrumentExtrasFields
          :method-code="methodCode"
          :method-options="methodOptions"
          :bd-bank-options="bdBankOptions"
          :loading="loadingPaymentMeta"
          :bd-bank-id="bdBankId"
          :cheque-number="chequeNumber"
          :instrument-date="instrumentDate"
          :instrument-reference="instrumentReference"
          @update:bd-bank-id="bdBankId = $event"
          @update:cheque-number="chequeNumber = $event"
          @update:instrument-date="instrumentDate = $event"
          @update:instrument-reference="instrumentReference = $event"
        />

        <q-input v-model="reference" outlined dense clearable label="Payment reference (optional)" />
        <q-input v-model="note" outlined dense label="Notes" type="textarea" autogrow />
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md q-pt-none">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Add payment"
          :loading="loading"
          :disable="!!submitDisabledReason"
          @click="submit"
        >
          <q-tooltip v-if="submitDisabledReason">{{ submitDisabledReason }}</q-tooltip>
        </q-btn>
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { formatAmountBdt } from 'src/utils/currency';
import PaymentInstrumentExtrasFields from './PaymentInstrumentExtrasFields.vue';
import { useWholesalePaymentMethodMeta } from '../composables/useWholesalePaymentMethodMeta';
import {
  paymentInstrumentExtrasBlockReason,
  paymentMethodFieldFlags,
} from '../utils/paymentInstrumentFields';
import { apBillCurrencyGroups } from '../utils/parseApBillPaper';
import type { RecordBillPaymentInput } from '../composables/useRecordBillPaymentMutation';

const props = defineProps<{
  modelValue: boolean;
  dueAmount: number;
  billId: number;
  profileId: number;
  tenantId: number;
  isAp: boolean;
  channelMeta?: Record<string, unknown> | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: RecordBillPaymentInput];
}>();

const localToday = () => {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const paidOn = ref(localToday());
const settlementCurrency = ref('BDT');
const foreignAmount = ref<number | null>(null);
const exchangeRate = ref<number | null>(null);
const amountBdt = ref<number | null>(null);
const methodCode = ref('bank_transfer');
const reference = ref('');
const note = ref('');
const bdBankId = ref<number | null>(null);
const chequeNumber = ref('');
const instrumentDate = ref('');
const instrumentReference = ref('');

const { loadingPaymentMeta, methodOptions, bdBankOptions, loadPaymentMeta } =
  useWholesalePaymentMethodMeta('bank_transfer');

const { data: currenciesData } = useGlobalCurrenciesQuery();

const settlementCurrencyOptions = computed(() => {
  const fromRef = (currenciesData.value ?? [])
    .filter((c) => c.is_active)
    .map((c) => ({ label: `${c.code} — ${c.name}`, value: c.code }));
  const codes = new Set(fromRef.map((o) => o.value));
  if (!codes.has('BDT')) {
    fromRef.unshift({ label: 'BDT — Bangladesh Taka', value: 'BDT' });
  }
  return fromRef.sort((a, b) => (a.value === 'BDT' ? -1 : b.value === 'BDT' ? 1 : a.value.localeCompare(b.value)));
});

const computedBdtAmount = computed(() => {
  if (settlementCurrency.value === 'BDT') return null;
  const foreign = foreignAmount.value;
  const rate = exchangeRate.value;
  if (foreign == null || rate == null || foreign <= 0 || rate <= 0) return null;
  return Math.round(foreign * rate * 100) / 100;
});

watch([settlementCurrency, foreignAmount, exchangeRate], () => {
  if (settlementCurrency.value === 'BDT') {
    foreignAmount.value = null;
    exchangeRate.value = null;
    return;
  }
  if (computedBdtAmount.value != null) {
    amountBdt.value = computedBdtAmount.value;
  }
});

const methodFieldFlags = computed(() => {
  const row = methodOptions.value.find((m) => m.value === methodCode.value);
  const meta = row
    ? { code: row.code, category: row.category }
    : { code: methodCode.value.toUpperCase(), category: '' };
  return paymentMethodFieldFlags(meta);
});

const instrumentFields = computed(() => ({
  bdBankId: bdBankId.value,
  chequeNumber: chequeNumber.value,
  instrumentDate: instrumentDate.value,
  instrumentReference: instrumentReference.value,
}));

const resetInstrumentFields = () => {
  bdBankId.value = null;
  chequeNumber.value = '';
  instrumentDate.value = '';
  instrumentReference.value = '';
};

watch(methodCode, () => {
  resetInstrumentFields();
});

const defaultSettlementCurrency = () => {
  if (!props.isAp) return 'BDT';
  const groups = apBillCurrencyGroups(props.channelMeta ?? null);
  if (groups.length === 1 && groups[0]?.currency_code && groups[0].currency_code !== 'BDT') {
    return groups[0].currency_code;
  }
  return 'BDT';
};

const resetForm = () => {
  paidOn.value = localToday();
  settlementCurrency.value = defaultSettlementCurrency();
  foreignAmount.value = null;
  exchangeRate.value = null;
  amountBdt.value = Math.max(0, Number(props.dueAmount) || 0);
  methodCode.value = 'bank_transfer';
  reference.value = '';
  note.value = '';
  resetInstrumentFields();
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      void loadPaymentMeta();
      resetForm();
    }
  },
);

const allocToBill = computed(() => {
  const amt = Number(amountBdt.value) || 0;
  const due = Math.max(0, Number(props.dueAmount) || 0);
  return Math.min(amt, due);
});

const paymentLeftover = computed(() => {
  const amt = Number(amountBdt.value) || 0;
  return Math.max(0, amt - allocToBill.value);
});

const paymentOverDue = computed(
  () => paymentLeftover.value > 0 && allocToBill.value > 0,
);

const submitDisabledReason = computed(() => {
  const amt = Number(amountBdt.value);
  if (!amt || amt <= 0) return 'Enter a payment amount';
  if (settlementCurrency.value !== 'BDT') {
    if (computedBdtAmount.value == null) return 'Enter foreign amount and exchange rate';
    if (Math.round(amt * 100) !== Math.round(computedBdtAmount.value * 100)) {
      return 'BDT amount must match foreign × rate';
    }
  }
  return paymentInstrumentExtrasBlockReason(methodFieldFlags.value, instrumentFields.value);
});

const close = () => emit('update:modelValue', false);

const submit = () => {
  if (submitDisabledReason.value) return;
  const amt = Number(amountBdt.value);
  emit('submit', {
    tenantId: props.tenantId,
    billId: props.billId,
    isAp: props.isAp,
    profileId: props.profileId,
    paidOn: paidOn.value,
    amountBdt: amt,
    billDueAmount: props.dueAmount,
    settlementCurrencyCode: settlementCurrency.value,
    foreignAmount: settlementCurrency.value === 'BDT' ? null : Number(foreignAmount.value),
    exchangeRate: settlementCurrency.value === 'BDT' ? null : Number(exchangeRate.value),
    methodCode: methodCode.value,
    reference: reference.value.trim() || null,
    note: note.value.trim() || null,
    instrumentFields: instrumentFields.value,
  });
};
</script>

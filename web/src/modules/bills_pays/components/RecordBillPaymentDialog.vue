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
          v-if="isAp"
          v-model="payFromPotId"
          :options="payFromOptions"
          emit-value
          map-options
          outlined
          dense
          label="Pay from (location & currency)"
          hint="Till, safe, or bank — and which cash pot"
          :loading="payFromLoading"
        />

        <template v-if="isAp">
          <q-select
            v-model="apPaymentCurrency"
            :options="settlementCurrencyOptions"
            emit-value
            map-options
            outlined
            dense
            label="Payment currency"
            hint="Currency you record this pay-out in"
          />
          <p v-if="apNeedsCurrencyShift" class="text-caption text-grey-7 q-mb-none">
            {{ apCurrencyShiftHint }}
          </p>
          <template v-if="apNeedsSeparateBooksFx">
            <q-input
              v-model.number="apForeignAmount"
              outlined
              dense
              :label="`Amount (${apPaymentCurrency})`"
              type="number"
              step="0.01"
            />
            <q-input
              v-model.number="apBooksExchangeRate"
              outlined
              dense
              :label="apBooksCashRateLabel"
              type="number"
              step="0.0001"
            />
          </template>
          <template v-else-if="apNeedsBooksFx">
            <q-input
              v-model.number="apForeignAmount"
              outlined
              dense
              :label="`Amount (${apPaymentCurrency})`"
              type="number"
              step="0.01"
            />
          </template>
          <q-input
            v-if="apNeedsCurrencyShift"
            v-model.number="apTransactionRate"
            outlined
            dense
            :label="apPotCashRateLabel"
            type="number"
            step="0.0001"
            :hint="
              apNeedsBooksFx && !apNeedsSeparateBooksFx
                ? `Also converts to ${booksCurrencyCode} in the books`
                : 'How much pot cash per 1 unit of payment currency'
            "
          />
          <div
            v-if="apNeedsBooksFx && apComputedBooksBdt != null"
            class="text-caption text-grey-8"
          >
            Books ({{ booksCurrencyCode }}): {{ formatAmountBdt(apComputedBooksBdt) }}
          </div>
          <q-input
            v-if="!apNeedsBooksFx"
            v-model.number="amountBdt"
            outlined
            dense
            :label="`Payment amount (${booksCurrencyCode})`"
            type="number"
            step="0.01"
          />
        </template>

        <template v-else>
          <q-select
            v-model="settlementCurrency"
            :options="settlementCurrencyOptions"
            emit-value
            map-options
            outlined
            dense
            label="Payment currency"
          />
          <template v-if="collectNeedsBooksFx">
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
              :label="`${booksCurrencyCode} rate (per 1 ${settlementCurrency})`"
              type="number"
              step="0.0001"
            />
          </template>
          <div
            v-if="collectNeedsBooksFx && computedBdtAmount != null"
            class="text-caption text-grey-8"
          >
            Books ({{ booksCurrencyCode }}): {{ formatAmountBdt(computedBdtAmount) }}
          </div>
          <q-input
            v-if="!collectNeedsBooksFx"
            v-model.number="amountBdt"
            outlined
            dense
            :label="`Payment amount (${booksCurrencyCode})`"
            type="number"
            step="0.01"
          />
        </template>

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
import { useApPayoutFxFields } from '../composables/useApPayoutFxFields';
import { useBooksCurrencyCode } from '../composables/useBooksCurrencyCode';
import { useCashbookPayFromPotSelect } from '../composables/useCashbookPayFromPotSelect';
import { useCashbookPointsQuery } from '../composables/useCashbookPointsQuery';
import {
  paymentInstrumentExtrasBlockReason,
  paymentMethodFieldFlags,
} from '../utils/paymentInstrumentFields';
import { apBillBooksDueBdt } from '../utils/apBillBooks';
import { apBillCurrencyGroups, apBillPaperConversionRate } from '../utils/parseApBillPaper';
import { currenciesMatch } from '../utils/apPayoutFx';
import type { RecordBillPaymentInput } from '../composables/useRecordBillPaymentMutation';

const props = defineProps<{
  modelValue: boolean;
  dueAmount: number;
  billId: number;
  profileId: number;
  tenantId: number;
  /** Parent books tenant — cash points load from tenant cashbook. */
  booksTenantId: number;
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
const settlementCurrency = ref('BDT'); // reset on open via defaultSettlementCurrency()
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

const pointsContext = computed(() => ({
  booksTenantId: props.booksTenantId,
  entityType: 'tenant',
  entityId: props.booksTenantId,
  enabled: props.modelValue && props.isAp && props.booksTenantId > 0,
}));
const { pointsQuery } = useCashbookPointsQuery(pointsContext);
const apPoints = computed(() => pointsQuery.data.value);
const payFromEnabled = computed(
  () => props.modelValue && props.isAp && props.booksTenantId > 0,
);
const {
  selectedPotId: payFromPotId,
  payFromOptions,
  cashbookPointId,
  sourceCurrencyCode,
  loading: payFromLoading,
} = useCashbookPayFromPotSelect(apPoints, payFromEnabled);

const booksCurrencyCode = useBooksCurrencyCode();

const collectNeedsBooksFx = computed(
  () => !currenciesMatch(settlementCurrency.value, booksCurrencyCode.value),
);

const {
  paymentCurrency: apPaymentCurrency,
  foreignAmount: apForeignAmount,
  booksExchangeRate: apBooksExchangeRate,
  transactionRate: apTransactionRate,
  needsTransactionRate: apNeedsTransactionRate,
  needsCurrencyShift: apNeedsCurrencyShift,
  currencyShiftHint: apCurrencyShiftHint,
  potCashRateLabel: apPotCashRateLabel,
  booksCashRateLabel: apBooksCashRateLabel,
  needsBooksFx: apNeedsBooksFx,
  needsSeparateBooksFx: apNeedsSeparateBooksFx,
  computedBooksBdt: apComputedBooksBdt,
  resetFxAmounts: resetApFxAmounts,
  validateFxFields: validateApFxFields,
  settlementFxPayload: apSettlementFxPayload,
  sourceFxPayload: apSourceFxPayload,
} = useApPayoutFxFields(sourceCurrencyCode, amountBdt, booksCurrencyCode);

const { data: currenciesData } = useGlobalCurrenciesQuery();

const settlementCurrencyOptions = computed(() => {
  const fromRef = (currenciesData.value ?? [])
    .filter((c) => c.is_active)
    .map((c) => ({ label: `${c.code} — ${c.name}`, value: c.code }));
  const codes = new Set(fromRef.map((o) => o.value));
  const base = booksCurrencyCode.value;
  if (!codes.has(base)) {
    fromRef.unshift({ label: base, value: base });
  }
  return fromRef.sort((a, b) =>
    a.value === base ? -1 : b.value === base ? 1 : a.value.localeCompare(b.value),
  );
});

const computedBdtAmount = computed(() => {
  if (!collectNeedsBooksFx.value) return null;
  const foreign = foreignAmount.value;
  const rate = exchangeRate.value;
  if (foreign == null || rate == null || foreign <= 0 || rate <= 0) return null;
  return Math.round(foreign * rate * 100) / 100;
});

watch([settlementCurrency, foreignAmount, exchangeRate], () => {
  if (!props.isAp) {
    if (!collectNeedsBooksFx.value) {
      foreignAmount.value = null;
      exchangeRate.value = null;
      return;
    }
    if (computedBdtAmount.value != null) {
      amountBdt.value = computedBdtAmount.value;
    }
  }
});

watch(payFromPotId, () => {
  if (props.isAp) resetApFxAmounts();
  else {
    foreignAmount.value = null;
    exchangeRate.value = null;
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
  const base = booksCurrencyCode.value;
  if (!props.isAp) return base;
  const groups = apBillCurrencyGroups(props.channelMeta ?? null);
  if (groups.length === 1 && groups[0]?.currency_code && groups[0].currency_code !== base) {
    return groups[0].currency_code;
  }
  return base;
};

const resetForm = () => {
  paidOn.value = localToday();
  const defaultPayCur = defaultSettlementCurrency();
  settlementCurrency.value = defaultPayCur;
  if (props.isAp) {
    apPaymentCurrency.value = defaultPayCur;
    resetApFxAmounts();
  }
  foreignAmount.value = null;
  exchangeRate.value = null;
  const paperRate = apBillPaperConversionRate(props.channelMeta ?? null);
  amountBdt.value = Math.max(
    0,
    apBillBooksDueBdt(props.channelMeta ?? null, Number(props.dueAmount) || 0, paperRate),
  );
  methodCode.value = 'bank_transfer';
  reference.value = '';
  note.value = '';
  payFromPotId.value = null;
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

const booksDueBdt = computed(() => {
  const fxRate = props.isAp
    ? apNeedsSeparateBooksFx.value
      ? Number(apBooksExchangeRate.value) || null
      : apNeedsBooksFx.value
        ? Number(apTransactionRate.value) || null
        : null
    : collectNeedsBooksFx.value
      ? Number(exchangeRate.value) || null
      : null;
  return apBillBooksDueBdt(props.channelMeta ?? null, Number(props.dueAmount) || 0, fxRate);
});

const allocToBill = computed(() => {
  const amt = Number(amountBdt.value) || 0;
  const due = Math.max(0, booksDueBdt.value);
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
  if (props.isAp) {
    if (payFromLoading.value) return 'Loading pay-from locations…';
    if (!payFromPotId.value) return 'Choose location and currency to pay from';
    const fxReason = validateApFxFields();
    if (fxReason) return fxReason;
  } else if (collectNeedsBooksFx.value) {
    if (computedBdtAmount.value == null) {
      return `Enter payment currency amount and ${booksCurrencyCode.value} rate`;
    }
    if (Math.round(amt * 100) !== Math.round(computedBdtAmount.value * 100)) {
      return `Books amount (${booksCurrencyCode.value}) must match payment currency × rate`;
    }
  }
  return paymentInstrumentExtrasBlockReason(methodFieldFlags.value, instrumentFields.value);
});

const close = () => emit('update:modelValue', false);

const submit = () => {
  if (submitDisabledReason.value) return;
  const amt = Number(amountBdt.value);
  const fx = props.isAp
    ? { ...apSettlementFxPayload(), ...apSourceFxPayload(payFromPotId.value) }
    : {
        settlement_currency_code: settlementCurrency.value,
        foreign_amount: collectNeedsBooksFx.value ? Number(foreignAmount.value) : null,
        exchange_rate: collectNeedsBooksFx.value ? Number(exchangeRate.value) : null,
      };
  emit('submit', {
    tenantId: props.tenantId,
    billId: props.billId,
    isAp: props.isAp,
    profileId: props.profileId,
    paidOn: paidOn.value,
    amountBdt: amt,
    billDueAmount: booksDueBdt.value,
    settlementCurrencyCode: fx.settlement_currency_code,
    booksCurrencyCode: booksCurrencyCode.value,
    foreignAmount: fx.foreign_amount,
    exchangeRate: fx.exchange_rate,
    methodCode: methodCode.value,
    reference: reference.value.trim() || null,
    note: note.value.trim() || null,
    sourceCurrencyCode: props.isAp ? fx.source_currency_code : null,
    transactionRate: props.isAp ? fx.transaction_rate : null,
    cashbookPointPotId: props.isAp ? fx.cashbook_point_pot_id : null,
    cashbookPointId: props.isAp ? cashbookPointId.value : null,
    instrumentFields: instrumentFields.value,
  });
};
</script>

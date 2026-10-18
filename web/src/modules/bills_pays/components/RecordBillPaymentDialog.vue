<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="record-bill-payment-card" style="width: min(480px, 92vw)">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">{{ isAp ? 'Pay out' : 'Collect payment' }}</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-card-section class="q-gutter-y-md q-pt-sm">
        <div class="text-body2 text-weight-bold record-bill-payment-due">
          Due on this bill:
          <span class="font-mono">{{ dueAmountDisplay }}</span>
        </div>
        <div v-if="paymentOverDue" class="text-caption text-grey-8">
          {{ formatAmountBdt(allocToBill) }} applies to this bill.
          {{ formatAmountBdt(paymentLeftover) }} stays unallocated on the payment.
        </div>

        <BillDialogField label="Payment date">
          <q-input v-model="paidOn" outlined dense mask="####-##-##" hide-bottom-space>
            <template #prepend>
              <BillDialogFieldIcon name="ph ph-calendar-blank" />
            </template>
            <template #append>
              <q-icon name="ph ph-calendar" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="paidOn" mask="YYYY-MM-DD" />
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
        </BillDialogField>

        <BillDialogField
          v-if="isAp"
          label="Pay from (location & currency)"
          hint="Till, safe, or bank — and which cash pot"
        >
          <q-select
            v-model="payFromPotId"
            :options="payFromOptions"
            emit-value
            map-options
            outlined
            dense
            hide-bottom-space
            :loading="payFromLoading"
          >
            <template #prepend>
              <BillDialogFieldIcon name="ph ph-wallet" />
            </template>
          </q-select>
        </BillDialogField>

        <template v-if="isAp">
          <BillDialogField label="Payment currency" hint="Currency you record this pay-out in">
            <q-select
              v-model="apPaymentCurrency"
              :options="settlementCurrencyOptions"
              emit-value
              map-options
              outlined
              dense
              hide-bottom-space
            >
              <template #prepend>
                <BillDialogFieldIcon name="ph ph-coins" />
              </template>
            </q-select>
          </BillDialogField>
          <p v-if="apNeedsCurrencyShift" class="text-caption text-grey-7 q-mb-none">
            {{ apCurrencyShiftHint }}
          </p>
          <template v-if="apNeedsSeparateBooksFx">
            <BillDialogField :label="`Amount (${apPaymentCurrency})`">
              <q-input
                v-model.number="apForeignAmount"
                outlined
                dense
                type="number"
                step="0.01"
                hide-bottom-space
              >
                <template #prepend>
                  <BillDialogFieldIcon name="ph ph-money" />
                </template>
              </q-input>
            </BillDialogField>
            <BillDialogField :label="apBooksCashRateLabel">
              <q-input
                v-model.number="apBooksExchangeRate"
                outlined
                dense
                type="number"
                step="0.0001"
                hide-bottom-space
              >
                <template #prepend>
                  <BillDialogFieldIcon name="ph ph-arrows-left-right" />
                </template>
              </q-input>
            </BillDialogField>
          </template>
          <template v-else-if="apNeedsBooksFx">
            <BillDialogField :label="`Amount (${apPaymentCurrency})`">
              <q-input
                v-model.number="apForeignAmount"
                outlined
                dense
                type="number"
                step="0.01"
                hide-bottom-space
              >
                <template #prepend>
                  <BillDialogFieldIcon name="ph ph-money" />
                </template>
              </q-input>
            </BillDialogField>
          </template>
          <BillDialogField
            v-if="apNeedsCurrencyShift"
            :label="apPotCashRateLabel"
            :hint="
              apNeedsBooksFx && !apNeedsSeparateBooksFx
                ? `Also converts to ${booksCurrencyCode} in the books`
                : 'How much pot cash per 1 unit of payment currency'
            "
          >
            <q-input
              v-model.number="apTransactionRate"
              outlined
              dense
              type="number"
              step="0.0001"
              hide-bottom-space
            >
              <template #prepend>
                <BillDialogFieldIcon name="ph ph-arrows-left-right" />
              </template>
            </q-input>
          </BillDialogField>
          <div
            v-if="apNeedsBooksFx && apComputedBooksBdt != null"
            class="text-caption text-grey-8"
          >
            Books ({{ booksCurrencyCode }}): {{ formatAmountBdt(apComputedBooksBdt) }}
          </div>
          <BillDialogField v-if="!apNeedsBooksFx" :label="`Payment amount (${booksCurrencyCode})`">
            <q-input
              v-model.number="amountBdt"
              outlined
              dense
              type="number"
              step="0.01"
              hide-bottom-space
            >
              <template #prepend>
                <BillDialogFieldIcon name="ph ph-money" />
              </template>
            </q-input>
          </BillDialogField>
        </template>

        <template v-else>
          <BillDialogField label="Payment currency">
            <q-select
              v-model="settlementCurrency"
              :options="settlementCurrencyOptions"
              emit-value
              map-options
              outlined
              dense
              hide-bottom-space
            >
              <template #prepend>
                <BillDialogFieldIcon name="ph ph-coins" />
              </template>
            </q-select>
          </BillDialogField>
          <template v-if="collectNeedsBooksFx">
            <BillDialogField :label="`Amount (${settlementCurrency})`">
              <q-input
                v-model.number="foreignAmount"
                outlined
                dense
                type="number"
                step="0.01"
                hide-bottom-space
              >
                <template #prepend>
                  <BillDialogFieldIcon name="ph ph-money" />
                </template>
              </q-input>
            </BillDialogField>
            <BillDialogField :label="`${booksCurrencyCode} rate (per 1 ${settlementCurrency})`">
              <q-input
                v-model.number="exchangeRate"
                outlined
                dense
                type="number"
                step="0.0001"
                hide-bottom-space
              >
                <template #prepend>
                  <BillDialogFieldIcon name="ph ph-arrows-left-right" />
                </template>
              </q-input>
            </BillDialogField>
          </template>
          <div
            v-if="collectNeedsBooksFx && computedBdtAmount != null"
            class="text-caption text-grey-8"
          >
            Books ({{ booksCurrencyCode }}): {{ formatAmountBdt(computedBdtAmount) }}
          </div>
          <BillDialogField v-if="!collectNeedsBooksFx" :label="`Payment amount (${booksCurrencyCode})`">
            <q-input
              v-model.number="amountBdt"
              outlined
              dense
              type="number"
              step="0.01"
              hide-bottom-space
            >
              <template #prepend>
                <BillDialogFieldIcon name="ph ph-money" />
              </template>
            </q-input>
          </BillDialogField>
        </template>

        <BillDialogField label="Method">
          <q-select
            v-model="methodCode"
            :options="methodOptions"
            emit-value
            map-options
            outlined
            dense
            hide-bottom-space
            :loading="loadingPaymentMeta"
          >
            <template #prepend>
              <BillDialogFieldIcon name="ph ph-credit-card" />
            </template>
          </q-select>
        </BillDialogField>

        <PaymentInstrumentExtrasFields
          external-labels
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

        <BillDialogField label="Payment reference (optional)">
          <q-input v-model="reference" outlined dense clearable hide-bottom-space>
            <template #prepend>
              <BillDialogFieldIcon name="ph ph-hash" />
            </template>
          </q-input>
        </BillDialogField>
        <BillDialogField label="Notes">
          <q-input v-model="note" outlined dense type="textarea" autogrow hide-bottom-space>
            <template #prepend>
              <BillDialogFieldIcon name="ph ph-note" />
            </template>
          </q-input>
        </BillDialogField>
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
import { formatAmountBdt, formatSettlementCurrencyAmount } from 'src/utils/currency';
import BillDialogField from './BillDialogField.vue';
import BillDialogFieldIcon from './BillDialogFieldIcon.vue';
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
import {
  apBillBooksDueBdt,
  apBillDueStoresForeignFace,
  apBillPaperCurrencyCode,
} from '../utils/apBillBooks';
import { apBillCurrencyGroups, apBillPaperConversionRate } from '../utils/parseApBillPaper';
import { currenciesMatch } from '../utils/apPayoutFx';
import type { RecordBillPaymentInput } from '../composables/useRecordBillPaymentMutation';

const props = defineProps<{
  modelValue: boolean;
  dueAmount: number;
  /** Bill header due currency (e.g. GBP on AP voucher, BDT on AR). */
  dueCurrencyCode?: string | null;
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

const billDueCurrencyCode = computed(() => {
  const explicit = props.dueCurrencyCode?.trim();
  if (explicit) return explicit.toUpperCase();
  const due = Number(props.dueAmount) || 0;
  if (props.isAp && apBillDueStoresForeignFace(props.channelMeta ?? null, due)) {
    return apBillPaperCurrencyCode(props.channelMeta ?? null);
  }
  return booksCurrencyCode.value;
});

const dueAmountDisplay = computed(() =>
  formatSettlementCurrencyAmount(props.dueAmount, billDueCurrencyCode.value),
);

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
      void loadPaymentMeta((code) => {
        methodCode.value = code;
      });
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
    sourceCurrencyCode:
      props.isAp && 'source_currency_code' in fx ? fx.source_currency_code : null,
    transactionRate: props.isAp && 'transaction_rate' in fx ? fx.transaction_rate : null,
    cashbookPointPotId:
      props.isAp && 'cashbook_point_pot_id' in fx ? fx.cashbook_point_pot_id : null,
    cashbookPointId: props.isAp ? cashbookPointId.value : null,
    instrumentFields: instrumentFields.value,
  });
};
</script>

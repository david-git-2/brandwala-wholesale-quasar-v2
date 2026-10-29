<template>
  <q-card
      class="record-bill-payment-card"
      :class="{ 'record-bill-payment-card--embedded': embedded }"
      :style="embedded ? undefined : { width: 'min(440px, 92vw)' }"
    >
      <q-card-section v-if="!embedded" class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">{{ isAp ? 'Pay out' : 'Collect payment' }}</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-card-section class="q-pt-sm">
        <div class="record-bill-payment-form">
        <q-banner
          v-if="replacingPayId"
          dense
          rounded
          class="record-bill-payment-replace-banner"
        >
          <template #avatar>
            <q-icon name="ph ph-warning" color="warning" />
          </template>
          Replacing voided pay #{{ replacingPayId }}. Check amount and rate, then post the new payment.
        </q-banner>

        <div class="record-bill-payment-summary">
          <div class="text-caption text-grey-7">Due on this bill</div>
          <div class="text-subtitle1 text-weight-bold font-mono q-mt-xs">{{ dueAmountDisplay }}</div>
          <div
            v-if="isAp && payFromPotId && !showApPayFromField"
            class="text-caption text-grey-7 q-mt-xs"
          >
            Pay from {{ payFromPotLabel }}
          </div>
        </div>

        <div v-if="paymentOverDue" class="text-caption text-grey-8">
          {{ formatAmountBdt(allocToBill) }} on this bill ·
          {{ formatAmountBdt(paymentLeftover) }} unallocated
        </div>

        <q-banner
          v-if="!isAp && applyOpenFirstAvailable"
          dense
          rounded
          class="bg-blue-1 text-blue-10"
        >
          <q-checkbox v-model="applyOpenFirst" dense label="Apply open credit notes and pay leftover to this bill first" />
        </q-banner>

        <template v-if="isAp">
          <q-select
            v-if="showApPaymentCurrencySelect"
            v-model="apPaymentCurrency"
            :options="settlementCurrencyOptions"
            emit-value
            map-options
            outlined
            dense
            hide-bottom-space
            label="Payment currency"
          />

          <div
            v-if="apNeedsSeparateBooksFx"
            class="record-bill-payment-split record-bill-payment-split--wide-narrow"
          >
              <q-input
                v-model.number="apForeignAmount"
                outlined
                dense
                type="number"
                step="0.01"
                min="0"
                hide-bottom-space
                :label="apAmountInputLabel"
                class="record-bill-payment-amount"
              />
              <q-input
                v-model.number="apBooksExchangeRate"
                outlined
                dense
                type="number"
                step="0.0001"
                min="0"
                hide-bottom-space
                :label="apBooksCashRateLabel"
              />
          </div>
          <template v-else-if="apNeedsBooksFx">
            <div
              v-if="apNeedsCurrencyShift"
              class="record-bill-payment-split record-bill-payment-split--wide-narrow"
            >
              <q-input
                v-model.number="apForeignAmount"
                outlined
                dense
                type="number"
                step="0.01"
                min="0"
                hide-bottom-space
                :label="apAmountInputLabel"
                class="record-bill-payment-amount"
              />
              <q-input
                v-model.number="apTransactionRate"
                outlined
                dense
                type="number"
                step="0.0001"
                min="0"
                hide-bottom-space
                :label="apPotCashRateLabel"
              />
            </div>
            <q-input
              v-else
              v-model.number="apForeignAmount"
              outlined
              dense
              type="number"
              step="0.01"
              min="0"
              hide-bottom-space
              :label="apAmountInputLabel"
              class="record-bill-payment-amount"
            />
          </template>
          <div
            v-else-if="apUsesForeignPaymentAmount"
            class="record-bill-payment-split record-bill-payment-split--wide-narrow"
          >
            <q-input
              v-model.number="apForeignAmount"
              outlined
              dense
              type="number"
              step="0.01"
              min="0"
              hide-bottom-space
              :label="apAmountInputLabel"
              class="record-bill-payment-amount"
            />
            <q-input
              v-model.number="apBooksExchangeRate"
              outlined
              dense
              type="number"
              step="0.0001"
              min="0"
              hide-bottom-space
              :label="apBooksCashRateLabel"
            />
          </div>
          <q-input
            v-else-if="!apShowForeignAmountField"
            v-model.number="amountBdt"
            outlined
            dense
            type="number"
            step="0.01"
            min="0"
            hide-bottom-space
            :label="`Amount (${booksCurrencyCode})`"
            class="record-bill-payment-amount"
          />

          <div
            v-if="apBooksAmountPreview != null"
            class="text-caption text-grey-7"
          >
            In books ({{ booksCurrencyCode }}): {{ formatAmountBdt(apBooksAmountPreview) }}
          </div>

          <q-select
            v-if="showApPayFromField"
            v-model="payFromPotId"
            :options="payFromOptions"
            emit-value
            map-options
            outlined
            dense
            hide-bottom-space
            label="Pay from"
            :loading="payFromLoading"
          />
        </template>

        <template v-else>
          <q-select
            v-model="collectReceivePotId"
            :options="collectReceiveOptions"
            emit-value
            map-options
            outlined
            dense
            hide-bottom-space
            class="q-mb-sm"
            label="Receive into"
            :loading="collectReceiveLoading"
          />
          <q-input
            v-if="collectPotNeedsFx"
            v-model.number="collectTransactionRate"
            outlined
            dense
            type="number"
            step="0.0001"
            min="0"
            hide-bottom-space
            class="q-mb-sm"
            :label="`${booksCurrencyCode} per 1 ${collectPotCurrency}`"
          />
          <q-select
            v-if="collectNeedsBooksFx || settlementCurrencyOptions.length > 1"
            v-model="settlementCurrency"
            :options="settlementCurrencyOptions"
            emit-value
            map-options
            outlined
            dense
            hide-bottom-space
            label="Payment currency"
          />
          <div
            v-if="collectNeedsBooksFx"
            class="record-bill-payment-split record-bill-payment-split--wide-narrow"
          >
              <q-input
                v-model.number="foreignAmount"
                outlined
                dense
                type="number"
                step="0.01"
                min="0"
                hide-bottom-space
                :label="`Amount (${settlementCurrency})`"
                class="record-bill-payment-amount"
              />
              <q-input
                v-model.number="exchangeRate"
                outlined
                dense
                type="number"
                step="0.0001"
                min="0"
                hide-bottom-space
                :label="`${booksCurrencyCode} per 1 ${settlementCurrency}`"
              />
          </div>
          <q-input
            v-else
            v-model.number="amountBdt"
            outlined
            dense
            type="number"
            step="0.01"
            min="0"
            hide-bottom-space
            :label="`Amount (${booksCurrencyCode})`"
            class="record-bill-payment-amount"
          />
          <div
            v-if="collectNeedsBooksFx && computedBdtAmount != null"
            class="text-caption text-grey-7"
          >
            In books ({{ booksCurrencyCode }}): {{ formatAmountBdt(computedBdtAmount) }}
          </div>
        </template>

        <div class="record-bill-payment-split">
          <q-input
            v-model="paidOn"
            outlined
            dense
            stack-label
            mask="####-##-##"
            hide-bottom-space
            label="Date"
          >
            <template #append>
              <q-icon name="ph ph-calendar" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="paidOn" mask="YYYY-MM-DD" />
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
          <q-select
            v-model="methodCode"
            :options="methodOptions"
            emit-value
            map-options
            outlined
            dense
            hide-bottom-space
            :label="isAp ? 'Method' : 'How they paid'"
            :loading="loadingPaymentMeta"
            :disable="loadingPaymentMeta && !methodOptions.length"
          />
        </div>

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

        <q-expansion-item
          class="record-bill-payment-more"
          dense
          dense-toggle
          expand-icon-class="text-grey-7"
          header-class="record-bill-payment-more-header"
          label="Reference & note (optional)"
        >
          <div class="q-gutter-y-sm q-pt-xs">
            <q-input
              v-model="reference"
              outlined
              dense
              clearable
              hide-bottom-space
              label="Reference"
            />
            <q-input
              v-model="note"
              outlined
              dense
              autogrow
              hide-bottom-space
              label="Note"
            />
          </div>
        </q-expansion-item>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md q-pt-none">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Add payment"
          :loading="loading || preApplySubmitting"
          :disable="!!submitDisabledReason"
          @click="submit"
        >
          <q-tooltip v-if="submitDisabledReason">{{ submitDisabledReason }}</q-tooltip>
        </q-btn>
      </q-card-actions>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { useGlobalReferenceStore } from 'src/modules/global_reference/stores/globalReferenceStore';
import { formatAmountBdt, formatSettlementCurrencyAmount } from 'src/utils/currency';
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
} from '../utils/apBillBooks';
import { apBillCurrencyGroups, apBillPaperConversionRate, apBillPaperCurrencyCode } from '../utils/parseApBillPaper';
import { currenciesMatch, defaultApPaymentCurrency } from '../utils/apPayoutFx';
import type { RecordBillPaymentInput } from '../composables/useRecordBillPaymentMutation';
import type { PayCorrectionSnapshot } from '../types/payCorrectionSnapshot';
import { billsRepository } from '../repositories/billsRepository';
import { useApplySettlementMutation } from '../composables/useApplySettlementMutation';
import { useBooksExchangeRateQuery } from '../composables/useBooksExchangeRateQuery';
import { buildPreApplySettlementLines } from '../utils/fifoBillAlloc';

const props = defineProps<{
  modelValue: boolean;
  embedded?: boolean;
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
  shipmentId?: number | null;
  replacingPayId?: number | null;
  prefillSnapshot?: PayCorrectionSnapshot | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: RecordBillPaymentInput];
  cancel: [];
}>();

const dialogActive = computed(() => props.modelValue || !!props.embedded);

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
const applyOpenFirst = ref(false);
const applyOpenFirstAvailable = ref(false);
const preApplyPools = ref<Array<{ kind: 'credit_note' | 'pay'; allocator_id: number; pool: number }>>([]);
const preApplySubmitting = ref(false);
const preApplyMutation = useApplySettlementMutation({ successMessage: 'Open credit and leftover applied.' });
const { loadingPaymentMeta, methodOptions, bdBankOptions, syncPaymentMetaDefaults } =
  useWholesalePaymentMethodMeta('bank_transfer', () => dialogActive.value);

const pointsContext = computed(() => ({
  booksTenantId: props.booksTenantId,
  entityType: 'tenant',
  entityId: props.booksTenantId,
  enabled: dialogActive.value && props.isAp && props.booksTenantId > 0,
}));
const { pointsQuery } = useCashbookPointsQuery(pointsContext);
const apPoints = computed(() => pointsQuery.data.value);
const payFromEnabled = computed(
  () => dialogActive.value && props.isAp && props.booksTenantId > 0,
);
const {
  selectedPotId: payFromPotId,
  payFromOptions,
  cashbookPointId,
  sourceCurrencyCode,
  loading: payFromLoading,
} = useCashbookPayFromPotSelect(apPoints, payFromEnabled);

const booksCurrencyCode = useBooksCurrencyCode();

const collectPointsContext = computed(() => ({
  booksTenantId: props.booksTenantId,
  entityType: 'tenant',
  entityId: props.booksTenantId,
  enabled: dialogActive.value && !props.isAp && props.booksTenantId > 0,
}));
const { pointsQuery: collectPointsQuery } = useCashbookPointsQuery(collectPointsContext);
const collectPoints = computed(() => collectPointsQuery.data.value);
const collectReceiveEnabled = computed(
  () => dialogActive.value && !props.isAp && props.booksTenantId > 0,
);
const {
  selectedPotId: collectReceivePotId,
  payFromOptions: collectReceiveOptions,
  cashbookPointId: collectCashbookPointId,
  sourceCurrencyCode: collectPotCurrency,
  loading: collectReceiveLoading,
} = useCashbookPayFromPotSelect(collectPoints, collectReceiveEnabled);

const collectPotNeedsFx = computed(
  () => !props.isAp && collectPotCurrency.value !== booksCurrencyCode.value,
);
const collectTransactionRate = ref<number | null>(null);
const collectFxRateQuery = useBooksExchangeRateQuery(
  computed(() => props.booksTenantId),
  collectPotCurrency,
  computed(() => dialogActive.value && !props.isAp && collectPotNeedsFx.value),
);
watch(
  () => collectFxRateQuery.data.value,
  (rate) => {
    if (rate != null && collectPotNeedsFx.value) collectTransactionRate.value = rate;
  },
);

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
  needsCurrencyShift: apNeedsCurrencyShift,
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

/** Bill due in foreign (e.g. GBP) while books stay BDT — always pay in bill currency, not books. */
const apUsesForeignPaymentAmount = computed(
  () => props.isAp && !currenciesMatch(billDueCurrencyCode.value, booksCurrencyCode.value),
);

const apShowForeignAmountField = computed(
  () => apNeedsBooksFx.value || apUsesForeignPaymentAmount.value,
);

const apAmountInputLabel = computed(() => {
  const code = apUsesForeignPaymentAmount.value
    ? billDueCurrencyCode.value
    : apPaymentCurrency.value;
  return `Amount (${code})`;
});

const syncApPaymentCurrencyFromBill = () => {
  if (!props.isAp) return;
  const cur = billDueCurrencyCode.value;
  apPaymentCurrency.value = cur;
  settlementCurrency.value = cur;
};

const showApPayFromField = computed(() => payFromOptions.value.length > 1);

const showApPaymentCurrencySelect = computed(() => {
  if (!props.isAp) return false;
  return apBillCurrencyGroups(props.channelMeta ?? null).length > 1;
});

const payFromPotLabel = computed(() => {
  const id = payFromPotId.value;
  const row = payFromOptions.value.find((o) => o.value === id);
  return row?.label ?? '';
});

const globalRefStore = useGlobalReferenceStore();
const { currencies: currenciesData } = storeToRefs(globalRefStore);

watch(
  () => dialogActive.value,
  (open) => {
    if (open && currenciesData.value.length === 0) {
      void globalRefStore.ensureCurrenciesLoaded();
    }
  },
);

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

watch(sourceCurrencyCode, (next, prev) => {
  if (prev === next) return;
  if (props.isAp) {
    if (payFromPotId.value == null) return;
    resetApFxAmounts();
  } else {
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
  const dueCur = billDueCurrencyCode.value;
  if (dueCur && !currenciesMatch(dueCur, base)) {
    return dueCur;
  }
  return defaultApPaymentCurrency([{ channel_meta: props.channelMeta ?? null }], base);
};

const resetForm = () => {
  paidOn.value = localToday();
  syncApPaymentCurrencyFromBill();
  const defaultPayCur = billDueCurrencyCode.value;
  settlementCurrency.value = defaultPayCur;
  if (props.isAp) {
    resetApFxAmounts();
    const due = Number(props.dueAmount) || 0;
    if (due > 0 && currenciesMatch(billDueCurrencyCode.value, defaultPayCur)) {
      if (!currenciesMatch(defaultPayCur, booksCurrencyCode.value)) {
        apForeignAmount.value = due;
        const paperRate = apBillPaperConversionRate(props.channelMeta ?? null);
        if (paperRate != null && paperRate > 0) {
          apBooksExchangeRate.value = paperRate;
        }
      } else {
        amountBdt.value = due;
      }
    }
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

const applyCorrectionPrefill = (snap: PayCorrectionSnapshot) => {
  const datePart = snap.paymentDate?.slice(0, 10);
  if (datePart) paidOn.value = datePart;

  const settle = snap.settlementCurrencyCode || booksCurrencyCode.value;
  settlementCurrency.value = settle;

  if (props.isAp) {
    apPaymentCurrency.value = settle;
    if (snap.foreignAmount != null && snap.foreignAmount > 0) {
      apForeignAmount.value = snap.foreignAmount;
    }
    if (snap.transactionRate != null && snap.transactionRate > 0) {
      apTransactionRate.value = snap.transactionRate;
    }
    if (snap.exchangeRate > 0 && snap.exchangeRate !== 1) {
      apBooksExchangeRate.value = snap.exchangeRate;
    }
    if (snap.amountBdt > 0) {
      amountBdt.value = snap.amountBdt;
    }
  } else {
    if (snap.foreignAmount != null && snap.foreignAmount > 0) {
      foreignAmount.value = snap.foreignAmount;
    }
    if (snap.exchangeRate > 0) {
      exchangeRate.value = snap.exchangeRate;
    }
    if (collectPotNeedsFx.value && snap.transactionRate != null && snap.transactionRate > 0) {
      collectTransactionRate.value = snap.transactionRate;
    }
    if (snap.amountBdt > 0) {
      amountBdt.value = snap.amountBdt;
    }
  }

  if (snap.instrumentMethodCode) {
    methodCode.value = snap.instrumentMethodCode.toLowerCase();
  }
  if (snap.reference) {
    reference.value = snap.reference;
  }

  const potId = snap.cashbookPointPotId;
  if (potId != null) {
    payFromPotId.value = potId;
    collectReceivePotId.value = potId;
  }
};

watch(
  () => dialogActive.value,
  (open) => {
    if (open) {
      syncPaymentMetaDefaults((code) => {
        methodCode.value = code;
      });
      resetForm();
      const snap = props.prefillSnapshot;
      if (snap) {
        applyCorrectionPrefill(snap);
      }
    }
  },
  { immediate: true },
);

watch(
  () => [dialogActive.value, payFromLoading.value, collectReceiveLoading.value, props.prefillSnapshot] as const,
  ([open, apLoad, collectLoad, snap]) => {
    if (!open || !snap?.cashbookPointPotId) return;
    if (props.isAp && apLoad) return;
    if (!props.isAp && collectLoad) return;
    payFromPotId.value = snap.cashbookPointPotId;
    collectReceivePotId.value = snap.cashbookPointPotId;
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

const apBooksAmountPreview = computed(() => {
  if (apComputedBooksBdt.value != null) return apComputedBooksBdt.value;
  if (!apUsesForeignPaymentAmount.value) return null;
  const foreign = apForeignAmount.value;
  const rate = apBooksExchangeRate.value;
  if (foreign == null || rate == null || foreign <= 0 || rate <= 0) return null;
  return Math.round(foreign * rate * 100) / 100;
});

watch([apForeignAmount, apBooksExchangeRate, apUsesForeignPaymentAmount], () => {
  if (!props.isAp || !apUsesForeignPaymentAmount.value || apNeedsBooksFx.value) return;
  const preview = apBooksAmountPreview.value;
  if (preview != null) amountBdt.value = preview;
});

const validateApForeignPayFields = (): string | null => {
  if (!apUsesForeignPaymentAmount.value || apNeedsBooksFx.value) return null;
  if ((apForeignAmount.value ?? 0) <= 0) {
    return `Enter amount in ${billDueCurrencyCode.value}`;
  }
  if ((apBooksExchangeRate.value ?? 0) <= 0) {
    return `Enter ${booksCurrencyCode.value} rate`;
  }
  const books = apBooksAmountPreview.value;
  if (books == null) return 'Enter payment amount and books rate';
  if (Math.round((amountBdt.value ?? 0) * 100) !== Math.round(books * 100)) {
    return `Books amount (${booksCurrencyCode.value}) must match payment × rate`;
  }
  return null;
};

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
    const fxReason = validateApFxFields() ?? validateApForeignPayFields();
    if (fxReason) return fxReason;
  } else {
    if (collectReceiveLoading.value) return 'Loading receive-into locations…';
    if (!collectReceivePotId.value || !collectCashbookPointId.value) {
      return 'Choose where to receive cash';
    }
    if (
      collectPotNeedsFx.value &&
      !(collectTransactionRate.value != null && collectTransactionRate.value > 0)
    ) {
      return `Enter ${booksCurrencyCode.value} rate for this currency pot`;
    }
    if (collectNeedsBooksFx.value) {
      if (computedBdtAmount.value == null) {
        return `Enter payment currency amount and ${booksCurrencyCode.value} rate`;
      }
      if (Math.round(amt * 100) !== Math.round(computedBdtAmount.value * 100)) {
        return `Books amount (${booksCurrencyCode.value}) must match payment currency × rate`;
      }
    }
  }
  return paymentInstrumentExtrasBlockReason(methodFieldFlags.value, instrumentFields.value);
});

watch(
  () => dialogActive.value,
  async (open) => {
    applyOpenFirst.value = false;
    applyOpenFirstAvailable.value = false;
    preApplyPools.value = [];
    if (!open || props.isAp || !props.booksTenantId || !props.profileId) return;
    try {
      const openProfile = await billsRepository.listOpenOnProfile({
        parentTenantId: props.booksTenantId,
        profileId: props.profileId,
      });
      const pools: Array<{ kind: 'credit_note' | 'pay'; allocator_id: number; pool: number }> = [];
      for (const cn of (openProfile.open_credit_notes ?? []) as Array<{
        bill_id: number;
        due_amount: number;
      }>) {
        const pool = Number(cn.due_amount ?? 0);
        if (pool > 0) pools.push({ kind: 'credit_note', allocator_id: Number(cn.bill_id), pool });
      }
      for (const pl of (openProfile.pay_leftover ?? []) as Array<{
        pay_id: number;
        unallocated_amount: number;
      }>) {
        const pool = Number(pl.unallocated_amount ?? 0);
        if (pool > 0) pools.push({ kind: 'pay', allocator_id: Number(pl.pay_id), pool });
      }
      preApplyPools.value = pools;
      applyOpenFirstAvailable.value = pools.length > 0;
    } catch {
      applyOpenFirstAvailable.value = false;
    }
  },
);

const close = () => {
  if (props.embedded) {
    emit('cancel');
    return;
  }
  emit('update:modelValue', false);
};

const submit = async () => {
  if (submitDisabledReason.value) return;
  if (!props.isAp && applyOpenFirst.value && preApplyPools.value.length) {
    preApplySubmitting.value = true;
    try {
      const lines = buildPreApplySettlementLines(
        [{ id: props.billId, due_amount: booksDueBdt.value, invoice_date: paidOn.value }],
        preApplyPools.value,
      );
      if (lines.length) {
        await preApplyMutation.mutateAsync({ tenantId: props.tenantId, lines });
      }
    } finally {
      preApplySubmitting.value = false;
    }
  }
  const amt = Number(amountBdt.value);
  const fx = props.isAp
    ? {
        ...apSettlementFxPayload(),
        ...(apUsesForeignPaymentAmount.value && !apNeedsBooksFx.value
          ? {
              settlement_currency_code: billDueCurrencyCode.value,
              foreign_amount: Number(apForeignAmount.value),
              exchange_rate: Number(apBooksExchangeRate.value),
            }
          : {}),
        ...apSourceFxPayload(payFromPotId.value),
      }
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
    shipmentId: props.shipmentId ?? null,
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
    sourceCurrencyCode: props.isAp
      ? 'source_currency_code' in fx
        ? fx.source_currency_code
        : null
      : collectPotCurrency.value,
    transactionRate: props.isAp
      ? 'transaction_rate' in fx
        ? fx.transaction_rate
        : null
      : collectPotNeedsFx.value
        ? collectTransactionRate.value
        : null,
    cashbookPointPotId: props.isAp
      ? 'cashbook_point_pot_id' in fx
        ? fx.cashbook_point_pot_id
        : null
      : collectReceivePotId.value,
    cashbookPointId: props.isAp ? cashbookPointId.value : collectCashbookPointId.value,
    instrumentFields: instrumentFields.value,
  });
};
</script>

<style scoped lang="scss">
.record-bill-payment-form {
  display: flex;
  flex-direction: column;
  gap: 12px;

  :deep(.q-field) {
    margin-bottom: 0;
  }
}

.record-bill-payment-replace-banner {
  background: var(--tf-attention-soft);
  color: var(--tf-neutral-ink);
  border: 1px solid var(--tf-neutral-border);
}

.record-bill-payment-split {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  align-items: start;
}

.record-bill-payment-split--wide-narrow {
  grid-template-columns: minmax(0, 1.35fr) minmax(0, 1fr);
}

.record-bill-payment-summary {
  padding: 10px 12px;
  border-radius: 8px;
  background: var(--tf-surface-muted, rgba(0, 0, 0, 0.04));
}

.record-bill-payment-amount :deep(.q-field__native) {
  font-size: 1.05rem;
  font-weight: 600;
}

.record-bill-payment-more {
  :deep(.q-expansion-item__border) {
    display: none;
  }

  :deep(.q-item) {
    padding: 0;
    min-height: 32px;
  }
}

.record-bill-payment-more-header {
  min-height: 32px;
  padding-left: 0;
  padding-right: 0;
}
</style>

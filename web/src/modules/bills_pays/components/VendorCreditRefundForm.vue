<template>
  <div :class="pageLayout ? 'column q-gutter-y-md' : 'column q-gutter-y-md'">
    <div
      v-if="!pageLayout"
      class="q-pa-sm rounded-borders"
      style="border: 1px solid var(--tf-neutral-border)"
    >
      <div class="text-caption text-grey-7">From vendor</div>
      <div class="text-body2 text-weight-medium">{{ fromProfileName }}</div>
      <div class="text-caption text-grey-7 q-mt-sm">Into our cash</div>
      <div class="text-body2">{{ tenantLabel }}</div>
    </div>

    <div>
      <q-card v-if="pageLayout && creditNoteOptions.length > 1" flat bordered class="q-pa-md q-mb-md">
        <BillDialogField label="Credit note">
          <q-select
            :model-value="creditNoteId"
            :options="creditNoteOptions"
            emit-value
            map-options
            outlined
            dense
            @update:model-value="emit('update:creditNoteId', $event)"
          />
        </BillDialogField>
      </q-card>

      <div v-else-if="!pageLayout && creditNoteOptions.length > 1" class="column q-gutter-y-xs">
        <div class="text-caption text-weight-bold text-uppercase text-grey-7">Credit note</div>
        <q-select
          :model-value="creditNoteId"
          :options="creditNoteOptions"
          emit-value
          map-options
          outlined
          dense
          @update:model-value="emit('update:creditNoteId', $event)"
        />
      </div>

      <q-card v-if="pageLayout" flat bordered class="q-pa-md q-mb-md">
        <div class="text-caption text-weight-bold text-uppercase text-grey-7 q-mb-md">Amount</div>
        <BillDialogField label="Refund currency" hint="Currency the vendor sends">
          <q-select
            v-model="refundPaymentCurrency"
            :options="settlementCurrencyOptions"
            emit-value
            map-options
            outlined
            dense
          />
        </BillDialogField>
        <MoneyPayDialogAmountBlock
          class="q-mt-md"
          :amount="primaryPayAmount"
          :currency-code="refundPaymentCurrency"
          :max-amount="maxSettlementAmount"
          :books-preview-label="booksAmountPreviewLabel"
          data-test="vendor-refund-amount"
          @update:amount="onPrimaryAmountInput"
        />
        <template v-if="refundNeedsSeparateBooksFx">
          <BillDialogField class="q-mt-md" :label="refundBooksCashRateLabel">
            <q-input
              v-model.number="refundBooksExchangeRate"
              outlined
              dense
              type="number"
              step="0.0001"
            />
          </BillDialogField>
        </template>
        <p v-if="refundNeedsCurrencyShift" class="text-caption text-grey-7 q-mb-none q-mt-sm">
          {{ refundCurrencyShiftHint }}
        </p>
        <BillDialogField
          v-if="refundNeedsCurrencyShift"
          class="q-mt-sm"
          :label="refundPotCashRateLabel"
        >
          <q-input
            v-model.number="refundTransactionRate"
            outlined
            dense
            type="number"
            step="0.0001"
          />
        </BillDialogField>
      </q-card>

      <template v-else>
        <div class="text-caption text-grey-7">
          Open credit:
          <strong>{{ openCreditDisplay }}</strong>
        </div>
        <q-select
          v-model="refundPaymentCurrency"
          :options="settlementCurrencyOptions"
          emit-value
          map-options
          outlined
          dense
          label="Refund currency"
        />
        <MoneyPayDialogAmountBlock
          :amount="primaryPayAmount"
          :currency-code="refundPaymentCurrency"
          :max-amount="maxSettlementAmount"
          :books-preview-label="booksAmountPreviewLabel"
          @update:amount="onPrimaryAmountInput"
        />
        <template v-if="refundNeedsSeparateBooksFx">
          <q-input
            v-model.number="refundBooksExchangeRate"
            outlined
            dense
            :label="refundBooksCashRateLabel"
            type="number"
            step="0.0001"
          />
        </template>
        <q-input
          v-if="refundNeedsCurrencyShift"
          v-model.number="refundTransactionRate"
          outlined
          dense
          :label="refundPotCashRateLabel"
          type="number"
          step="0.0001"
        />
      </template>

      <q-card v-if="pageLayout" flat bordered class="q-pa-md q-mb-md">
        <PaymentLegPotChips
          v-model="receiveIntoPotId"
          leg-label="Receive at"
          :party-name="tenantLabel"
          :options="receiveIntoOptions"
          :sections="receiveIntoSections"
          :loading="receiveIntoLoading"
        />
      </q-card>

      <PaymentLegPotChips
        v-else
        v-model="receiveIntoPotId"
        leg-label="Receive at"
        :party-name="tenantLabel"
        :options="receiveIntoOptions"
        :sections="receiveIntoSections"
        :loading="receiveIntoLoading"
      />

      <q-card v-if="pageLayout" flat bordered class="q-pa-md">
        <div class="text-caption text-weight-bold text-uppercase text-grey-7 q-mb-md">
          Payment details
        </div>
        <BillDialogField label="Date received">
          <q-input v-model="receivedOn" outlined dense mask="####-##-##">
            <template #append>
              <q-icon name="ph ph-calendar" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="receivedOn" mask="YYYY-MM-DD" />
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
        </BillDialogField>
        <BillDialogField label="Note" hint="Optional" class="q-mt-md">
          <q-input v-model="note" outlined dense type="textarea" autogrow />
        </BillDialogField>
      </q-card>

      <template v-else>
        <q-input v-model="receivedOn" outlined dense label="Date received" mask="####-##-##" />
        <q-input v-model="note" outlined dense label="Note (optional)" type="textarea" autogrow />
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import { storeToRefs } from 'pinia';
import { useGlobalReferenceStore } from 'src/modules/global_reference/stores/globalReferenceStore';
import { useCashbookLegPots } from '../composables/useCashbookLegPots';
import { useBooksCurrencyCode } from '../composables/useBooksCurrencyCode';
import { useApPayoutFxFields } from '../composables/useApPayoutFxFields';
import type { PostVendorCreditRefundInput } from '../composables/usePostVendorCreditRefundMutation';
import {
  vendorRefundDefaultSettlementCurrency,
  vendorRefundInvoiceConversionRate,
  vendorRefundOpenCreditFace,
} from '../utils/vendorRefundDisplay';
import BillDialogField from './BillDialogField.vue';
import MoneyPayDialogAmountBlock from './MoneyPayDialogAmountBlock.vue';
import PaymentLegPotChips from './PaymentLegPotChips.vue';

const props = withDefaults(
  defineProps<{
    creditNoteId: number;
    parentBillId: number | null;
    openCredit: number;
    booksTenantId: number;
    /** Tenant money profile (receive leg), usually bill `from_profile_id` on AP. */
    receiveProfileId?: number | null;
    fromProfileName: string;
    tenantLabel: string;
    channelMeta?: Record<string, unknown> | null;
    creditNoteOptions?: Array<{ label: string; value: number }>;
    active?: boolean;
    /** Full-page payment flow (bill pay layout). */
    pageLayout?: boolean;
  }>(),
  { pageLayout: true },
);

const emit = defineEmits<{
  'update:creditNoteId': [value: number];
  submit: [payload: PostVendorCreditRefundInput];
  'pay-amount-change': [amount: number | null, currencyCode: string];
}>();

const pageLayout = computed(() => props.pageLayout !== false);
const formActive = computed(() => props.active !== false);

const localToday = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const receivedOn = ref(localToday());
const amountBdt = ref<number | null>(null);
const note = ref('');

const booksCurrencyCode = useBooksCurrencyCode();
const receiveProfileId = computed(() => {
  const explicit = props.receiveProfileId;
  if (explicit != null && explicit > 0) return explicit;
  return props.booksTenantId;
});
const booksTenantIdRef = computed(() => props.booksTenantId);
const receiveLegEnabled = computed(
  () => formActive.value && props.booksTenantId > 0 && receiveProfileId.value > 0,
);
const kernelFetchWhenEmpty = ref(true);

const {
  selectedPotId: receiveIntoPotId,
  chipOptions: receiveIntoOptions,
  locationSections: receiveIntoSections,
  cashbookPointId,
  sourceCurrencyCode,
  loading: receiveIntoLoading,
} = useCashbookLegPots(
  receiveProfileId,
  booksTenantIdRef,
  receiveLegEnabled,
  undefined,
  undefined,
  kernelFetchWhenEmpty,
);

const {
  paymentCurrency: refundPaymentCurrency,
  foreignAmount: refundForeignAmount,
  booksExchangeRate: refundBooksExchangeRate,
  transactionRate: refundTransactionRate,
  needsCurrencyShift: refundNeedsCurrencyShift,
  currencyShiftHint: refundCurrencyShiftHint,
  potCashRateLabel: refundPotCashRateLabel,
  booksCashRateLabel: refundBooksCashRateLabel,
  needsBooksFx: refundNeedsBooksFx,
  needsSeparateBooksFx: refundNeedsSeparateBooksFx,
  computedBooksBdt: refundComputedBooksBdt,
  resetFxAmounts: resetRefundFxAmounts,
  validateFxFields: validateRefundFxFields,
  settlementFxPayload: refundSettlementFxPayload,
  sourceFxPayload: refundSourceFxPayload,
} = useApPayoutFxFields(sourceCurrencyCode, amountBdt, booksCurrencyCode);

const globalRefStore = useGlobalReferenceStore();
const { currencies: currenciesData } = storeToRefs(globalRefStore);

watch(
  formActive,
  (open) => {
    if (open && currenciesData.value.length === 0) {
      void globalRefStore.ensureCurrenciesLoaded();
    }
  },
  { immediate: true },
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

const openCreditFace = computed(() =>
  vendorRefundOpenCreditFace(
    props.openCredit,
    props.channelMeta ?? null,
    booksCurrencyCode.value,
  ),
);

const maxSettlementAmount = computed(() => openCreditFace.value.amount);

const openCreditDisplay = computed(() => {
  const face = openCreditFace.value;
  const books = props.openCredit;
  if (face.currencyCode !== booksCurrencyCode.value) {
    return `${face.amount} ${face.currencyCode} (${formatAmountBdt(books)} books)`;
  }
  return formatAmountBdt(books);
});

const primaryPayAmount = computed({
  get: () => (refundNeedsBooksFx.value ? refundForeignAmount.value : amountBdt.value),
  set: (v: number | null) => {
    if (refundNeedsBooksFx.value) {
      refundForeignAmount.value = v;
    } else {
      amountBdt.value = v;
    }
  },
});

const booksAmountPreviewLabel = computed(() => {
  if (!refundNeedsBooksFx.value) return null;
  const books = refundComputedBooksBdt.value;
  if (books == null) return null;
  return `Books (${booksCurrencyCode.value}): ${formatAmountBdt(books)}`;
});

function onPrimaryAmountInput(value: number | null) {
  primaryPayAmount.value = value;
}

const creditNoteOptions = computed(() => props.creditNoteOptions ?? []);

function resetRefundForm() {
  receivedOn.value = localToday();
  note.value = '';
  receiveIntoPotId.value = null;
  const base = booksCurrencyCode.value;
  const currency = vendorRefundDefaultSettlementCurrency(props.channelMeta ?? null, base);
  const rate = vendorRefundInvoiceConversionRate(props.channelMeta ?? null);
  refundPaymentCurrency.value = currency;
  resetRefundFxAmounts();
  const face = vendorRefundOpenCreditFace(props.openCredit, props.channelMeta ?? null, base);
  if (currency !== base && rate && rate > 0 && props.openCredit > 0) {
    refundForeignAmount.value = face.amount;
    refundBooksExchangeRate.value = rate;
    refundTransactionRate.value = rate;
    amountBdt.value = props.openCredit;
  } else {
    amountBdt.value = props.openCredit > 0 ? props.openCredit : null;
    refundForeignAmount.value = null;
  }
}

watch(
  () => [formActive.value, props.channelMeta, props.openCredit, props.creditNoteId] as const,
  ([open]) => {
    if (open) resetRefundForm();
  },
);

watch(receiveIntoPotId, () => {
  if (!receiveIntoPotId.value) return;
  resetRefundFxAmounts();
});

watch(
  [primaryPayAmount, refundPaymentCurrency, openCreditFace],
  () => {
    emit('pay-amount-change', primaryPayAmount.value, refundPaymentCurrency.value);
  },
  { immediate: true },
);

const submitDisabledReason = computed(() => {
  const books = Number(amountBdt.value ?? 0);
  if (books <= 0) return 'Enter a refund amount.';
  if (books > props.openCredit + 0.01) {
    return `Cannot exceed ${formatAmountBdt(props.openCredit)} books.`;
  }
  if (receiveIntoLoading.value) return 'Loading receive locations…';
  if (!receiveIntoPotId.value) return 'Choose where to receive the refund';
  const fxReason = validateRefundFxFields();
  if (fxReason) return fxReason;
  if (!receivedOn.value) return 'Date is required.';
  return null;
});

function buildPayload(): PostVendorCreditRefundInput | null {
  if (submitDisabledReason.value || !receiveIntoPotId.value || cashbookPointId.value == null) {
    return null;
  }
  const fx = {
    ...refundSettlementFxPayload(),
    ...refundSourceFxPayload(receiveIntoPotId.value),
  };
  return {
    creditNoteId: props.creditNoteId,
    parentBillId: props.parentBillId,
    amount: Number(amountBdt.value),
    cashbookPointId: cashbookPointId.value,
    cashbookPointPotId: fx.cashbook_point_pot_id,
    receivedOn: receivedOn.value,
    note: note.value.trim() || null,
    settlementCurrencyCode: fx.settlement_currency_code,
    foreignAmount: fx.foreign_amount,
    exchangeRate: fx.exchange_rate,
    sourceCurrencyCode: fx.source_currency_code,
    transactionRate: fx.transaction_rate,
  };
}

function trySubmit() {
  const payload = buildPayload();
  if (payload) emit('submit', payload);
}

defineExpose({
  submitDisabledReason,
  trySubmit,
  buildPayload,
  openCreditFace,
  primaryPayAmount,
  refundPaymentCurrency,
});
</script>
<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: min(480px, 92vw)">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">Record vendor refund</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>
      <q-card-section class="q-gutter-y-md q-pt-sm">
        <div class="q-pa-sm rounded-borders bg-grey-2">
          <div class="text-caption text-grey-7">From</div>
          <div class="text-body2 text-weight-medium">{{ fromProfileName }}</div>
          <div class="text-caption text-grey-7 q-mt-sm">Into our cash</div>
          <div class="text-body2">{{ tenantLabel }}</div>
        </div>
        <div class="text-caption text-grey-7">
          Open credit:
          <strong>{{ openCreditDisplay }}</strong>
        </div>
        <q-input v-model="receivedOn" outlined dense label="Date received" mask="####-##-##">
          <template #append>
            <q-icon name="ph ph-calendar" class="cursor-pointer">
              <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                <q-date v-model="receivedOn" mask="YYYY-MM-DD" />
              </q-popup-proxy>
            </q-icon>
          </template>
        </q-input>
        <q-select
          v-model="receiveIntoPotId"
          :options="receiveIntoOptions"
          emit-value
          map-options
          outlined
          dense
          label="Receive into (location & currency)"
          hint="Till, safe, or bank — and which cash pot"
          :loading="receiveIntoLoading"
        />
        <q-select
          v-model="refundPaymentCurrency"
          :options="settlementCurrencyOptions"
          emit-value
          map-options
          outlined
          dense
          label="Refund currency"
          hint="Currency the vendor refunds in"
        />
        <p v-if="refundNeedsCurrencyShift" class="text-caption text-grey-7 q-mb-none">
          {{ refundCurrencyShiftHint }}
        </p>
        <template v-if="refundNeedsSeparateBooksFx">
          <q-input
            v-model.number="refundForeignAmount"
            outlined
            dense
            :label="`Amount (${refundPaymentCurrency})`"
            type="number"
            step="0.01"
          />
          <q-input
            v-model.number="refundBooksExchangeRate"
            outlined
            dense
            :label="refundBooksCashRateLabel"
            type="number"
            step="0.0001"
          />
        </template>
        <template v-else-if="refundNeedsBooksFx">
          <q-input
            v-model.number="refundForeignAmount"
            outlined
            dense
            :label="`Amount (${refundPaymentCurrency})`"
            type="number"
            step="0.01"
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
          :hint="
            refundNeedsBooksFx && !refundNeedsSeparateBooksFx
              ? `Also converts to ${booksCurrencyCode} in the books`
              : 'How much pot cash per 1 unit of refund currency'
          "
        />
        <div
          v-if="refundNeedsBooksFx && refundComputedBooksBdt != null"
          class="text-caption text-grey-8"
        >
          Books ({{ booksCurrencyCode }}): {{ formatAmountBdt(refundComputedBooksBdt) }}
        </div>
        <q-input
          v-if="!refundNeedsBooksFx"
          v-model.number="amountBdt"
          outlined
          dense
          :label="`Amount (${booksCurrencyCode})`"
          type="number"
          step="0.01"
          :max="openCredit"
        />
        <q-input v-model="note" outlined dense label="Note (optional)" type="textarea" autogrow />
      </q-card-section>
      <q-card-actions align="right" class="q-pa-md q-pt-none">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Record refund"
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
import { formatAmountBdt } from 'src/utils/currency';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { useCashbookPointsQuery } from '../composables/useCashbookPointsQuery';
import { useCashbookPayFromPotSelect } from '../composables/useCashbookPayFromPotSelect';
import { useBooksCurrencyCode } from '../composables/useBooksCurrencyCode';
import { useApPayoutFxFields } from '../composables/useApPayoutFxFields';
import type { PostVendorCreditRefundInput } from '../composables/usePostVendorCreditRefundMutation';
import { apBillPaperCurrencyCode as apInvoiceCurrencyFromMeta } from '../utils/apBillBooks';
import { apBillCurrencyGroups, apBillPaperConversionRate } from '../utils/parseApBillPaper';

function defaultSettlementCurrency(
  channelMeta: Record<string, unknown> | null | undefined,
  booksCurrency: string,
): string {
  const groups = apBillCurrencyGroups(channelMeta ?? null);
  if (groups.length === 1) {
    const c = (groups[0]?.currency_code ?? '').trim().toUpperCase();
    if (c && c !== booksCurrency) return c;
  }
  const code = apInvoiceCurrencyFromMeta(channelMeta ?? null);
  return code || booksCurrency;
}

function invoiceConversionRate(channelMeta: Record<string, unknown> | null | undefined): number | null {
  const fromPaper = apBillPaperConversionRate(channelMeta ?? null);
  if (fromPaper != null && fromPaper > 0) return fromPaper;
  const raw = channelMeta?.ap_paper;
  if (!raw || typeof raw !== 'object') return null;
  const direct = Number((raw as Record<string, unknown>).conversion_rate);
  if (Number.isFinite(direct) && direct > 0 && Math.abs(direct - 1) > 0.0001) return direct;
  return null;
}

const props = defineProps<{
  modelValue: boolean;
  creditNoteId: number;
  parentBillId: number | null;
  openCredit: number;
  booksTenantId: number;
  fromProfileName: string;
  tenantLabel: string;
  channelMeta?: Record<string, unknown> | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: PostVendorCreditRefundInput];
}>();

const localToday = () => {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const receivedOn = ref(localToday());
const amountBdt = ref<number | null>(null);
const note = ref('');

const booksCurrencyCode = useBooksCurrencyCode();

const pointsContext = computed(() => ({
  booksTenantId: props.booksTenantId,
  entityType: 'tenant',
  entityId: props.booksTenantId,
  enabled: props.modelValue && props.booksTenantId > 0,
}));
const { pointsQuery } = useCashbookPointsQuery(pointsContext);
const apPoints = computed(() => pointsQuery.data.value);
const receiveIntoEnabled = computed(() => props.modelValue && props.booksTenantId > 0);
const {
  selectedPotId: receiveIntoPotId,
  payFromOptions: receiveIntoOptions,
  cashbookPointId,
  sourceCurrencyCode,
  loading: receiveIntoLoading,
} = useCashbookPayFromPotSelect(apPoints, receiveIntoEnabled);

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

const invoiceCurrency = computed(() =>
  defaultSettlementCurrency(props.channelMeta ?? null, booksCurrencyCode.value),
);
const invoiceRate = computed(() => invoiceConversionRate(props.channelMeta ?? null));

const openCreditDisplay = computed(() => {
  const books = props.openCredit;
  const paper = invoiceCurrency.value;
  const rate = invoiceRate.value;
  const base = booksCurrencyCode.value;
  if (paper && paper !== base && rate && rate > 0) {
    const foreign = Math.round((books / rate) * 100) / 100;
    return `${foreign} ${paper} (${formatAmountBdt(books)} books)`;
  }
  return formatAmountBdt(books);
});

function resetRefundForm() {
  receivedOn.value = localToday();
  note.value = '';
  receiveIntoPotId.value = null;
  const base = booksCurrencyCode.value;
  const currency = defaultSettlementCurrency(props.channelMeta ?? null, base);
  const rate = invoiceConversionRate(props.channelMeta ?? null);
  refundPaymentCurrency.value = currency;
  resetRefundFxAmounts();
  if (currency !== base && rate && rate > 0 && props.openCredit > 0) {
    refundForeignAmount.value = Math.round((props.openCredit / rate) * 100) / 100;
    refundBooksExchangeRate.value = rate;
    refundTransactionRate.value = rate;
    amountBdt.value = props.openCredit;
  } else {
    amountBdt.value = props.openCredit > 0 ? props.openCredit : null;
  }
}

watch(
  () => [props.modelValue, props.channelMeta, props.openCredit] as const,
  ([open]) => {
    if (open) resetRefundForm();
  },
);

watch(receiveIntoPotId, () => {
  resetRefundFxAmounts();
});

const submitDisabledReason = computed(() => {
  const books = Number(amountBdt.value ?? 0);
  if (books <= 0) return 'Enter a refund amount.';
  if (books > props.openCredit + 0.01) {
    return `Cannot exceed ${formatAmountBdt(props.openCredit)} books.`;
  }
  if (receiveIntoLoading.value) return 'Loading receive locations…';
  if (!receiveIntoPotId.value) return 'Choose location and currency to receive into';
  const fxReason = validateRefundFxFields();
  if (fxReason) return fxReason;
  if (!receivedOn.value) return 'Date is required.';
  return null;
});

function close() {
  emit('update:modelValue', false);
}

function submit() {
  if (submitDisabledReason.value || !receiveIntoPotId.value || cashbookPointId.value == null) return;
  const fx = {
    ...refundSettlementFxPayload(),
    ...refundSourceFxPayload(receiveIntoPotId.value),
  };
  emit('submit', {
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
  });
}
</script>

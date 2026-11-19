<template>
  <div class="column q-gutter-y-md">
    <q-card v-if="creditNoteOptions.length > 1" flat bordered class="q-pa-md">
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

    <q-card flat bordered class="q-pa-md">
      <div class="text-caption text-weight-bold text-uppercase text-grey-7 q-mb-md">Amount</div>
      <div class="text-caption text-grey-7">Refund currency</div>
      <div class="text-body2 text-weight-medium q-mb-md">{{ billRefundCurrency }}</div>
      <MoneyPayDialogAmountBlock
        class="q-mt-md"
        :amount="primaryPayAmount"
        :currency-code="billRefundCurrency"
        :max-amount="maxSettlementAmount"
        :books-preview-label="booksAmountPreviewLabel"
        data-test="vendor-refund-amount"
        @update:amount="onPrimaryAmountInput"
      />
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

    <q-card flat bordered class="q-pa-md">
      <div class="row items-baseline justify-between q-mb-md">
        <div class="text-caption text-weight-bold text-uppercase text-grey-7">Receive at</div>
        <div class="text-caption text-grey-7">{{ tenantLabel }}</div>
      </div>
      <ProfileCashMovementLegPicker
        v-model:currency-code="profileLegCurrency"
        v-model:location-point-id="receiveLocationPointId"
        v-model:bundle-id="receiveBundleId"
        v-model:books-rate="receiveBooksRate"
        v-model:deposit-requires-bundle-pick="depositRequiresBundlePick"
        :books-tenant-id="booksTenantId"
        :operating-tenant-id="operatingTenantId"
        :profile-id="receiveProfileIdForPicker"
        kind="deposit"
        :enabled="receiveLegEnabled"
        hide-amount
        lock-currency
      />
    </q-card>

    <q-card flat bordered class="q-pa-md">
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
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import ProfileCashMovementLegPicker from 'src/modules/people/components/ProfileCashMovementLegPicker.vue';
import { useProfileCashMovementLegData } from 'src/modules/people/composables/useProfileCashMovementLegData';
import { useBooksCurrencyCode } from '../composables/useBooksCurrencyCode';
import { useApPayoutFxFields } from '../composables/useApPayoutFxFields';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';
import { showErrorNotification } from 'src/utils/appFeedback';
import type { PostVendorCreditRefundInput } from '../composables/usePostVendorCreditRefundMutation';
import {
  vendorRefundBillCurrency,
  vendorRefundInvoiceConversionRate,
  vendorRefundOpenCreditFace,
} from '../utils/vendorRefundDisplay';
import BillDialogField from './BillDialogField.vue';
import MoneyPayDialogAmountBlock from './MoneyPayDialogAmountBlock.vue';

const props = defineProps<{
  creditNoteId: number;
  parentBillId: number | null;
  openCredit: number;
  booksTenantId: number;
  operatingTenantId: number;
  /** Tenant money profile (receive leg), usually bill `from_profile_id` on AP. */
  receiveProfileId?: number | null;
  fromProfileName: string;
  tenantLabel: string;
  channelMeta?: Record<string, unknown> | null;
  invoiceCurrencyCode?: string | null;
  creditNoteOptions?: Array<{ label: string; value: number }>;
  active?: boolean;
}>();

const emit = defineEmits<{
  'update:creditNoteId': [value: number];
  submit: [payload: PostVendorCreditRefundInput];
  'pay-amount-change': [amount: number | null, currencyCode: string];
}>();

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
const operatingTenantId = computed(() =>
  props.operatingTenantId > 0 ? props.operatingTenantId : props.booksTenantId,
);
const receiveProfileIdForPicker = computed(() => {
  const id = receiveProfileId.value;
  return id > 0 ? id : null;
});
const receiveLegEnabled = computed(
  () => formActive.value && props.booksTenantId > 0 && receiveProfileId.value > 0,
);

const profileLegCurrency = ref('BDT');
const receiveLocationPointId = ref<number | null>(null);
const receiveBundleId = ref<number | null>(null);
const receiveBooksRate = ref<number | null>(null);
const depositRequiresBundlePick = ref(false);

const profileLegData = useProfileCashMovementLegData(
  booksTenantIdRef,
  receiveProfileIdForPicker,
  receiveLegEnabled,
);

const billRefundCurrency = computed(() =>
  vendorRefundBillCurrency(props.invoiceCurrencyCode, booksCurrencyCode.value),
);

const receiveSourceCurrency = computed(() => billRefundCurrency.value);

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
} = useApPayoutFxFields(receiveSourceCurrency, amountBdt, booksCurrencyCode);

watch(
  billRefundCurrency,
  (code) => {
    profileLegCurrency.value = code;
    refundPaymentCurrency.value = code;
  },
  { immediate: true },
);

watch(
  receiveBooksRate,
  (rate) => {
    if (refundNeedsBooksFx.value) {
      refundBooksExchangeRate.value = rate;
    }
  },
  { immediate: true },
);

const openCreditFace = computed(() =>
  vendorRefundOpenCreditFace(
    props.openCredit,
    props.channelMeta ?? null,
    booksCurrencyCode.value,
    props.invoiceCurrencyCode,
  ),
);

const maxSettlementAmount = computed(() => openCreditFace.value.amount);

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

const receiveLegDisabledReason = computed((): string | null => {
  if (profileLegData.loading.value) return 'Loading receive locations…';
  if (receiveLocationPointId.value == null) {
    return 'Choose where to receive the refund.';
  }
  if (depositRequiresBundlePick.value) {
    if (receiveBundleId.value == null || receiveBundleId.value <= 0) {
      return 'Choose a bundle.';
    }
    return null;
  }
  const legCurrency = billRefundCurrency.value;
  if (legCurrency !== booksCurrencyCode.value) {
    const rate = Number(receiveBooksRate.value);
    if (!Number.isFinite(rate) || rate <= 0) {
      return 'Enter the books rate for the new bundle.';
    }
  }
  return null;
});

function resetRefundForm() {
  receivedOn.value = localToday();
  note.value = '';
  receiveLocationPointId.value = null;
  receiveBundleId.value = null;
  const base = booksCurrencyCode.value;
  const face = vendorRefundOpenCreditFace(
    props.openCredit,
    props.channelMeta ?? null,
    base,
    props.invoiceCurrencyCode,
  );
  const currency = face.currencyCode;
  const rate = vendorRefundInvoiceConversionRate(props.channelMeta ?? null);
  refundPaymentCurrency.value = currency;
  profileLegCurrency.value = currency;
  receiveBooksRate.value = rate;
  resetRefundFxAmounts();
  if (currency !== base && rate && rate > 0 && props.openCredit > 0) {
    refundForeignAmount.value = face.amount;
    refundBooksExchangeRate.value = rate;
    refundTransactionRate.value = rate;
    amountBdt.value = props.openCredit;
  } else if (currency !== base && props.openCredit > 0) {
    refundForeignAmount.value = face.amount;
    amountBdt.value = null;
  } else {
    amountBdt.value = props.openCredit > 0 ? props.openCredit : null;
    refundForeignAmount.value = null;
  }
}

watch(
  () =>
    [
      formActive.value,
      props.channelMeta,
      props.openCredit,
      props.creditNoteId,
      props.invoiceCurrencyCode,
    ] as const,
  ([open]) => {
    if (open) resetRefundForm();
  },
);

watch(
  [primaryPayAmount, refundPaymentCurrency, openCreditFace],
  () => {
    emit('pay-amount-change', primaryPayAmount.value, refundPaymentCurrency.value);
  },
  { immediate: true },
);

const submitDisabledReason = computed(() => {
  const books = Number(amountBdt.value ?? 0);
  const settlementAmt = Number(primaryPayAmount.value ?? 0);
  if (refundNeedsBooksFx.value) {
    if (settlementAmt <= 0) return 'Enter a refund amount.';
    if (settlementAmt > maxSettlementAmount.value + 0.01) {
      return `Cannot exceed ${maxSettlementAmount.value.toFixed(2)} ${refundPaymentCurrency.value}.`;
    }
    if (books <= 0) return 'Enter the books exchange rate and amount.';
  } else {
    if (books <= 0) return 'Enter a refund amount.';
    if (books > props.openCredit + 0.01) {
      return `Cannot exceed ${openCreditFace.value.amount.toFixed(2)} ${openCreditFace.value.currencyCode}.`;
    }
  }
  const legReason = receiveLegDisabledReason.value;
  if (legReason) return legReason;
  const fxReason = validateRefundFxFields();
  if (fxReason) return fxReason;
  if (!receivedOn.value) return 'Date is required.';
  return null;
});

async function buildPayload(): Promise<PostVendorCreditRefundInput | null> {
  if (submitDisabledReason.value || receiveLocationPointId.value == null) {
    return null;
  }
  const pointId = receiveLocationPointId.value;
  const point = profileLegData.pointById(pointId);
  const pointCode = point?.code?.trim() || 'main';
  const pid = receiveProfileId.value;
  if (pid <= 0) return null;

  let potId = receiveBundleId.value;
  let cashbookPointId = pointId;
  const legCurrency = billRefundCurrency.value;

  if (depositRequiresBundlePick.value && potId != null && potId > 0) {
    /* use selected BDT bundle */
  } else {
    const booksRate =
      legCurrency !== booksCurrencyCode.value
        ? Number(receiveBooksRate.value) || null
        : null;
    try {
      const prov = await moneyKernelRepository.provisionCashbookCurrency(
        props.booksTenantId,
        pid,
        legCurrency,
        pointCode,
        booksRate,
      );
      potId = prov.pot_id ?? potId;
      if (prov.cashbook_point_id != null) {
        cashbookPointId = prov.cashbook_point_id;
      }
    } catch (err) {
      showErrorNotification(
        err instanceof Error ? err.message : 'Could not open a cash bundle at this location.',
      );
      return null;
    }
  }

  if (potId == null || potId <= 0) return null;

  const fx = {
    ...refundSettlementFxPayload(),
    ...refundSourceFxPayload(potId),
  };
  return {
    creditNoteId: props.creditNoteId,
    parentBillId: props.parentBillId,
    amount: Number(amountBdt.value),
    cashbookPointId,
    cashbookPointPotId: fx.cashbook_point_pot_id ?? potId,
    receivedOn: receivedOn.value,
    note: note.value.trim() || null,
    settlementCurrencyCode: fx.settlement_currency_code,
    foreignAmount: fx.foreign_amount,
    exchangeRate: fx.exchange_rate,
    sourceCurrencyCode: fx.source_currency_code,
    transactionRate: fx.transaction_rate,
  };
}

async function trySubmit() {
  const payload = await buildPayload();
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
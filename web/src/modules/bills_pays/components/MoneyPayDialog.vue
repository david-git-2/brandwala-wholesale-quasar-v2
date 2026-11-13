<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card flat bordered class="money-pay-dialog-card">
      <q-card-section class="money-pay-dialog__header row items-start no-wrap">
        <div class="col">
          <div class="money-pay-dialog__title">{{ dialogTitle }}</div>
          <div v-if="subtitle" class="money-pay-dialog__subtitle">{{ subtitle }}</div>
        </div>
        <TfBtn
          variant="icon"
          icon="ph ph-x"
          aria-label="Close"
          class="money-pay-dialog__close"
          @click="close"
        />
      </q-card-section>

      <q-card-section class="money-pay-dialog__body q-pt-none">
        <MoneyPayDialogSummary
          v-if="showSummary"
          :visible="showSummary"
          :context="summary"
          class="money-pay-dialog__summary"
        />

        <div class="money-pay-dialog__grid">
          <div class="money-pay-dialog__col money-pay-dialog__col--left">
            <div class="money-pay-dialog__section">
              <div
                class="money-pay-dialog__section-title money-pay-dialog__section-title--spacer"
                aria-hidden="true"
              >
                &nbsp;
              </div>
              <div class="money-pay-dialog__section-body money-pay-dialog__stack">
                <ProfileCashMovementLegPicker
                  v-if="isProfileCashLeg"
                  v-model:currency-code="profileLegCurrency"
                  v-model:amount="amount"
                  v-model:location-point-id="profileLegLocationPointId"
                  v-model:bundle-id="profileLegBundleId"
                  v-model:books-rate="profileLegBooksRate"
                  v-model:deposit-requires-bundle-pick="profileLegDepositRequiresBundlePick"
                  :books-tenant-id="booksTenantId ?? 0"
                  :operating-tenant-id="operatingTenantId ?? 0"
                  :profile-id="profileId ?? null"
                  :kind="kind"
                  :enabled="dialogOpen"
                  :amount-show-error="amountShowError"
                  :lock-currency="lockProfileCurrency"
                  :prefill-location-label="props.prefill?.legLocationPointLabel ?? null"
                />

                <div
                  v-if="displayPayBalanceShortfall > 0"
                  class="money-pay-dialog__balance-warning q-mb-sm"
                >
                  <div class="text-caption text-negative">
                    Need {{ displayPayBalanceShortfall.toFixed(2) }} more in the selected bundle.
                  </div>
                </div>

                <div v-if="showFromLeg && !isProfileCashLeg" data-test="money-pay-from-pot">
                  <PaymentLegPotChips
                    v-model="fromPotId"
                    leg-label="From location"
                    :party-name="fromPartyName"
                    :options="fromPotOptions"
                    :sections="fromPotSections"
                    :loading="fromPotLoading"
                  />
                  <div
                    v-if="displayPayPotBalance != null"
                    class="text-caption text-grey-7 q-mt-xs"
                  >
                    Available: {{ displayPayPotBalance.toFixed(2) }} {{ amountCurrencyCode }}
                  </div>
                </div>

                <div v-if="showToLeg && !isProfileCashLeg" data-test="money-pay-to-pot">
                  <PaymentLegPotChips
                    v-model="toPotId"
                    leg-label="To location"
                    :party-name="toPartyName"
                    :options="toPotOptions"
                    :sections="toPotSections"
                    :loading="toPotLoading"
                  />
                </div>

                <div
                  v-if="showAddMoneyPanel"
                  class="money-pay-dialog__add-money q-mt-sm"
                >
                  <TfBtn
                    variant="secondary"
                    size="sm"
                    icon="ph ph-plus"
                    label="Add money"
                    data-test="money-pay-add-money-open"
                    @click="emit('openDeposit')"
                  />
                </div>

                <PayOpenBillsAllocSection
                  v-if="showAllocations && allocationRows.length"
                  :rows="allocationRows"
                  @fill-oldest="fillOldestAllocations()"
                />
              </div>
            </div>
          </div>

          <div class="money-pay-dialog__col money-pay-dialog__col--right">
            <div class="money-pay-dialog__section">
              <div class="money-pay-dialog__section-title money-pay-dialog__section-title--right">
                Payment details
              </div>
              <div class="money-pay-dialog__section-body money-pay-dialog__stack">
                <BillDialogField v-if="showDate" label="Payment date">
                  <q-input
                    v-model="paymentDate"
                    outlined
                    dense
                    mask="####-##-##"
                    placeholder="YYYY-MM-DD"
                    hide-bottom-space
                    data-test="money-pay-date"
                  >
                    <template #append>
                      <q-icon name="ph ph-calendar" class="cursor-pointer money-pay-dialog__field-icon">
                        <q-popup-proxy transition-show="scale" transition-hide="scale">
                          <q-date v-model="paymentDate" mask="YYYY-MM-DD" />
                        </q-popup-proxy>
                      </q-icon>
                    </template>
                  </q-input>
                </BillDialogField>

                <BillDialogField v-if="showInstrument" :label="methodLabel">
                  <q-select
                    v-model="methodCode"
                    :options="resolvedMethodOptions"
                    emit-value
                    map-options
                    outlined
                    dense
                    hide-bottom-space
                    :loading="loadingPaymentMeta"
                    :disable="loadingPaymentMeta && !methodOptions.length"
                    data-test="money-pay-method"
                  />
                </BillDialogField>

                <BillDialogField
                  v-if="showInstrument && methodFieldFlags.showBank"
                  :label="methodFieldFlags.bankLabel"
                >
                  <q-select
                    v-model="bdBankId"
                    :options="bdBankOptions"
                    emit-value
                    map-options
                    outlined
                    dense
                    :clearable="!methodFieldFlags.bankRequired"
                    hide-bottom-space
                    :loading="loadingPaymentMeta"
                    data-test="money-pay-bank"
                  />
                </BillDialogField>

                <PaymentInstrumentExtrasFields
                  v-if="showInstrument && showRequiredInstrumentExtras"
                  external-labels
                  omit-bank
                  omit-instrument-reference
                  :omit-instrument-date="!methodFieldFlags.instrumentDateRequired"
                  :omit-cheque-number="!methodFieldFlags.chequeNumberRequired"
                  :method-code="methodCode"
                  :method-options="methodOptions"
                  :bd-bank-options="bdBankOptions"
                  :loading="loadingPaymentMeta"
                  :bd-bank-id="bdBankId"
                  :cheque-number="chequeNumber"
                  :instrument-date="instrumentDate"
                  :instrument-reference="instrumentReference"
                  @update:bd-bank-id="(v) => (bdBankId = v)"
                  @update:cheque-number="(v) => (chequeNumber = v)"
                  @update:instrument-date="(v) => (instrumentDate = v)"
                  @update:instrument-reference="(v) => (instrumentReference = v)"
                />

                <q-expansion-item
                  v-if="showOptionalDetails"
                  v-model="optionalDetailsOpen"
                  dense
                  expand-icon-class="money-pay-dialog__optional-chevron"
                  class="money-pay-dialog__optional"
                  header-class="money-pay-dialog__optional-header"
                  :label="optionalDetailsOpen ? 'Hide details' : 'Add more details'"
                >
                  <div class="money-pay-dialog__optional-body q-gutter-y-md">
                    <PaymentInstrumentExtrasFields
                      v-if="showInstrument && showOptionalInstrumentExtras"
                      external-labels
                      omit-bank
                      :omit-cheque-number="methodFieldFlags.chequeNumberRequired"
                      :omit-instrument-date="methodFieldFlags.instrumentDateRequired"
                      :method-code="methodCode"
                      :method-options="methodOptions"
                      :bd-bank-options="bdBankOptions"
                      :loading="loadingPaymentMeta"
                      :bd-bank-id="bdBankId"
                      :cheque-number="chequeNumber"
                      :instrument-date="instrumentDate"
                      :instrument-reference="instrumentReference"
                      @update:bd-bank-id="(v) => (bdBankId = v)"
                      @update:cheque-number="(v) => (chequeNumber = v)"
                      @update:instrument-date="(v) => (instrumentDate = v)"
                      @update:instrument-reference="(v) => (instrumentReference = v)"
                    />

                    <template v-if="showReferenceNote">
                      <BillDialogField label="Reference" hint="Optional">
                        <q-input
                          v-model="reference"
                          outlined
                          dense
                          clearable
                          hide-bottom-space
                        />
                      </BillDialogField>
                      <BillDialogField label="Note" hint="Optional">
                        <q-input
                          v-model="note"
                          outlined
                          dense
                          autogrow
                          hide-bottom-space
                        />
                      </BillDialogField>
                    </template>
                  </div>
                </q-expansion-item>
              </div>
            </div>
          </div>
        </div>
      </q-card-section>

      <q-card-actions class="money-pay-dialog__footer column items-stretch q-pa-md">
        <div
          v-if="footerHint"
          class="money-pay-dialog__footer-hint q-mb-sm"
          role="status"
        >
          {{ footerHint }}
        </div>
        <div class="row justify-end items-center q-gutter-md money-pay-dialog__footer-actions">
          <TfBtn variant="link" size="md" label="Cancel" @click="close" />
          <TfBtn
            variant="primary"
            size="md"
            :label="submitLabelResolved"
            :loading="loading"
            :disable="!!submitDisabledReasonResolved"
            data-test="money-pay-submit"
            @click="onSubmit"
          />
        </div>
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, toRef, watch } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import BillDialogField from './BillDialogField.vue';
import PaymentInstrumentExtrasFields from './PaymentInstrumentExtrasFields.vue';
import PaymentLegPotChips from './PaymentLegPotChips.vue';
import PayOpenBillsAllocSection from './PayOpenBillsAllocSection.vue';
import MoneyPayDialogSummary from './MoneyPayDialogSummary.vue';
import ProfileCashMovementLegPicker from 'src/modules/people/components/ProfileCashMovementLegPicker.vue';
import { useProfileCashMovementLegData } from 'src/modules/people/composables/useProfileCashMovementLegData';
import {
  isProfileCashMovementMethod,
  sortProfileCashMovementMethods,
} from 'src/modules/people/constants/profileCashMovementMethods';
import { useWholesalePaymentMethodMeta } from '../composables/useWholesalePaymentMethodMeta';
import { useMoneyPayDialogForm } from '../composables/useMoneyPayDialogForm';
import { useMoneyPayDialogFx } from '../composables/useMoneyPayDialogFx';
import type { OpenBillAllocRow } from '../composables/useOpenBillAllocations';
import type { CashbookLegPotChipOption } from '../composables/useCashbookLegPots';
import type {
  MoneyPayKind,
  MoneyPayDialogFieldFlags,
  MoneyPayDialogPrefill,
  MoneyPaySubmitPayload,
  MoneyPaySummaryContext,
} from '../types/moneyPayDialog';
import type { CashbookLegLocationSection } from '../composables/useCashbookLegPots';

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    kind?: MoneyPayKind;
    title?: string | null;
    subtitle?: string | null;
    submitLabel?: string | null;
    loading?: boolean;
    summary?: MoneyPaySummaryContext | null;
    amountCurrencyCode?: string | null;
    fromPartyName?: string;
    toPartyName?: string;
    fromPotOptions?: CashbookLegPotChipOption[];
    toPotOptions?: CashbookLegPotChipOption[];
    fromPotSections?: CashbookLegLocationSection[];
    toPotSections?: CashbookLegLocationSection[];
    fromPotLoading?: boolean;
    toPotLoading?: boolean;
    allocationRows?: OpenBillAllocRow[];
    lockBillId?: number | null;
    prefill?: MoneyPayDialogPrefill | null;
    fieldFlags?: MoneyPayDialogFieldFlags;
    defaultMethodCode?: string;
    booksCurrencyCode?: string;
    booksTenantId?: number | null;
    payPotBalance?: number | null;
    payBalanceShortfall?: number;
    legLayout?: 'default' | 'profile_cash';
    profileId?: number | null;
    operatingTenantId?: number | null;
  }>(),
  {
    kind: 'payment',
    title: null,
    subtitle: null,
    submitLabel: null,
    loading: false,
    summary: null,
    amountCurrencyCode: 'BDT',
    fromPartyName: 'Payer',
    toPartyName: 'Payee',
    fromPotOptions: () => [],
    toPotOptions: () => [],
    fromPotSections: () => [],
    toPotSections: () => [],
    fromPotLoading: false,
    toPotLoading: false,
    allocationRows: () => [],
    lockBillId: null,
    prefill: null,
    fieldFlags: () => ({}),
    defaultMethodCode: 'bank_transfer',
    booksCurrencyCode: 'BDT',
    booksTenantId: null,
    payPotBalance: null,
    payBalanceShortfall: 0,
    legLayout: 'default',
    profileId: null,
    operatingTenantId: null,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: MoneyPaySubmitPayload];
  cancel: [];
  amountChange: [amount: number];
  openDeposit: [];
}>();

const profileLegCurrency = ref('BDT');
const profileLegLocationPointId = ref<number | null>(null);
const profileLegBundleId = ref<number | null>(null);
const profileLegBooksRate = ref<number | null>(null);
const profileLegDepositRequiresBundlePick = ref(false);

const isProfileCashLeg = computed(
  () =>
    props.legLayout === 'profile_cash'
    && (props.kind === 'deposit' || props.kind === 'withdrawal'),
);

const resolvedMethodOptions = computed(() => {
  if (!isProfileCashLeg.value) return methodOptions.value;
  const filtered = methodOptions.value.filter(isProfileCashMovementMethod);
  return sortProfileCashMovementMethods(filtered.length ? filtered : methodOptions.value);
});

const dialogOpen = computed(() => props.modelValue);

const lockProfileCurrency = computed(
  () => isProfileCashLeg.value && !!props.prefill?.currencyCode?.trim(),
);
const kindRef = toRef(props, 'kind');
const fieldFlagsRef = toRef(props, 'fieldFlags');
const prefillRef = toRef(props, 'prefill');
const initialAllocationRows = toRef(props, 'allocationRows');
const lockBillIdRef = toRef(props, 'lockBillId');

const { loadingPaymentMeta, methodOptions, bdBankOptions } = useWholesalePaymentMethodMeta(
  props.defaultMethodCode,
  dialogOpen,
);

const {
  amount,
  paymentDate,
  methodCode,
  fromPotId,
  toPotId,
  reference,
  note,
  bdBankId,
  chequeNumber,
  instrumentDate,
  instrumentReference,
  allocationRows,
  showFromLeg,
  showToLeg,
  showAllocations,
  showInstrument,
  showDate,
  showReferenceNote,
  showSummary,
  submitDisabledReason,
  methodFieldFlags,
  buildPayload,
  fillOldestAllocations,
} = useMoneyPayDialogForm({
  kind: kindRef,
  dialogOpen,
  fieldFlags: fieldFlagsRef,
  prefill: prefillRef,
  initialAllocationRows,
  methodOptions,
  defaultMethodCode: props.defaultMethodCode,
  lockBillId: lockBillIdRef,
});

const showAddMoneyPanel = computed(
  () => props.kind === 'payment' && showFromLeg.value,
);

const selectedFromPotOption = computed(() => {
  if (props.kind !== 'payment' || !showFromLeg.value) return null;
  const id = fromPotId.value;
  if (id == null) return null;
  return props.fromPotOptions.find((o) => o.value === id) ?? null;
});

const displayPayPotBalance = computed((): number | null => {
  const opt = selectedFromPotOption.value;
  if (opt != null && Number.isFinite(Number(opt.amount))) {
    return Number(opt.amount);
  }
  return props.payPotBalance ?? null;
});

const displayPayBalanceShortfall = computed((): number => {
  if (props.kind !== 'payment' || !showFromLeg.value) {
    return props.payBalanceShortfall ?? 0;
  }
  const bal = displayPayPotBalance.value;
  if (bal == null) return props.payBalanceShortfall ?? 0;
  const need = Number(amount.value);
  if (!Number.isFinite(need) || need <= 0) return props.payBalanceShortfall ?? 0;
  return Math.max(0, need - bal);
});

const amountCurrencyRef = computed(() => {
  if (isProfileCashLeg.value) {
    return profileLegCurrency.value?.trim().toUpperCase() || 'BDT';
  }
  return props.amountCurrencyCode ?? 'BDT';
});
const booksCurrencyRef = computed(() => props.booksCurrencyCode ?? 'BDT');
const booksTenantIdRef = computed(() => props.booksTenantId ?? 0);
const profileIdRef = computed(() => props.profileId ?? null);
const profileLegDataEnabled = computed(() => dialogOpen.value && isProfileCashLeg.value);
const profileLegData = useProfileCashMovementLegData(
  booksTenantIdRef,
  profileIdRef,
  profileLegDataEnabled,
);

const {
  validateFx,
  settlementFxFields,
  sourceFxFields,
} = useMoneyPayDialogFx({
  dialogOpen,
  kind: kindRef,
  showFromLeg,
  fromPotId,
  toPotId,
  fromPotOptions: toRef(props, 'fromPotOptions'),
  toPotOptions: toRef(props, 'toPotOptions'),
  paymentCurrencyCode: amountCurrencyRef,
  booksCurrencyCode: booksCurrencyRef,
  booksTenantId: booksTenantIdRef,
});

const profileLegDisabledReason = computed((): string | null => {
  if (!isProfileCashLeg.value) return null;
  if (profileLegLocationPointId.value == null) {
    return props.kind === 'deposit' ? 'Choose a deposit location.' : 'Choose a withdraw location.';
  }
  const legCurrency = profileLegCurrency.value?.trim().toUpperCase() || 'BDT';
  if (props.kind === 'deposit') {
    if (profileLegDepositRequiresBundlePick.value) {
      if (profileLegBundleId.value == null || profileLegBundleId.value <= 0) {
        return 'Next: choose a bundle.';
      }
      return null;
    }
    if (legCurrency !== 'BDT') {
      const rate = Number(profileLegBooksRate.value);
      if (!Number.isFinite(rate) || rate <= 0) return 'Next: enter a books rate for a new bundle.';
    }
    return null;
  }
  if (profileLegBundleId.value == null || profileLegBundleId.value <= 0) {
    return 'Choose a bundle.';
  }
  return null;
});

const submitDisabledReasonResolved = computed(() => {
  const base = submitDisabledReason.value;
  if (base) return base;
  const profileLeg = profileLegDisabledReason.value;
  if (profileLeg) return profileLeg;
  const fx = validateFx();
  if (fx) return fx;
  if (props.kind === 'payment' && displayPayBalanceShortfall.value > 0) {
    return 'Add money to cover the payment amount.';
  }
  return null;
});

watch(amount, (v) => {
  emit('amountChange', Number(v) || 0);
});

const kindTitles: Record<MoneyPayKind, string> = {
  payment: 'Payment',
  deposit: 'Pay in',
  withdrawal: 'Pay out',
  transfer: 'Transfer',
};

const kindSubtitles: Partial<Record<MoneyPayKind, string>> = {
  deposit: 'Cash into a pot',
  withdrawal: 'Cash out of a pot',
  transfer: 'Move between pots',
};

const dialogTitle = computed(() => props.title?.trim() || kindTitles[props.kind]);

const subtitle = computed(
  () => props.subtitle?.trim() || kindSubtitles[props.kind] || null,
);

const methodLabel = computed(() => {
  if (props.kind === 'withdrawal') return 'Method';
  if (props.kind === 'deposit') return 'How they paid';
  return props.kind === 'payment' ? 'Method' : 'How they paid';
});

const submitLabelResolved = computed(() => {
  if (props.submitLabel?.trim()) return props.submitLabel.trim();
  if (props.kind === 'deposit') {
    return isProfileCashLeg.value ? 'Deposit' : 'Post receipt';
  }
  if (props.kind === 'withdrawal') return 'Cash out';
  if (props.kind === 'transfer') return 'Post transfer';
  return 'Add payment';
});

const amountTouched = ref(false);
const submitAttempted = ref(false);
const optionalDetailsOpen = ref(false);

watch(dialogOpen, (open) => {
  if (open) {
    amountTouched.value = false;
    submitAttempted.value = false;
    optionalDetailsOpen.value = false;
    const prefillCcy = props.prefill?.currencyCode?.trim().toUpperCase();
    profileLegCurrency.value = prefillCcy || 'BDT';
    profileLegLocationPointId.value = props.prefill?.legLocationPointId ?? null;
    const prefillBundleId = props.prefill?.toPotId;
    const allowPrefillBundle =
      !prefillCcy || prefillCcy === 'BDT' || props.kind !== 'deposit';
    profileLegBundleId.value =
      allowPrefillBundle && prefillBundleId != null && prefillBundleId > 0
        ? prefillBundleId
        : null;
    profileLegBooksRate.value = prefillCcy && prefillCcy !== 'BDT' ? null : 1;
    profileLegDepositRequiresBundlePick.value = false;
  }
});

const amountShowError = computed(
  () => amountTouched.value || submitAttempted.value,
);

const footerHint = computed(() => {
  const reason = submitDisabledReasonResolved.value;
  if (!reason) return null;
  // Profile cash legs show amount errors on their own field.
  if (reason === 'Next: enter an amount greater than zero.' && isProfileCashLeg.value) {
    return null;
  }
  return reason;
});

const showRequiredInstrumentExtras = computed(() => {
  if (!showInstrument) return false;
  const f = methodFieldFlags.value;
  return (
    (f.showChequeNumber && f.chequeNumberRequired)
    || (f.showInstrumentDate && f.instrumentDateRequired)
  );
});

const showOptionalInstrumentExtras = computed(() => {
  if (!showInstrument) return false;
  const f = methodFieldFlags.value;
  return (
    f.showInstrumentReference
    || (f.showInstrumentDate && !f.instrumentDateRequired)
  );
});

const showOptionalDetails = computed(() => {
  if (showReferenceNote) return true;
  return showOptionalInstrumentExtras.value;
});

const close = () => {
  amountTouched.value = false;
  submitAttempted.value = false;
  optionalDetailsOpen.value = false;
  emit('update:modelValue', false);
  emit('cancel');
};

const onSubmit = () => {
  submitAttempted.value = true;
  if (submitDisabledReasonResolved.value) return;
  const base = buildPayload();
  const { exchangeRate } = settlementFxFields();
  const { sourceCurrencyCode, transactionRate: txnRate } = sourceFxFields();
  const legCurrency = profileLegCurrency.value?.trim().toUpperCase() || null;
  const profilePotId = profileLegBundleId.value;
  const depositPotId =
    isProfileCashLeg.value
    && props.kind === 'deposit'
    && profileLegDepositRequiresBundlePick.value
      ? profilePotId
      : null;
  emit('submit', {
    ...base,
    exchangeRate,
    transactionRate: txnRate,
    sourceCurrencyCode: isProfileCashLeg.value ? legCurrency : sourceCurrencyCode,
    legCurrencyCode: isProfileCashLeg.value ? legCurrency : null,
    legLocationPointId:
      isProfileCashLeg.value ? profileLegLocationPointId.value : null,
    legLocationCode: isProfileCashLeg.value
      ? profileLegData.pointById(profileLegLocationPointId.value)?.code?.trim() || 'main'
      : null,
    legBooksRate:
      isProfileCashLeg.value
      && props.kind === 'deposit'
      && legCurrency !== 'BDT'
        ? Number(profileLegBooksRate.value) || null
        : null,
    fromPotId:
      isProfileCashLeg.value && props.kind === 'withdrawal'
        ? profilePotId
        : base.fromPotId,
    toPotId:
      isProfileCashLeg.value && props.kind === 'deposit'
        ? depositPotId
        : base.toPotId,
  });
};
</script>

<style scoped lang="scss">
.money-pay-dialog-card {
  width: min(760px, 96vw);
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  background: var(--tf-neutral-surface, #fff);
  border-radius: var(--tf-radius-md, 12px);
}

.money-pay-dialog__header {
  padding: var(--tf-space-md, 16px) var(--tf-space-md, 16px) var(--tf-space-sm, 8px);
}

.money-pay-dialog__title {
  font-size: 15px;
  font-weight: 600;
  line-height: 1.3;
  color: var(--tf-neutral-ink, #0f172a);
}

.money-pay-dialog__subtitle {
  font-size: 12px;
  color: var(--tf-neutral-muted, #475569);
  margin-top: 2px;
}

.money-pay-dialog__close {
  flex-shrink: 0;
  margin-top: -4px;
}

.money-pay-dialog__body {
  overflow-y: auto;
  padding: 0 var(--tf-space-md, 16px) var(--tf-space-md, 16px);
}

.money-pay-dialog__stack {
  display: flex;
  flex-direction: column;
  gap: var(--tf-space-lg, 20px);
}

.money-pay-dialog__section-body :deep(.bill-dialog-field__label) {
  margin-bottom: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-chrome-text, #5b6b80);
}

.money-pay-dialog__section-body :deep(.q-field--outlined .q-field__control) {
  border-radius: var(--tf-radius-sm, 8px);
}

.money-pay-dialog__field-icon {
  font-size: 18px;
  color: var(--tf-neutral-muted, #475569);
}

.money-pay-dialog__optional {
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
  border-radius: var(--tf-radius-sm, 8px);
  overflow: hidden;
  margin-top: 2px;
}

.money-pay-dialog__optional-body {
  padding: 0 var(--tf-space-md, 12px) var(--tf-space-md, 14px);
  display: flex;
  flex-direction: column;
  gap: var(--tf-space-md, 14px);
}

:deep(.money-pay-dialog__optional-header) {
  min-height: 44px;
  padding: 0 var(--tf-space-md, 12px);
  font-size: 13px;
  font-weight: 500;
  color: var(--tf-neutral-muted, #64748b);
}

:deep(.money-pay-dialog__optional-header .q-focus-helper) {
  display: none;
}

:deep(.money-pay-dialog__optional-chevron) {
  font-size: 16px;
  color: var(--tf-neutral-muted, #64748b);
}

.money-pay-dialog__summary {
  margin-bottom: var(--tf-space-md, 16px);
}

.money-pay-dialog__grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--tf-space-lg, 24px);
}

.money-pay-dialog__section-title {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text, #5b6b80);
  margin-bottom: var(--tf-space-sm, 8px);
  min-height: 17px;
}

.money-pay-dialog__section-title--right {
  margin-bottom: 6px;
}

.money-pay-dialog__section-title--spacer {
  visibility: hidden;
}

.money-pay-dialog__footer {
  border-top: 1px solid var(--tf-neutral-border, #e2e8f0);
  margin-top: var(--tf-space-xs, 4px);
}

.money-pay-dialog__footer-hint {
  font-size: 12px;
  color: var(--tf-warning, #b45309);
  text-align: right;
}

.money-pay-dialog__footer-actions {
  gap: var(--tf-space-md, 12px);
}

.money-pay-dialog__footer-actions :deep(.q-btn) {
  min-height: 42px;
  font-size: 14px;
}

.money-pay-dialog__footer-actions :deep(.q-btn--flat) {
  padding: 0 14px;
  font-weight: 500;
}

.money-pay-dialog__footer-actions :deep(.q-btn--unelevated) {
  min-width: 7.5rem;
  padding: 0 20px;
  font-weight: 600;
}

@media (min-width: 600px) {
  .money-pay-dialog__grid {
    grid-template-columns: 1fr 1fr;
    align-items: start;
  }
}

@media (max-width: 599px) {
  .money-pay-dialog__section-title--right,
  .money-pay-dialog__section-title--spacer {
    display: none;
  }
}
</style>

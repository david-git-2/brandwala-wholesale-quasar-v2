<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="bundleQuery.isLoading.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="bundleQuery.isError.value || !bill" class="col flex flex-center column q-gutter-sm">
      <span class="text-negative">{{ loadErrorMessage }}</span>
      <TfBtn variant="secondary" label="Go back" @click="goBack" />
    </div>

    <div v-else-if="!canRecordPayment" class="col flex flex-center column q-gutter-sm">
      <span class="text-grey-7">This bill cannot take a payment right now.</span>
      <TfBtn variant="secondary" label="Back to bill" @click="goBack" />
    </div>

    <template v-else>
      <div class="bill-pay-page__toolbar row items-center justify-between q-mb-sm shrink-0">
        <div class="text-h6 text-weight-bold">Pay bill</div>
        <div class="row items-center q-gutter-sm">
          <TfBtn variant="secondary" label="Cancel" @click="goBack" />
          <TfBtn
            variant="primary"
            icon="ph ph-wallet"
            label="Record payment"
            :loading="recordPaymentMutation.isPending.value"
            :disable="Boolean(finalSubmitDisabled)"
            data-test="bill-pay-submit"
            @click="onSubmit"
          />
        </div>
      </div>

      <div class="col overflow-auto bill-pay-page__body">
        <div class="bill-pay-page__stack column q-gutter-y-md">
          <MoneyPayDialogSummary
            :visible="true"
            :context="moneyPaySummary"
            :pay-amount="effectivePayAmount"
            :pay-currency-code="paymentDueCurrencyCode"
          />

          <q-card flat bordered class="q-pa-md">
            <div class="text-caption text-weight-bold text-uppercase text-grey-7">Bill</div>
            <div class="text-subtitle1 text-weight-bold q-mt-xs">{{ billLeafLabel }}</div>
            <div class="text-caption text-grey-7 q-mt-xs">
              Due {{ paymentDueAmount.toFixed(2) }} {{ paymentDueCurrencyCode }}
            </div>
          </q-card>

          <q-card
            v-if="!showPayerBundleLines && showToLeg"
            flat
            bordered
            class="q-pa-md"
          >
            <MoneyPayDialogAmountBlock
              :amount="amount"
              :currency-code="paymentDueCurrencyCode"
              :max-amount="paymentDueAmount"
              :show-error="amountTouched"
              data-test="bill-pay-amount"
              @update:amount="(v) => (amount = v)"
              @blur="amountTouched = true"
            />
            <p class="text-caption text-grey-7 q-mb-none q-mt-sm">
              Can be less than bill due, but not more.
            </p>
          </q-card>

          <q-card v-if="showPayerBundleLines" flat bordered class="q-pa-md">
            <div class="row items-center justify-between q-mb-sm">
              <div class="text-caption text-weight-bold text-uppercase text-grey-7">
                {{ isApBill ? 'Pay from' : 'Customer pays from' }}
              </div>
              <TfBtn
                variant="secondary"
                size="sm"
                icon="ph ph-plus"
                label="Add money"
                data-test="bill-pay-add-money"
                @click="openPayerDeposit"
              />
            </div>
            <div class="text-caption text-grey-7 q-mb-sm">{{ payFromPartyName }}</div>
            <BillPayBundleLinesEditor
              :lines="bundlePayLines"
              :bundle-options="fromPotOptions"
              :currency-code="paymentDueCurrencyCode"
              :total-amount="bundlePayTotal"
              :can-add-line="canAddBundleLine"
              :used-bundle-ids="usedBundleIds"
              :line-available="lineAvailable"
              :show-amount-error="showBundleAmountError"
              :show-bundle-error="showBundleSelectError"
              :parse-amount="parseBundleAmount"
              @add-line="addBundleLine"
              @remove-line="removeBundleLine"
              @update-line="updateBundleLine"
            />
          </q-card>

          <q-card v-if="showToLeg && !showPayerBundleLines" flat bordered class="q-pa-md" data-test="bill-pay-to-pot">
            <PaymentLegPotChips
              v-model="toPotId"
              leg-label="Receive at"
              :party-name="payToPartyName"
              :options="toPotOptions"
              :sections="toPotSections"
              :loading="toPotLoading"
            />
          </q-card>

          <q-card v-if="showToLeg && arDualCashbook" flat bordered class="q-pa-md" data-test="bill-pay-to-pot">
            <div class="row items-center justify-between q-mb-sm">
              <div class="text-caption text-weight-bold text-uppercase text-grey-7">Receive at</div>
              <TfBtn
                variant="secondary"
                size="sm"
                icon="ph ph-plus"
                label="New bundle"
                data-test="bill-pay-new-receive-bundle"
                @click="openReceiveDeposit"
              />
            </div>
            <PaymentLegPotChips
              v-model="toPotId"
              leg-label="Tenant location"
              :party-name="payToPartyName"
              :options="toPotOptions"
              :sections="toPotSections"
              :loading="toPotLoading"
            />
          </q-card>

          <q-card flat bordered class="q-pa-md">
            <div class="text-caption text-weight-bold text-uppercase text-grey-7 q-mb-md">
              Payment details
            </div>
            <div class="column q-gutter-y-md">
              <BillDialogField v-if="showDate" label="Payment date">
                <q-input
                  v-model="paymentDate"
                  outlined
                  dense
                  mask="####-##-##"
                  placeholder="YYYY-MM-DD"
                  hide-bottom-space
                  data-test="bill-pay-date"
                >
                  <template #append>
                    <q-icon name="ph ph-calendar" class="cursor-pointer">
                      <q-popup-proxy transition-show="scale" transition-hide="scale">
                        <q-date v-model="paymentDate" mask="YYYY-MM-DD" />
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
              </BillDialogField>

              <BillDialogField v-if="showInstrument" label="Method">
                <q-select
                  v-model="methodCode"
                  :options="resolvedMethodOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  hide-bottom-space
                  :loading="loadingPaymentMeta"
                  data-test="bill-pay-method"
                />
              </BillDialogField>

              <BillDialogField v-if="showInstrument && methodFieldFlags.showBank" :label="methodFieldFlags.bankLabel">
                <BdBankSelect
                  v-model="bdBankId"
                  :options="bdBankOptions"
                  :clearable="!methodFieldFlags.bankRequired"
                  :loading="loadingPaymentMeta"
                />
              </BillDialogField>

              <PaymentInstrumentExtrasFields
                v-if="showInstrument && showRequiredInstrumentExtras"
                external-labels
                omit-bank
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

              <BillDialogField label="Reference" hint="Optional">
                <q-input v-model="reference" outlined dense clearable hide-bottom-space />
              </BillDialogField>
              <BillDialogField label="Note" hint="Optional">
                <q-input v-model="note" outlined dense autogrow hide-bottom-space />
              </BillDialogField>
            </div>
          </q-card>
        </div>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import TfBtn from 'src/components/ui/TfBtn.vue';
import BillDialogField from '../components/BillDialogField.vue';
import BdBankSelect from '../components/BdBankSelect.vue';
import PaymentInstrumentExtrasFields from '../components/PaymentInstrumentExtrasFields.vue';
import PaymentLegPotChips from '../components/PaymentLegPotChips.vue';
import MoneyPayDialogSummary from '../components/MoneyPayDialogSummary.vue';
import MoneyPayDialogAmountBlock from '../components/MoneyPayDialogAmountBlock.vue';
import BillPayBundleLinesEditor from '../components/BillPayBundleLinesEditor.vue';
import { PROFILE_CASH_DEFAULT_METHOD } from 'src/modules/people/constants/profileCashMovementMethods';
import { useBillDetailBundleQuery } from '../composables/useBillDetailBundleQuery';
import { useBillPayCashbookLegsStore } from '../stores/billPayCashbookLegsStore';
import { useBillPayBillContext } from '../composables/useBillPayBillContext';
import { useBillPayPage } from '../composables/useBillPayPage';
import { useBillPayBundleLines } from '../composables/useBillPayBundleLines';
import { useMoneyPayDialogForm } from '../composables/useMoneyPayDialogForm';
import { useWholesalePaymentMethodMeta } from '../composables/useWholesalePaymentMethodMeta';
import { billDetailRoute } from '../utils/billRoutes';
import { useProfileCashMovementNav } from 'src/modules/people/composables/useProfileCashMovementNav';
import { cashbookNavAxesForBillDeposit } from '../utils/cashbookNavFromProfile';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();
const payCashbookLegsStore = useBillPayCashbookLegsStore();
const { goToCashMovement } = useProfileCashMovementNav();

const pageActive = ref(true);
const amountTouched = ref(false);

const billId = computed(() => {
  const raw = route.params.billId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const staffOperatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const operatingTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t?.id) return 0;
  return t.parent_id ?? t.id;
});
const booksTenantId = operatingTenantId;

const bundleQuery = useBillDetailBundleQuery(billId, operatingTenantId);
const bill = computed(() => bundleQuery.data.value?.bill);

watch(
  () => bundleQuery.data.value?.payCashbookLegs,
  (legs) => {
    payCashbookLegsStore.syncFromBundleQuery(billId.value, legs);
  },
  { immediate: true },
);

watch(billId, (id) => {
  if (id == null) payCashbookLegsStore.clear();
});

onMounted(() => {
  if (billId.value != null) {
    void bundleQuery.refetch();
  }
});

const {
  isApBill,
  billShipmentId,
  billProfileId,
  paymentDueAmount,
  paymentDueCurrencyCode,
  canRecordPayment,
  billLeafLabel,
} = useBillPayBillContext(bill, computed(() => bundleQuery.data.value), billId);

const {
  recordPaymentMutation,
  moneyPayFieldFlags,
  moneyPaySummary,
  moneyPayAllocationRows,
  moneyPayPrefill,
  fromPotOptions,
  toPotOptions,
  toPotSections,
  toPotLoading,
  payFromPartyName,
  payToPartyName,
  arDualCashbook,
  showPayerBundleLines,
  payerTopUpProfileId,
  receiveBundleProfileId,
  buildRecordPayload,
  refetchPayLegs,
} = useBillPayPage({
  billId,
  bill,
  operatingTenantId,
  staffOperatingTenantId,
  isApBill,
  billProfileId,
  paymentDueAmount,
  paymentDueCurrencyCode,
  billShipmentId,
  booksTenantId,
  pageActive,
});

const fieldFlagsRef = computed(() => moneyPayFieldFlags.value);
const prefillRef = computed(() => moneyPayPrefill.value);
const dialogOpenRef = ref(true);

const { methodOptions, resolvedMethodOptions, bdBankOptions, loading: loadingPaymentMeta } =
  useWholesalePaymentMethodMeta();

const {
  amount,
  paymentDate,
  methodCode,
  toPotId,
  reference,
  note,
  bdBankId,
  chequeNumber,
  instrumentDate,
  instrumentReference,
  showToLeg,
  showInstrument,
  showDate,
  methodFieldFlags,
  submitDisabledReason,
  buildPayload,
} = useMoneyPayDialogForm({
  kind: ref('payment'),
  dialogOpen: dialogOpenRef,
  fieldFlags: fieldFlagsRef,
  prefill: prefillRef,
  initialAllocationRows: moneyPayAllocationRows,
  methodOptions,
  defaultMethodCode: PROFILE_CASH_DEFAULT_METHOD,
  lockBillId: billId,
});

const showRequiredInstrumentExtras = computed(() => {
  const f = methodFieldFlags.value;
  return (
    f.chequeNumberRequired
    || f.instrumentDateRequired
    || f.instrumentReferenceRequired
    || f.bankRequired
  );
});

const {
  lines: bundlePayLines,
  totalAmount: bundlePayTotal,
  canAddLine: canAddBundleLine,
  usedBundleIds,
  addLine: addBundleLine,
  removeLine: removeBundleLine,
  updateLine: updateBundleLine,
  lineAvailable,
  showAmountError: showBundleAmountError,
  showBundleError: showBundleSelectError,
  buildBundleDebits,
  submitDisabledReason: bundleSubmitReason,
  submitAttempted: bundleSubmitAttempted,
  parseAmount: parseBundleAmount,
} = useBillPayBundleLines({
  enabled: showPayerBundleLines,
  bundleOptions: fromPotOptions,
  billDue: paymentDueAmount,
  billCurrency: paymentDueCurrencyCode,
  seedBundleId: computed(() => moneyPayPrefill.value.fromPotId ?? null),
  seedAmount: computed(() => moneyPayPrefill.value.amount ?? null),
});

watch(
  bundlePayTotal,
  (total) => {
    if (showPayerBundleLines.value) {
      amount.value = total > 0 ? total : null;
    }
  },
  { immediate: true },
);

const effectivePayAmount = computed(() => {
  if (showPayerBundleLines.value) return bundlePayTotal.value;
  return Number(amount.value) || 0;
});

const finalSubmitDisabled = computed(
  () => bundleSubmitReason.value || submitDisabledReason.value,
);

const loadErrorMessage = computed(() => {
  const err = bundleQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load bill.';
});

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined,
);

const goBack = () => {
  const id = billId.value;
  if (id != null) {
    void router.push(billDetailRoute(id, tenantSlug.value));
    return;
  }
  void router.back();
};

const payPageReturnPath = computed(() => route.fullPath);

const depositPrefillAmount = computed((): number | null => {
  const due = paymentDueAmount.value;
  if (showPayerBundleLines.value) {
    const paying = bundlePayTotal.value;
    if (paying > 0) {
      let covered = 0;
      for (const line of bundlePayLines.value) {
        const id = line.bundleId;
        const want = Number(line.amount) || 0;
        if (id == null || want <= 0) continue;
        const avail = lineAvailable(id);
        if (avail != null) covered += Math.min(want, avail);
      }
      const shortfall = paying - covered;
      if (shortfall > 0.009) return Math.round(shortfall * 100) / 100;
    }
  }
  return due > 0 ? due : null;
});

const depositPrefillCurrency = computed(() => paymentDueCurrencyCode.value);

const openPayerDeposit = () => {
  const profileId = payerTopUpProfileId.value;
  if (profileId == null) return;
  const axes = cashbookNavAxesForBillDeposit({
    profileId,
    isApBill: isApBill.value,
    isPayerLeg: true,
    operatingTenantId: operatingTenantId.value,
    arDualCashbook: arDualCashbook.value,
  });
  goToCashMovement({
    kind: 'deposit',
    entityType: axes.entityType,
    entityId: axes.entityId,
    partyName: payFromPartyName.value,
    returnTo: payPageReturnPath.value,
    prefillCurrency: depositPrefillCurrency.value,
    prefillAmount: depositPrefillAmount.value ?? undefined,
  });
};

const openReceiveDeposit = () => {
  const profileId = receiveBundleProfileId.value;
  const axes = cashbookNavAxesForBillDeposit({
    profileId: profileId ?? 0,
    isApBill: false,
    isPayerLeg: false,
    operatingTenantId: operatingTenantId.value,
    arDualCashbook: arDualCashbook.value,
  });
  goToCashMovement({
    kind: 'deposit',
    entityType: axes.entityType,
    entityId: axes.entityId,
    partyName: payToPartyName.value,
    returnTo: payPageReturnPath.value,
    prefillCurrency: depositPrefillCurrency.value,
    prefillAmount: depositPrefillAmount.value ?? undefined,
  });
};

const onSubmit = async () => {
  bundleSubmitAttempted.value = true;
  amountTouched.value = true;
  if (finalSubmitDisabled.value) return;

  const debits = showPayerBundleLines.value ? buildBundleDebits() : null;
  const payload = buildPayload();
  if (showPayerBundleLines.value && debits != null) {
    payload.amount = debits.reduce((s, d) => s + d.amount, 0);
    payload.fromPotId = debits[0]?.cash_bundle_id ?? null;
  }

  const input = buildRecordPayload(payload, debits);
  try {
    await recordPaymentMutation.mutateAsync(input);
    goBack();
  } catch {
    // toast from mutation
  }
};

watch(
  () => billLeafLabel.value,
  (label) => {
    const slug = tenantSlug.value;
    const prefix = slug ? `/${slug}` : '';
    setCustomBreadcrumbs([
      { label: 'Bills', to: `${prefix}/app/bills` },
      { label, to: billId.value != null ? billDetailRoute(billId.value, slug) : undefined },
      { label: 'Pay' },
    ]);
  },
  { immediate: true },
);

onMounted(() => {
  void refetchPayLegs();
});

onUnmounted(clearCustomBreadcrumbs);
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
}

.bill-pay-page__body {
  min-height: 0;
}
</style>
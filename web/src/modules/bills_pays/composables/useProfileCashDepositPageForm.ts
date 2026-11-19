import { computed, ref, toRef, type Ref } from 'vue';
import {
  isProfileCashMovementMethod,
  sortProfileCashMovementMethods,
} from 'src/modules/people/constants/profileCashMovementMethods';
import { useProfileCashMovementLegData } from 'src/modules/people/composables/useProfileCashMovementLegData';
import { useMoneyPayDialogForm } from './useMoneyPayDialogForm';
import { useProfileDepositLines } from './useProfileDepositLines';
import { useWholesalePaymentMethodMeta } from './useWholesalePaymentMethodMeta';
import { PROFILE_CASH_DEFAULT_METHOD } from 'src/modules/people/constants/profileCashMovementMethods';
import type { MoneyPaySubmitPayload } from '../types/moneyPayDialog';

export function useProfileCashDepositPageForm(options: {
  pageReady: Ref<boolean>;
  profileId: Ref<number | null>;
  booksTenantId: Ref<number>;
}) {
  const kindRef = ref<'deposit'>('deposit');
  const fieldFlagsRef = ref({
    showAllocations: false,
    showFromLeg: false,
    showToLeg: false,
    showInstrument: true,
    showDate: true,
    showReferenceNote: true,
  });

  const profileLegCurrency = ref('BDT');
  const profileLegLocationPointId = ref<number | null>(null);
  const profileLegBundleId = ref<number | null>(null);
  const profileLegBooksRate = ref<number | null>(1);
  const profileLegDepositRequiresBundlePick = ref(false);

  const pageOpen = toRef(options, 'pageReady');

  const { loadingPaymentMeta, methodOptions, bdBankOptions } = useWholesalePaymentMethodMeta(
    PROFILE_CASH_DEFAULT_METHOD,
    pageOpen,
  );

  const resolvedMethodOptions = computed(() => {
    const filtered = methodOptions.value.filter(isProfileCashMovementMethod);
    return sortProfileCashMovementMethods(filtered.length ? filtered : methodOptions.value);
  });

  const {
    paymentDate,
    buildPayload,
  } = useMoneyPayDialogForm({
    kind: kindRef,
    dialogOpen: pageOpen,
    fieldFlags: fieldFlagsRef,
    prefill: ref(null),
    initialAllocationRows: ref([]),
    methodOptions: resolvedMethodOptions,
    defaultMethodCode: PROFILE_CASH_DEFAULT_METHOD,
    lockBillId: ref(null),
  });

  const {
    lines: depositLines,
    addLine: addDepositLine,
    removeLine: removeDepositLine,
    trimPostedLines: trimDepositLines,
    totalAmount: depositLinesTotal,
    buildDepositLines,
    submitDisabledReason: depositLinesSubmitDisabledReason,
    canAddLine: canAddDepositLine,
  } = useProfileDepositLines({
    dialogOpen: pageOpen,
    methodOptions: resolvedMethodOptions,
    defaultMethodCode: PROFILE_CASH_DEFAULT_METHOD,
  });

  const booksTenantIdRef = computed(() => options.booksTenantId.value);
  const profileIdRef = computed(() => options.profileId.value);
  const profileLegData = useProfileCashMovementLegData(
    booksTenantIdRef,
    profileIdRef,
    pageOpen,
  );

  const profileLegDisabledReason = computed((): string | null => {
    if (profileLegLocationPointId.value == null) {
      return 'Choose a deposit location.';
    }
    const legCurrency = profileLegCurrency.value?.trim().toUpperCase() || 'BDT';
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
  });

  const submitDisabledReason = computed((): string | null => {
    const lineReason = depositLinesSubmitDisabledReason.value;
    if (lineReason) return lineReason;
    return profileLegDisabledReason.value;
  });

  const locationLabel = computed(() => {
    const point = profileLegData.pointById(profileLegLocationPointId.value);
    return point?.name?.trim() || point?.code?.trim() || null;
  });

  const bundleLabel = computed(() => {
    const id = profileLegBundleId.value;
    if (id == null || id <= 0) return null;
    const bundle = profileLegData.bundles.value.find((b) => b.bundleId === id);
    if (!bundle) return `Bundle #${id}`;
    return `${bundle.locationName} · ${bundle.currencyCode}`;
  });

  const buildSubmitPayload = (): MoneyPaySubmitPayload => {
    const base = buildPayload();
    const legCurrency = profileLegCurrency.value?.trim().toUpperCase() || null;
    const profilePotId = profileLegBundleId.value;
    const depositPotId =
      profileLegDepositRequiresBundlePick.value ? profilePotId : null;
    const depositLinePayload = buildDepositLines();
    const multiTotal = depositLinesTotal.value;
    return {
      ...base,
      amount: multiTotal,
      depositLines: depositLinePayload,
      sourceCurrencyCode: legCurrency,
      legCurrencyCode: legCurrency,
      legLocationPointId: profileLegLocationPointId.value,
      legLocationCode:
        profileLegData.pointById(profileLegLocationPointId.value)?.code?.trim() || 'main',
      legBooksRate: legCurrency !== 'BDT' ? Number(profileLegBooksRate.value) || null : null,
      toPotId: depositPotId,
    };
  };

  const submitAttempted = ref(false);

  return {
    loadingPaymentMeta,
    resolvedMethodOptions,
    profileLegCurrency,
    profileLegLocationPointId,
    profileLegBundleId,
    profileLegBooksRate,
    profileLegDepositRequiresBundlePick,
    paymentDate,
    depositLines,
    addDepositLine,
    removeDepositLine,
    trimDepositLines,
    depositLinesTotal,
    canAddDepositLine,
    bdBankOptions,
    submitDisabledReason,
    locationLabel,
    bundleLabel,
    buildSubmitPayload,
    submitAttempted,
  };
}
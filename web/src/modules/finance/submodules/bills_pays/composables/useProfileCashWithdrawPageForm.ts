import { computed, ref, toRef, type Ref } from 'vue';
import {
  isProfileCashMovementMethod,
  sortProfileCashMovementMethods,
  PROFILE_CASH_DEFAULT_METHOD,
} from 'src/modules/people/constants/profileCashMovementMethods';
import { useProfileCashMovementLegData } from 'src/modules/people/composables/useProfileCashMovementLegData';
import { useMoneyPayDialogForm } from './useMoneyPayDialogForm';
import { useWholesalePaymentMethodMeta } from './useWholesalePaymentMethodMeta';
import type { MoneyPaySubmitPayload } from '../types/moneyPayDialog';
export function useProfileCashWithdrawPageForm(options: {
  pageReady: Ref<boolean>;
  profileId: Ref<number | null>;
  booksTenantId: Ref<number>;
}) {
  const kindRef = ref<'withdrawal'>('withdrawal');
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

  const { loadingPaymentMeta, methodOptions } = useWholesalePaymentMethodMeta(
    PROFILE_CASH_DEFAULT_METHOD,
    pageOpen,
  );

  const resolvedMethodOptions = computed(() => {
    const filtered = methodOptions.value.filter(isProfileCashMovementMethod);
    return sortProfileCashMovementMethods(filtered.length ? filtered : methodOptions.value);
  });

  const {
    amount,
    paymentDate,
    methodCode,
    reference,
    note,
    bdBankId,
    chequeNumber,
    instrumentDate,
    instrumentReference,
    buildPayload,
    methodFieldFlags,
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

  const booksTenantIdRef = computed(() => options.booksTenantId.value);
  const profileIdRef = computed(() => options.profileId.value);
  useProfileCashMovementLegData(booksTenantIdRef, profileIdRef, pageOpen);

  const profileLegDisabledReason = computed((): string | null => {
    if (profileLegLocationPointId.value == null) {
      return 'Choose a withdraw location.';
    }
    if (profileLegBundleId.value == null || profileLegBundleId.value <= 0) {
      return 'Choose a bundle.';
    }
    const pay = Number(amount.value);
    if (!Number.isFinite(pay) || pay <= 0) {
      return 'Enter an amount greater than zero.';
    }
    const flags = methodFieldFlags.value;
    if (flags.showChequeNumber && flags.chequeNumberRequired && !chequeNumber.value.trim()) {
      return 'Enter cheque number.';
    }
    if (flags.showInstrumentDate && flags.instrumentDateRequired && !instrumentDate.value.trim()) {
      return 'Enter instrument date.';
    }
    return null;
  });

  const buildSubmitPayload = (): MoneyPaySubmitPayload => {
    const base = buildPayload();
    const legCurrency = profileLegCurrency.value?.trim().toUpperCase() || null;
    return {
      ...base,
      sourceCurrencyCode: legCurrency,
      legCurrencyCode: legCurrency,
      legLocationPointId: profileLegLocationPointId.value,
      fromPotId: profileLegBundleId.value,
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
    amount,
    paymentDate,
    methodCode,
    reference,
    note,
    bdBankId,
    chequeNumber,
    instrumentDate,
    instrumentReference,
    methodFieldFlags,
    submitDisabledReason: profileLegDisabledReason,
    buildSubmitPayload,
    submitAttempted,
  };
}
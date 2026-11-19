import { computed, ref, type ComputedRef, type Ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useQueryClient } from '@tanstack/vue-query';
import { billsQueryKeys } from '../services/billsQueryKeys';
import type { BillDetailBundle } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { useBillPayCashbookLegsStore } from '../stores/billPayCashbookLegsStore';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCashbookLegPots, type CashbookLegPotChipOption } from './useCashbookLegPots';
import { useBooksCurrencyCode } from './useBooksCurrencyCode';
import {
  useRecordBillPaymentMutation,
  type RecordBillPaymentInput,
} from './useRecordBillPaymentMutation';
import type { OpenBillAllocRow } from './useOpenBillAllocations';
import type {
  MoneyPayDialogFieldFlags,
  MoneyPaySubmitPayload,
  MoneyPaySummaryContext,
} from '../types/moneyPayDialog';
import type { BundleDebitPayload } from './useBillPayBundleLines';

function findPotChipOption(
  options: CashbookLegPotChipOption[],
  potId: number | null,
): CashbookLegPotChipOption | null {
  if (potId == null || potId <= 0) return null;
  return options.find((o) => o.value === potId) ?? null;
}

export function useBillPayPage(options: {
  billId: ComputedRef<number | null>;
  bill: ComputedRef<GlobalInvoiceDetail | undefined>;
  operatingTenantId: ComputedRef<number>;
  staffOperatingTenantId: ComputedRef<number>;
  isApBill: ComputedRef<boolean>;
  billProfileId: ComputedRef<number | null>;
  paymentDueAmount: ComputedRef<number>;
  paymentDueCurrencyCode: ComputedRef<string>;
  billShipmentId: ComputedRef<number | null>;
  booksTenantId: ComputedRef<number>;
  pageActive: Ref<boolean>;
}) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();
  const payCashbookLegsStore = useBillPayCashbookLegsStore();
  const { payCashbookLegs } = storeToRefs(payCashbookLegsStore);
  const booksCurrencyCode = useBooksCurrencyCode();
  const recordPaymentMutation = useRecordBillPaymentMutation(() => options.billId.value);

  const legBooksTenantId = computed(() => options.booksTenantId.value);

  const apPayFromProfileId = computed(
    () =>
      options.bill.value?.from_profile_id
      ?? options.bill.value?.from_profile?.id
      ?? null,
  );
  const apPayToProfileId = computed(
    () =>
      options.bill.value?.to_profile_id
      ?? options.bill.value?.to_profile?.id
      ?? options.billProfileId.value
      ?? null,
  );

  const arReceiveProfileId = computed(
    () =>
      options.bill.value?.to_profile_id
      ?? options.bill.value?.to_profile?.id
      ?? null,
  );

  const arPayerProfileId = computed(
    () =>
      options.bill.value?.from_profile_id
      ?? options.bill.value?.from_profile?.id
      ?? options.billProfileId.value
      ?? null,
  );

  const bundleLegsReady = computed(() => {
    const legs = payCashbookLegs.value;
    if (!legs) return false;
    const dueCur = options.paymentDueCurrencyCode.value.trim().toUpperCase() || 'BDT';
    const legCur = legs.currency_code.trim().toUpperCase() || 'BDT';
    if (legCur === dueCur) return true;
    const hasDuePot = (leg: typeof legs.from_leg) =>
      leg?.pots.some((p) => p.currency_code.trim().toUpperCase() === dueCur) ?? false;
    return hasDuePot(legs.from_leg) || hasDuePot(legs.to_leg);
  });

  const storeLegForProfile = (
    side: 'from' | 'to',
    profileId: ComputedRef<number | null | undefined>,
  ) =>
    computed(() => {
      const legs = payCashbookLegs.value;
      const pid = profileId.value;
      if (!legs || pid == null || pid <= 0) return null;
      const leg = side === 'from' ? legs.from_leg : legs.to_leg;
      if (!leg || leg.profile_id !== pid) return null;
      return leg;
    });

  const legsEnabled = computed(
    () => options.pageActive.value && legBooksTenantId.value > 0,
  );

  const bundledApFromLeg = storeLegForProfile('from', apPayFromProfileId);
  const bundledApToLeg = storeLegForProfile('to', apPayToProfileId);
  const bundledArToLeg = storeLegForProfile('to', arReceiveProfileId);
  const bundledArFromLeg = storeLegForProfile('from', arPayerProfileId);

  const arDualCashbook = computed(
    () =>
      !options.isApBill.value
      && bundleLegsReady.value
      && bundledArFromLeg.value != null
      && bundledArToLeg.value != null,
  );

  const {
    selectedPotId: apFromPotId,
    chipOptions: apFromPotOptions,
    locationSections: apFromLocationSections,
    loading: apFromPotLoading,
    selectPotAfterRefresh: selectApFromPotAfterRefresh,
  } = useCashbookLegPots(
    apPayFromProfileId,
    legBooksTenantId,
    computed(() => legsEnabled.value && options.isApBill.value),
    options.paymentDueCurrencyCode,
    bundledApFromLeg,
    undefined,
    computed(() => true),
  );

  const {
    selectedPotId: apToPotId,
    chipOptions: apToPotOptions,
    locationSections: apToLocationSections,
    loading: apToPotLoading,
  } = useCashbookLegPots(
    apPayToProfileId,
    legBooksTenantId,
    computed(() => legsEnabled.value && options.isApBill.value),
    options.paymentDueCurrencyCode,
    bundledApToLeg,
  );

  const {
    selectedPotId: arFromPotId,
    chipOptions: arFromPotOptions,
    locationSections: arFromLocationSections,
    loading: arFromPotLoading,
    selectPotAfterRefresh: selectArFromPotAfterRefresh,
  } = useCashbookLegPots(
    arPayerProfileId,
    legBooksTenantId,
    computed(() => legsEnabled.value && !options.isApBill.value),
    options.paymentDueCurrencyCode,
    bundledArFromLeg,
    undefined,
    computed(() => false),
  );

  const {
    selectedPotId: arToPotId,
    chipOptions: arToPotOptions,
    locationSections: arToLocationSections,
    loading: arToPotLoading,
    selectPotAfterRefresh: selectArToPotAfterRefresh,
  } = useCashbookLegPots(
    arReceiveProfileId,
    legBooksTenantId,
    computed(() => legsEnabled.value && !options.isApBill.value),
    options.paymentDueCurrencyCode,
    bundledArToLeg,
  );

  const fromPotOptions = computed(() => {
    if (options.isApBill.value) return apFromPotOptions.value;
    if (arDualCashbook.value) return arFromPotOptions.value;
    return [];
  });
  const toPotOptions = computed(() =>
    options.isApBill.value ? apToPotOptions.value : arToPotOptions.value,
  );
  const fromPotSections = computed(() => {
    if (options.isApBill.value) return apFromLocationSections.value;
    if (arDualCashbook.value) return arFromLocationSections.value;
    return [];
  });
  const toPotSections = computed(() =>
    options.isApBill.value ? apToLocationSections.value : arToLocationSections.value,
  );
  const fromPotLoading = computed(() => {
    if (options.isApBill.value) return apFromPotLoading.value;
    if (arDualCashbook.value) return arFromPotLoading.value;
    return false;
  });
  const toPotLoading = computed(() =>
    options.isApBill.value ? apToPotLoading.value : arToPotLoading.value,
  );

  const showPayerBundleLines = computed(
    () => options.isApBill.value || arDualCashbook.value,
  );

  const payFromPartyName = computed(() => {
    if (options.isApBill.value) {
      return (
        options.bill.value?.from_profile?.name?.trim()
        || authStore.selectedTenant?.name
        || 'Tenant'
      );
    }
    return options.bill.value?.from_profile?.name?.trim() || 'Customer';
  });

  const payToPartyName = computed(() => {
    if (options.isApBill.value) {
      return (
        options.bill.value?.to_profile?.name?.trim()
        || options.bill.value?.profiles?.name
        || 'Payee'
      );
    }
    return authStore.selectedTenant?.name || 'Tenant';
  });

  const moneyPayFieldFlags = computed((): MoneyPayDialogFieldFlags => {
    if (options.isApBill.value) {
      return { showAllocations: false, showFromLeg: false, showToLeg: false };
    }
    if (arDualCashbook.value) {
      return {
        showFromLeg: false,
        showToLeg: true,
        showAllocations: false,
        showCreateToBundle: true,
      };
    }
    return { showFromLeg: false, showAllocations: false };
  });

  const moneyPaySummary = computed((): MoneyPaySummaryContext => ({
    modeCaption: options.isApBill.value ? 'Pay out' : 'Collect on bill',
    dueAmount: options.paymentDueAmount.value,
    dueCurrencyCode: options.paymentDueCurrencyCode.value,
    payerName: payFromPartyName.value,
    payeeName: payToPartyName.value,
  }));

  const moneyPayAllocationRows = computed((): OpenBillAllocRow[] => {
    const id = options.billId.value;
    const b = options.bill.value;
    if (id == null || !b) return [];
    const due = options.paymentDueAmount.value;
    return [
      {
        id,
        invoice_no: b.invoice_no?.trim() || `#${id}`,
        due_amount: due,
        selected: true,
        allocAmount: due,
      },
    ];
  });

  const payerTopUpProfileId = computed(() => {
    if (options.isApBill.value) return apPayFromProfileId.value;
    if (arDualCashbook.value) return arPayerProfileId.value;
    return arReceiveProfileId.value;
  });

  const receiveBundleProfileId = computed(() => arReceiveProfileId.value);

  const moneyPayPrefill = computed(() => {
    const due = options.paymentDueAmount.value;
    let amount: number | null = due > 0 ? due : null;
    const primaryBundle = options.isApBill.value
      ? apFromPotId.value
      : arDualCashbook.value
        ? arFromPotId.value
        : null;
    if (amount != null && primaryBundle != null && showPayerBundleLines.value) {
      const opt = findPotChipOption(fromPotOptions.value, primaryBundle);
      const bal = opt != null ? Number(opt.amount) : null;
      if (bal != null && bal > 0 && bal < amount) {
        amount = bal;
      }
    }
    return {
      amount,
      fromPotId: primaryBundle,
      toPotId: options.isApBill.value ? apToPotId.value : arToPotId.value,
    };
  });

  const payerProfileId = computed(
    () =>
      options.bill.value?.from_profile_id
      ?? options.bill.value?.from_profile?.id
      ?? null,
  );

  const buildRecordPayload = (
    payload: MoneyPaySubmitPayload,
    bundleDebits: BundleDebitPayload[] | null,
  ): RecordBillPaymentInput => {
    const billId = options.billId.value;
    const payerId = payerProfileId.value;
    if (billId == null || payerId == null) {
      throw new Error('Bill not ready.');
    }

    const isAp = options.isApBill.value;
    const dual = arDualCashbook.value;

    let fromPotId: number | null;
    let paymentAmount = payload.amount;

    if (bundleDebits != null && bundleDebits.length > 0) {
      fromPotId = bundleDebits[0].cash_bundle_id;
      paymentAmount = bundleDebits.reduce((s, d) => s + d.amount, 0);
    } else if (isAp || dual) {
      fromPotId = payload.fromPotId;
    } else {
      fromPotId = payload.toPotId;
    }

    if (fromPotId == null) {
      throw new Error(
        isAp || dual
          ? 'Choose which cash bundle pays from.'
          : 'Choose where to receive cash.',
      );
    }
    if (dual && (payload.toPotId == null || payload.toPotId <= 0)) {
      throw new Error('Choose which cash bundle receives the payment.');
    }

    const settlement =
      options.paymentDueCurrencyCode.value.trim() || booksCurrencyCode.value;

    const selectedFromPot =
      isAp || dual
        ? findPotChipOption(fromPotOptions.value, fromPotId)
        : null;

    return {
      tenantId: options.operatingTenantId.value,
      billId,
      isAp,
      payerProfileId: payerId,
      shipmentId: options.billShipmentId.value,
      paidOn: payload.paymentDate,
      paymentAmount,
      billDueAmount: options.paymentDueAmount.value,
      settlementCurrencyCode: settlement,
      fromPotId,
      fromPotCurrencyCode: selectedFromPot?.currencyCode ?? undefined,
      fromPotAvailableBalance:
        bundleDebits != null && bundleDebits.length > 1
          ? undefined
          : selectedFromPot != null
            ? Number(selectedFromPot.amount)
            : undefined,
      toPotId: payload.toPotId,
      skipCustomerAutoDeposit: !isAp && dual,
      methodCode: payload.methodCode,
      reference: payload.reference,
      note: payload.note,
      instrumentFields: payload.instrumentFields,
      bundleDebits: bundleDebits != null && bundleDebits.length > 0 ? bundleDebits : undefined,
    };
  };

  const refetchPayLegs = async () => {
    const billId = options.billId.value;
    if (billId == null) return;
    await queryClient.refetchQueries({ queryKey: billsQueryKeys.detailBundle(billId) });
    const fresh = queryClient.getQueryData<BillDetailBundle>(
      billsQueryKeys.detailBundle(billId),
    );
    payCashbookLegsStore.replaceFromBundleQuery(billId, fresh?.payCashbookLegs);
  };

  const selectPotAfterDeposit = (potId: number, purpose: 'payer' | 'receive') => {
    if (!Number.isFinite(potId) || potId <= 0) return;
    if (purpose === 'receive') {
      selectArToPotAfterRefresh(potId);
    } else if (options.isApBill.value) {
      selectApFromPotAfterRefresh(potId);
    } else if (arDualCashbook.value) {
      selectArFromPotAfterRefresh(potId);
    }
  };

  return {
    recordPaymentMutation,
    moneyPayFieldFlags,
    moneyPaySummary,
    moneyPayAllocationRows,
    moneyPayPrefill,
    fromPotOptions,
    toPotOptions,
    fromPotSections,
    toPotSections,
    fromPotLoading,
    toPotLoading,
    payFromPartyName,
    payToPartyName,
    paymentDueCurrencyCode: options.paymentDueCurrencyCode,
    booksCurrencyCode,
    operatingTenantId: options.operatingTenantId,
    staffOperatingTenantId: options.staffOperatingTenantId,
    arDualCashbook,
    showPayerBundleLines,
    payerTopUpProfileId,
    receiveBundleProfileId,
    buildRecordPayload,
    refetchPayLegs,
    selectPotAfterDeposit,
    apFromPotId,
    arFromPotId,
    arToPotId,
  };
}
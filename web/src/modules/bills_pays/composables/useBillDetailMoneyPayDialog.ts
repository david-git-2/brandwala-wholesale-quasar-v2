import { computed, ref, type ComputedRef, type Ref } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { PROFILE_CASH_DEFAULT_METHOD } from 'src/modules/people/constants/profileCashMovementMethods';
import { applyDepositCacheUpdate } from './applyDepositCacheUpdate';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCashbookLegPots } from './useCashbookLegPots';
import { useBooksCurrencyCode } from './useBooksCurrencyCode';
import {
  useRecordBillPaymentMutation,
  type RecordBillPaymentInput,
} from './useRecordBillPaymentMutation';
import type { OpenBillAllocRow } from './useOpenBillAllocations';
import type {
  MoneyPayDialogFieldFlags,
  MoneyPayDialogPrefill,
  MoneyPaySubmitPayload,
  MoneyPaySummaryContext,
} from '../types/moneyPayDialog';
import type { BillPayCashbookLegs } from '../types/billPayCashbookLegs';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';
import { createPayIdempotencyKey } from '../repositories/paysRepository';
import { buildKernelPayMovementMeta } from '../utils/kernelPayMovementMeta';

export function useBillDetailMoneyPayDialog(options: {
  billId: ComputedRef<number | null>;
  bill: ComputedRef<GlobalInvoiceDetail | undefined>;
  operatingTenantId: ComputedRef<number>;
  isApBill: ComputedRef<boolean>;
  billProfileId: ComputedRef<number | null>;
  paymentDueAmount: ComputedRef<number>;
  paymentDueCurrencyCode: ComputedRef<string>;
  billShipmentId: ComputedRef<number | null>;
  payCashbookLegs?: ComputedRef<BillPayCashbookLegs | null | undefined>;
}) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();
  const dialogOpen = ref(false);
  const booksCurrencyCode = useBooksCurrencyCode();
  const recordPaymentMutation = useRecordBillPaymentMutation(() => options.billId.value);

  const dialogEnabled = computed(
    () => dialogOpen.value && options.operatingTenantId.value > 0,
  );

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

  const legBooksTenantId = computed(() => options.operatingTenantId.value);

  const bundleLegsReady = computed(() => {
    const legs = options.payCashbookLegs?.value;
    if (!legs) return false;
    const dueCur = options.paymentDueCurrencyCode.value.trim().toUpperCase() || 'BDT';
    return legs.currency_code === dueCur;
  });

  const apLegsEnabled = computed(
    () => options.isApBill.value && legBooksTenantId.value > 0 && dialogOpen.value,
  );

  const arLegsEnabled = computed(
    () => !options.isApBill.value && legBooksTenantId.value > 0 && dialogOpen.value,
  );

  const bundledApFromLeg = computed(() => {
    const legs = options.payCashbookLegs?.value;
    if (!legs || !bundleLegsReady.value) return null;
    return legs.from_leg;
  });

  const bundledApToLeg = computed(() => {
    const legs = options.payCashbookLegs?.value;
    if (!legs || !bundleLegsReady.value) return null;
    return legs.to_leg;
  });

  const bundledArToLeg = computed(() => bundledApToLeg.value);

  const bundledArFromLeg = computed(() => {
    const legs = options.payCashbookLegs?.value;
    if (!legs || !bundleLegsReady.value) return null;
    return legs.from_leg;
  });

  const arPayerProfileId = computed(
    () =>
      options.bill.value?.from_profile_id
      ?? options.bill.value?.from_profile?.id
      ?? options.billProfileId.value
      ?? null,
  );

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
    selectedPotBalance: apFromPotBalance,
    sourceCurrencyCode: apFromPotCurrency,
    cashbookPointId: apFromCashbookPointId,
    selectPotAfterRefresh: selectApFromPotAfterRefresh,
  } = useCashbookLegPots(
    apPayFromProfileId,
    legBooksTenantId,
    apLegsEnabled,
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
    apLegsEnabled,
    options.paymentDueCurrencyCode,
    bundledApToLeg,
  );

  const {
    selectedPotId: arFromPotId,
    chipOptions: arFromPotOptions,
    locationSections: arFromLocationSections,
    loading: arFromPotLoading,
    selectedPotBalance: arFromPotBalance,
    sourceCurrencyCode: arFromPotCurrency,
    cashbookPointId: arFromCashbookPointId,
    selectPotAfterRefresh: selectArFromPotAfterRefresh,
  } = useCashbookLegPots(
    arPayerProfileId,
    legBooksTenantId,
    arLegsEnabled,
    options.paymentDueCurrencyCode,
    bundledArFromLeg,
    undefined,
    // Collect: show payer bundles at $0 so staff can pick a bundle and use Add money.
    computed(() => false),
  );

  const {
    selectedPotId: arToPotId,
    chipOptions: arToPotOptions,
    locationSections: arToLocationSections,
    loading: arToPotLoading,
    cashbookPointId: arToCashbookPointId,
    selectPotAfterRefresh: selectArToPotAfterRefresh,
  } = useCashbookLegPots(
    arReceiveProfileId,
    legBooksTenantId,
    arLegsEnabled,
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

  const payFromPartyName = computed(() => {
    if (options.isApBill.value) {
      return (
        options.bill.value?.from_profile?.name?.trim() ||
        authStore.selectedTenant?.name ||
        'Tenant'
      );
    }
    return options.bill.value?.from_profile?.name?.trim() || 'Customer';
  });

  const payToPartyName = computed(() => {
    if (options.isApBill.value) {
      return (
        options.bill.value?.to_profile?.name?.trim() ||
        options.bill.value?.profiles?.name ||
        'Payee'
      );
    }
    return authStore.selectedTenant?.name || 'Tenant';
  });

  const moneyPayFieldFlags = computed((): MoneyPayDialogFieldFlags => {
    if (options.isApBill.value) {
      return { showAllocations: false, showToLeg: false };
    }
    if (arDualCashbook.value) {
      return {
        showFromLeg: true,
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

  type PayDepositPurpose = 'from_top_up' | 'to_new_bundle';
  const payDepositPurpose = ref<PayDepositPurpose>('from_top_up');
  const payDepositDialogOpen = ref(false);

  const payDepositDefaultLocationPointId = computed(() => {
    if (payDepositPurpose.value === 'to_new_bundle' && arToCashbookPointId.value != null) {
      return arToCashbookPointId.value;
    }
    if (options.isApBill.value && apFromCashbookPointId.value != null) {
      return apFromCashbookPointId.value;
    }
    if (arDualCashbook.value && arFromCashbookPointId.value != null) {
      return arFromCashbookPointId.value;
    }
    if (apFromCashbookPointId.value != null) return apFromCashbookPointId.value;
    const leg = options.isApBill.value
      ? bundledApFromLeg.value
      : payDepositPurpose.value === 'to_new_bundle'
        ? bundledArToLeg.value
        : arDualCashbook.value
          ? bundledArFromLeg.value
          : bundledArToLeg.value;
    const points = leg?.points ?? [];
    if (!points.length) return null;
    const main = points.find(
      (p) => p.is_active !== false && p.code?.trim().toLowerCase() === 'main',
    );
    const active = points.filter((p) => p.is_active !== false);
    return main?.id ?? active[0]?.id ?? null;
  });

  const payDepositDefaultLocationPointLabel = computed(() => {
    const pointId = payDepositDefaultLocationPointId.value;
    if (pointId == null) return null;
    const leg = options.isApBill.value
      ? bundledApFromLeg.value
      : payDepositPurpose.value === 'to_new_bundle'
        ? bundledArToLeg.value
        : arDualCashbook.value
          ? bundledArFromLeg.value
          : bundledArToLeg.value;
    const point = leg?.points?.find((p) => p.id === pointId);
    const name = point?.name?.trim();
    if (name) return name;
    return point?.code?.trim() || null;
  });

  const payDepositFieldFlags = computed((): MoneyPayDialogFieldFlags => ({
    showAllocations: false,
    showFromLeg: false,
    showToLeg: false,
    showInstrument: true,
    showDate: true,
    showReferenceNote: true,
  }));

  const payDepositPrefill = computed((): MoneyPayDialogPrefill => {
    const due = options.paymentDueAmount.value;
    const ccy = options.paymentDueCurrencyCode.value.trim().toUpperCase() || 'BDT';
    return {
      currencyCode: ccy,
      legLocationPointId: payDepositDefaultLocationPointId.value,
      legLocationPointLabel: payDepositDefaultLocationPointLabel.value,
      toPotId:
        payDepositPurpose.value === 'to_new_bundle'
          ? null
          : ccy === 'BDT' && options.isApBill.value
            ? apFromPotId.value
            : null,
      amount:
        payDepositPurpose.value === 'to_new_bundle'
          ? null
          : due > 0
            ? due
            : null,
      methodCode: PROFILE_CASH_DEFAULT_METHOD,
    };
  });

  const payDepositProfileId = computed(() => {
    if (payDepositPurpose.value === 'to_new_bundle') {
      return arReceiveProfileId.value;
    }
    if (options.isApBill.value) return apPayFromProfileId.value;
    if (arDualCashbook.value) return arPayerProfileId.value;
    return arReceiveProfileId.value;
  });

  const payDepositPartyName = computed(() => {
    if (payDepositPurpose.value === 'to_new_bundle') {
      return payToPartyName.value;
    }
    if (options.isApBill.value) {
      return payFromPartyName.value;
    }
    if (arDualCashbook.value) {
      return payFromPartyName.value;
    }
    return payToPartyName.value;
  });

  const openPayDepositDialog = () => {
    payDepositPurpose.value = 'from_top_up';
    if (payDepositProfileId.value == null) {
      showErrorNotification('Cash profile not ready for deposit.');
      return;
    }
    payDepositDialogOpen.value = true;
  };

  const openPayReceiveBundleDeposit = () => {
    payDepositPurpose.value = 'to_new_bundle';
    if (arReceiveProfileId.value == null) {
      showErrorNotification('Tenant cash profile not ready.');
      return;
    }
    payDepositDialogOpen.value = true;
  };

  const payDepositDialogSubtitle = computed(() => {
    const ccy = options.paymentDueCurrencyCode.value.trim().toUpperCase() || 'BDT';
    const name = payDepositPartyName.value.trim();
    if (payDepositPurpose.value === 'to_new_bundle') {
      return name
        ? `Open a receive bundle on ${name}'s cashbook`
        : 'Open a receive bundle on the tenant cashbook';
    }
    return name
      ? `Add ${ccy} to ${name}'s cashbook before paying`
      : `Add ${ccy} before paying`;
  });

  const payPotBalance = computed(() => {
    if (options.isApBill.value) {
      if (apFromPotId.value == null) return null;
      const bal = apFromPotBalance.value;
      return bal != null ? Number(bal) : null;
    }
    if (arDualCashbook.value) {
      if (arFromPotId.value == null) return null;
      const bal = arFromPotBalance.value;
      return bal != null ? Number(bal) : null;
    }
    return null;
  });

  const moneyPayPrefill = computed(() => {
    const due = options.paymentDueAmount.value;
    let amount: number | null = due > 0 ? due : null;
    if (
      amount != null
      && (options.isApBill.value || arDualCashbook.value)
    ) {
      const bal = payPotBalance.value;
      if (bal != null && bal > 0 && bal < amount) {
        amount = bal;
      }
    }
    return {
      amount,
      fromPotId: options.isApBill.value
        ? apFromPotId.value
        : arDualCashbook.value
          ? arFromPotId.value
          : null,
      toPotId: options.isApBill.value ? apToPotId.value : arToPotId.value,
    };
  });

  const payPotBalanceLoading = computed(() => {
    if (options.isApBill.value) return apFromPotLoading.value;
    if (arDualCashbook.value) return arFromPotLoading.value;
    return false;
  });

  const payAmountForBalance = ref(0);

  const payBalanceShortfall = computed(() => {
    if (!options.isApBill.value && !arDualCashbook.value) return 0;
    if (payPotBalance.value == null) return 0;
    const need = payAmountForBalance.value;
    if (need <= 0) return 0;
    return Math.max(0, need - payPotBalance.value);
  });

  const onPayAmountPreview = (amount: number) => {
    payAmountForBalance.value = amount;
  };

  const payDepositMutation = useMutation({
    mutationFn: async (payload: MoneyPaySubmitPayload) => {
      const tenantId = options.operatingTenantId.value;
      const profileId = payDepositProfileId.value;
      if (!tenantId || profileId == null) {
        throw new Error('Cash profile not ready.');
      }
      const amount = Number(payload.amount);
      if (!Number.isFinite(amount) || amount <= 0) {
        throw new Error('Enter an amount greater than zero.');
      }
      const currency =
        payload.legCurrencyCode?.trim().toUpperCase()
        || options.paymentDueCurrencyCode.value.trim().toUpperCase()
        || 'BDT';
      if (payload.legLocationPointId == null) {
        throw new Error('Choose a deposit location.');
      }
      const selectedPotId = payload.toPotId;
      if (selectedPotId != null && selectedPotId <= 0) {
        throw new Error('Choose a bundle.');
      }
      const locationCode =
        payload.legLocationCode?.trim()
        || undefined;
      const deposit = await moneyKernelRepository.deposit({
        tenantId,
        profileId,
        amount,
        currencyCode: currency,
        potId: selectedPotId != null && selectedPotId > 0 ? selectedPotId : null,
        locationCode: selectedPotId != null && selectedPotId > 0 ? null : locationCode,
        booksRate: payload.legBooksRate ?? null,
        idempotencyKey: createPayIdempotencyKey(),
        meta: buildKernelPayMovementMeta(payload, {
          source: 'bill_pay_top_up',
        }),
      });
      return {
        deposit,
        tenantId,
        profileId,
        billId: options.billId.value,
        locationCode: locationCode ?? null,
        legLocationPointId: payload.legLocationPointId,
        legBooksRate: payload.legBooksRate ?? null,
      };
    },
    onSuccess: (result) => {
      showSuccessNotification('Deposit posted.');
      payDepositDialogOpen.value = false;
      applyDepositCacheUpdate(queryClient, {
        booksTenantId: result.tenantId,
        profileId: result.profileId,
        billId: result.billId,
        locationCode: result.locationCode,
        legLocationPointId: result.legLocationPointId,
        legBooksRate: result.legBooksRate,
        deposit: result.deposit,
      });
      const newPotId = result.deposit.pot_id;
      if (Number.isFinite(newPotId) && newPotId > 0) {
        if (payDepositPurpose.value === 'to_new_bundle') {
          selectArToPotAfterRefresh(newPotId);
        } else if (options.isApBill.value) {
          selectApFromPotAfterRefresh(newPotId);
        } else if (arDualCashbook.value) {
          selectArFromPotAfterRefresh(newPotId);
        }
      }
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not post deposit.');
    },
  });

  const onPayDepositSubmit = (payload: MoneyPaySubmitPayload) => {
    void payDepositMutation.mutateAsync(payload);
  };

  const openMoneyPayDialog = () => {
    dialogOpen.value = true;
  };

  const payerProfileId = computed(
    () =>
      options.bill.value?.from_profile_id
      ?? options.bill.value?.from_profile?.id
      ?? null,
  );

  const buildRecordPayload = (payload: MoneyPaySubmitPayload): RecordBillPaymentInput => {
    const billId = options.billId.value;
    const payerId = payerProfileId.value;
    if (billId == null || payerId == null) {
      throw new Error('Bill not ready.');
    }

    const isAp = options.isApBill.value;
    const dual = arDualCashbook.value;
    let fromPotId: number | null;
    if (isAp) {
      fromPotId = payload.fromPotId;
    } else if (dual) {
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

    return {
      tenantId: options.operatingTenantId.value,
      billId,
      isAp,
      payerProfileId: payerId,
      shipmentId: options.billShipmentId.value,
      paidOn: payload.paymentDate,
      paymentAmount: payload.amount,
      billDueAmount: options.paymentDueAmount.value,
      settlementCurrencyCode: settlement,
      fromPotId,
      fromPotCurrencyCode: isAp
        ? apFromPotCurrency.value
        : dual
          ? arFromPotCurrency.value
          : undefined,
      fromPotAvailableBalance: isAp
        ? apFromPotBalance.value
        : dual
          ? arFromPotBalance.value
          : undefined,
      toPotId: payload.toPotId,
      skipCustomerAutoDeposit: !isAp && dual,
      methodCode: payload.methodCode,
      reference: payload.reference,
      note: payload.note,
      instrumentFields: payload.instrumentFields,
    };
  };

  const onMoneyPaySubmit = async (payload: MoneyPaySubmitPayload) => {
    const input = buildRecordPayload(payload);
    await recordPaymentMutation.mutateAsync(input);
    dialogOpen.value = false;
  };

  return {
    dialogOpen,
    openMoneyPayDialog,
    onMoneyPaySubmit,
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
    payPotBalance,
    payPotBalanceLoading,
    payBalanceShortfall,
    onPayAmountPreview,
    payDepositDialogOpen,
    payDepositDialogSubtitle,
    payDepositPartyName,
    payDepositPrefill,
    payDepositFieldFlags,
    payDepositProfileId,
    openPayDepositDialog,
    openPayReceiveBundleDeposit,
    onPayDepositSubmit,
    payDepositMutation,
    arDualCashbook,
  };
}

import { computed, ref, type ComputedRef, type Ref } from 'vue';
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
  MoneyPaySubmitPayload,
  MoneyPaySummaryContext,
} from '../types/moneyPayDialog';
import type { CashbookLegPotChipOption } from './useCashbookLegPots';
import type { BillPayCashbookLegs } from '../types/billPayCashbookLegs';
import {
  needsPayoutBooksFx,
  needsPayoutTransactionRate,
} from '../utils/apPayoutFx';

function potMeta(
  potId: number | null,
  options: CashbookLegPotChipOption[],
): { pointId: number | null; currencyCode: string | null } {
  if (potId == null) return { pointId: null, currencyCode: null };
  const opt = options.find((o) => o.value === potId);
  return {
    pointId: opt?.pointId ?? null,
    currencyCode: opt?.currencyCode ?? null,
  };
}

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
    () =>
      options.isApBill.value
      && legBooksTenantId.value > 0
      && (dialogOpen.value || bundleLegsReady.value),
  );

  const arLegsEnabled = computed(
    () =>
      !options.isApBill.value
      && legBooksTenantId.value > 0
      && (dialogOpen.value || bundleLegsReady.value),
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

  const {
    selectedPotId: apFromPotId,
    chipOptions: apFromPotOptions,
    loading: apFromPotLoading,
  } = useCashbookLegPots(
    apPayFromProfileId,
    legBooksTenantId,
    apLegsEnabled,
    options.paymentDueCurrencyCode,
    bundledApFromLeg,
  );

  const {
    selectedPotId: apToPotId,
    chipOptions: apToPotOptions,
    loading: apToPotLoading,
  } = useCashbookLegPots(
    apPayToProfileId,
    legBooksTenantId,
    apLegsEnabled,
    options.paymentDueCurrencyCode,
    bundledApToLeg,
  );

  const {
    selectedPotId: arToPotId,
    chipOptions: arToPotOptions,
    loading: arToPotLoading,
  } = useCashbookLegPots(
    arReceiveProfileId,
    legBooksTenantId,
    arLegsEnabled,
    options.paymentDueCurrencyCode,
    bundledArToLeg,
  );

  const fromPotOptions = computed(() =>
    options.isApBill.value ? apFromPotOptions.value : [],
  );
  const toPotOptions = computed(() =>
    options.isApBill.value ? apToPotOptions.value : arToPotOptions.value,
  );
  const fromPotLoading = computed(() =>
    options.isApBill.value ? apFromPotLoading.value : false,
  );
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
      return { showAllocations: false };
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

  const moneyPayPrefill = computed(() => ({
    amount: options.paymentDueAmount.value > 0 ? options.paymentDueAmount.value : null,
    fromPotId: options.isApBill.value ? apFromPotId.value : null,
    toPotId: options.isApBill.value ? apToPotId.value : arToPotId.value,
  }));

  const openMoneyPayDialog = () => {
    dialogOpen.value = true;
  };

  const buildRecordPayload = (payload: MoneyPaySubmitPayload): RecordBillPaymentInput => {
    const billId = options.billId.value;
    const profileId = options.billProfileId.value;
    if (billId == null || profileId == null) {
      throw new Error('Bill not ready.');
    }

    const isAp = options.isApBill.value;
    const fromMeta = potMeta(payload.fromPotId, fromPotOptions.value);
    const toMeta = potMeta(payload.toPotId, toPotOptions.value);

    const cashbookPointPotId = isAp ? payload.fromPotId : payload.toPotId;
    const cashbookPointId = isAp ? fromMeta.pointId : toMeta.pointId;
    const sourceCurrencyCode = isAp ? fromMeta.currencyCode : toMeta.currencyCode;

    const settlement =
      options.paymentDueCurrencyCode.value.trim() || booksCurrencyCode.value;
    const payCur = settlement.trim().toUpperCase();
    const srcCur = (sourceCurrencyCode ?? booksCurrencyCode.value).trim().toUpperCase();
    const booksBase = booksCurrencyCode.value.trim().toUpperCase();
    const needsBooks = needsPayoutBooksFx(payCur, booksBase);
    const needsTxn = needsPayoutTransactionRate(payCur, srcCur);
    const txnRate =
      payload.transactionRate != null && payload.transactionRate > 0
        ? payload.transactionRate
        : needsTxn
          ? payload.exchangeRate ?? null
          : 1;
    const booksRate = payload.exchangeRate ?? null;

    return {
      tenantId: options.operatingTenantId.value,
      billId,
      isAp,
      profileId,
      shipmentId: options.billShipmentId.value,
      cashbookPointId,
      paidOn: payload.paymentDate,
      amountBdt: payload.amount,
      billDueAmount: options.paymentDueAmount.value,
      settlementCurrencyCode: settlement,
      booksCurrencyCode: booksCurrencyCode.value,
      foreignAmount: needsBooks ? payload.amount : null,
      exchangeRate: needsBooks ? booksRate : null,
      sourceCurrencyCode: payload.sourceCurrencyCode ?? sourceCurrencyCode,
      transactionRate: needsTxn ? txnRate : 1,
      cashbookPointPotId,
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
    fromPotLoading,
    toPotLoading,
    payFromPartyName,
    payToPartyName,
    paymentDueCurrencyCode: options.paymentDueCurrencyCode,
    booksCurrencyCode,
    operatingTenantId: options.operatingTenantId,
  };
}

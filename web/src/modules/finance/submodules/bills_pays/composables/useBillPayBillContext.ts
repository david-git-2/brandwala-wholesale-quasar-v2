import { computed, type ComputedRef, type Ref } from 'vue';
import type { GlobalInvoiceDetail } from 'src/modules/finance/submodules/bills_pays/types/invoice';
import type { BillDetailBundle } from 'src/modules/finance/submodules/bills_pays/repositories/billsRepository';
import type { BillNetBalances } from '../types/billBalances';
import { apBillDueStoresForeignFace } from '../utils/apBillBooks';
import { apBillCurrencyBalances, apBillPaperCurrencyCode } from '../utils/parseApBillPaper';
import { shipmentIdFromBill } from '../utils/shipmentApBillSource';

export function useBillPayBillContext(
  bill: ComputedRef<GlobalInvoiceDetail | undefined>,
  bundle: ComputedRef<BillDetailBundle | undefined>,
  billId: Ref<number | null>,
) {
  const isApBill = computed(() => bill.value?.invoice_type === 'ap');
  const billShipmentId = computed(() => shipmentIdFromBill(bill.value) ?? null);

  const billDocumentKind = computed(() => {
    const b = bill.value as { document_kind?: string } | undefined;
    return b?.document_kind ?? 'standard';
  });
  const isStandardBill = computed(() => billDocumentKind.value === 'standard');

  const netBalances = computed(
    () => bundle.value?.netBalances as BillNetBalances | undefined,
  );

  const apCurrencyBalances = computed(() => {
    if (!isApBill.value || !bill.value) return null;
    return apBillCurrencyBalances(
      bill.value.channel_meta as Record<string, unknown> | null,
      bill.value.paid_amount,
      bill.value.due_amount,
    );
  });

  const apBillSettlementCurrency = computed(() => {
    if (apCurrencyBalances.value?.[0]?.currency_code) {
      return apCurrencyBalances.value[0].currency_code;
    }
    if (!isApBill.value || !bill.value) return null;
    const fromPaper = apBillPaperCurrencyCode(bill.value.channel_meta as Record<string, unknown> | null);
    if (fromPaper !== 'BDT') return fromPaper;
    const header = String(bill.value.currency_code ?? '').trim().toUpperCase();
    if (header && header !== 'BDT') return header;
    const deskCcy = bundle.value?.billLines?.[0]?.currency_code?.trim().toUpperCase();
    if (deskCcy && deskCcy !== 'BDT') return deskCcy;
    return null;
  });

  const billProfileId = computed(() => {
    const b = bill.value;
    if (!b) return null;
    return b.profile_id ?? (b as { profile_id?: number }).profile_id ?? null;
  });

  const paymentDueAmount = computed(() => {
    const nb = netBalances.value;
    if (isApBill.value && apBillSettlementCurrency.value) {
      if (nb?.open_txn != null) return Math.max(0, Number(nb.open_txn));
    }
    if (nb?.due_amount != null) return Math.max(0, Number(nb.due_amount));
    return Math.max(0, Number(bill.value?.due_amount ?? 0));
  });

  const paymentDueCurrencyCode = computed(() => {
    const b = bill.value;
    if (!b) return 'BDT';
    if (apBillSettlementCurrency.value) return apBillSettlementCurrency.value;
    const due = paymentDueAmount.value;
    const meta = (b.channel_meta as Record<string, unknown> | null) ?? null;
    if (isApBill.value && apBillDueStoresForeignFace(meta, due)) {
      return apBillPaperCurrencyCode(meta);
    }
    const header = String(b.currency_code ?? '').trim();
    if (header) return header.toUpperCase();
    return 'BDT';
  });

  const canRecordPayment = computed(() => {
    const b = bill.value;
    if (!b || !isStandardBill.value) return false;
    if (b.invoice_status !== 'issued') return false;
    if (!billProfileId.value) return false;
    return paymentDueAmount.value > 0;
  });

  const billLeafLabel = computed(() => {
    const no = bill.value?.invoice_no?.trim();
    if (no) return no;
    return billId.value ? `Bill #${billId.value}` : 'Bill';
  });

  return {
    isApBill,
    billShipmentId,
    isStandardBill,
    billProfileId,
    paymentDueAmount,
    paymentDueCurrencyCode,
    canRecordPayment,
    billLeafLabel,
  };
}
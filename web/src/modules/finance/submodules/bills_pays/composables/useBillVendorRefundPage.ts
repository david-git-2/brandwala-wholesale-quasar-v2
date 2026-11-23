import { computed, ref, watch, type ComputedRef } from 'vue';
import type { GlobalInvoiceDetail } from 'src/modules/finance/submodules/bills_pays/types/invoice';
import type { BillDetailBundle } from 'src/modules/finance/submodules/bills_pays/repositories/billsRepository';
import type { BillAdjustmentRow } from '../types/billAdjustments';

export function useBillVendorRefundPage(params: {
  routeBillId: ComputedRef<number | null>;
  creditNoteIdFromQuery: ComputedRef<number | null>;
  bill: ComputedRef<GlobalInvoiceDetail | undefined>;
  bundle: ComputedRef<BillDetailBundle | undefined>;
}) {
  const billDocumentKind = computed(() => {
    const b = params.bill.value as { document_kind?: string } | undefined;
    return b?.document_kind ?? 'standard';
  });

  const isApBill = computed(() => params.bill.value?.invoice_type === 'ap');
  const isCreditNotePage = computed(
    () => isApBill.value && billDocumentKind.value === 'credit_note',
  );

  const adjustmentRows = computed(
    () => (params.bundle.value?.adjustments ?? []) as BillAdjustmentRow[],
  );

  const openCreditNoteOptions = computed(() =>
    adjustmentRows.value
      .filter((r) => r.document_kind === 'credit_note' && Number(r.due_amount ?? 0) > 0)
      .map((r) => ({
        label: `${r.invoice_no ?? `Note #${r.id}`} · due ${Number(r.due_amount ?? 0).toFixed(2)}`,
        value: r.id,
      })),
  );

  const selectedCreditNoteId = ref<number | null>(null);

  watch(
    () =>
      [
        params.routeBillId.value,
        params.creditNoteIdFromQuery.value,
        isCreditNotePage.value,
        openCreditNoteOptions.value,
      ] as const,
    ([routeId, queryCnId, onCnPage, options]) => {
      if (onCnPage && routeId) {
        selectedCreditNoteId.value = routeId;
        return;
      }
      if (queryCnId) {
        selectedCreditNoteId.value = queryCnId;
        return;
      }
      if (options.length === 1) {
        selectedCreditNoteId.value = options[0]!.value;
        return;
      }
      if (
        selectedCreditNoteId.value != null &&
        options.some((o) => o.value === selectedCreditNoteId.value)
      ) {
        return;
      }
      selectedCreditNoteId.value = options[0]?.value ?? null;
    },
    { immediate: true },
  );

  const activeCreditNoteRow = computed(() => {
    const id = selectedCreditNoteId.value;
    if (!id) return null;
    if (isCreditNotePage.value && params.bill.value?.id === id) {
      return {
        id,
        invoice_no: params.bill.value.invoice_no,
        due_amount: params.bill.value.due_amount,
        parent_bill_id: (params.bill.value as { parent_bill_id?: number | null }).parent_bill_id ?? null,
      };
    }
    const row = adjustmentRows.value.find((r) => r.id === id);
    return row ?? null;
  });

  const parentBillId = computed(() => {
    if (isCreditNotePage.value) {
      return (
        (params.bill.value as { parent_bill_id?: number | null } | undefined)?.parent_bill_id
        ?? null
      );
    }
    return params.routeBillId.value;
  });

  const openCreditBooks = computed(() => {
    const row = activeCreditNoteRow.value;
    if (!row) return 0;
    return Math.max(0, Number(row.due_amount ?? 0));
  });

  const channelMeta = computed(
    () => (params.bill.value?.channel_meta as Record<string, unknown> | null) ?? null,
  );

  const fromProfileName = computed(() => {
    const b = params.bill.value;
    if (!b) return 'Vendor';
    const to = b.to_profile as { name?: string } | null | undefined;
    if (to?.name) return to.name;
    return b.recipient_name?.trim() || 'Vendor';
  });

  const canRecordVendorRefund = computed(() => {
    const b = params.bill.value;
    if (!isApBill.value || !b || b.invoice_status !== 'issued') return false;
    if (!selectedCreditNoteId.value || openCreditBooks.value <= 0) return false;
    if (isCreditNotePage.value) return true;
    return billDocumentKind.value === 'standard' && openCreditNoteOptions.value.length > 0;
  });

  const tenantReceiveProfileId = computed((): number | null => {
    const id = selectedCreditNoteId.value;
    if (id == null) return null;
    if (isCreditNotePage.value && params.bill.value?.id === id) {
      const b = params.bill.value;
      return (
        b.to_profile_id
        ?? (b.to_profile as { id?: number } | null | undefined)?.id
        ?? b.from_profile_id
        ?? null
      );
    }
    const adj = adjustmentRows.value.find((r) => r.id === id);
    return adj?.to_profile_id ?? adj?.from_profile_id ?? null;
  });

  return {
    billDocumentKind,
    isApBill,
    isCreditNotePage,
    openCreditNoteOptions,
    selectedCreditNoteId,
    activeCreditNoteRow,
    parentBillId,
    openCreditBooks,
    channelMeta,
    fromProfileName,
    canRecordVendorRefund,
    tenantReceiveProfileId,
  };
}
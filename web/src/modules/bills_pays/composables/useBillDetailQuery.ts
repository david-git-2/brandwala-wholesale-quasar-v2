import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { listBillLinesForInvoice } from '../repositories/billLinesRepository';

function billDocumentKind(inv: { document_kind?: string | null } | undefined): string {
  return inv?.document_kind ?? 'standard';
}

function shouldLoadStockLines(inv: {
  invoice_type: string;
  document_kind?: string | null;
}): boolean {
  if (inv.invoice_type === 'ap') {
    return false;
  }
  const kind = billDocumentKind(inv);
  return kind === 'standard' || kind === 'credit_note' || kind === 'debit_note';
}

function isAdjustmentBill(inv: { document_kind?: string | null } | undefined): boolean {
  const kind = billDocumentKind(inv);
  return kind !== 'standard';
}

export function useBillDetailQuery(
  billId: Ref<number | null>,
  invoice?: Ref<GlobalInvoiceDetail | undefined>,
) {
  const usesBundle = computed(() => invoice !== undefined);

  const detailQuery = useQuery({
    queryKey: computed(() => billsQueryKeys.detail(billId.value)),
    queryFn: () => invoiceRepository.getGlobalInvoiceById(billId.value!),
    enabled: computed(
      () => !usesBundle.value && billId.value != null && billId.value > 0,
    ),
    staleTime: 30_000,
  });

  const invoiceData = computed(() => invoice?.value ?? detailQuery.data.value);

  const itemsQuery = useQuery({
    queryKey: computed(() => billsQueryKeys.items(billId.value)),
    queryFn: () => invoiceRepository.listGlobalInvoiceItems(billId.value!),
    enabled: computed(() => {
      const id = billId.value;
      if (id == null || id <= 0) return false;
      const inv = invoiceData.value;
      if (!inv) return false;
      return shouldLoadStockLines(inv);
    }),
    staleTime: 30_000,
  });

  const billLinesQuery = useQuery({
    queryKey: computed(() => [...billsQueryKeys.detail(billId.value), 'bill-lines']),
    queryFn: () => listBillLinesForInvoice(billId.value!),
    enabled: computed(() => {
      const id = billId.value;
      if (id == null || id <= 0) return false;
      const inv = invoiceData.value;
      if (!inv) return false;
      return isAdjustmentBill(inv);
    }),
    staleTime: 30_000,
  });

  return { detailQuery, itemsQuery, billLinesQuery };
}

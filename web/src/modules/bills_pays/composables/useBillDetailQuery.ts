import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { billsRepository, type BillDetailBundle } from '../repositories/billsRepository';
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

function shouldLoadBillLines(inv: {
  invoice_type: string;
  document_kind?: string | null;
}): boolean {
  return isAdjustmentBill(inv) || inv.invoice_type === 'ap';
}

export function useBillDetailQuery(
  billId: Ref<number | null>,
  invoice?: Ref<GlobalInvoiceDetail | undefined>,
  bundle?: Ref<BillDetailBundle | undefined>,
) {
  const usesBundle = computed(() => invoice !== undefined);
  const bundleHasStockItems = computed(() => bundle?.value?.stockItems !== undefined);
  const bundleHasBillLines = computed(() => bundle?.value?.billLines !== undefined);

  const detailQuery = useQuery({
    queryKey: computed(() => billsQueryKeys.detail(billId.value)),
    queryFn: () => billsRepository.getBillById(billId.value!),
    enabled: computed(
      () => !usesBundle.value && billId.value != null && billId.value > 0,
    ),
    staleTime: 30_000,
  });

  const invoiceData = computed(() => invoice?.value ?? detailQuery.data.value);

  const itemsQuery = useQuery({
    queryKey: computed(() => billsQueryKeys.items(billId.value)),
    queryFn: () => billsRepository.listBillItems(billId.value!),
    enabled: computed(() => {
      if (bundleHasStockItems.value) return false;
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
      if (bundleHasBillLines.value) return false;
      const id = billId.value;
      if (id == null || id <= 0) return false;
      const inv = invoiceData.value;
      if (!inv) return false;
      return shouldLoadBillLines(inv);
    }),
    staleTime: 30_000,
  });

  return { detailQuery, itemsQuery, billLinesQuery, invoiceData };
}

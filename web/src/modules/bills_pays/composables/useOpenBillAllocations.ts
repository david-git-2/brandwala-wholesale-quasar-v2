import { computed, ref, watch, type Ref } from 'vue';
import { billsRepository } from '../repositories/billsRepository';

export type OpenBillAllocRow = {
  id: number;
  invoice_no: string;
  due_amount: number;
  selected: boolean;
  allocAmount: number;
};

export function useOpenBillAllocations(
  booksTenantId: Ref<number>,
  profileId: Ref<number | null>,
  invoiceType: Ref<'ar' | 'ap' | null>,
  enabled: Ref<boolean>,
) {
  const loading = ref(false);
  const rows = ref<OpenBillAllocRow[]>([]);

  const load = async () => {
    const pid = profileId.value;
    const parentId = booksTenantId.value;
    if (!pid || !parentId || !enabled.value) {
      rows.value = [];
      return;
    }
    loading.value = true;
    try {
      const { data } = await billsRepository.listBills({
        parentTenantId: parentId,
        profileId: pid,
        invoiceStatus: 'issued',
        quickFilter: 'unpaid',
        invoiceType: invoiceType.value === 'ap' ? 'ap' : undefined,
        arSide: invoiceType.value === 'ap' ? 'we_owe' : 'they_owe',
        pageSize: 100,
      });
      rows.value = data.map((b) => ({
        id: b.id,
        invoice_no: b.invoice_no ?? `#${b.id}`,
        due_amount: Number(b.due_amount) || 0,
        selected: false,
        allocAmount: Number(b.due_amount) || 0,
      }));
    } finally {
      loading.value = false;
    }
  };

  watch([profileId, invoiceType, enabled], () => {
    void load();
  });

  const selectedAllocations = computed(() =>
    rows.value
      .filter((b) => b.selected && (Number(b.allocAmount) || 0) > 0)
      .map((b) => ({ bill_id: b.id, amount: Number(b.allocAmount) || 0 })),
  );

  const allocTotal = computed(() =>
    selectedAllocations.value.reduce((s, a) => s + a.amount, 0),
  );

  const fillOldestFirst = (cashTotal: number) => {
    let remaining = cashTotal;
    for (const bill of rows.value) {
      if (remaining <= 0) {
        bill.selected = false;
        continue;
      }
      const take = Math.min(bill.due_amount, remaining);
      bill.selected = take > 0;
      bill.allocAmount = take;
      remaining -= take;
    }
  };

  return {
    loading,
    rows,
    load,
    selectedAllocations,
    allocTotal,
    fillOldestFirst,
  };
}

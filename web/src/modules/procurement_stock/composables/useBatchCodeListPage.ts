import { computed, ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import type { BatchCodeListRow } from '../repositories/batchCodeRepository';
import { useBatchCodeListsQuery } from './useBatchCodeQueries';

export function useBatchCodeListPage() {
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();

  const searchText = ref('');

  const resolveParentTenantId = (): number => {
    const currentTenant =
      tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === authStore.tenantId);
    const tenantId = currentTenant?.parent_id ?? authStore.tenantId;
    if (!tenantId) throw new Error('No tenant found');
    return tenantId;
  };

  const parentTenantId = computed(() => {
    try {
      return resolveParentTenantId();
    } catch {
      return null;
    }
  });

  const listsQuery = useBatchCodeListsQuery(parentTenantId);

  const rows = computed(() => listsQuery.data.value ?? []);
  const loading = computed(
    () => listsQuery.isPending.value && listsQuery.isFetching.value,
  );
  const refetch = listsQuery.refetch;
  const queryError = computed(() =>
    listsQuery.error.value
      ? (listsQuery.error.value as Error).message || 'Failed to load batch code lists'
      : null,
  );

  const filteredRows = computed(() => {
    const query = searchText.value.trim().toLowerCase();
    if (!query) return rows.value;
    return rows.value.filter((row) => {
      const listName = row.name?.toLowerCase() ?? '';
      const vendor = row.vendor?.name?.toLowerCase() ?? '';
      const shipment = row.shipment?.name?.toLowerCase() ?? '';
      const shipmentNo = String(row.shipment?.tenant_shipment_id ?? '');
      return (
        listName.includes(query) ||
        vendor.includes(query) ||
        shipment.includes(query) ||
        shipmentNo.includes(query)
      );
    });
  });

  const itemCountFor = (row: BatchCodeListRow): number =>
    row.batch_code_items?.[0]?.count ?? 0;

  const shipmentIdsWithList = computed(() =>
    rows.value
      .map((row) => row.shipment_id)
      .filter((id): id is number => typeof id === 'number'),
  );

  return {
    loading,
    error: queryError,
    searchText,
    filteredRows,
    load: refetch,
    itemCountFor,
    shipmentIdsWithList,
    parentTenantId,
  };
}

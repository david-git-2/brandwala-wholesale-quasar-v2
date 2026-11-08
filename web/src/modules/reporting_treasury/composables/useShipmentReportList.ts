import { computed, ref, watch } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shipmentReportRepository } from '../repositories/shipmentReportRepository';
import type { ShipmentReportListRow } from '../types/shipmentReportTypes';

export const shipmentReportQueryKeys = {
  all: ['reporting_treasury', 'shipment_report'] as const,
  list: (tenantId: number, search: string) =>
    ['reporting_treasury', 'shipment_report', 'list', tenantId, search] as const,
};

export function useShipmentReportList() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const searchText = ref('');
  const debouncedSearch = ref('');

  let searchTimer: ReturnType<typeof setTimeout> | undefined;
  watch(searchText, (value) => {
    if (searchTimer) {
      clearTimeout(searchTimer);
    }
    searchTimer = setTimeout(() => {
      debouncedSearch.value = value.trim();
    }, 300);
  });

  const isEnabled = computed(() => Boolean(tenantId.value && tenantId.value > 0));

  const listQuery = useQuery({
    queryKey: computed(() =>
      shipmentReportQueryKeys.list(tenantId.value || 0, debouncedSearch.value),
    ),
    queryFn: () =>
      shipmentReportRepository.fetchAllActiveShipments(
        tenantId.value || 0,
        debouncedSearch.value || null,
      ),
    enabled: isEnabled,
    staleTime: 1000 * 30,
  });

  return {
    shipments: computed(() => listQuery.data.value ?? []),
    isLoading: listQuery.isLoading,
    isFetching: listQuery.isFetching,
    error: listQuery.error,
    searchText,
    refetch: listQuery.refetch,
  };
}

export function formatShipmentDisplayNo(row: Pick<ShipmentReportListRow, 'shipment_no' | 'tenant_shipment_id'>) {
  if (row.shipment_no) {
    return row.shipment_no;
  }
  if (row.tenant_shipment_id != null) {
    return String(row.tenant_shipment_id);
  }
  return 'No number';
}

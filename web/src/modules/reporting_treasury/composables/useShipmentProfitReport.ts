import { ref, computed } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shipmentProfitRepository } from '../repositories/shipmentProfitRepository';
import type { ShipmentProfitReportQueryParams } from '../types/shipmentProfitTypes';

export const shipmentProfitQueryKeys = {
  all: ['reporting_treasury', 'shipment_profit'] as const,
  list: (params: ShipmentProfitReportQueryParams) =>
    ['reporting_treasury', 'shipment_profit', 'list', params] as const,
  detail: (tenantId: number, shipmentId: number) =>
    ['reporting_treasury', 'shipment_profit', 'detail', tenantId, shipmentId] as const,
};

export function useShipmentProfitReport() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const preset = ref<'all' | 'month' | 'quarter' | 'year' | 'custom'>('all');
  const startDate = ref<string | null>(null);
  const endDate = ref<string | null>(null);
  const searchText = ref('');
  const page = ref(1);
  const pageSize = ref(20);

  const isEnabled = computed(() => Boolean(tenantId.value && tenantId.value > 0));

  const queryParams = computed<ShipmentProfitReportQueryParams>(() => ({
    tenantId: tenantId.value || 0,
    search: searchText.value.trim() ? searchText.value.trim() : null,
    startDate: startDate.value ? new Date(startDate.value).toISOString() : null,
    endDate: endDate.value ? new Date(endDate.value).toISOString() : null,
    page: page.value,
    pageSize: pageSize.value,
  }));

  const reportQuery = useQuery({
    queryKey: computed(() => shipmentProfitQueryKeys.list(queryParams.value)),
    queryFn: () => shipmentProfitRepository.fetchShipmentProfitReport(queryParams.value),
    enabled: isEnabled,
    staleTime: 1000 * 30, // 30s cache
  });

  function setPreset(val: 'all' | 'month' | 'quarter' | 'year' | 'custom') {
    preset.value = val;
    const now = new Date();
    if (val === 'all') {
      startDate.value = null;
      endDate.value = null;
    } else if (val === 'month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1);
      startDate.value = start.toISOString().slice(0, 10);
      endDate.value = now.toISOString().slice(0, 10);
    } else if (val === 'quarter') {
      const start = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
      startDate.value = start.toISOString().slice(0, 10);
      endDate.value = now.toISOString().slice(0, 10);
    } else if (val === 'year') {
      const start = new Date(now.getFullYear(), 0, 1);
      startDate.value = start.toISOString().slice(0, 10);
      endDate.value = now.toISOString().slice(0, 10);
    }
    page.value = 1;
  }

  function exportCsv() {
    if (reportQuery.data.value) {
      shipmentProfitRepository.exportReportToCsv(reportQuery.data.value);
    }
  }

  return {
    summary: computed(() => reportQuery.data.value?.summary ?? null),
    shipments: computed(() => reportQuery.data.value?.shipments ?? []),
    pagination: computed(() => reportQuery.data.value?.meta ?? null),
    isLoading: reportQuery.isLoading,
    isFetching: reportQuery.isFetching,
    isError: reportQuery.isError,
    error: reportQuery.error,
    preset,
    startDate,
    endDate,
    searchText,
    page,
    pageSize,
    setPreset,
    exportCsv,
    refetch: reportQuery.refetch,
  };
}

export function useShipmentProfitDetail(shipmentId: () => number | null) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
  const id = computed(() => shipmentId());

  const isEnabled = computed(() => Boolean(tenantId.value && tenantId.value > 0 && id.value && id.value > 0));

  const detailQuery = useQuery({
    queryKey: computed(() => shipmentProfitQueryKeys.detail(tenantId.value || 0, id.value || 0)),
    queryFn: () =>
      shipmentProfitRepository.fetchShipmentProfitReport({
        tenantId: tenantId.value || 0,
        shipmentId: id.value,
      }),
    enabled: isEnabled,
    staleTime: 1000 * 60,
  });

  return {
    shipment: computed(() => detailQuery.data.value?.shipments[0] ?? null),
    items: computed(() => detailQuery.data.value?.shipments[0]?.items ?? []),
    isLoading: detailQuery.isLoading,
    isError: detailQuery.isError,
    error: detailQuery.error,
    refetch: detailQuery.refetch,
  };
}

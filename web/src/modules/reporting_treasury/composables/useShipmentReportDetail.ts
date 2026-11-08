import { computed, type MaybeRefOrGetter, toValue } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shipmentReportDetailRepository } from '../repositories/shipmentReportDetailRepository';

export const shipmentReportDetailQueryKeys = {
  detail: (tenantId: number, shipmentId: number) =>
    ['reporting_treasury', 'shipment_report_detail', tenantId, shipmentId] as const,
};

export function useShipmentReportDetail(shipmentId: MaybeRefOrGetter<number | null>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
  const id = computed(() => toValue(shipmentId));

  const isEnabled = computed(
    () => Boolean(tenantId.value && tenantId.value > 0 && id.value && id.value > 0),
  );

  const detailQuery = useQuery({
    queryKey: computed(() =>
      shipmentReportDetailQueryKeys.detail(tenantId.value || 0, id.value || 0),
    ),
    queryFn: () =>
      shipmentReportDetailRepository.fetchDetail(tenantId.value || 0, id.value || 0),
    enabled: isEnabled,
    staleTime: 1000 * 30,
  });

  return {
    detail: computed(() => detailQuery.data.value ?? null),
    isLoading: detailQuery.isLoading,
    isFetching: detailQuery.isFetching,
    error: detailQuery.error,
    refetch: detailQuery.refetch,
  };
}

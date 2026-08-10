import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import { thriftReportsRepository } from '../repositories/thriftReportsRepository';

export function useThriftReportShipmentsQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.reportShipments(Number(tenantId.value) || 0)),
    queryFn: () => thriftReportsRepository.listShipments(Number(tenantId.value)),
    enabled: computed(() => !!tenantId.value),
    staleTime: 60 * 1000,
  });
}

export function useThriftShipmentSalesReportQuery(
  tenantId: Ref<number | null | undefined>,
  shipmentId: Ref<number | null | undefined>,
) {
  return useQuery({
    queryKey: computed(() =>
      thriftQueryKeys.reportDetail({
        tenantId: Number(tenantId.value) || 0,
        shipmentId: Number(shipmentId.value) || 0,
      }),
    ),
    queryFn: () =>
      thriftReportsRepository.getShipmentSalesReport(
        Number(tenantId.value),
        Number(shipmentId.value),
      ),
    enabled: computed(() => !!tenantId.value && !!shipmentId.value),
    staleTime: 30 * 1000,
  });
}

export function useThriftPeriodSalesReportQuery(
  tenantId: Ref<number | null | undefined>,
  dateFrom: Ref<string>,
  dateTo: Ref<string>,
  saleChannel: Ref<'IN_STORE' | 'ONLINE' | null>,
) {
  return useQuery({
    queryKey: computed(() =>
      thriftQueryKeys.salesReport({
        tenantId: Number(tenantId.value) || 0,
        dateFrom: dateFrom.value,
        dateTo: dateTo.value,
        saleChannel: saleChannel.value,
      }),
    ),
    queryFn: () =>
      thriftReportsRepository.getSalesReport({
        tenantId: Number(tenantId.value),
        dateFrom: dateFrom.value,
        dateTo: dateTo.value,
        saleChannel: saleChannel.value,
      }),
    enabled: computed(() => !!tenantId.value && !!dateFrom.value && !!dateTo.value),
    staleTime: 30 * 1000,
  });
}

export function useThriftDashboardMetricsQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.dashboardMetrics(Number(tenantId.value) || 0)),
    queryFn: () => thriftReportsRepository.getDashboardMetrics(Number(tenantId.value)),
    enabled: computed(() => !!tenantId.value),
    staleTime: 30 * 1000,
  });
}

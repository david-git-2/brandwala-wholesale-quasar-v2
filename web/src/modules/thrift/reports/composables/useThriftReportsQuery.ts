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

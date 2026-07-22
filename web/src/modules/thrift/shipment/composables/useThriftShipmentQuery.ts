import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from 'src/modules/thrift/shared/queryKeys/thriftQueryKeys';
import { thriftShipmentRepository } from '../repositories/thriftShipmentRepository';

export function useThriftShipmentsQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.shipments(tenantId.value ?? 0)),
    queryFn: () => thriftShipmentRepository.fetchShipments(tenantId.value!),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}

export function useThriftShipmentDetailQuery(
  tenantId: Ref<number | null | undefined>,
  id: Ref<number | null | undefined>,
) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.shipmentDetail(String(id.value ?? ''))),
    queryFn: () => thriftShipmentRepository.fetchShipmentById(tenantId.value!, id.value!),
    staleTime: 30_000,
    enabled: computed(() => !!tenantId.value && !!id.value),
  });
}

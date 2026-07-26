import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import { globalStockAllocationRepository } from '../repositories/globalStockAllocationRepository';
import { tenantRepository } from 'src/modules/tenant/repositories/tenantRepository';
import { globalShipmentRepository } from '../repositories/globalShipmentRepository';
import { globalStockTypeRepository } from '../repositories/globalStockTypeRepository';

export interface AllocatableStockListQueryParams {
  tenantId: number | null;
  page: number;
  pageSize: number;
  search?: string | null;
  shipmentId?: number | null;
  stockTypeId?: number | null;
}

export function useAllocatableStockListQuery(params: Ref<AllocatableStockListQueryParams>) {
  return useQuery({
    queryKey: computed(() =>
      procurementStockQueryKeys.allocatableStockList({
        tenantId: params.value.tenantId ?? 0,
        page: params.value.page,
        pageSize: params.value.pageSize,
        search: params.value.search ?? null,
        shipmentId: params.value.shipmentId ?? null,
        stockTypeId: params.value.stockTypeId ?? null,
      }),
    ),
    queryFn: () =>
      globalStockAllocationRepository.listAllocatableStockPaginated(
        params.value.tenantId!,
        params.value.page,
        params.value.pageSize,
        params.value.search,
        params.value.shipmentId,
        params.value.stockTypeId,
      ),
    staleTime: 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}

export function useStockAllocationsQuery(stockId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.stockAllocations(stockId.value ?? 0)),
    queryFn: () => globalStockAllocationRepository.listChildAllocationSummary(stockId.value!),
    staleTime: 30 * 1000,
    enabled: computed(() => !!stockId.value),
  });
}

export function useChildTenantsQuery(parentTenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.childTenants(parentTenantId.value ?? 0)),
    queryFn: async () => {
      const tenants = await tenantRepository.listTenants();
      return tenants.filter((t) => t.parent_id === parentTenantId.value);
    },
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => !!parentTenantId.value),
  });
}

export function useShipmentsQuery(tenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.shipments(tenantId.value ?? 0)),
    queryFn: async () => {
      const result = await globalShipmentRepository.listPaginated(tenantId.value!, 1, 100);
      return result.data || [];
    },
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}

export function useStockTypesQuery(tenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.stockTypes(tenantId.value ?? 0)),
    queryFn: async () => {
      return globalStockTypeRepository.listStockTypes(tenantId.value);
    },
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}

import { useQuery } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref, unref } from 'vue';
import { globalShipmentRepository } from '../repositories/globalShipmentRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

const ONE_HOUR = 60 * 60 * 1000;
const TWENTY_MINUTES = 20 * 60 * 1000;

/**
 * Cargo Companies query cached for 20 minutes
 */
export function useCargoCompaniesQuery(
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined> | number | null | undefined,
) {
  const resolvedTenantId = computed(() => {
    const raw = unref(tenantId);
    return raw && !isNaN(Number(raw)) ? Number(raw) : null;
  });

  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.cargoCompanies(resolvedTenantId.value!)),
    queryFn: () => globalShipmentRepository.listCargoCompaniesForTenant(resolvedTenantId.value!),
    enabled: computed(() => resolvedTenantId.value !== null),
    staleTime: TWENTY_MINUTES,
    gcTime: TWENTY_MINUTES * 2,
  });
}

/**
 * Shipment Progress Flows query cached for 1 hour
 */
export function useShipmentProgressFlowsQuery(
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined> | number | null | undefined,
) {
  const resolvedTenantId = computed(() => {
    const raw = unref(tenantId);
    return raw && !isNaN(Number(raw)) ? Number(raw) : null;
  });

  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.progressFlows(resolvedTenantId.value!, true)),
    queryFn: () => globalShipmentRepository.listShipmentProgressFlows(resolvedTenantId.value!, true),
    enabled: computed(() => resolvedTenantId.value !== null),
    staleTime: ONE_HOUR,
    gcTime: ONE_HOUR * 2,
  });
}

/**
 * Shipment Progress Flow Stages query cached for 1 hour per flow
 */
export function useShipmentProgressFlowStagesQuery(
  flowId: Ref<number | null | undefined> | ComputedRef<number | null | undefined> | number | null | undefined,
) {
  const resolvedFlowId = computed(() => {
    const raw = unref(flowId);
    return raw && !isNaN(Number(raw)) ? Number(raw) : null;
  });

  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.progressStages(resolvedFlowId.value!, false)),
    queryFn: () => globalShipmentRepository.listShipmentProgressFlowStages(resolvedFlowId.value!, false),
    enabled: computed(() => resolvedFlowId.value !== null),
    staleTime: ONE_HOUR,
    gcTime: ONE_HOUR * 2,
  });
}

/**
 * Consolidated Shipment Overview Details Query (Single RPC)
 */
export function useShipmentOverviewDetailsQuery(
  shipmentId: Ref<number | null | undefined> | ComputedRef<number | null | undefined> | number | null | undefined,
) {
  const resolvedShipmentId = computed(() => {
    const raw = unref(shipmentId);
    return raw && !isNaN(Number(raw)) ? Number(raw) : null;
  });

  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.shipmentOverview(resolvedShipmentId.value!)),
    queryFn: () => globalShipmentRepository.getShipmentOverviewDetails(resolvedShipmentId.value!),
    enabled: computed(() => resolvedShipmentId.value !== null),
    staleTime: 30 * 1000, // 30 seconds
  });
}


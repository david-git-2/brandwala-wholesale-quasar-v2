import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref, unref } from 'vue';
import {
  procurementDemandRepository,
  type ProcurementDemandSourceType,
  type ProcurementDemandStatus,
  type RecordProcurementPlacementParams,
} from '../repositories/procurementDemandRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

export function useRecordProcurementPlacementMutation(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  procurementStatus: Ref<ProcurementDemandStatus> | ComputedRef<ProcurementDemandStatus>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  childTenantId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  limit?: number;
  offset?: Ref<number> | ComputedRef<number>;
}) {
  const queryClient = useQueryClient();

  const queryKey = computed(() =>
    procurementStockQueryKeys.demandGroups({
      tenantId: Number(unref(options.tenantId)) || 0,
      procurementStatus: unref(options.procurementStatus),
      search: (() => {
        const raw = unref(options.search);
        const trimmed = typeof raw === 'string' ? raw.trim() : '';
        return trimmed.length ? trimmed : null;
      })(),
      childTenantId: unref(options.childTenantId) ?? null,
      limit: options.limit ?? 50,
      offset: unref(options.offset) ?? 0,
    }),
  );

  return useMutation({
    mutationFn: (payload: Omit<RecordProcurementPlacementParams, 'tenantId'>) => {
      const tenantId = unref(options.tenantId);
      if (!tenantId) throw new Error('Tenant is required');
      return procurementDemandRepository.recordProcurementPlacement({
        tenantId,
        ...payload,
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: queryKey.value });
    },
  });
}

export function useCancelProcurementPlacementMutation(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  procurementStatus: Ref<ProcurementDemandStatus> | ComputedRef<ProcurementDemandStatus>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  childTenantId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  limit?: number;
  offset?: Ref<number> | ComputedRef<number>;
}) {
  const queryClient = useQueryClient();

  const queryKey = computed(() =>
    procurementStockQueryKeys.demandGroups({
      tenantId: Number(unref(options.tenantId)) || 0,
      procurementStatus: unref(options.procurementStatus),
      search: (() => {
        const raw = unref(options.search);
        const trimmed = typeof raw === 'string' ? raw.trim() : '';
        return trimmed.length ? trimmed : null;
      })(),
      childTenantId: unref(options.childTenantId) ?? null,
      limit: options.limit ?? 50,
      offset: unref(options.offset) ?? 0,
    }),
  );

  return useMutation({
    mutationFn: (placementId: number) => {
      const tenantId = unref(options.tenantId);
      if (!tenantId) throw new Error('Tenant is required');
      return procurementDemandRepository.cancelProcurementPlacement(tenantId, placementId);
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: queryKey.value });
    },
  });
}

export type PlacementDialogTarget = {
  sourceType: ProcurementDemandSourceType;
  sourceId: number;
  productName: string;
  remainingQuantity: number;
  defaultVendorId?: number | null;
  defaultVendorCode?: string | null;
};

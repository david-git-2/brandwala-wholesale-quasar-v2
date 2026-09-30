import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref, unref } from 'vue';
import {
  procurementDemandRepository,
  type FillPreorderDemandPlacedQuantitiesParams,
  type ProcurementDemandSourceType,
  type ProcurementDemandStatus,
  type SetPreorderDemandVendorParams,
  type UpsertPreorderDemandParams,
} from '../repositories/procurementDemandRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

function invalidateDemandDeskQueries(queryClient: ReturnType<typeof useQueryClient>) {
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandGroups'] });
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandGroupItems'] });
}

function useDemandGroupsQueryKey(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  procurementStatus: Ref<ProcurementDemandStatus> | ComputedRef<ProcurementDemandStatus>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  childTenantId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  limit?: number;
  offset?: Ref<number> | ComputedRef<number>;
}) {
  return computed(() =>
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
}

export function useUpsertPreorderDemandMutation(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  procurementStatus: Ref<ProcurementDemandStatus> | ComputedRef<ProcurementDemandStatus>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  childTenantId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  limit?: number;
  offset?: Ref<number> | ComputedRef<number>;
}) {
  const queryClient = useQueryClient();
  const queryKey = useDemandGroupsQueryKey(options);

  return useMutation({
    mutationFn: (payload: Omit<UpsertPreorderDemandParams, 'tenantId'>) => {
      const tenantId = unref(options.tenantId);
      if (!tenantId) throw new Error('Tenant is required');
      return procurementDemandRepository.upsertPreorderDemand({
        tenantId,
        ...payload,
      });
    },
    onSuccess: () => {
      invalidateDemandDeskQueries(queryClient);
    },
  });
}

export function useFillPreorderDemandPlacedQuantitiesMutation(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  procurementStatus: Ref<ProcurementDemandStatus> | ComputedRef<ProcurementDemandStatus>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  childTenantId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  limit?: number;
  offset?: Ref<number> | ComputedRef<number>;
}) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: Omit<FillPreorderDemandPlacedQuantitiesParams, 'tenantId'>) => {
      const tenantId = unref(options.tenantId);
      if (!tenantId) throw new Error('Tenant is required');
      return procurementDemandRepository.fillPreorderDemandPlacedQuantitiesForDocument({
        tenantId,
        ...payload,
      });
    },
    onSuccess: () => {
      invalidateDemandDeskQueries(queryClient);
    },
  });
}

export function useSetPreorderDemandVendorMutation(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  procurementStatus: Ref<ProcurementDemandStatus> | ComputedRef<ProcurementDemandStatus>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  childTenantId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  limit?: number;
  offset?: Ref<number> | ComputedRef<number>;
}) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: Omit<SetPreorderDemandVendorParams, 'tenantId'>) => {
      const tenantId = unref(options.tenantId);
      if (!tenantId) throw new Error('Tenant is required');
      return procurementDemandRepository.setPreorderDemandVendorForDocument({
        tenantId,
        ...payload,
      });
    },
    onSuccess: () => {
      invalidateDemandDeskQueries(queryClient);
    },
  });
}

/** @deprecated use useUpsertPreorderDemandMutation */
export const useRecordProcurementPlacementMutation = useUpsertPreorderDemandMutation;

export type PlacementDialogTarget = {
  sourceType: ProcurementDemandSourceType;
  sourceId: number;
  productName: string;
  remainingQuantity: number;
  defaultVendorId?: number | null;
};

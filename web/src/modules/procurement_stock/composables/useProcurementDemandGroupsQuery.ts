import { useQuery } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref, unref } from 'vue';
import {
  procurementDemandRepository,
  type ProcurementDemandStatus,
} from '../repositories/procurementDemandRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import { STALE_STANDARD } from 'src/query/staleTimes';

export function useProcurementDemandGroupsQuery(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  procurementStatus: Ref<ProcurementDemandStatus> | ComputedRef<ProcurementDemandStatus>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  childTenantId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  profileId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  limit?: number;
  offset?: Ref<number> | ComputedRef<number>;
  enabled?: Ref<boolean> | ComputedRef<boolean>;
}) {
  const resolvedTenantId = computed(() => {
    const raw = unref(options.tenantId);
    return raw && !Number.isNaN(Number(raw)) ? Number(raw) : null;
  });

  const resolvedSearch = computed(() => {
    const raw = unref(options.search);
    const trimmed = typeof raw === 'string' ? raw.trim() : '';
    return trimmed.length ? trimmed : null;
  });

  const resolvedChildTenantId = computed(() => {
    const raw = unref(options.childTenantId);
    return raw && !Number.isNaN(Number(raw)) ? Number(raw) : null;
  });

  const resolvedProfileId = computed(() => {
    const raw = unref(options.profileId);
    return raw && !Number.isNaN(Number(raw)) ? Number(raw) : null;
  });

  const resolvedOffset = computed(() => unref(options.offset) ?? 0);

  const queryKey = computed(() =>
    procurementStockQueryKeys.demandGroups({
      tenantId: resolvedTenantId.value ?? 0,
      procurementStatus: unref(options.procurementStatus),
      search: resolvedSearch.value,
      childTenantId: resolvedChildTenantId.value,
      profileId: resolvedProfileId.value,
      limit: options.limit ?? 50,
      offset: resolvedOffset.value,
    }),
  );

  return useQuery({
    queryKey,
    queryFn: () =>
      procurementDemandRepository.listProcurementDemandGroups({
        tenantId: resolvedTenantId.value!,
        procurementStatus: unref(options.procurementStatus),
        search: resolvedSearch.value,
        childTenantId: resolvedChildTenantId.value,
        profileId: resolvedProfileId.value,
        limit: options.limit ?? 50,
        offset: resolvedOffset.value,
      }),
    enabled: computed(() => {
      if (unref(options.enabled) === false) return false;
      return resolvedTenantId.value !== null;
    }),
    staleTime: STALE_STANDARD,
  });
}

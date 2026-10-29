import { useQuery, keepPreviousData, type QueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  cashbookRepository,
  type CashbookEntityType,
} from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';

/** Profile picker lists — cache longer to avoid refetch on every tab switch. */
const PROFILE_LIST_STALE_MS = 120_000;

export type CashbookEntitiesParams = {
  tenantId: number;
  booksTenantId: number;
  entityType: CashbookEntityType | 'tenant';
  search?: string;
  offset?: number;
  limit?: number;
};

const entityListQueryKey = (
  tenantId: number,
  entityType: CashbookEntityType,
  params: { search?: string; offset?: number; limit?: number },
) => cashbookQueryKeys.entities(tenantId, entityType, params);

export function prefetchCashbookProfileLists(
  queryClient: QueryClient,
  tenantId: number,
  booksTenantId: number,
  options?: { search?: string; limit?: number },
) {
  if (!tenantId) return;
  const limit = options?.limit ?? 200;
  const search = options?.search;

  void queryClient.prefetchQuery({
    queryKey: cashbookQueryKeys.tenantCash(tenantId, booksTenantId),
    queryFn: () => cashbookRepository.getTenantCashRow(tenantId, booksTenantId),
    staleTime: PROFILE_LIST_STALE_MS,
  });

  for (const entityType of ['customer', 'courier', 'vendor'] as const) {
    void queryClient.prefetchQuery({
      queryKey: entityListQueryKey(tenantId, entityType, { search, limit }),
      queryFn: () =>
        cashbookRepository.listEntities({
          tenantId,
          entityType,
          search,
          limit,
        }),
      staleTime: PROFILE_LIST_STALE_MS,
    });
  }
}

export function useCashbookEntitiesQuery(params: Ref<CashbookEntitiesParams>) {
  const tenantCashQuery = useQuery({
    queryKey: computed(() =>
      cashbookQueryKeys.tenantCash(params.value.tenantId, params.value.booksTenantId),
    ),
    queryFn: () =>
      cashbookRepository.getTenantCashRow(params.value.tenantId, params.value.booksTenantId),
    enabled: computed(() => params.value.entityType === 'tenant' && !!params.value.tenantId),
    staleTime: PROFILE_LIST_STALE_MS,
  });

  const entitiesQuery = useQuery({
    queryKey: computed(() =>
      entityListQueryKey(params.value.tenantId, params.value.entityType as CashbookEntityType, {
        search: params.value.search,
        offset: params.value.offset,
        limit: params.value.limit,
      }),
    ),
    queryFn: () =>
      cashbookRepository.listEntities({
        tenantId: params.value.tenantId,
        entityType: params.value.entityType as CashbookEntityType,
        search: params.value.search,
        offset: params.value.offset,
        limit: params.value.limit,
      }),
    staleTime: PROFILE_LIST_STALE_MS,
    placeholderData: keepPreviousData,
    enabled: computed(
      () =>
        params.value.entityType !== 'tenant' &&
        !!params.value.tenantId &&
        ['customer', 'courier', 'vendor'].includes(params.value.entityType),
    ),
  });

  return { tenantCashQuery, entitiesQuery };
}

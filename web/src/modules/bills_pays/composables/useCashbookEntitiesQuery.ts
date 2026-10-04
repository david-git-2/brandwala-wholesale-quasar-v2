import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  cashbookRepository,
  type CashbookEntityType,
} from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';

export type CashbookEntitiesParams = {
  tenantId: number;
  booksTenantId: number;
  entityType: CashbookEntityType | 'tenant';
  search?: string;
  offset?: number;
  limit?: number;
};

export function useCashbookEntitiesQuery(params: Ref<CashbookEntitiesParams>) {
  const tenantCashQuery = useQuery({
    queryKey: computed(() =>
      cashbookQueryKeys.tenantCash(params.value.tenantId, params.value.booksTenantId),
    ),
    queryFn: () =>
      cashbookRepository.getTenantCashRow(params.value.tenantId, params.value.booksTenantId),
    enabled: computed(() => params.value.entityType === 'tenant' && !!params.value.tenantId),
    staleTime: 30_000,
  });

  const entitiesQuery = useQuery({
    queryKey: computed(() =>
      cashbookQueryKeys.entities(params.value.tenantId, params.value.entityType, {
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
    staleTime: 30_000,
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

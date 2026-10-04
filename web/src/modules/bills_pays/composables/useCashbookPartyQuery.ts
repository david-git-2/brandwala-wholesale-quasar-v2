import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { cashbookRepository } from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';

export type CashbookPartyParams = {
  tenantId: number;
  entityType: string;
  entityId: number;
  search?: string;
  ledgerOffset?: number;
  ledgerLimit?: number;
};

export function useCashbookPartyQuery(params: Ref<CashbookPartyParams>) {
  const detailQuery = useQuery({
    queryKey: computed(() =>
      cashbookQueryKeys.detail(params.value.tenantId, params.value.entityType, params.value.entityId),
    ),
    queryFn: () =>
      cashbookRepository.getPartyDetail(
        params.value.tenantId,
        params.value.entityType,
        params.value.entityId,
      ),
    enabled: computed(() => !!params.value.tenantId && !!params.value.entityId),
    staleTime: 30_000,
  });

  const ledgerQuery = useQuery({
    queryKey: computed(() =>
      cashbookQueryKeys.ledger(params.value.tenantId, params.value.entityType, params.value.entityId, {
        search: params.value.search,
        offset: params.value.ledgerOffset,
        limit: params.value.ledgerLimit,
      }),
    ),
    queryFn: () =>
      cashbookRepository.listLedger({
        tenantId: params.value.tenantId,
        entityType: params.value.entityType,
        entityId: params.value.entityId,
        search: params.value.search,
        offset: params.value.ledgerOffset,
        limit: params.value.ledgerLimit,
      }),
    enabled: computed(() => !!params.value.tenantId && !!params.value.entityId),
    staleTime: 30_000,
    placeholderData: keepPreviousData,
  });

  return { detailQuery, ledgerQuery };
}

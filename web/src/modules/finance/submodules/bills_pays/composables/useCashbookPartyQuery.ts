import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, unref, type ComputedRef, type Ref } from 'vue';
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

type CashbookPartyQueryOptions = {
  /** Default true (Cashbook party page). Bill detail only needs detail. */
  fetchLedger?: boolean;
  enabled?: Ref<boolean> | ComputedRef<boolean>;
};

export function useCashbookPartyQuery(
  params: Ref<CashbookPartyParams>,
  options?: CashbookPartyQueryOptions,
) {
  const fetchLedger = options?.fetchLedger ?? true;
  const externalEnabled = computed(() => unref(options?.enabled ?? true));

  const partyReady = computed(
    () =>
      externalEnabled.value &&
      !!params.value.tenantId &&
      !!params.value.entityId,
  );

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
    enabled: partyReady,
    staleTime: 60_000,
    gcTime: 5 * 60_000,
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
    enabled: computed(() => fetchLedger && partyReady.value),
    staleTime: 60_000,
    gcTime: 5 * 60_000,
    placeholderData: keepPreviousData,
  });

  return { detailQuery, ledgerQuery };
}

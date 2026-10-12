import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { cashbookRepository } from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';

export type CashbookPointsContext = {
  booksTenantId: number;
  entityType: string;
  entityId: number;
  enabled: boolean;
};

export function useCashbookPointsQuery(ctx: Ref<CashbookPointsContext>) {
  const accountQuery = useQuery({
    queryKey: computed(() =>
      cashbookQueryKeys.cashbookAccount(
        ctx.value.booksTenantId,
        ctx.value.entityType,
        ctx.value.entityId,
      ),
    ),
    queryFn: () =>
      cashbookRepository.findCashbookAccountId({
        booksTenantId: ctx.value.booksTenantId,
        entityType: ctx.value.entityType,
        entityId: ctx.value.entityId,
      }),
    enabled: computed(() => ctx.value.enabled && !!ctx.value.booksTenantId && !!ctx.value.entityId),
    staleTime: 60_000,
  });

  const cashbookAccountId = computed(() => accountQuery.data.value ?? null);

  const pointsQuery = useQuery({
    queryKey: computed(() => cashbookQueryKeys.points(cashbookAccountId.value)),
    queryFn: () => cashbookRepository.listCashbookPoints(cashbookAccountId.value!),
    enabled: computed(() => ctx.value.enabled && cashbookAccountId.value != null),
    staleTime: 30_000,
  });

  return { accountQuery, pointsQuery, cashbookAccountId };
}

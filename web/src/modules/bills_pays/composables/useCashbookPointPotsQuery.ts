import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { cashbookRepository } from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';

export function useCashbookPointPotsQuery(pointId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => cashbookQueryKeys.pointPots(pointId.value)),
    queryFn: () => cashbookRepository.listCashbookPointPots(pointId.value!),
    enabled: computed(() => enabled.value && pointId.value != null && pointId.value > 0),
    staleTime: 30_000,
  });
}

export function useCashbookPointPotsBatchQuery(pointIds: Ref<number[]>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => [...cashbookQueryKeys.root, 'point_pots_batch', pointIds.value] as const),
    queryFn: () => cashbookRepository.listCashbookPointPotsForPoints(pointIds.value),
    enabled: computed(() => enabled.value && pointIds.value.length > 0),
    staleTime: 30_000,
  });
}

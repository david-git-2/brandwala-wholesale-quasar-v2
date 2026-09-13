import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import {
  emptyPbcFileSummaryMetrics,
  mapPbcFileSummaryFromRpc,
} from './usePbcFileSummaryMetrics';

type SummaryRates = {
  cargoRate: number;
  conversionRate: number;
  profitRate: number;
};

export function usePbcFileSummaryQuery(
  fileId: Ref<number>,
  rates: Ref<SummaryRates>,
) {
  const query = useQuery({
    queryKey: computed(() =>
      productBasedCostingQueryKeys.fileSummary(fileId.value, {
        conversionRate: rates.value.conversionRate,
        cargoRate: rates.value.cargoRate,
        profitRate: rates.value.profitRate,
      }),
    ),
    queryFn: () =>
      productBasedCostingRepository.getProductBasedCostingFileSummary(fileId.value, {
        conversion_rate: rates.value.conversionRate,
        cargo_rate_kg_gbp: rates.value.cargoRate,
        profit_rate: rates.value.profitRate,
      }),
    enabled: computed(() => fileId.value > 0),
    staleTime: 30 * 1000,
  });

  const summaryMetrics = computed(() => {
    if (!query.data.value) return emptyPbcFileSummaryMetrics();
    return mapPbcFileSummaryFromRpc(query.data.value);
  });

  return {
    ...query,
    summaryMetrics,
  };
}

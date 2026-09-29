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
  vatRate: number;
  offerPricingMode: string;
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
        vatRate: rates.value.vatRate,
        offerPricingMode: rates.value.offerPricingMode,
      }),
    ),
    queryFn: () =>
      productBasedCostingRepository.getProductBasedCostingFileSummary(fileId.value, {
        conversion_rate: rates.value.conversionRate,
        cargo_rate_kg_gbp: rates.value.cargoRate,
        profit_rate: rates.value.profitRate,
        vat_rate: rates.value.vatRate,
        offer_pricing_mode: rates.value.offerPricingMode,
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

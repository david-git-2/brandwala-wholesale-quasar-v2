import { useQuery } from '@tanstack/vue-query';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import { thriftCurrencyRepository } from '../repositories/thriftCurrencyRepository';

export function useThriftCurrenciesQuery() {
  return useQuery({
    queryKey: thriftQueryKeys.currencies(),
    queryFn: () => thriftCurrencyRepository.fetchActiveCurrencies(),
    staleTime: 15 * 60 * 1000, // reference data — 15 min
  });
}

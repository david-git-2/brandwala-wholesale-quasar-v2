import { useQuery } from '@tanstack/vue-query';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';

const STALE_MS = 24 * 60 * 60 * 1000;

export function useMoneyKernelCurrenciesQuery() {
  return useQuery({
    queryKey: ['money-kernel', 'currencies'],
    queryFn: () => moneyKernelRepository.listCurrencies(),
    staleTime: STALE_MS,
    gcTime: STALE_MS,
  });
}

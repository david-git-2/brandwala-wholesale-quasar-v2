import { QueryClient } from '@tanstack/vue-query';
import { STALE_STANDARD } from './staleTimes';

export const appQueryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: STALE_STANDARD,
      gcTime: 5 * 60_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 0,
    },
  },
});

export function clearShopOrderQueryCache() {
  void appQueryClient.removeQueries({ queryKey: ['shopOrder'] });
  void appQueryClient.removeQueries({ queryKey: ['shop_order'] });
  void appQueryClient.removeQueries({ queryKey: ['auth', 'shopLoginGroups'] });
}

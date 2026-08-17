import { QueryClient } from '@tanstack/vue-query';

export const appQueryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
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
}

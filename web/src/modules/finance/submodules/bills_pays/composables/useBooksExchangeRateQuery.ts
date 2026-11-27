import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { cashbookRepository } from '../repositories/cashbookRepository';

export function useBooksExchangeRateQuery(
  tenantId: Ref<number>,
  quoteCurrencyCode: Ref<string>,
  enabled: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() => [
      'booksExchangeRate',
      tenantId.value,
      quoteCurrencyCode.value,
    ]),
    queryFn: async () => {
      const rows = await cashbookRepository.listBooksExchangeRates({
        tenantId: tenantId.value,
        quoteCurrencyCode: quoteCurrencyCode.value,
        limit: 1,
      });
      const row = rows[0];
      return row ? Number(row.rate) : null;
    },
    enabled: computed(
      () =>
        enabled.value &&
        tenantId.value > 0 &&
        quoteCurrencyCode.value.length >= 3 &&
        quoteCurrencyCode.value !== 'BDT',
    ),
    staleTime: 60_000,
  });
}

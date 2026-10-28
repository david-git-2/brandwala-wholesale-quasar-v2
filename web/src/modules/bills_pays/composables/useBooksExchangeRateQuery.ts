import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { cashbookRepository } from '../repositories/cashbookRepository';

export function useBooksExchangeRateQuery(
  parentTenantId: Ref<number>,
  quoteCurrencyCode: Ref<string>,
  enabled: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() => [
      'booksExchangeRate',
      parentTenantId.value,
      quoteCurrencyCode.value,
    ]),
    queryFn: async () => {
      const rows = await cashbookRepository.listBooksExchangeRates({
        parentTenantId: parentTenantId.value,
        quoteCurrencyCode: quoteCurrencyCode.value,
        limit: 1,
      });
      const row = rows[0];
      return row ? Number(row.rate) : null;
    },
    enabled: computed(
      () =>
        enabled.value &&
        parentTenantId.value > 0 &&
        quoteCurrencyCode.value.length >= 3 &&
        quoteCurrencyCode.value !== 'BDT',
    ),
    staleTime: 60_000,
  });
}

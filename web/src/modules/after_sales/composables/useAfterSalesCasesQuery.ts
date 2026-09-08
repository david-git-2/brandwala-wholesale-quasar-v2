import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { afterSalesRepositoryStub } from '../repositories/afterSalesRepository.stub';
import { afterSalesQueryKeys } from '../services/afterSalesQueryKeys';
import type { AfterSalesCaseListFilters } from '../types/afterSales.types';

export function useAfterSalesCasesQuery(
  tenantId: Ref<number | null | undefined>,
  filters: Ref<AfterSalesCaseListFilters>,
) {
  return useQuery({
    queryKey: computed(() => afterSalesQueryKeys.cases(tenantId.value ?? 0, filters.value)),
    queryFn: () => afterSalesRepositoryStub.listCases(tenantId.value!, filters.value),
    enabled: computed(() => Boolean(tenantId.value)),
    staleTime: 15_000,
  });
}

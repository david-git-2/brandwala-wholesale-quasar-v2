import { computed } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { CourierUnremittedFinancialSummary } from '../types';

export function useCourierHoldingsQuery() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const query = useQuery<CourierUnremittedFinancialSummary[], Error>({
    queryKey: computed(() => shopOrderQueryKeys.courierHoldingSummary(tenantId.value || 0)),
    queryFn: () => courierRemittanceRepository.fetchUnremittedSummary(tenantId.value!),
    enabled: computed(() => Boolean(tenantId.value && tenantId.value > 0)),
    staleTime: 1000 * 60 * 2, // 2 minutes
  });

  const totals = computed(() => {
    const list = query.data.value || [];
    return list.reduce(
      (acc, item) => {
        acc.grossCod += Number(item.gross_cod_total || 0);
        acc.companyWholesale += Number(item.company_wholesale_total || 0);
        acc.middlemanMargin += Number(item.middleman_margin_total || 0);
        acc.orderCount += Number(item.unremitted_order_count || 0);
        return acc;
      },
      { grossCod: 0, companyWholesale: 0, middlemanMargin: 0, orderCount: 0 },
    );
  });

  return {
    summaryList: computed(() => query.data.value || []),
    totals,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    refetch: query.refetch,
  };
}

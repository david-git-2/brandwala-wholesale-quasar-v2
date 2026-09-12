import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import { salesInvoiceDashboardRepository } from '../repositories/salesInvoiceDashboardRepository';

export function useSalesInvoiceDashboardQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => salesInvoiceQueryKeys.dashboard(Number(tenantId.value) || 0)),
    queryFn: () => salesInvoiceDashboardRepository.getMetrics(Number(tenantId.value)),
    enabled: computed(() => !!tenantId.value),
    staleTime: 30 * 1000,
  });
}

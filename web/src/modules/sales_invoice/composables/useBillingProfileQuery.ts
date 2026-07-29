import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  billingProfileRepository,
  type BillingProfileListQuery,
} from '../repositories/billingProfileRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';

export function useBillingProfilesQuery(
  tenantId: Ref<number | null | undefined>,
  params?: Ref<Partial<BillingProfileListQuery> | undefined>
) {
  const queryParams = computed<BillingProfileListQuery>(() => {
    const p: BillingProfileListQuery = { page_size: 1000 };
    if (tenantId.value) {
      p.tenant_id = tenantId.value;
    }
    if (params?.value) {
      Object.assign(p, params.value);
    }
    return p;
  });

  return useQuery({
    queryKey: computed(() =>
      salesInvoiceQueryKeys.billingProfiles(tenantId.value ?? null, queryParams.value)
    ),
    queryFn: () => {
      if (!tenantId.value) return { data: [], meta: { total: 0, page: 1, page_size: 1000, total_pages: 1 } };
      return billingProfileRepository.listBillingProfiles(queryParams.value);
    },
    enabled: computed(() => !!tenantId.value),
    staleTime: 2 * 60 * 1000,
  });
}


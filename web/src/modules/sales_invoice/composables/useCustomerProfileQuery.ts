import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  customerProfileRepository,
  type CustomerProfileListQuery,
} from '../repositories/customerProfileRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';

export function useCustomerProfilesQuery(
  tenantId: Ref<number | null | undefined>,
  params?: Ref<Partial<CustomerProfileListQuery> | undefined>
) {
  const queryParams = computed<CustomerProfileListQuery>(() => {
    const p: CustomerProfileListQuery = { page_size: 1000 };
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
      salesInvoiceQueryKeys.customerProfiles(tenantId.value ?? null, queryParams.value)
    ),
    queryFn: () => {
      if (!tenantId.value) return { data: [], meta: { total: 0, page: 1, page_size: 1000, total_pages: 1 } };
      return customerProfileRepository.listCustomerProfiles(queryParams.value);
    },
    enabled: computed(() => !!tenantId.value),
    staleTime: 2 * 60 * 1000,
  });
}


import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import type { CustomerProfileListQuery } from '../repositories/customerProfileRepository';
import { useCustomerProfileStore } from '../stores/customerProfileStore';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';

export function useCustomerProfilesQuery(
  tenantId: Ref<number | null | undefined>,
  params?: Ref<Partial<CustomerProfileListQuery> | undefined>,
) {
  const store = useCustomerProfileStore();

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
      salesInvoiceQueryKeys.customerProfiles(
        tenantId.value ?? null,
        queryParams.value as Record<string, unknown>,
      ),
    ),
    queryFn: async () => {
      if (!tenantId.value) {
        return { data: [], meta: { total: 0, page: 1, page_size: 1000, total_pages: 1 } };
      }
      const id = tenantId.value;
      if (store.loadedTenantIds[id]) {
        const data = store.byTenantId[id] ?? [];
        return {
          data,
          meta: {
            total: data.length,
            page: 1,
            page_size: 1000,
            total_pages: 1,
          },
        };
      }
      const data = await store.ensureLoaded(id);
      return {
        data,
        meta: {
          total: data.length,
          page: 1,
          page_size: 1000,
          total_pages: 1,
        },
      };
    },
    enabled: computed(() => !!tenantId.value),
    staleTime: 2 * 60 * 1000,
  });
}

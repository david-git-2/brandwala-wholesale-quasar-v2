import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { tenantQueryKeys } from 'src/modules/tenant/shared/queryKeys/tenantQueryKeys';
import { shopPermissionsRepository } from '../repositories/shopPermissionsRepository';
import { BOOKS_CUSTOMER_GROUPS_STALE_MS } from '../utils/booksCustomerGroupsCache';

export function useBooksCustomerGroupsQuery(
  tenantId: Ref<number | null | undefined>,
  _unusedParentTenantId?: Ref<number | null | undefined>,
  enabled?: Ref<boolean>,
) {
  const booksTenantId = computed(() => tenantId.value ?? 0);

  return useQuery({
    queryKey: computed(() => tenantQueryKeys.booksCustomerGroups(booksTenantId.value)),
    queryFn: () => shopPermissionsRepository.listCustomerGroupsByBooksTenantId(booksTenantId.value),
    enabled: computed(
      () => (enabled?.value ?? true) && booksTenantId.value > 0,
    ),
    staleTime: BOOKS_CUSTOMER_GROUPS_STALE_MS,
    refetchOnWindowFocus: false,
  });
}

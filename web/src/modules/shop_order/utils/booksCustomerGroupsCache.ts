import type { QueryClient } from '@tanstack/vue-query';
import { tenantQueryKeys } from 'src/modules/tenant/shared/queryKeys/tenantQueryKeys';
import { shopPermissionsRepository } from '../repositories/shopPermissionsRepository';
import type { BooksCustomerGroupRow } from '../types/shopCustomerAccessPage';

export const BOOKS_CUSTOMER_GROUPS_STALE_MS = 20 * 60 * 1000;

export function seedBooksCustomerGroups(
  queryClient: QueryClient,
  booksTenantId: number,
  groups: BooksCustomerGroupRow[],
) {
  queryClient.setQueryData(tenantQueryKeys.booksCustomerGroups(booksTenantId), groups);
}

export async function fetchBooksCustomerGroupsCached(
  queryClient: QueryClient,
  booksTenantId: number,
): Promise<BooksCustomerGroupRow[]> {
  return queryClient.fetchQuery({
    queryKey: tenantQueryKeys.booksCustomerGroups(booksTenantId),
    queryFn: () => shopPermissionsRepository.listCustomerGroupsByBooksTenantId(booksTenantId),
    staleTime: BOOKS_CUSTOMER_GROUPS_STALE_MS,
  });
}

import type { QueryClient } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopCustomerGroupAccess } from '../types';
import type { BooksCustomerGroupRow, ShopCustomerAccessPageBundle } from '../types/shopCustomerAccessPage';

export function toBooksCustomerGroupRow(group: {
  id: number;
  name: string;
  is_active?: boolean | null;
  accent_color?: string | null;
}): BooksCustomerGroupRow {
  return {
    id: group.id,
    name: group.name,
    is_active: group.is_active !== false,
    accent_color: group.accent_color ?? null,
  };
}

export function appendCustomerGroupToAccessPageCaches(
  queryClient: QueryClient,
  group: BooksCustomerGroupRow,
) {
  const entries = queryClient.getQueriesData<ShopCustomerAccessPageBundle>({
    queryKey: shopOrderQueryKeys.shopCustomerAccessPageRoot(),
  });

  for (const [queryKey, prev] of entries) {
    if (!prev) continue;
    if (prev.customer_groups.some((row) => row.id === group.id)) continue;
    queryClient.setQueryData<ShopCustomerAccessPageBundle>(queryKey, {
      ...prev,
      customer_groups: [...prev.customer_groups, group].sort((a, b) => a.id - b.id),
    });
  }
}

export function upsertAccessOverrideInAccessPageCache(
  queryClient: QueryClient,
  tenantId: number,
  shopId: number,
  override: ShopCustomerGroupAccess,
) {
  queryClient.setQueryData<ShopCustomerAccessPageBundle>(
    shopOrderQueryKeys.shopCustomerAccessPage(tenantId, shopId),
    (prev) => {
      if (!prev) return prev;
      const idx = prev.access_overrides.findIndex(
        (row) =>
          row.customer_group_id === override.customer_group_id && row.shop_id === override.shop_id,
      );
      const access_overrides =
        idx >= 0
          ? prev.access_overrides.map((row, i) => (i === idx ? override : row))
          : [...prev.access_overrides, override];
      return { ...prev, access_overrides };
    },
  );
}

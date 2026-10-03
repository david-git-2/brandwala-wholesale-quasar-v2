import { keepPreviousData, useInfiniteQuery } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref, unref } from 'vue';
import type { StockAvailability } from '../constants/stockAvailability';
import {
  globalStockRepository,
  type GlobalStockGroupRow,
} from '../repositories/globalStockRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

export const WAREHOUSE_STOCK_GROUPS_PAGE_SIZE = 50;

export function useWarehouseStockGroupsQuery(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  groupBy: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  shipmentId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  shipmentStatus?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  locationId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  availability?: Ref<StockAvailability | null | undefined> | ComputedRef<StockAvailability | null | undefined>;
  gradeTagId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  hideZeroStock?: Ref<boolean | undefined> | ComputedRef<boolean | undefined>;
  enabled?: Ref<boolean> | ComputedRef<boolean>;
  limit?: number;
}) {
  const resolvedTenantId = computed(() => {
    const raw = unref(options.tenantId);
    return raw && !Number.isNaN(Number(raw)) ? Number(raw) : null;
  });

  const resolvedGroupBy = computed(() => {
    const raw = unref(options.groupBy);
    return raw && String(raw).trim() ? String(raw) : null;
  });

  const resolvedSearch = computed(() => {
    const raw = unref(options.search);
    const trimmed = typeof raw === 'string' ? raw.trim() : '';
    return trimmed.length ? trimmed : null;
  });

  const pageSize = options.limit ?? WAREHOUSE_STOCK_GROUPS_PAGE_SIZE;

  const queryKey = computed(() =>
    procurementStockQueryKeys.warehouseStockGroups({
      tenantId: resolvedTenantId.value ?? 0,
      groupBy: resolvedGroupBy.value ?? '',
      limit: pageSize,
      search: resolvedSearch.value,
      shipmentId: unref(options.shipmentId) ?? null,
      shipmentStatus: unref(options.shipmentStatus) ?? null,
      locationId: unref(options.locationId) ?? null,
      availability: unref(options.availability) ?? null,
      gradeTagId: unref(options.gradeTagId) ?? null,
      hideZeroStock: unref(options.hideZeroStock) ?? true,
    }),
  );

  const query = useInfiniteQuery({
    queryKey,
    queryFn: async ({ pageParam }) => {
      const tenantId = resolvedTenantId.value;
      const groupBy = resolvedGroupBy.value;
      if (!tenantId || !groupBy) {
        throw new Error('Warehouse groups query missing tenant or groupBy');
      }
      const offset = typeof pageParam === 'number' ? pageParam : 0;
      return globalStockRepository.listGroups(tenantId, {
        groupBy,
        limit: pageSize,
        offset,
        search: resolvedSearch.value,
        shipmentId: unref(options.shipmentId) ?? null,
        shipmentStatus: unref(options.shipmentStatus) ?? null,
        locationId: unref(options.locationId) ?? null,
        availability: unref(options.availability) ?? null,
        gradeTagId: unref(options.gradeTagId) ?? null,
        hideZeroStock: unref(options.hideZeroStock) ?? true,
      });
    },
    getNextPageParam: (lastPage, allPages) => {
      if (!lastPage.meta.has_more) return undefined;
      return allPages.length * pageSize;
    },
    initialPageParam: 0,
    staleTime: 30_000,
    placeholderData: keepPreviousData,
    enabled: computed(() => {
      if (unref(options.enabled) === false) return false;
      return resolvedTenantId.value !== null && resolvedGroupBy.value !== null;
    }),
  });

  const groups = computed<GlobalStockGroupRow[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<string>();
    const rows: GlobalStockGroupRow[] = [];
    for (const page of pages) {
      for (const row of page.groups) {
        if (seen.has(row.key)) continue;
        seen.add(row.key);
        rows.push(row);
      }
    }
    return rows;
  });

  const totalGroups = computed(() => query.data.value?.pages?.[0]?.meta.total ?? null);

  const hasMore = computed(() => query.hasNextPage.value ?? false);

  return {
    ...query,
    groups,
    totalGroups,
    hasMore,
  };
}

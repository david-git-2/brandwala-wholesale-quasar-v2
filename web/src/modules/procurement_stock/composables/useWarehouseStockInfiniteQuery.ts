import { keepPreviousData, useInfiniteQuery } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref, unref } from 'vue';
import type { StockAvailability } from '../constants/stockAvailability';
import {
  globalStockRepository,
  type GlobalStock,
  type GlobalStockListCursor,
} from '../repositories/globalStockRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

export const WAREHOUSE_STOCK_PAGE_SIZE = 20;

export function useWarehouseStockInfiniteQuery(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  shipmentId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  shipmentStatus?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  locationId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  availability?: Ref<StockAvailability | null | undefined> | ComputedRef<StockAvailability | null | undefined>;
  gradeTagId?: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  isSellable?: Ref<boolean | null | undefined> | ComputedRef<boolean | null | undefined>;
  hideZeroStock?: Ref<boolean | undefined> | ComputedRef<boolean | undefined>;
  groupBy?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  groupKey?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
  enabled?: Ref<boolean> | ComputedRef<boolean>;
  limit?: number;
}) {
  const resolvedTenantId = computed(() => {
    const raw = unref(options.tenantId);
    return raw && !Number.isNaN(Number(raw)) ? Number(raw) : null;
  });

  const resolvedSearch = computed(() => {
    const raw = unref(options.search);
    const trimmed = typeof raw === 'string' ? raw.trim() : '';
    return trimmed.length ? trimmed : null;
  });

  const resolvedShipmentId = computed(() => {
    const raw = unref(options.shipmentId);
    return raw != null && !Number.isNaN(Number(raw)) ? Number(raw) : null;
  });

  const resolvedLocationId = computed(() => {
    const raw = unref(options.locationId);
    return raw != null && !Number.isNaN(Number(raw)) ? Number(raw) : null;
  });

  const pageSize = options.limit ?? WAREHOUSE_STOCK_PAGE_SIZE;

  const queryKey = computed(() =>
    procurementStockQueryKeys.warehouseStockList({
      tenantId: resolvedTenantId.value ?? 0,
      limit: pageSize,
      search: resolvedSearch.value,
      shipmentId: resolvedShipmentId.value,
      shipmentStatus: unref(options.shipmentStatus) ?? null,
      locationId: resolvedLocationId.value,
      availability: unref(options.availability) ?? null,
      gradeTagId: unref(options.gradeTagId) ?? null,
      isSellable: unref(options.isSellable) ?? null,
      hideZeroStock: unref(options.hideZeroStock) ?? true,
      groupBy: unref(options.groupBy) ?? null,
      groupKey: unref(options.groupKey) ?? null,
    }),
  );

  const query = useInfiniteQuery({
    queryKey,
    queryFn: async ({ pageParam }) => {
      const tenantId = resolvedTenantId.value;
      if (!tenantId) {
        throw new Error('Warehouse stock query is missing tenant');
      }
      const cursor = (pageParam as GlobalStockListCursor | null) ?? null;
      return globalStockRepository.listCursor(tenantId, {
        limit: pageSize,
        cursor,
        search: resolvedSearch.value,
        shipmentId: resolvedShipmentId.value,
        shipmentStatus: unref(options.shipmentStatus) ?? null,
        locationId: resolvedLocationId.value,
        availability: unref(options.availability) ?? null,
        gradeTagId: unref(options.gradeTagId) ?? null,
        isSellable: unref(options.isSellable) ?? null,
        hideZeroStock: unref(options.hideZeroStock) ?? true,
        groupBy: unref(options.groupBy) ?? null,
        groupKey: unref(options.groupKey) ?? null,
        includeTotal: cursor == null,
      });
    },
    getNextPageParam: (lastPage) => {
      if (!lastPage.meta.has_more || !lastPage.meta.next_cursor) return undefined;
      const id = Number(lastPage.meta.next_cursor.id);
      return Number.isFinite(id) ? { id } : undefined;
    },
    initialPageParam: null as GlobalStockListCursor | null,
    staleTime: 30_000,
    placeholderData: keepPreviousData,
    enabled: computed(() => {
      if (unref(options.enabled) === false) return false;
      return resolvedTenantId.value !== null;
    }),
  });

  const stockRows = computed<GlobalStock[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const rows: GlobalStock[] = [];
    for (const page of pages) {
      for (const row of page.data) {
        if (seen.has(row.id)) continue;
        seen.add(row.id);
        rows.push(row);
      }
    }
    return rows;
  });

  const totalCount = computed(() => {
    const first = query.data.value?.pages?.[0];
    return first?.meta.total ?? null;
  });

  const hasMore = computed(() => query.hasNextPage.value ?? false);

  return {
    ...query,
    stockRows,
    totalCount,
    hasMore,
  };
}

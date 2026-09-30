import { keepPreviousData, useInfiniteQuery } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref, unref } from 'vue';
import {
  procurementDemandRepository,
  type ProcurementDemandDocumentType,
  type ProcurementDemandGroupItemsCursor,
  type ProcurementDemandItem,
} from '../repositories/procurementDemandRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import { DEMAND_GROUP_ITEMS_PAGE_SIZE } from './useProcurementDemandGroupItemsInfiniteQuery';

export function useProcurementFulfillGroupItemsInfiniteQuery(options: {
  tenantId: Ref<number | null | undefined> | ComputedRef<number | null | undefined>;
  documentType: Ref<ProcurementDemandDocumentType | null> | ComputedRef<ProcurementDemandDocumentType | null>;
  documentId: Ref<number | null> | ComputedRef<number | null>;
  search?: Ref<string | null | undefined> | ComputedRef<string | null | undefined>;
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

  const resolvedDocumentType = computed(() => unref(options.documentType));
  const resolvedDocumentId = computed(() => {
    const raw = unref(options.documentId);
    return raw && !Number.isNaN(Number(raw)) ? Number(raw) : null;
  });

  const pageSize = options.limit ?? DEMAND_GROUP_ITEMS_PAGE_SIZE;

  const queryKey = computed(() =>
    procurementStockQueryKeys.fulfillGroupItems({
      tenantId: resolvedTenantId.value ?? 0,
      documentType: resolvedDocumentType.value ?? '',
      documentId: resolvedDocumentId.value ?? 0,
      search: resolvedSearch.value,
      limit: pageSize,
    }),
  );

  const query = useInfiniteQuery({
    queryKey,
    queryFn: async ({ pageParam }) => {
      const tenantId = resolvedTenantId.value;
      const documentType = resolvedDocumentType.value;
      const documentId = resolvedDocumentId.value;
      if (!tenantId || !documentType || !documentId) {
        throw new Error('Fulfill group items query is missing scope');
      }
      return procurementDemandRepository.listProcurementFulfillGroupItems({
        tenantId,
        documentType,
        documentId,
        search: resolvedSearch.value,
        limit: pageSize,
        cursor: (pageParam as ProcurementDemandGroupItemsCursor | null) ?? null,
      });
    },
    getNextPageParam: (lastPage) =>
      lastPage.meta.has_more && lastPage.meta.next_cursor
        ? lastPage.meta.next_cursor
        : undefined,
    initialPageParam: null as ProcurementDemandGroupItemsCursor | null,
    staleTime: 30_000,
    placeholderData: keepPreviousData,
    enabled: computed(() => {
      if (unref(options.enabled) === false) return false;
      return (
        resolvedTenantId.value !== null &&
        resolvedDocumentType.value !== null &&
        resolvedDocumentId.value !== null
      );
    }),
  });

  const demandItems = computed<ProcurementDemandItem[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<string>();
    const items: ProcurementDemandItem[] = [];
    for (const page of pages) {
      for (const item of page.items) {
        const key = `${item.source_type}-${item.source_id}`;
        if (seen.has(key)) continue;
        seen.add(key);
        items.push(item);
      }
    }
    return items;
  });

  const hasMoreItems = computed(() => query.hasNextPage.value ?? false);

  return {
    ...query,
    demandItems,
    hasMoreItems,
  };
}

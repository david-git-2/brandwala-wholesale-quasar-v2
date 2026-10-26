import type { InfiniteData, QueryClient } from '@tanstack/vue-query';
import {
  computePbcFileSummaryMetrics,
  mapPbcFileSummaryMetricsToRpc,
} from '../composables/usePbcFileSummaryMetrics';
import {
  PBC_ITEMS_PAGE_SIZE,
  productBasedCostingQueryKeys,
} from '../shared/queryKeys/productBasedCostingQueryKeys';
import type {
  PbcFileDetailsBundlePage,
  PbcItemProductCatalog,
  ProductBasedCostingFile,
  ProductBasedCostingFileListPage,
  ProductBasedCostingItem,
} from '../types';
import { toNumberSafe } from './pricing';

function fileSummaryRates(file: ProductBasedCostingFile) {
  return {
    conversionRate: toNumberSafe(file.conversion_rate) || 140,
    cargoRate: toNumberSafe(file.cargo_rate_kg_gbp),
    profitRate: toNumberSafe(file.profit_rate) || 25,
    vatRate: toNumberSafe(file.vat_rate),
    offerPricingMode: file.offer_pricing_mode ?? 'landed_cost_plus',
  };
}

function collectBundleItems(data: InfiniteData<PbcFileDetailsBundlePage>): ProductBasedCostingItem[] {
  const seen = new Set<number>();
  const items: ProductBasedCostingItem[] = [];
  for (const page of data.pages) {
    for (const item of page.items.data) {
      if (!seen.has(item.id)) {
        seen.add(item.id);
        items.push(item);
      }
    }
  }
  return items;
}

function recomputeBundleSummary(
  file: ProductBasedCostingFile | null | undefined,
  items: ProductBasedCostingItem[],
): Record<string, unknown> | null {
  if (!file) return null;
  const metrics = computePbcFileSummaryMetrics(items, fileSummaryRates(file));
  return mapPbcFileSummaryMetricsToRpc(metrics) as Record<string, unknown>;
}

function syncFileSummaryQueryCaches(
  queryClient: QueryClient,
  fileId: number,
  summary: Record<string, unknown> | null,
) {
  if (!summary) return;
  queryClient.setQueriesData<Record<string, unknown>>(
    { queryKey: productBasedCostingQueryKeys.fileSummaryRoot(fileId) },
    () => summary,
  );
}

function applyDetailsBundlePatch(
  queryClient: QueryClient,
  fileId: number,
  patchPages: (pages: PbcFileDetailsBundlePage[]) => PbcFileDetailsBundlePage[],
) {
  queryClient.setQueriesData<InfiniteData<PbcFileDetailsBundlePage>>(
    { queryKey: productBasedCostingQueryKeys.fileDetailsPageRoot(fileId) },
    (oldData) => {
      if (!oldData?.pages?.length) {
        return oldData;
      }

      const pages = patchPages(oldData.pages);
      const items = collectBundleItems({ ...oldData, pages });
      const summary = recomputeBundleSummary(pages[0]?.file, items);
      syncFileSummaryQueryCaches(queryClient, fileId, summary);

      return {
        ...oldData,
        pages: pages.map((page, index) => ({
          ...page,
          summary: index === 0 ? summary : page.summary,
        })),
      };
    },
  );
}

export function addPbcItemToDetailsBundleCache(
  queryClient: QueryClient,
  fileId: number,
  item: ProductBasedCostingItem,
) {
  applyDetailsBundlePatch(queryClient, fileId, (pages) => {
    if (pages.some((page) => page.items.data.some((existing) => existing.id === item.id))) {
      return pages;
    }

    const [firstPage, ...restPages] = pages;
    if (!firstPage) {
      return pages;
    }

    return [
      {
        ...firstPage,
        items: {
          ...firstPage.items,
          data: [...firstPage.items.data, item],
        },
      },
      ...restPages,
    ];
  });
}

export function removePbcItemFromDetailsBundleCache(
  queryClient: QueryClient,
  fileId: number,
  itemId: number,
) {
  applyDetailsBundlePatch(queryClient, fileId, (pages) =>
    pages.map((page) => ({
      ...page,
      items: {
        ...page.items,
        data: page.items.data.filter((item) => item.id !== itemId),
      },
    })),
  );
}

export function updatePbcItemInDetailsBundleCache(
  queryClient: QueryClient,
  fileId: number,
  updated: ProductBasedCostingItem,
) {
  applyDetailsBundlePatch(queryClient, fileId, (pages) =>
    pages.map((page) => ({
      ...page,
      items: {
        ...page.items,
        data: page.items.data.map((item) =>
          item.id === updated.id ? { ...item, ...updated } : item,
        ),
      },
    })),
  );
}

export function readPbcFileFromDetailsBundleCache(
  queryClient: QueryClient,
  fileId: number,
): ProductBasedCostingFile | undefined {
  const queries = queryClient.getQueriesData<InfiniteData<PbcFileDetailsBundlePage>>({
    queryKey: productBasedCostingQueryKeys.fileDetailsPageRoot(fileId),
  });
  for (const [, data] of queries) {
    const file = data?.pages?.[0]?.file;
    if (file?.id === fileId) {
      return file;
    }
  }
  return undefined;
}

export function readPbcFileFromListCache(
  queryClient: QueryClient,
  fileId: number,
): ProductBasedCostingFile | undefined {
  const listQueries = queryClient.getQueriesData<InfiniteData<ProductBasedCostingFileListPage>>({
    queryKey: ['productBasedCosting', 'files', 'list'],
  });
  for (const [, data] of listQueries) {
    const pages = data?.pages ?? [];
    for (const page of pages) {
      const found = page.data.find((file) => file.id === fileId);
      if (found) {
        return found;
      }
    }
  }
  return undefined;
}

export function readPbcProductCatalogFromDetailsBundleCache(
  queryClient: QueryClient,
  fileId: number,
): Map<number, PbcItemProductCatalog> {
  const map = new Map<number, PbcItemProductCatalog>();
  const queries = queryClient.getQueriesData<InfiniteData<PbcFileDetailsBundlePage>>({
    queryKey: productBasedCostingQueryKeys.fileDetailsPageRoot(fileId),
  });
  for (const [, data] of queries) {
    for (const page of data?.pages ?? []) {
      for (const row of page.product_catalog ?? []) {
        const productId = row.product_id;
        if (!Number.isFinite(productId) || productId <= 0) continue;
        map.set(productId, {
          languages: row.languages ?? null,
          country_of_origin: row.country_of_origin ?? null,
          available_units: row.available_units ?? null,
          batch_code_manufacture_date: row.batch_code_manufacture_date ?? null,
          expire_date: row.expire_date ?? null,
        });
      }
    }
  }
  return map;
}

export function isPbcDetailsBundleQueryPending(
  queryClient: QueryClient,
  fileId: number,
): boolean {
  const state = queryClient.getQueryState({
    queryKey: productBasedCostingQueryKeys.fileDetailsPage(fileId, PBC_ITEMS_PAGE_SIZE),
  });
  if (!state) {
    return false;
  }
  return state.fetchStatus === 'fetching' || state.status === 'pending';
}

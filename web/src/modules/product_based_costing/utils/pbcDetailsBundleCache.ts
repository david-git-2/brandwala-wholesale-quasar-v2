import type { InfiniteData, QueryClient } from '@tanstack/vue-query';
import {
  PBC_ITEMS_PAGE_SIZE,
  productBasedCostingQueryKeys,
} from '../shared/queryKeys/productBasedCostingQueryKeys';
import type {
  PbcFileDetailsBundlePage,
  PbcItemProductCatalog,
  ProductBasedCostingFile,
  ProductBasedCostingFileListPage,
} from '../types';

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

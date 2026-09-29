import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref } from 'vue';
import { productRepository } from '../repositories/productRepository';
import { productsQueryKeys } from '../shared/queryKeys/productsQueryKeys';
import type { Product, ProductListCursor } from '../types';

const PRODUCTS_LIST_PAGE_SIZE = 20;

export interface ProductsQueryParams {
  pageSize?: number;
  cursor?: ProductListCursor | null;
  search?: string | null;
  searchField?: 'name' | 'barcode' | 'product_code' | 'id';
  category?: string | null;
  brand?: string | null;
  sortPrice?: 'asc' | 'desc';
  tenantId?: number | null;
  vendorCode?: string | null;
  marketCode?: string | null;
  isAvailable?: boolean | null;
}

export interface ProductLookupQueryParams {
  vendorCode?: string | null;
  tenantId?: number | null;
}

export function useProductsListQuery(params: Ref<ProductsQueryParams> | ComputedRef<ProductsQueryParams>) {
  return useQuery({
    queryKey: computed(() => productsQueryKeys.list(params.value)),
    queryFn: () => productRepository.listProducts(params.value),
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
  });
}

export type ProductsInfiniteListParams = Omit<ProductsQueryParams, 'cursor'>;

export function useProductsInfiniteListQuery(
  params: Ref<ProductsInfiniteListParams> | ComputedRef<ProductsInfiniteListParams>,
) {
  const query = useInfiniteQuery({
    queryKey: computed(() => productsQueryKeys.list(params.value)),
    queryFn: async ({ pageParam }) =>
      productRepository.listProducts({
        ...params.value,
        pageSize: params.value.pageSize ?? PRODUCTS_LIST_PAGE_SIZE,
        cursor: (pageParam as ProductListCursor | null) ?? null,
      }),
    getNextPageParam: (lastPage) =>
      lastPage.meta.has_more && lastPage.meta.next_cursor ? lastPage.meta.next_cursor : undefined,
    initialPageParam: null as ProductListCursor | null,
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
  });

  const products = computed<Product[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const rows: Product[] = [];
    for (const page of pages) {
      for (const product of page.data) {
        if (!seen.has(product.id)) {
          seen.add(product.id);
          rows.push(product);
        }
      }
    }
    return rows;
  });

  const hasMore = computed(() => query.hasNextPage.value ?? false);

  return {
    ...query,
    products,
    hasMore,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    isFetchingNextPage: query.isFetchingNextPage,
    error: query.error,
    fetchNextPage: query.fetchNextPage,
  };
}

export function useProductBrandsQuery(params: Ref<ProductLookupQueryParams> | ComputedRef<ProductLookupQueryParams>) {
  return useQuery({
    queryKey: computed(() => productsQueryKeys.brands(params.value)),
    queryFn: () => productRepository.listBrands(params.value),
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => params.value.tenantId !== null && params.value.tenantId !== undefined),
  });
}

export function useProductCategoriesQuery(params: Ref<ProductLookupQueryParams> | ComputedRef<ProductLookupQueryParams>) {
  return useQuery({
    queryKey: computed(() => productsQueryKeys.categories(params.value)),
    queryFn: () => productRepository.listCategories(params.value),
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => params.value.tenantId !== null && params.value.tenantId !== undefined),
  });
}

export function useProductDetailQuery(id: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => productsQueryKeys.detail(id.value!)),
    queryFn: () => productRepository.getProductById(id.value!),
    enabled: computed(() => id.value !== null && id.value !== undefined && !isNaN(Number(id.value))),
    staleTime: 5 * 60 * 1000,
  });
}

import { keepPreviousData, useQuery } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref } from 'vue';
import { productRepository } from '../repositories/productRepository';
import { productsQueryKeys } from '../shared/queryKeys/productsQueryKeys';

export interface ProductsQueryParams {
  page?: number;
  pageSize?: number;
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

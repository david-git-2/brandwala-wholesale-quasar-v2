import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { productRepository } from '../repositories/productRepository';
import { productsQueryKeys } from '../shared/queryKeys/productsQueryKeys';
import type {
  ProductBrandCreateInput,
  ProductCategoryCreateInput,
  ProductCreateInput,
  ProductUpdateInput,
} from '../types';

export function useCreateProductMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: ProductCreateInput) => productRepository.createProduct(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: productsQueryKeys.lists() });
    },
  });
}

export function useUpdateProductMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: ProductUpdateInput) => productRepository.updateProduct(input),
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({ queryKey: productsQueryKeys.lists() });
      void queryClient.invalidateQueries({ queryKey: productsQueryKeys.detail(variables.id) });
    },
  });
}

export function useDeleteProductMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => productRepository.deleteProduct({ id }),
    onSuccess: (_, id) => {
      void queryClient.invalidateQueries({ queryKey: productsQueryKeys.lists() });
      queryClient.removeQueries({ queryKey: productsQueryKeys.detail(id) });
    },
  });
}

export function useCreateProductBrandMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: ProductBrandCreateInput) => productRepository.createProductBrand(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [...productsQueryKeys.all, 'brands'] });
    },
  });
}

export function useCreateProductCategoryMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: ProductCategoryCreateInput) => productRepository.createProductCategory(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [...productsQueryKeys.all, 'categories'] });
    },
  });
}

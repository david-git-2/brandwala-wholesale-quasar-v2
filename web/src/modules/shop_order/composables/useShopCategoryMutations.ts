import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { shopCategoryRepository } from '../repositories/shopCategoryRepository';
import type { CreateShopCategoryPayload, UpdateShopCategoryPayload } from '../types';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useCreateShopCategoryMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: CreateShopCategoryPayload) => shopCategoryRepository.createCategory(input),
    onSuccess: async (_, variables) => {
      await queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.categories(variables.tenant_id),
      });
    },
  });
}

export function useUpdateShopCategoryMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: UpdateShopCategoryPayload) => shopCategoryRepository.updateCategory(input),
    onSuccess: async (_, variables) => {
      await queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.categories(variables.tenant_id),
      });
    },
  });
}

export function useDeleteShopCategoryMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: { id: number; tenantId: number }) =>
      shopCategoryRepository.deleteCategory(input.id, input.tenantId),
    onSuccess: async (_, variables) => {
      await queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.categories(variables.tenantId),
      });
    },
  });
}

import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { shopCategoryRepository } from '../repositories/shopCategoryRepository';
import type { CreateShopCategoryPayload, UpdateShopCategoryPayload } from '../types';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { invalidateTenantSetupLookups } from '../utils/tenantSetupLookupCache';

export function useCreateShopCategoryMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: CreateShopCategoryPayload) => shopCategoryRepository.createCategory(input),
    onSuccess: async (_, variables) => {
      await queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.categories(variables.tenant_id),
      });
      invalidateTenantSetupLookups(queryClient, variables.tenant_id);
      await queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.shopSetupBundleRoot() });
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
      invalidateTenantSetupLookups(queryClient, variables.tenant_id);
      await queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.shopSetupBundleRoot() });
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
      invalidateTenantSetupLookups(queryClient, variables.tenantId);
      await queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.shopSetupBundleRoot() });
    },
  });
}

import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useRecalcShopDisplayQuantitiesMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (shopId: number) => shopOrderRepository.recalcShopDisplayQuantities(shopId),
    onSuccess: (updatedCount, shopId) => {
      void queryClient.invalidateQueries({
        queryKey: ['shopOrder', 'storefrontAdminListings', { shopId }],
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(shopId),
      });
      showSuccessNotification(
        updatedCount > 0
          ? `Updated display quantity for ${updatedCount} listing(s).`
          : 'No unlocked listings were updated.',
      );
    },
    onError: (error: Error) => {
      showErrorNotification(error.message || 'Failed to recalculate display quantities.');
    },
  });
}

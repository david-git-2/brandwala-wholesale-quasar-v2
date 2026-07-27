import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { showWarningDialog, showSuccessNotification } from 'src/utils/appFeedback';
import { shopPricingRepository } from '../repositories/shopPricingRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { UpsertListingPayload, UpsertShopPricingRulePayload } from '../types';

export function useSaveShopListingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: UpsertListingPayload) => shopPricingRepository.upsertListing(payload),
    onSuccess: (data, payload) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(payload.shop_id),
      });
      void queryClient.invalidateQueries({
        queryKey: ['shop_order', 'pricing_candidates'],
      });
      showSuccessNotification('Shop product listing saved successfully.');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to save product listing.', 'Save Failed');
    },
  });
}

export function useSaveShopPricingRuleMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: UpsertShopPricingRulePayload) =>
      shopPricingRepository.upsertPricingRule(payload),
    onSuccess: (data, payload) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingRule(payload.shop_id),
      });
      showSuccessNotification('Shop pricing rule updated successfully.');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to save pricing rule.', 'Save Failed');
    },
  });
}

export function useBulkApplyShopMarkupMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      shopId,
      markupAmount,
      markupType,
      targetPrice,
      listingIds,
    }: {
      shopId: number;
      markupAmount?: number;
      markupType?: 'percentage' | 'fixed';
      targetPrice?: 'sell_price' | 'min_sell_price';
      listingIds?: number[];
    }) => shopPricingRepository.bulkApplyMarkup(shopId, markupAmount, markupType, targetPrice, listingIds),
    onSuccess: (count, variables) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(variables.shopId),
      });
      showSuccessNotification(`Markup applied to ${count} listing(s) successfully.`);
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to bulk apply markup.', 'Apply Failed');
    },
  });
}

export function useDeleteShopListingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ listingId, tenantId }: { listingId: number; tenantId: number; shopId: number }) =>
      shopPricingRepository.deleteListing(listingId, tenantId),
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(variables.shopId),
      });
      void queryClient.invalidateQueries({
        queryKey: ['shop_order', 'pricing_candidates'],
      });
      showSuccessNotification('Product listing removed successfully.');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to remove product listing.', 'Delete Failed');
    },
  });
}

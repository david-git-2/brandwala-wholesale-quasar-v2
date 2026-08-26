import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { showErrorNotification, showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import { shopPricingRepository } from '../repositories/shopPricingRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type {
  ShopCatalogStockGrade,
  ShopStorefrontAdminListing,
  ShopStorefrontAdminListingsResult,
  UpsertListingPayload,
} from '../types';
import type { Product } from 'src/modules/products/types';
import type { CandidateAllocation } from '../types/pricing';

type StorefrontListingsCache = ShopStorefrontAdminListingsResult | undefined;

const patchStorefrontListingsCache = (
  queryClient: ReturnType<typeof useQueryClient>,
  shopId: number,
  search: string | null,
  updater: (current: ShopStorefrontAdminListingsResult) => ShopStorefrontAdminListingsResult,
) => {
  const key = shopOrderQueryKeys.storefrontAdminListings(shopId, search);
  queryClient.setQueryData<StorefrontListingsCache>(key, (current) => {
    if (!current) return current;
    return updater(current);
  });
};

export function useToggleShopStorefrontListingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: UpsertListingPayload) => shopPricingRepository.upsertListing(payload),
    onSuccess: (_data, payload) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(payload.shop_id),
      });
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to update listing status.', 'Update Failed');
    },
  });
}

export function useDeleteShopStorefrontListingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      listingId,
      tenantId,
    }: {
      listingId: number;
      tenantId: number;
      shopId: number;
      search: string | null;
    }) => shopPricingRepository.deleteListing(listingId, tenantId),
    onSuccess: (_, variables) => {
      patchStorefrontListingsCache(
        queryClient,
        variables.shopId,
        variables.search,
        (current) => ({
          ...current,
          data: current.data.filter((row) => row.listing_id !== variables.listingId),
          meta: {
            ...current.meta,
            total: Math.max(0, current.meta.total - 1),
          },
        }),
      );
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(variables.shopId),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingCandidates(variables.tenantId, variables.shopId),
      });
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to remove product listing.', 'Delete Failed');
    },
  });
}

export function useCopyShopStorefrontGradeMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      shopId,
      tenantId,
      source,
      grade,
    }: {
      shopId: number;
      tenantId: number;
      source: ShopStorefrontAdminListing;
      grade: ShopCatalogStockGrade;
    }) => {
      const candidates = await shopPricingRepository.listCandidateAllocations(tenantId, shopId);
      const match = candidates.find(
        (row) => row.product_id === source.product_id && row.stock_grade?.slug === grade.slug,
      );

      if (!match?.global_stock_id) {
        throw new Error('No listable stock found for this product and grade.');
      }

      const sellAmount = Number(source.sell_price?.amount ?? source.sell_price_amount ?? 0);
      const sellCurrencyId =
        source.sell_price?.currency_id ?? source.sell_price_currency_id ?? 0;

      const payload: UpsertListingPayload = {
        tenant_id: tenantId,
        shop_id: shopId,
        global_stock_id: match.global_stock_id,
        sell_price_amount: sellAmount,
        sell_price_currency_id: sellCurrencyId,
        minimum_sell_price_amount: source.minimum_sell_price_amount ?? null,
        minimum_sell_price_currency_id: source.minimum_sell_price_currency_id ?? null,
        show_quantity: source.show_quantity ?? true,
        display_quantity_override: source.display_quantity_override ?? null,
        is_active: true,
      };

      return shopPricingRepository.upsertListing(payload);
    },
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['shopOrder', 'storefrontAdminListings', { shopId: variables.shopId }],
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(variables.shopId),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingCandidates(variables.tenantId, variables.shopId),
      });
    },
    onError: (error: Error) => {
      showErrorNotification(error.message || 'Failed to copy listing for grade.');
    },
  });
}

export function patchStorefrontListingActive(
  queryClient: ReturnType<typeof useQueryClient>,
  shopId: number,
  search: string | null,
  listingId: number,
  isActive: boolean,
) {
  patchStorefrontListingsCache(queryClient, shopId, search, (current) => ({
    ...current,
    data: current.data.map((row) =>
      row.listing_id === listingId
        ? { ...row, listing_status: isActive ? 'active' : 'inactive' }
        : row,
    ),
  }));
}

export function useSaveShopStorefrontListingPricingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: UpsertListingPayload) => shopPricingRepository.upsertListing(payload),
    onSuccess: (_data, payload) => {
      void queryClient.invalidateQueries({
        queryKey: ['shopOrder', 'storefrontAdminListings', { shopId: payload.shop_id }],
      });
      if (payload.id) {
        void queryClient.invalidateQueries({
          queryKey: shopOrderQueryKeys.storefrontListingPriceCalc(payload.shop_id, payload.id),
        });
      }
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(payload.shop_id),
      });
      showSuccessNotification('Listing pricing saved.');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to save listing pricing.', 'Save Failed');
    },
  });
}

const roundNearest5or0 = (val: number): number => {
  if (!val || val <= 0) return 0;
  return Math.round(val / 5) * 5;
};

const roundNearest50or100 = (val: number): number => {
  if (!val || val <= 0) return 0;
  return Math.round(val / 50) * 50;
};

export function useAddShopStorefrontListingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (
      input:
        | {
            mode: 'stock';
            shopId: number;
            tenantId: number;
            stock: CandidateAllocation;
            sellCurrencyId: number;
            shopType: 'fixed_price' | 'dropship' | 'vendor_catalog';
            markupPercentage: number;
            dropshipMarkupPercentage: number;
          }
        | {
            mode: 'product';
            shopId: number;
            tenantId: number;
            product: Pick<Product, 'id' | 'list_price_amount' | 'reference_cost_amount'>;
            sellCurrencyId: number;
          },
    ) => {
      if (input.mode === 'product') {
        const sellAmount = Number(
          input.product.list_price_amount ?? input.product.reference_cost_amount ?? 0,
        );
        const payload: UpsertListingPayload = {
          tenant_id: input.tenantId,
          shop_id: input.shopId,
          product_id: input.product.id,
          global_stock_id: null,
          sell_price_amount: Number.isFinite(sellAmount) ? sellAmount : 0,
          sell_price_currency_id: input.sellCurrencyId,
          minimum_sell_price_amount: null,
          minimum_sell_price_currency_id: null,
          show_quantity: true,
          display_quantity_override: null,
          is_active: false,
        };
        return shopPricingRepository.upsertListing(payload);
      }

      const { stock, shopType, markupPercentage, dropshipMarkupPercentage, sellCurrencyId } = input;
      const unitCost = Number(stock.unit_cost_amount ?? 0);
      const sellMarkupPct = Number(markupPercentage ?? 0);
      const dropshipMarkupPct = Number(dropshipMarkupPercentage ?? 0);
      const rawSell = unitCost > 0 ? unitCost * (1 + sellMarkupPct / 100) : 0;
      const calculatedSell = rawSell > 0 ? roundNearest5or0(rawSell) : 0;
      const rawFloor = unitCost > 0 ? unitCost * (1 + dropshipMarkupPct / 100) : 0;
      const calculatedFloor = rawFloor > 0 ? roundNearest50or100(rawFloor) : null;

      const payload: UpsertListingPayload = {
        tenant_id: input.tenantId,
        shop_id: input.shopId,
        global_stock_id: stock.global_stock_id,
        sell_price_amount: calculatedSell,
        sell_price_currency_id: sellCurrencyId,
        minimum_sell_price_amount:
          shopType === 'dropship' ? calculatedFloor : null,
        minimum_sell_price_currency_id:
          shopType === 'dropship' ? sellCurrencyId : null,
        show_quantity: true,
        display_quantity_override: null,
        is_active: true,
      };

      return shopPricingRepository.upsertListing(payload);
    },
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['shopOrder', 'storefrontAdminListings', { shopId: variables.shopId }],
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingListings(variables.shopId),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.pricingCandidates(variables.tenantId, variables.shopId),
      });
    },
  });
}

import { useInfiniteQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import type { Shop, ShopCatalogListCursor, ShopCatalogStorefrontProduct } from '../types';

const PAGE_SIZE = 24;

type AdminCatalogRow = {
  product_id: number;
  product_name: string;
  product_image_url: string | null;
  product_barcode: string | null;
  product_brand: string | null;
  vendor_code: string | null;
  country_of_origin: string | null;
  batch_code_manufacture_date: string | null;
  expire_date: string | null;
  languages: string | null;
  available_units: number | null;
  unit_price_amount: number | string | null;
  unit_price_currency_id: number | null;
  unit_price_currency_code?: string | null;
  unit_price_currency_symbol?: string | null;
};

function rowToCatalogStorefrontProduct(row: AdminCatalogRow): ShopCatalogStorefrontProduct {
  return {
    product_id: row.product_id,
    product_name: row.product_name ?? '',
    product_image_url: row.product_image_url,
    product_brand: row.product_brand,
    product_barcode: row.product_barcode,
    vendor_code: row.vendor_code,
    country_of_origin: row.country_of_origin,
    batch_code_manufacture_date: row.batch_code_manufacture_date,
    expire_date: row.expire_date,
    available_units: row.available_units,
    languages: row.languages,
    unit_price_amount: row.unit_price_amount,
    unit_price_currency_id: row.unit_price_currency_id,
    unit_price_currency_code: row.unit_price_currency_code ?? null,
    unit_price_currency_symbol: row.unit_price_currency_symbol ?? null,
  };
}

export function useShopCatalogStorefrontInfiniteQuery(
  tenantId: Ref<number | null | undefined>,
  shop: Ref<Shop | null | undefined>,
  search: Ref<string | null>,
  enabled: Ref<boolean>,
  showAllProducts?: Ref<boolean>,
) {
  const vendorFilters = computed(() => shop.value?.vendor_filters ?? null);
  const hasVendorFilters = computed(() => {
    const filters = vendorFilters.value;
    if (Array.isArray(filters) && filters.length > 0) {
      return filters.some((f) => Boolean(f.vendor_code?.trim()));
    }
    return Boolean(shop.value?.vendor_code?.trim());
  });
  const minAvailableUnits = computed(() => shop.value?.min_available_units ?? 0);
  const applyMinAvailableUnits = computed(
    () => !showAllProducts?.value && (minAvailableUnits.value ?? 0) > 0,
  );
  const searchParam = computed(() => search.value?.trim() || null);

  const query = useInfiniteQuery({
    queryKey: computed(() => [
      'shopOrder',
      'catalogStorefront',
      {
        tenantId: tenantId.value ?? 0,
        shopId: shop.value?.id ?? 0,
        search: searchParam.value,
        minAvailableUnits: minAvailableUnits.value,
        showAllProducts: showAllProducts?.value ?? false,
      },
    ]),
    queryFn: async ({ pageParam }) => {
      const result = await shopOrderRepository.browseShopCatalogForAdmin(
        tenantId.value!,
        shop.value!.id,
        {
          search: searchParam.value,
          limit: PAGE_SIZE,
          cursor: (pageParam as ShopCatalogListCursor | null) ?? null,
          includeBelowMinUnits: showAllProducts?.value ?? false,
        },
      );

      const rows = (result.data ?? []) as AdminCatalogRow[];

      return {
        items: rows.map(rowToCatalogStorefrontProduct),
        hasMore: result.meta?.has_more ?? false,
        nextCursor: result.meta?.next_cursor ?? null,
      };
    },
    getNextPageParam: (lastPage) =>
      lastPage.hasMore && lastPage.nextCursor ? lastPage.nextCursor : undefined,
    initialPageParam: null as ShopCatalogListCursor | null,
    staleTime: 30 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(
      () =>
        enabled.value &&
        hasVendorFilters.value &&
        !!tenantId.value &&
        tenantId.value > 0 &&
        !!shop.value?.id,
    ),
  });

  const catalogItems = computed(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const items: ShopCatalogStorefrontProduct[] = [];

    for (const page of pages) {
      for (const item of page.items) {
        if (seen.has(item.product_id)) continue;
        seen.add(item.product_id);
        items.push(item);
      }
    }

    return items;
  });

  return {
    ...query,
    catalogItems,
    hasVendorFilters,
    minAvailableUnits,
    applyMinAvailableUnits,
  };
}

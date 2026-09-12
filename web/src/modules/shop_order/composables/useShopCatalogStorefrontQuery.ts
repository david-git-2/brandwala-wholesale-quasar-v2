import { useInfiniteQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import type { Shop, ShopCatalogStorefrontProduct } from '../types';

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
  const hasVendorFilters = computed(() => (vendorFilters.value?.length ?? 0) > 0);
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
    queryFn: async ({ pageParam = 0 }) => {
      const offset = pageParam as number;
      const result = await shopOrderRepository.browseShopCatalogForAdmin(
        tenantId.value!,
        shop.value!.id,
        {
          search: searchParam.value,
          limit: PAGE_SIZE,
          offset,
          includeBelowMinUnits: showAllProducts?.value ?? false,
        },
      );

      const rows = (result.data ?? []) as AdminCatalogRow[];

      const total = Number(result.meta?.total ?? 0);

      return {
        items: rows.map(rowToCatalogStorefrontProduct),
        total: Number.isFinite(total) ? total : 0,
        pageSize: result.meta?.page_size ?? PAGE_SIZE,
        nextOffset: offset + rows.length,
      };
    },
    getNextPageParam: (lastPage) => {
      if (lastPage.nextOffset < lastPage.total && lastPage.items.length > 0) {
        return lastPage.nextOffset;
      }
      return undefined;
    },
    initialPageParam: 0,
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

  const totalItems = computed(() => query.data.value?.pages?.[0]?.total ?? 0);

  return {
    ...query,
    catalogItems,
    totalItems,
    hasVendorFilters,
    minAvailableUnits,
    applyMinAvailableUnits,
  };
}

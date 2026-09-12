<template>
  <component
    :is="embedded ? 'div' : 'q-page'"
    :class="embedded ? 'catalog-storefront-embed' : 'bw-page'"
  >
    <section :class="embedded ? 'catalog-storefront-embed__stack' : 'bw-page__stack'">
      <q-banner
        v-if="!hasVendorFilters"
        rounded
        class="bg-amber-1 text-amber-10"
        data-test="catalog-storefront-no-vendors"
      >
        {{ $t('shop_admin.vendor_required_to_publish') }}
      </q-banner>

      <section v-else class="column q-gutter-y-sm">
        <div class="row items-center q-col-gutter-sm no-wrap">
          <div class="col min-width-0">
            <q-input
              v-model="search"
              clearable
              dense
              outlined
              :placeholder="$t('shop_admin.storefront_search_placeholder')"
              data-test="catalog-storefront-search"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
        </div>

        <q-toggle
          v-if="minAvailableUnits > 0"
          v-model="showAllProducts"
          dense
          :label="$t('shop_admin.catalog_storefront_show_all_products')"
          data-test="catalog-storefront-show-all"
        />
      </section>

      <div
        v-if="hasVendorFilters && active"
        class="theme-shop catalog-storefront-preview relative-position"
      >
        <q-inner-loading :showing="isLoading && catalogItems.length === 0" color="primary" />

        <div
          v-if="catalogItems.length > 0"
          class="catalog-storefront-body"
        >
          <div class="row q-col-gutter-md catalog-storefront-grid">
            <div
              v-for="item in catalogItems"
              :key="item.product_id"
              class="col-12 col-sm-6 col-md-4 catalog-storefront-grid-item"
            >
              <ShopCatalogStorefrontCard :item="item" :format-money="formatMoney" />
            </div>
          </div>

          <div v-if="hasNextPage" class="catalog-storefront-load-more row justify-center">
            <q-btn
              outline
              color="primary"
              :label="$t('shop_admin.storefront_load_more')"
              :loading="isFetchingNextPage"
              :disable="isFetchingNextPage"
              data-test="catalog-storefront-load-more"
              @click="onLoadMore"
            />
          </div>
        </div>

        <div
          v-else-if="isError"
          class="column items-center justify-center catalog-storefront-empty q-pa-xl text-center"
        >
          <q-icon name="ph ph-warning-circle" size="64px" color="negative" class="q-mb-md" />
          <div class="text-body1 text-grey-8">
            {{ error?.message || $t('shop_admin.storefront_load_failed') }}
          </div>
        </div>

        <div
          v-else-if="!isLoading"
          class="column items-center justify-center catalog-storefront-empty q-pa-xl text-center"
        >
          <q-icon name="ph ph-tote" size="64px" color="grey-5" class="q-mb-md" />
          <div class="text-h6 text-weight-bold text-grey-8">
            {{ $t('shop_admin.storefront_no_products') }}
          </div>
        </div>
      </div>
    </section>
  </component>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import ShopCatalogStorefrontCard from 'src/modules/shop_order/components/ShopCatalogStorefrontCard.vue';
import { useShopCatalogStorefrontInfiniteQuery } from '../composables/useShopCatalogStorefrontQuery';
import type { Shop } from '../types';

const props = withDefaults(
  defineProps<{
    embedded?: boolean;
    shop: Shop | null;
    tenantId: number;
    active?: boolean;
  }>(),
  {
    embedded: false,
    shop: null,
    active: true,
  },
);

const search = ref('');
const showAllProducts = ref(false);
const shopRef = computed(() => props.shop);
const tenantIdRef = computed(() => props.tenantId);
const isActive = computed(() => props.active);

const {
  catalogItems,
  hasVendorFilters,
  isLoading,
  isError,
  error,
  isFetchingNextPage,
  hasNextPage,
  fetchNextPage,
  minAvailableUnits,
} = useShopCatalogStorefrontInfiniteQuery(
  tenantIdRef,
  shopRef,
  search,
  isActive,
  showAllProducts,
);

const onLoadMore = () => {
  if (!hasNextPage.value || isFetchingNextPage.value) return;
  void fetchNextPage();
};

const formatMoney = (amount: unknown, symbol?: string | null) => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '—';
  const sym = symbol?.trim() || '৳';
  const formatted = n.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${sym} ${formatted}`;
};

</script>

<style scoped>
.catalog-storefront-embed,
.catalog-storefront-embed__stack,
.catalog-storefront-preview,
.catalog-storefront-body {
  height: auto;
  min-height: 0;
}

.catalog-storefront-embed__stack {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.catalog-storefront-load-more {
  padding-top: 16px;
  padding-bottom: 0;
}

.catalog-storefront-grid {
  margin-bottom: 0 !important;
}

@media (min-width: 600px) {
  .catalog-storefront-grid {
    display: grid !important;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 16px;
    margin: 0 !important;
  }

  .catalog-storefront-grid-item {
    width: 100% !important;
    max-width: none !important;
    padding: 0 !important;
  }
}

.catalog-storefront-empty {
  min-height: 280px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 60%, transparent);
  border-radius: 16px;
  border: 1px dashed var(--bw-theme-border, rgba(34, 56, 101, 0.12));
}
</style>

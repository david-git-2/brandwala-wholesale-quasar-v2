<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">{{ $t('shop_admin.shop_and_order') }}</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Shop Pricing & Dropship Stores</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Select a store below to manage product listings, sell prices, markups, and stock overrides.
          </p>
        </div>
      </section>

      <!-- Filters / Search -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm-5">
            <q-input
              v-model="search"
              clearable
              debounce="300"
              dense
              outlined
              placeholder="Search stores..."
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-auto">
            <q-btn-toggle
              v-model="typeFilter"
              dense
              no-caps
              rounded
              unelevated
              toggle-color="primary"
              :options="filterOptions"
            />
          </div>
        </div>
      </q-card>

      <!-- Error banner -->
      <q-banner v-if="isError" class="text-white bg-negative" rounded>
        {{ error?.message || 'Failed to load shops' }}
      </q-banner>

      <!-- Loading State -->
      <div v-if="isLoading" class="row q-col-gutter-md">
        <div v-for="n in 6" :key="n" class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="60%" height="24px" class="q-mb-sm" />
            <q-skeleton type="text" width="40%" height="16px" class="q-mb-md" />
            <q-skeleton type="rect" height="36px" />
          </q-card>
        </div>
      </div>

      <!-- Empty State -->
      <q-card v-else-if="filteredShops.length === 0" flat bordered class="text-center q-pa-xl">
        <q-icon name="ph ph-storefront" size="48px" class="text-grey-5 q-mb-sm block" />
        <div class="text-h6 text-grey-7">No shops found</div>
        <div class="text-caption text-grey-6">
          {{ typeFilter === 'dropship' ? 'No dropship stores are available for pricing.' : 'No shops match your criteria.' }}
        </div>
      </q-card>

      <!-- Shops Grid -->
      <div v-else class="row q-col-gutter-md">
        <div v-for="shop in filteredShops" :key="shop.id" class="col-12 col-sm-6 col-md-4">
          <q-card
            flat
            bordered
            class="shop-pricing-card cursor-pointer"
            @click="goToShopPricing(shop.id)"
          >
            <q-card-section class="q-pb-sm">
              <div class="row items-center justify-between no-wrap q-mb-xs">
                <div class="text-subtitle1 text-weight-bold ellipsis text-grey-9">
                  {{ shop.name }}
                </div>
                <q-chip
                  dense
                  size="sm"
                  :color="shopTypeColor(shop.shop_type)"
                  text-color="white"
                  class="text-weight-bold q-ml-sm shrink-0"
                >
                  {{ shopTypeLabel(shop.shop_type) }}
                </q-chip>
              </div>
              <div class="text-caption text-grey-6 ellipsis">
                Slug: {{ shop.slug }}
              </div>
            </q-card-section>

            <q-separator />

            <q-card-section class="row items-center justify-between py-sm text-caption">
              <div class="row items-center text-grey-7">
                <q-icon
                  :name="shop.is_active ? 'ph ph-check-circle' : 'ph ph-x-circle'"
                  :color="shop.is_active ? 'positive' : 'grey-5'"
                  class="q-mr-xs"
                />
                {{ shop.is_active ? 'Active' : 'Inactive' }}
              </div>
              <q-btn
                flat
                dense
                no-caps
                color="primary"
                icon-right="ph ph-arrow-right"
                label="Manage Pricing"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopListQuery } from '../composables/useShopQuery';
import type { Shop, ShopType } from '../types';

const router = useRouter();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const search = ref('');
const typeFilter = ref<'all' | 'dropship' | 'fixed_price' | 'vendor_catalog'>('dropship');

const filterOptions = [
  { label: 'Dropship Stores', value: 'dropship' },
  { label: 'All Shops', value: 'all' },
  { label: 'Vendor Catalog', value: 'vendor_catalog' },
  { label: 'Fixed Price', value: 'fixed_price' },
];

const queryParams = computed(() => ({
  tenantId: tenantId.value,
  search: search.value.trim() || null,
}));

const { data: shops, isLoading, isError, error } = useShopListQuery(queryParams);

const filteredShops = computed(() => {
  if (!shops.value) return [];
  if (typeFilter.value === 'all') return shops.value;
  return shops.value.filter((s: Shop) => s.shop_type === typeFilter.value);
});

const goToShopPricing = (shopId: number) => {
  void router.push({
    name: 'app-shop-pricing-page',
    params: {
      tenantSlug: tenantSlug.value,
      shopId: String(shopId),
    },
  });
};

const shopTypeLabel = (type: ShopType) => {
  const map: Record<ShopType, string> = {
    vendor_catalog: 'Vendor Catalog',
    fixed_price: 'Fixed Price',
    dropship: 'Dropship',
  };
  return map[type] ?? type;
};

const shopTypeColor = (type: ShopType) => {
  const map: Record<ShopType, string> = {
    vendor_catalog: 'indigo',
    fixed_price: 'teal',
    dropship: 'deep-orange',
  };
  return map[type] ?? 'grey';
};
</script>

<style scoped lang="scss">
.shop-pricing-card {
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  }
}
</style>

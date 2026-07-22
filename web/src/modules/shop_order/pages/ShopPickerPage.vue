<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Shop Scope</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Select Wholesale Shop</h1>
        </div>
        <div class="col-auto">
          <q-btn color="primary" unelevated no-caps class="pill-btn" label="View All Products" @click="goBrowseAll" />
        </div>
      </section>

      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-xs-12 col-sm-6 col-md-4">
            <q-input
              v-model="search"
              filled
              dense
              class="soft-input"
              placeholder="Search shops..."
              clearable
            >
              <template #prepend>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>
          <div class="col-xs-12 col-sm-6 col-md-3">
            <q-select
              v-model="selectedType"
              filled
              dense
              options-dense
              emit-value
              map-options
              class="soft-input"
              :options="shopTypeOptions"
            />
          </div>
        </div>
      </q-card>

      <div v-if="loading" class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <q-banner v-else-if="error" class="bg-negative text-white" rounded>
        {{ error }}
      </q-banner>

      <div
        v-else-if="filteredShops.length === 0"
        class="column items-center justify-center q-pa-xl text-center text-grey-6"
      >
        <q-icon name="storefront" size="64px" color="grey-4" class="q-mb-md" />
        <div class="text-h6">{{ $t('shop_admin.no_shops_available') }}</div>
        <p class="text-body2 text-grey-5 q-mb-none">
          {{ $t('shop_admin.no_shops_access') }}
        </p>
      </div>

      <div v-else class="row q-col-gutter-md">
        <div v-for="shop in filteredShops" :key="shop.id" class="col-12 col-sm-6 col-md-4">
          <q-card
            flat
            bordered
            class="shop-card cursor-pointer relative-position"
            :class="{ 'shop-card--last-visited': String(shop.id) === lastVisitedShopId }"
            @click="openShop(shop)"
          >
            <q-card-section>
              <div class="row items-start no-wrap q-gutter-sm">
                <q-avatar color="primary-1" text-color="primary" icon="storefront" size="40px" />
                <div class="col">
                  <div class="row items-center gap-xs">
                    <div class="text-subtitle1 text-weight-bold text-grey-9">{{ shop.name }}</div>
                    <q-badge
                      v-if="String(shop.id) === lastVisitedShopId"
                      color="primary"
                      outline
                      class="q-px-xs text-caption"
                    >
                      Last Visited
                    </q-badge>
                  </div>
                  <div class="text-caption text-grey-6">/{{ shop.slug }}</div>
                </div>
                <q-icon name="chevron_right" color="grey-5" class="q-mt-xs" />
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderService } from '../services/shopOrderService';
import type { CustomerAccessibleShop } from '../repositories/shopOrderRepository';

const authStore = useAuthStore();
const router = useRouter();
const { t } = useI18n();

const shops = ref<CustomerAccessibleShop[]>([]);
const loading = ref(true);
const error = ref<string | null>(null);
const lastVisitedShopId = ref<string | null>(null);
const search = ref('');
const selectedType = ref<string | null>(null);

const shopTypeOptions = computed(() => [
  { label: 'All Shop Types', value: null },
  { label: 'Fixed Price', value: 'fixed_price' },
  { label: 'Vendor Catalog', value: 'vendor_catalog' },
  { label: 'Dropship Portal', value: 'dropship' },
]);

const filteredShops = computed(() => {
  return shops.value.filter((s) => {
    const matchesSearch = !search.value || s.name.toLowerCase().includes(search.value.toLowerCase()) || s.slug.toLowerCase().includes(search.value.toLowerCase());
    const matchesType = !selectedType.value || s.shop_type === selectedType.value;
    return matchesSearch && matchesType;
  });
});

const goBrowseAll = () => {
  const tenantSlug = authStore.tenantSlug;
  const targetShop = shops.value[0];
  if (targetShop) {
    void router.push(
      tenantSlug ? `/${tenantSlug}/shop/browse/${targetShop.slug}` : `/shop/browse/${targetShop.slug}`,
    );
  }
};

const openShop = (shop: CustomerAccessibleShop) => {
  localStorage.setItem('last_visited_shop_id', String(shop.id));
  localStorage.setItem('last_visited_shop_slug', shop.slug);
  const tenantSlug = authStore.tenantSlug;
  void router.push(
    tenantSlug ? `/${tenantSlug}/shop/browse/${shop.slug}` : `/shop/browse/${shop.slug}`,
  );
};

onMounted(async () => {
  lastVisitedShopId.value = localStorage.getItem('last_visited_shop_id');
  loading.value = true;
  error.value = null;
  const result = await shopOrderService.listShopsForCustomer(authStore.tenantId);
  loading.value = false;

  if (!result.success) {
    error.value = result.error ?? t('shop_admin.failed_load_shops');
    return;
  }

  shops.value = result.data ?? [];

  const onlyShop = shops.value[0];
  if (shops.value.length === 1 && onlyShop) {
    openShop(onlyShop);
  }
});
</script>

<style scoped>
.shop-card {
  border-radius: 12px;
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease, border-color 0.2s ease;
}

.shop-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.06);
  border-color: var(--q-primary);
}

.shop-card--last-visited {
  border-color: var(--q-primary);
  background-color: rgba(var(--q-primary-rgb, 25, 118, 210), 0.02);
}

.gap-xs {
  gap: 6px;
}
</style>

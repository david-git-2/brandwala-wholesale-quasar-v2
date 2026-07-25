<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Shop Scope</div>
          <h1 class="text-h5 text-weight-bold q-my-none">
            Select {{ tenantName }} Shop
          </h1>
        </div>
      </section>

      <div v-if="isLoading" class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <q-banner v-else-if="isError" class="bg-negative text-white" rounded>
        {{ error?.message || $t('shop_admin.failed_load_shops') }}
      </q-banner>

      <div
        v-else-if="shops.length === 0"
        class="column items-center justify-center q-pa-xl text-center text-grey-6"
      >
        <q-icon name="ph ph-storefront" size="64px" color="grey-4" class="q-mb-md" />
        <div class="text-h6">{{ $t('shop_admin.no_shops_available') }}</div>
        <p class="text-body2 text-grey-5 q-mb-none">
          {{ $t('shop_admin.no_shops_access') }}
        </p>
      </div>

      <div v-else class="row q-col-gutter-md q-mt-md">
        <div v-for="shop in shops" :key="shop.id" class="col-12 col-sm-6 col-md-4">
          <q-card
            flat
            bordered
            class="shop-card cursor-pointer relative-position column justify-between full-height"
            :class="{ 'shop-card--last-visited': String(shop.id) === lastVisitedShopId }"
            @click="openShop(shop)"
          >
            <q-card-section>
              <div class="row items-start no-wrap q-gutter-sm q-mb-sm">
                <q-avatar color="blue-1" text-color="primary" icon="ph ph-storefront" size="40px" />
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
                </div>
                <q-icon name="ph ph-caret-right" color="grey-5" class="q-mt-xs" />
              </div>

              <!-- Shop Description -->
              <div v-if="shop.description" class="text-body2 text-grey-7 q-mt-sm line-clamp-2">
                {{ shop.description }}
              </div>

              <!-- Shop Categories -->
              <div v-if="getShopCategories(shop).length > 0" class="q-mt-md">
                <div class="row q-gutter-xs items-center">
                  <q-chip
                    v-for="cat in getShopCategories(shop)"
                    :key="cat.id || cat.name"
                    dense
                    size="sm"
                    color="grey-2"
                    text-color="grey-9"
                    class="q-ma-none q-mr-xs q-mb-xs"
                    @click.stop="openShopCategory(shop)"
                  >
                    <q-avatar v-if="cat.icon" color="blue-1" text-color="primary" class="q-mr-xs" size="18px">
                      <q-icon :name="cat.icon.startsWith('ph ') ? cat.icon : 'ph ph-' + cat.icon" size="12px" />
                    </q-avatar>
                    <span>{{ cat.name }}</span>
                  </q-chip>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerShopsQuery } from '../composables/useShopQuery';
import type { CustomerAccessibleShop } from '../repositories/shopOrderRepository';

const authStore = useAuthStore();
const router = useRouter();

const tenantId = computed(() => authStore.tenantId);
const tenantName = computed(() => authStore.tenant?.name || 'Wholesale');

const { data: rawShops, isLoading, isError, error } = useCustomerShopsQuery(tenantId);

const shops = computed<CustomerAccessibleShop[]>(() => rawShops.value ?? []);
const lastVisitedShopId = ref<string | null>(localStorage.getItem('last_visited_shop_id'));

const getShopCategories = (shop: CustomerAccessibleShop) => {
  if (Array.isArray(shop.categories) && shop.categories.length > 0) {
    return shop.categories;
  }
  return [];
};

const openShop = (shop: CustomerAccessibleShop) => {
  localStorage.setItem('last_visited_shop_id', String(shop.id));
  localStorage.setItem('last_visited_shop_slug', shop.slug);
  const tenantSlug = authStore.tenantSlug;
  void router.push(
    tenantSlug ? `/${tenantSlug}/shop/browse/${shop.slug}` : `/shop/browse/${shop.slug}`,
  );
};

const openShopCategory = (shop: CustomerAccessibleShop) => {
  localStorage.setItem('last_visited_shop_id', String(shop.id));
  localStorage.setItem('last_visited_shop_slug', shop.slug);
  const tenantSlug = authStore.tenantSlug;
  void router.push(
    tenantSlug ? `/${tenantSlug}/shop/browse/${shop.slug}` : `/shop/browse/${shop.slug}`,
  );
};

// Auto redirect if customer has access to only 1 shop
watch(
  shops,
  (newShops) => {
    if (newShops.length === 1 && newShops[0]) {
      openShop(newShops[0]);
    }
  },
  { immediate: true },
);
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

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>


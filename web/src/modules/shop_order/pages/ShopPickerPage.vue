<template>
  <q-page class="q-pa-md">
    <section class="bw-page__stack">
      <section>
        <div class="text-overline text-primary">Shop</div>
        <h1 class="text-h5 text-weight-bold q-my-none">Browse shops</h1>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">Open a shop your group can access.</p>
      </section>

      <div v-if="loading" class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <q-banner v-else-if="error" class="bg-negative text-white" rounded>
        {{ error }}
      </q-banner>

      <div
        v-else-if="shops.length === 0"
        class="column items-center justify-center q-pa-xl text-center text-grey-6"
      >
        <q-icon name="storefront" size="64px" color="grey-4" class="q-mb-md" />
        <div class="text-h6">No shops available</div>
        <p class="text-body2 text-grey-5 q-mb-none">
          Your group does not have browse access to any shop yet.
        </p>
      </div>

      <div v-else class="row q-col-gutter-md">
        <div v-for="shop in shops" :key="shop.id" class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="shop-card cursor-pointer" @click="openShop(shop)">
            <q-card-section>
              <div class="row items-start no-wrap q-gutter-sm">
                <q-icon name="storefront" size="28px" color="primary" />
                <div class="col">
                  <div class="text-subtitle1 text-weight-bold">{{ shop.name }}</div>
                  <div class="text-caption text-grey-6">{{ shop.slug }}</div>
                </div>
                <q-icon name="chevron_right" color="grey-5" />
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderService } from '../services/shopOrderService';
import type { CustomerAccessibleShop } from '../repositories/shopOrderRepository';

const authStore = useAuthStore();
const router = useRouter();

const shops = ref<CustomerAccessibleShop[]>([]);
const loading = ref(true);
const error = ref<string | null>(null);

const openShop = (shop: CustomerAccessibleShop) => {
  localStorage.setItem('last_visited_shop_id', String(shop.id));
  localStorage.setItem('last_visited_shop_slug', shop.slug);
  const tenantSlug = authStore.tenantSlug;
  void router.push(
    tenantSlug ? `/${tenantSlug}/shop/browse/${shop.slug}` : `/shop/browse/${shop.slug}`,
  );
};

onMounted(async () => {
  loading.value = true;
  error.value = null;
  const result = await shopOrderService.listShopsForCustomer(authStore.tenantId);
  loading.value = false;

  if (!result.success) {
    error.value = result.error ?? 'Failed to load shops.';
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
.shop-card:hover {
  border-color: var(--q-primary);
}
</style>

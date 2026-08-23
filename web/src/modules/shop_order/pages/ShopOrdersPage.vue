<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <ShopOrdersSkeleton v-if="isLoadingOrders && !ordersData?.length" />

    <div v-else class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <ShopOrdersFilters
        v-model:selected-shop-id="selectedShopId"
        v-model:search="search"
        v-model:status-filter="statusFilter"
        v-model:shop-type-filter="shopTypeFilter"
        :shops="shops"
        :shops-loading="isLoadingShops"
      />

      <div class="col" style="min-height: 0">
        <ShopOrdersTable
          :orders="orders"
          :is-loading-orders="isLoadingOrders"
          :is-processing-dropship="isProcessingDropship"
          :is-dropship-shop="isDropshipShop"
          @row-click="goToOrderDetails"
          @add-to-dropship="addToDropshipDesk"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopListQuery } from '../composables/useShopQuery';
import { useStaffOrdersQuery } from '../composables/useStaffOrdersQuery';
import { useProcessDropshipOrderMutation } from '../composables/useShopOrderMutations';
import ShopOrdersFilters from '../components/ShopOrdersFilters.vue';
import ShopOrdersTable from '../components/ShopOrdersTable.vue';
import ShopOrdersSkeleton from '../components/ShopOrdersSkeleton.vue';
import type { ShopType } from '../types';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const selectedShopId = ref<number | null>(null);

const shopParams = computed(() => ({
  tenantId: tenantId.value,
}));
const { data: shopsData, isLoading: isLoadingShops } = useShopListQuery(shopParams);
const shops = computed(() => shopsData.value || []);

const search = ref('');
const statusFilter = ref<string | null>(null);
const shopTypeFilter = ref<string | null>(
  typeof route.query.shopType === 'string' ? route.query.shopType : null,
);

watch(
  () => route.query.shopType,
  (value) => {
    shopTypeFilter.value = typeof value === 'string' ? value : null;
  },
);

const orderParams = computed(() => ({
  tenantId: tenantId.value,
  search: search.value || null,
  status: statusFilter.value || null,
  shopId: selectedShopId.value || null,
}));
const { data: ordersData, isLoading: isLoadingOrders } = useStaffOrdersQuery(orderParams);

const shopTypeById = computed(() => {
  const map = new Map<number, ShopType>();
  for (const shop of shops.value) {
    map.set(shop.id, shop.shop_type);
  }
  return map;
});

const isDropshipShop = (shopId: number) => shopTypeById.value.get(shopId) === 'dropship';

const orders = computed(() => {
  let list = ordersData.value || [];
  if (shopTypeFilter.value) {
    list = list.filter((order) => shopTypeById.value.get(order.shop_id) === shopTypeFilter.value);
  }
  return list;
});

const { mutateAsync: processDropship, isPending: isProcessingDropship } = useProcessDropshipOrderMutation();

const goToOrderDetails = (orderId: number) => {
  const order = orders.value.find((o) => o.id === orderId);
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  const shopType = order ? shopTypeById.value.get(order.shop_id) : null;
  if (shopType === 'dropship') {
    void router.push(`${slug}/app/shop/dropship/${orderId}`);
  } else {
    void router.push(`${slug}/app/shop/orders/${orderId}`);
  }
};

const addToDropshipDesk = async (orderId: number) => {
  const res = await processDropship(orderId);
  if (res?.success) {
    const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
    void router.push(`${slug}/app/shop/dropship/${orderId}`);
  }
};
</script>

<script lang="ts">
export default {
  name: 'ShopOrdersPage',
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
</style>

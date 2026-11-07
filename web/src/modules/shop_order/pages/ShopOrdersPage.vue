<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <ShopOrdersSkeleton v-if="isLoadingOrders && !orders.length" />

    <div v-else class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <ShopOrdersFilters
        v-model:selected-shop-id="selectedShopId"
        v-model:selected-profile-id="selectedProfileId"
        v-model:search="searchInput"
        v-model:status-filter="statusFilter"
        :shops="shops"
        :profiles="customerProfiles"
        :shops-loading="isLoadingShops"
        :profiles-loading="isLoadingProfiles"
        :refreshing="isRefreshing"
        @apply-search="applySearch"
        @refresh="refresh()"
        @create-dropship="goCreateDropshipOrder"
        @create-catalog="goCreateCatalogOrder"
        @open-cancelled-delete="goCancelledOrdersDeletePage"
      />

      <div class="col" style="min-height: 0">
        <ShopOrdersList
          :orders="orders"
          :is-loading-orders="isLoadingOrders"
          :is-processing-dropship="isProcessingDropship"
          :is-dropship-shop="isDropshipShop"
          :is-parent-tenant="isParentTenant"
          :is-filtered="isFiltered"
          :has-next-page="hasNextPage"
          :is-fetching-next-page="isFetchingNextPage"
          @row-click="goToOrderDetails"
          @add-to-dropship="addToDropshipDesk"
          @clear-filters="clearAllFilters"
          @load-more="onLoadMoreOrders"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerProfiles } from 'src/modules/sales_invoice/composables/useCustomerProfiles';
import { useShopOrdersStaffPageQuery } from '../composables/useShopOrdersStaffPageQuery';
import { useProcessDropshipOrderMutation } from '../composables/useShopOrderMutations';
import ShopOrdersFilters from '../components/ShopOrdersFilters.vue';
import ShopOrdersList from '../components/ShopOrdersList.vue';
import ShopOrdersSkeleton from '../components/ShopOrdersSkeleton.vue';
import type { ShopType } from '../types';

const router = useRouter();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const parentTenantId = computed(() => authStore.selectedTenant?.parent_id ?? authStore.tenantId);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const isParentTenant = computed(() => {
  if (!tenantId.value) return false;
  const pId = authStore.selectedTenant?.parent_id ?? tenantId.value;
  return Number(pId) === Number(tenantId.value);
});

const selectedShopId = ref<number | null>(null);
const selectedProfileId = ref<number | null>(null);

const { profiles: customerProfiles, isLoading: isLoadingProfiles } = useCustomerProfiles(parentTenantId);

const searchInput = ref('');
const appliedSearch = ref('');
const statusFilter = ref<string | null>(null);

const applySearch = () => {
  appliedSearch.value = searchInput.value.trim();
};

const isFiltered = computed(() => {
  return Boolean(
    appliedSearch.value ||
      statusFilter.value ||
      selectedShopId.value !== null ||
      selectedProfileId.value !== null,
  );
});

const clearAllFilters = () => {
  searchInput.value = '';
  appliedSearch.value = '';
  statusFilter.value = null;
  selectedShopId.value = null;
  selectedProfileId.value = null;
};

const pageParams = computed(() => ({
  tenantId: tenantId.value,
  parentTenantId: parentTenantId.value,
  search: appliedSearch.value || null,
  status: statusFilter.value || null,
  shopId: selectedShopId.value || null,
  profileId: selectedProfileId.value || null,
}));

const {
  shops,
  orders,
  isLoadingOrders,
  isLoadingShops,
  hasNextPage,
  isFetchingNextPage,
  fetchNextPage,
  isRefreshing,
  refresh,
} = useShopOrdersStaffPageQuery(pageParams);

const onLoadMoreOrders = async (done: (stop?: boolean) => void) => {
  if (!hasNextPage.value) {
    done(true);
    return;
  }
  await fetchNextPage();
  done(!hasNextPage.value);
};

const isDropshipShop = (shopId: number) => {
  const order = orders.value.find((o) => o.shop_id === shopId);
  if (order?.shop_type_snapshot) {
    return order.shop_type_snapshot === 'dropship';
  }
  const shop = shops.value.find((s) => s.id === shopId);
  return shop?.shop_type === 'dropship';
};

const { mutateAsync: processDropship, isPending: isProcessingDropship } = useProcessDropshipOrderMutation();

const goCancelledOrdersDeletePage = () => {
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  void router.push(`${slug}/app/shop/orders/cancelled`);
};

const goToOrderDetails = (orderId: number) => {
  const order = orders.value.find((o) => o.id === orderId);
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  const shopType: ShopType | null | undefined =
    order?.shop_type_snapshot ?? shops.value.find((s) => s.id === order?.shop_id)?.shop_type;
  void router.push({
    path: `${slug}/app/shop/orders/${orderId}`,
    state: { shopTypeSnapshot: shopType ?? undefined },
  });
};

const goCreateDropshipOrder = () => {
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  void router.push(`${slug}/app/shop/orders/create`);
};

const goCreateCatalogOrder = () => {
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  void router.push(`${slug}/app/shop/orders/create-catalog`);
};

const addToDropshipDesk = async (orderId: number) => {
  const res = await processDropship(orderId);
  if (res?.success) {
    const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
    void router.push({
      path: `${slug}/app/shop/orders/${orderId}`,
      state: { shopTypeSnapshot: 'dropship' },
    });
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

<template>
  <q-page class="q-pa-md">
    <ShopOrdersSkeleton v-if="isLoadingOrders" />

    <div v-else class="q-gutter-y-md">
      <ShopOrdersHeader />

      <ShopOrdersFilters
        v-model:selected-shop-id="selectedShopId"
        v-model:search="search"
        v-model:status-filter="statusFilter"
        :shops="shops"
      />

      <ShopOrdersTable
        :orders="orders"
        :shops="shops"
        :currencies="currencies"
        :is-loading-orders="false"
        :is-processing-dropship="isProcessingDropship"
        @row-click="goToOrderDetails"
        @add-to-dropship="addToDropshipDesk"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { useShopListQuery } from '../composables/useShopQuery';
import { useStaffOrdersQuery } from '../composables/useStaffOrdersQuery';
import { useProcessDropshipOrderMutation } from '../composables/useShopOrderMutations';
import ShopOrdersHeader from '../components/ShopOrdersHeader.vue';
import ShopOrdersFilters from '../components/ShopOrdersFilters.vue';
import ShopOrdersTable from '../components/ShopOrdersTable.vue';
import ShopOrdersSkeleton from '../components/ShopOrdersSkeleton.vue';

const router = useRouter();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const shopParams = computed(() => ({
  tenantId: tenantId.value,
}));
const { data: shopsData } = useShopListQuery(shopParams);
const shops = computed(() => shopsData.value || []);

const search = ref('');
const statusFilter = ref<string | null>(null);
const selectedShopId = ref<number | null>(null);

const orderParams = computed(() => ({
  tenantId: tenantId.value,
  search: search.value || null,
  status: statusFilter.value || null,
  shopId: selectedShopId.value || null,
}));
const { data: ordersData, isLoading: isLoadingOrders } = useStaffOrdersQuery(orderParams);
const orders = computed(() => ordersData.value || []);

const { mutateAsync: processDropship, isPending: isProcessingDropship } = useProcessDropshipOrderMutation();

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value ?? []);

const goToOrderDetails = (orderId: number) => {
  const order = orders.value.find((o) => o.id === orderId);
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  if (order?.shop_type_snapshot === 'dropship') {
    void router.push(`${slug}/app/shop/dropship/${orderId}`);
  } else {
    void router.push(`${slug}/app/shop/orders/${orderId}`);
  }
};

const addToDropshipDesk = async (orderId: number) => {
  const res = await processDropship(orderId);
  if (res?.success) {
    const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
    void router.push(`${slug}/app/shop/dropship/orders/${orderId}`);
  }
};
</script>

<script lang="ts">
export default {
  name: 'ShopOrdersPage',
};
</script>

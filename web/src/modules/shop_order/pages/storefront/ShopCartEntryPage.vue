<template>
  <ShopDropshipPlaceOrderPage v-if="resolvedCartKind === 'dropship'" />
  <ShopCartPage v-else />
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { useActiveShopCartsQuery } from '../../composables/useActiveShopCartsQuery';
import { resolveCustomerShopTypePath } from '../../utils/catalogShop';
import { useShopCartQuery } from '../../composables/useShopCartQuery';
import { useShopCartSelection } from '../../composables/useShopCartSelection';
import ShopCartPage from './ShopCartPage.vue';
import ShopDropshipPlaceOrderPage from './ShopDropshipPlaceOrderPage.vue';

const route = useRoute();
const authStore = useAuthStore();

const {
  data: activeCartsData,
  isLoading: isCartsLoading,
} = useActiveShopCartsQuery();
const activeCarts = computed(() => activeCartsData.value ?? []);

const routeShopTypePath = computed(() =>
  resolveCustomerShopTypePath(route, authStore.tenantId),
);

const { selectedShopId } = useShopCartSelection(activeCarts, isCartsLoading, {
  cartKind: resolveCustomerShopTypePath(route, authStore.tenantId),
});

const selectedShopIdRef = ref<number | null>(null);

watch(
  selectedShopId,
  (val) => {
    selectedShopIdRef.value = val;
  },
  { immediate: true },
);

const { cart } = useShopCartQuery(selectedShopIdRef);

const resolvedCartKind = computed<'dropship' | 'catalog'>(() => {
  if (routeShopTypePath.value === 'dropship') return 'dropship';
  if (cart.value?.shop_type === 'dropship') return 'dropship';
  return 'catalog';
});
</script>

<script lang="ts">
export default {
  name: 'ShopCartEntryPage',
};
</script>

<template>
  <ShopDropshipCartPage v-if="resolvedCartKind === 'dropship'" />
  <ShopCartPage v-else />
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useActiveShopCartsQuery } from '../composables/useActiveShopCartsQuery';
import { useShopCartQuery } from '../composables/useShopCartQuery';
import { useShopCartSelection } from '../composables/useShopCartSelection';
import ShopCartPage from './ShopCartPage.vue';
import ShopDropshipCartPage from './ShopDropshipCartPage.vue';

const {
  data: activeCartsData,
  isLoading: isCartsLoading,
} = useActiveShopCartsQuery();
const activeCarts = computed(() => activeCartsData.value ?? []);

const { selectedShopId, currentShopCartInfo } = useShopCartSelection(
  activeCarts,
  isCartsLoading,
);

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
  const selectedCart =
    activeCarts.value.find((cartItem) => cartItem.shop_id === selectedShopId.value) ?? null;
  const shopType =
    cart.value?.shop_type ??
    selectedCart?.shop_type ??
    currentShopCartInfo.value?.shop_type ??
    (activeCarts.value.length === 1 ? activeCarts.value[0]?.shop_type : null);

  if (shopType === 'dropship') return 'dropship';

  if (
    activeCarts.value.length > 0 &&
    activeCarts.value.every((cartItem) => cartItem.shop_type === 'dropship')
  ) {
    return 'dropship';
  }

  return 'catalog';
});
</script>

<script lang="ts">
export default {
  name: 'ShopCartEntryPage',
};
</script>

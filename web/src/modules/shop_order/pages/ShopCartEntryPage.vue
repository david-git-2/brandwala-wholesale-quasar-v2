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

const { selectedShopId, showCartPicker, currentShopCartInfo } = useShopCartSelection(
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
  const shopType =
    cart.value?.shop_type ??
    currentShopCartInfo.value?.shop_type ??
    (activeCarts.value.length === 1 ? activeCarts.value[0]?.shop_type : null);

  if (shopType === 'dropship') return 'dropship';

  if (
    showCartPicker.value &&
    activeCarts.value.length > 0 &&
    activeCarts.value.every((c) => c.shop_type === 'dropship')
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

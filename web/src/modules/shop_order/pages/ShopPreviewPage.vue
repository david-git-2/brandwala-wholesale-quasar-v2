<template>
  <q-page class="bg-grey-1">
    <div v-if="!shop" class="flex flex-center q-py-xl">
      <q-spinner size="40px" color="primary" />
    </div>
    <ShopPreviewContainer
      v-else
      :shop-name="shop.name"
      :shop-type="shop.shop_type"
      :order-mode="shop.order_mode"
      :pricing-method="shop.pricing_method"
      :markup-percentage="shop.markup_percentage"
      :is-negotiable="shop.is_negotiable"
      :show-stock-quantity="shop.show_stock_quantity"
      :vendor-filters="shop.vendor_filters ?? null"
      :full-page="true"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useShopOrderStore } from 'src/modules/shop_order/stores/shopOrderStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ShopPreviewContainer from 'src/modules/shop_order/components/ShopPreviewContainer.vue';

const route = useRoute();
const store = useShopOrderStore();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const shopId = computed(() => Number(route.params.shopId));

const shop = computed(() => store.shops.find(s => s.id === shopId.value));

onMounted(async () => {
  if (store.shops.length === 0 && tenantId.value) {
    await store.fetchShopsByTenant(tenantId.value);
  }
});

</script>

<style scoped>
</style>

<template>
  <div>
    <div class="text-subtitle1 text-weight-bold q-mb-md">
      {{ $t('customer_dashboard.categories_title') }}
    </div>

    <div class="row q-col-gutter-md">
      <div v-for="category in categories" :key="category.id" class="col-6 col-sm-4 col-md-3">
        <q-card
          flat
          bordered
          class="category-card q-pa-md cursor-pointer card-hover"
          role="button"
          tabindex="0"
          data-test="category-card"
        >
          <div class="row items-center no-wrap q-gutter-sm">
            <q-icon
              :name="category.icon || 'ph ph-squares-four'"
              size="22px"
              color="primary"
            />
            <div class="text-subtitle2 text-weight-bold ellipsis">{{ category.name }}</div>
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';

type DashboardCategory = {
  id: number | string;
  name: string;
  icon?: string | null;
};

/** Dummy mix until customer-category RPC lands. */
const DUMMY_CATEGORIES: DashboardCategory[] = [
  { id: 'apparel', name: 'Apparel', icon: 'ph ph-t-shirt' },
  { id: 'footwear', name: 'Footwear', icon: 'ph ph-sneaker' },
  { id: 'accessories', name: 'Accessories', icon: 'ph ph-watch' },
  { id: 'home', name: 'Home', icon: 'ph ph-house' },
  { id: 'kids', name: 'Kids', icon: 'ph ph-baby' },
  { id: 'beauty', name: 'Beauty', icon: 'ph ph-sparkle' },
];

const props = defineProps<{
  shops: CustomerAccessibleShop[];
}>();

const categories = computed(() => {
  const seen = new Map<number, DashboardCategory>();
  props.shops.forEach((shop) => {
    (shop.categories ?? []).forEach((cat) => {
      if (!seen.has(cat.id)) {
        seen.set(cat.id, { id: cat.id, name: cat.name, icon: cat.icon });
      }
    });
  });
  const fromShops = [...seen.values()];
  return fromShops.length > 0 ? fromShops : DUMMY_CATEGORIES;
});
</script>

<style scoped>
.category-card {
  border-radius: 14px;
  background: var(--bw-theme-surface);
}
</style>

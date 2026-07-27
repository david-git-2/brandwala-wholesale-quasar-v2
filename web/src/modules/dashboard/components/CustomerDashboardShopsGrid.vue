<template>
  <div>
    <div class="row items-center justify-between q-mb-sm q-mb-md-md">
      <div>
        <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shops_title') }}</div>
        <div class="text-caption text-grey-6">{{ $t('customer_dashboard.shops_sub') }}</div>
      </div>
    </div>

    <div class="row q-col-gutter-md">
      <div
        v-for="shop in shops"
        :key="shop.id"
        class="col-12 col-sm-6 col-md-4"
      >
        <q-card flat bordered class="shop-item-card q-pa-md column justify-between">
          <div>
            <!-- Shop Title -->
            <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md cursor-pointer" @click="$emit('open-shop', shop)">
              {{ shop.name }}
            </div>

            <!-- Shop Categories Cards -->
            <div v-if="getShopCategories(shop).length > 0">
              <div class="row q-col-gutter-sm">
                <div
                  v-for="cat in getShopCategories(shop)"
                  :key="cat.name"
                  class="col-6"
                >
                  <div
                    class="category-mini-card column items-center justify-center text-center q-pa-sm q-pa-sm-md cursor-pointer"
                    @click.stop="$emit('open-shop-category', shop)"
                  >
                    <q-avatar size="38px" color="blue-1" text-color="primary" class="q-mb-xs">
                      <q-icon :name="cat.icon || 'ph ph-squares-four'" size="20px" />
                    </q-avatar>
                    <span class="text-caption text-weight-bold text-grey-9 ellipsis full-width q-mt-xs">{{ cat.name }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  shops: any[];
  categories: any[];
}>();

defineEmits<{
  (e: 'open-shop', shop: any): void;
  (e: 'open-shop-category', shop: any): void;
}>();

const getShopCategories = (shop: any) => {
  if (!shop) return [];
  if (shop.categories && Array.isArray(shop.categories) && shop.categories.length > 0) {
    return shop.categories;
  }
  const categoryIds = shop.category_ids;
  if (!categoryIds || !Array.isArray(categoryIds) || categoryIds.length === 0) {
    return [];
  }
  return props.categories.filter((cat: any) => categoryIds.includes(Number(cat.id)));
};
</script>

<style scoped>
.shop-item-card {
  border-radius: 14px;
  background: var(--bw-theme-surface, #ffffff);
  min-height: 160px;
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease;
}

.category-mini-card {
  border-radius: 12px;
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  background: var(--bw-theme-surface, #f8fafc);
  transition: all 0.2s ease;
}

.category-mini-card:hover {
  background: #f1f5f9;
  border-color: var(--q-primary);
  transform: translateY(-1px);
}
</style>

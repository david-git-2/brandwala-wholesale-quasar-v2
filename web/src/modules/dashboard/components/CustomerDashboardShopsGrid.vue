<template>
  <div>
    <div class="q-mb-md">
      <div class="text-subtitle1 text-weight-bold">{{ $t('customer_dashboard.shops_title') }}</div>
      <div class="text-caption text-grey-6">{{ $t('customer_dashboard.shops_sub') }}</div>
    </div>

    <div class="row q-col-gutter-md">
      <div v-for="shop in shops" :key="shop.id" class="col-12 col-sm-6 col-md-4">
        <q-card
          flat
          bordered
          class="shop-item-card column justify-between q-pa-md cursor-pointer card-hover"
          :class="{ 'shop-item-card--last': String(shop.id) === lastVisitedShopId }"
          role="button"
          tabindex="0"
          data-test="shop-card"
          @click="$emit('open-shop', shop)"
          @keydown.enter.prevent="$emit('open-shop', shop)"
        >
          <div>
            <div class="row items-start no-wrap q-gutter-sm">
              <q-avatar size="42px" class="shop-avatar text-weight-bold">
                {{ shopInitial(shop.name) }}
              </q-avatar>
              <div class="col">
                <div class="text-subtitle1 text-weight-bold">{{ shop.name }}</div>
                <div class="row items-center q-gutter-xs q-mt-xs">
                  <q-badge outline color="primary" class="q-px-xs">
                    {{ shopTypeLabel(shop.shop_type) }}
                  </q-badge>
                  <q-badge
                    v-if="String(shop.id) === lastVisitedShopId"
                    color="primary"
                    class="q-px-xs"
                  >
                    {{ $t('customer_dashboard.last_visited') }}
                  </q-badge>
                </div>
              </div>
            </div>

            <div v-if="shopTags(shop).length > 0" class="q-mt-md row q-gutter-xs">
              <q-chip
                v-for="tag in shopTags(shop)"
                :key="tag"
                dense
                outline
                size="sm"
                class="q-ma-none"
              >
                {{ tag }}
              </q-chip>
            </div>
          </div>

          <div class="row items-center text-primary text-weight-medium q-mt-md">
            <span>{{ $t('customer_dashboard.open_shop') }}</span>
            <q-icon name="ph ph-caret-right" size="18px" class="q-ml-xs" />
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import { customerShopTypeI18nKey } from 'src/modules/shop_order/utils/catalogShop';

defineProps<{
  shops: CustomerAccessibleShop[];
  lastVisitedShopId: string | null;
}>();

defineEmits<{
  (e: 'open-shop', shop: CustomerAccessibleShop): void;
}>();

const { t } = useI18n();

const shopInitial = (name: string) => (name.trim().charAt(0) || 'S').toUpperCase();

const shopTypeLabel = (shopType: string) => t(customerShopTypeI18nKey(shopType));

const shopTags = (shop: CustomerAccessibleShop) => {
  const cats = shop.categories;
  if (!Array.isArray(cats) || cats.length === 0) return [];
  return cats
    .map((c) => c.name)
    .filter(Boolean)
    .slice(0, 3);
};
</script>

<style scoped>
.shop-item-card {
  border-radius: 14px;
  background: var(--bw-theme-surface);
  min-height: 148px;
}

.shop-item-card--last {
  border-color: var(--q-primary);
  box-shadow: inset 3px 0 0 var(--q-primary);
}

.shop-avatar {
  background: var(--bw-theme-primary-soft);
  color: var(--q-primary);
}
</style>

<template>
  <q-badge
    v-if="visible"
    rounded
    class="order-pricing-mode-badge text-weight-bold text-caption q-px-sm q-py-xs"
    :color="badgeColors.color"
    :text-color="badgeColors.textColor"
  >
    {{ label }}
  </q-badge>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import type { ShopType } from '../types';

const props = defineProps<{
  isNegotiable: boolean;
  shopType?: ShopType | string | null;
}>();

const { t } = useI18n();

const visible = computed(() => {
  const shopType = props.shopType;
  return shopType === 'vendor_catalog' || shopType === 'fixed_price';
});

const label = computed(() =>
  props.isNegotiable ? t('shop_admin.order_pricing_negotiable') : t('shop_admin.order_pricing_fixed'),
);

const badgeColors = computed(() =>
  props.isNegotiable
    ? { color: 'purple-1', textColor: 'purple-9' }
    : { color: 'blue-grey-1', textColor: 'blue-grey-9' },
);
</script>

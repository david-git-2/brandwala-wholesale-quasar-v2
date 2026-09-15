<template>
  <div
    v-if="visible"
    class="order-pricing-mode-badge"
    :class="isNegotiable ? 'mode-negotiable' : 'mode-fixed'"
  >
    <q-icon
      :name="isNegotiable ? 'ph ph-arrows-left-right' : 'ph ph-lock'"
      size="12px"
      class="q-mr-xs"
    />
    <span>{{ label }}</span>
  </div>
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
  props.isNegotiable ? t('shop_admin.order_pricing_negotiable', 'Negotiable') : t('shop_admin.order_pricing_fixed', 'Fixed Price'),
);
</script>

<style scoped>
.order-pricing-mode-badge {
  display: inline-flex;
  align-items: center;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  padding: 3px 8px;
  border-radius: 6px;
  line-height: 1.2;
}

.mode-negotiable {
  background: #fdf4ff;
  color: #86198f;
  border: 1px solid #f0abfc;
}

.mode-fixed {
  background: #f1f5f9;
  color: #334155;
  border: 1px solid #cbd5e1;
}

body.body--dark .mode-negotiable {
  background: rgba(192, 38, 211, 0.15);
  color: #f0abfc;
  border-color: rgba(192, 38, 211, 0.3);
}

body.body--dark .mode-fixed {
  background: rgba(100, 116, 139, 0.15);
  color: #cbd5e1;
  border-color: rgba(100, 116, 139, 0.3);
}
</style>

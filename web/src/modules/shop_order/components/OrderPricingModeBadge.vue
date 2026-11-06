<template>
  <div
    v-if="visible && variant === 'text'"
    class="order-pricing-mode-text"
  >
    {{ label }}
  </div>
  <div
    v-else-if="visible"
    class="order-pricing-mode-badge"
    :class="
      isNegotiable ? 'mode-negotiable' : subtleFixed ? 'mode-fixed mode-fixed--subtle' : 'mode-fixed'
    "
  >
    <q-icon
      v-if="isNegotiable"
      name="ph ph-arrows-left-right"
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

const props = withDefaults(
  defineProps<{
  isNegotiable: boolean;
  shopType?: ShopType | string | null;
  variant?: 'badge' | 'text';
  /** Softer "Fixed" chip for dense tables (shop orders list). */
  subtleFixed?: boolean;
}>(),
  { variant: 'badge' },
);

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
  background: var(--tf-disabled-bg);
  color: var(--tf-neutral-muted);
  border: 0;
  font-weight: 500;
  font-size: 11px;
  padding: 1px 6px;
  border-radius: var(--tf-radius-sm);
  line-height: 1.25;
}

.mode-fixed--subtle {
  background: #f1f5f9;
  color: #94a3b8;
  border: 0;
  font-weight: 500;
  font-size: 11px;
  padding: 1px 6px;
  border-radius: 4px;
  line-height: 1.2;
}

.order-pricing-mode-text {
  display: block;
  margin-top: 0.15rem;
  font-size: 0.6875rem;
  font-weight: 500;
  line-height: 1.2;
  color: #6b7280;
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

body.body--dark .mode-fixed--subtle {
  background: rgba(148, 163, 184, 0.12);
  color: #94a3b8;
}
</style>

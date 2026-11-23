<template>
  <q-card
    flat
    class="shop-home-card shop-home-quick-action cursor-pointer"
    role="button"
    tabindex="0"
    data-test="shop-portal-quick-action"
    @click="$emit('start')"
    @keydown.enter.prevent="$emit('start')"
  >
    <div class="shop-home-quick-action__title">{{ $t('customer_dashboard.portal_start_order') }}</div>
    <div class="shop-home-quick-action__sub">{{ $t('customer_dashboard.portal_start_order_sub') }}</div>
    <q-icon name="ph ph-arrow-right" class="shop-home-quick-action__icon" aria-hidden="true" />
  </q-card>
</template>

<script setup lang="ts">
defineEmits<{
  (e: 'start'): void;
}>();
</script>

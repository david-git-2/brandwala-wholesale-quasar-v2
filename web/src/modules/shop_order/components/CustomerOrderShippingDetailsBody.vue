<template>
  <div>
    <div class="text-weight-medium text-grey-9">{{ order.recipient_name }}</div>
    <div v-if="order.recipient_phone" class="q-mt-xs">{{ order.recipient_phone }}</div>
    <div
      v-if="order.shipping_address"
      class="q-mt-sm text-grey-6"
      style="white-space: pre-wrap"
    >
      {{ order.shipping_address }}
    </div>

    <div
      v-if="order.delivery_instructions"
      class="q-mt-sm text-caption text-grey-7"
      style="white-space: pre-wrap"
    >
      <span class="text-weight-medium text-grey-8">{{ $t('shop_admin.delivery_instructions_notes') }}</span>
      {{ order.delivery_instructions }}
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  order: any;
}>();
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderShippingDetailsBody',
};
</script>

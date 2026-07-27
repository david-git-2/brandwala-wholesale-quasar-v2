<template>
  <q-card flat bordered class="details-card">
    <q-card-section class="q-px-lg q-py-md border-bottom">
      <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.shipping_details') }}</div>
    </q-card-section>

    <q-card-section class="q-px-lg q-py-md text-body2 text-grey-8">
      <div class="text-weight-bold text-grey-9">
        {{ order.recipient_name }}
      </div>
      <div class="q-mt-xs">{{ order.recipient_phone }}</div>
      <div
        class="q-mt-sm text-grey-6 bg-grey-1 q-pa-sm rounded-borders"
        style="white-space: pre-wrap"
      >
        {{ order.shipping_address }}
      </div>
      
      <div
        v-if="order.delivery_instructions"
        class="q-mt-sm q-pa-sm bg-blue-50 text-blue-9 text-caption rounded-borders"
        style="border: 1px solid #90caf9;"
      >
        <div class="text-weight-bold">{{ $t('shop_admin.delivery_instructions_notes') }}</div>
        <div style="white-space: pre-wrap">{{ order.delivery_instructions }}</div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
defineProps<{
  order: any;
}>();
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderShippingCard',
};
</script>

<style scoped>
.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}
</style>

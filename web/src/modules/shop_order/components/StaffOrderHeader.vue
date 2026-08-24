<template>
  <q-banner
    v-if="canFulfill && order.shop_type_snapshot === 'dropship'"
    rounded
    class="bg-blue-1 text-primary q-mb-sm border-blue"
    style="border: 1px solid #bfdbfe;"
  >
    <template v-slot:avatar>
      <q-avatar color="blue-2" text-color="primary" icon="ph ph-truck" size="40px" />
    </template>
    <div class="text-subtitle1 text-weight-bold">Order confirmed — action required</div>
    <div class="text-caption text-grey-8">
      Process this order to assign courier and start fulfillment.
    </div>
    <template v-slot:action>
      <q-btn
        unelevated
        color="primary"
        no-caps
        icon="ph ph-truck"
        icon-right="ph ph-arrow-right"
        :label="$t('shop_admin.add_to_dropship_desk')"
        class="text-weight-bold q-px-md"
        style="border-radius: 8px;"
        :loading="isProcessingDropship"
        @click="emit('add-to-dropship')"
      />
    </template>
  </q-banner>
</template>

<script setup lang="ts">
defineProps<{
  order: any;
  canFulfill: boolean;
  isProcessingDropship?: boolean;
}>();

const emit = defineEmits<{
  (e: 'add-to-dropship'): void;
}>();
</script>

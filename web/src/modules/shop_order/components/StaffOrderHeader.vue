<script setup lang="ts">
defineProps<{
  order: any;
  canFulfill: boolean;
  isProcessingDropship?: boolean;
}>();

const emit = defineEmits<{
  (e: 'go-back'): void;
  (e: 'add-to-dropship'): void;
}>();
</script>

<template>
  <div>
    <!-- Header -->
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="emit('go-back')" />
          <div>
            <div class="text-overline text-primary">{{ $t('shop_admin.staff_order_desk') }}</div>
            <h1 class="text-h5 text-weight-bold q-my-none">{{ order.order_no }}</h1>
            <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
              {{ $t('shop_admin.order_management') }}
            </p>
          </div>
        </div>
      </div>
      <div class="col-auto row q-gutter-sm items-center">
        <!-- Header actions can go here if needed -->
      </div>
    </section>

    <!-- Contextual Action Hero Banner for Confirmed Dropship Orders -->
    <q-banner
      v-if="canFulfill && order.shop_type_snapshot === 'dropship'"
      rounded
      class="bg-blue-1 text-primary q-my-sm border-blue"
      style="border: 1px solid #bfdbfe;"
    >
      <template v-slot:avatar>
        <q-avatar color="blue-2" text-color="primary" icon="ph ph-truck" size="40px" />
      </template>
      <div class="text-subtitle1 text-weight-bold">Order Confirmed — Action Required</div>
      <div class="text-caption text-grey-8">
        This order is confirmed and ready for dispatch. Push to Dropship Desk to allocate inventory and begin fulfillment.
      </div>
      <template v-slot:action>
        <q-btn
          unelevated
          color="primary"
          no-caps
          icon="ph ph-truck"
          icon-right="ph ph-arrow-right"
          :label="$t('shop_admin.add_to_dropship_desk')"
          class="text-weight-bold q-px-md rounded-borders"
          style="border-radius: 8px;"
          :loading="isProcessingDropship"
          @click="emit('add-to-dropship')"
        />
      </template>
    </q-banner>
  </div>
</template>

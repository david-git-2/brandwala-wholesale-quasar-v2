<template>
  <section class="row items-center justify-between q-col-gutter-md">
    <div class="col">
      <div class="row items-center q-gutter-x-sm">
        <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="emit('back')" />
        <div>
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">
            {{ shipmentName || 'Shipment Details' }}
          </h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Landed costing breakdown and item details
          </p>
        </div>
      </div>
    </div>
    <div class="col-auto row q-gutter-sm items-center">
      <LearnMoreHelpBtn guide-id="thrift_shipment" tab="workflows" />
      <template v-if="shipmentName">
        <q-badge outline color="primary" class="q-pa-xs">
          Purchase: {{ purchaseCurrencyCode }}
        </q-badge>
        <q-badge outline color="secondary" class="q-pa-xs">
          Cost: {{ costCurrencyCode }}
        </q-badge>
      </template>
    </div>
  </section>
</template>

<script setup lang="ts">
import LearnMoreHelpBtn from '@/modules/help/components/LearnMoreHelpBtn.vue';

defineProps<{
  shipmentName?: string | null | undefined;
  purchaseCurrencyCode?: string | undefined;
  costCurrencyCode?: string | undefined;
}>();

const emit = defineEmits<{
  (e: 'back'): void;
}>();
</script>

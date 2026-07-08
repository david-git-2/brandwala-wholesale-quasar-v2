<template>
  <q-dialog v-model="localModelValue" backdrop-filter="blur(4px)">
    <q-card
      style="width: 760px; max-width: 95vw; max-height: 90vh"
      class="floating-surface shadow-2 q-pa-md scroll"
    >
      <q-card-section class="row items-center justify-between q-py-sm">
        <div class="row items-center q-gutter-sm">
          <q-icon name="inventory_2" size="24px" color="primary" />
          <div class="text-h6 text-weight-bold text-black">Stock Batch Details</div>
          <q-badge v-if="item" color="primary" outline class="text-weight-bold q-ml-sm">
            Batch #{{ item.id }}
          </q-badge>
        </div>
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>
      <q-separator />

      <q-card-section v-if="item" class="q-pt-md">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-4 text-center border-right-light">
            <q-avatar rounded size="120px" class="bg-grey-2 q-mb-sm shadow-1">
              <img
                :src="item.image_url || 'https://placehold.co/120x120?text=No+Image'"
                alt="Product Image"
                style="object-fit: contain"
              />
            </q-avatar>
            <div class="text-subtitle1 text-weight-bold text-black q-px-xs">{{ item.name }}</div>
            <div class="text-caption text-grey-8 q-mt-xs">
              ID: <span class="text-black text-weight-medium">{{ item.id }}</span>
            </div>
            <div class="text-subtitle2 text-black q-mt-sm">
              Cost: <strong class="text-primary">BDT {{ item.cost ?? '-' }}</strong>
            </div>
          </div>

          <div class="col-12 col-sm-8">
            <q-list dense class="q-mb-md">
              <q-item>
                <q-item-section>
                  <q-item-label caption class="text-grey-8 text-weight-bold">Barcode</q-item-label>
                  <q-item-label class="text-weight-bold text-black">{{
                    item.barcode ?? '-'
                  }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-item-label caption class="text-grey-8 text-weight-bold"
                    >Product Code</q-item-label
                  >
                  <q-item-label class="text-weight-bold text-black">{{
                    item.product_code ?? '-'
                  }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-item-label caption class="text-grey-8 text-weight-bold"
                    >Shipment Source</q-item-label
                  >
                  <q-item-label class="text-weight-medium text-black">
                    {{ shipmentLabel }}
                  </q-item-label>
                </q-item-section>
              </q-item>
            </q-list>

            <q-separator class="q-my-sm" />

            <div class="text-subtitle1 text-weight-bold text-black q-mb-sm">Quantities Status</div>
            <div class="row q-col-gutter-sm">
              <div
                v-for="entry in formattedQuantities"
                :key="entry.label"
                class="col-4 text-center"
              >
                <div
                  class="q-pa-sm rounded-borders column items-center justify-center soft-qty-card"
                  :class="entry.bg"
                  style="min-height: 64px"
                >
                  <div class="text-caption text-grey-9 text-weight-bold text-uppercase">
                    {{ entry.label }}
                  </div>
                  <div class="text-h6 text-weight-bolder text-black q-mt-xs">{{ entry.val }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import type { InventoryItemWithStock } from '../types';

const props = defineProps<{
  modelValue: boolean;
  item: InventoryItemWithStock | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const shipmentLabel = computed(() => {
  const shipment = props.item?.shipment?.shipment as {
    tenant_shipment_id?: number;
    id?: number;
    name?: string;
  } | null;
  if (!shipment) return 'Manual Entry';
  return `#${shipment.tenant_shipment_id ?? shipment.id} - ${shipment.name ?? ''}`;
});

const formattedQuantities = computed(() => {
  if (!props.item) return [];
  const q = props.item.quantities;
  return [
    { label: 'available', val: q.available, bg: 'bg-green-1' },
    { label: 'open box', val: q.open_box, bg: 'bg-blue-1' },
    { label: 'reserved', val: q.reserved, bg: 'bg-indigo-1' },
    { label: 'damaged', val: q.damaged, bg: 'bg-red-1' },
    { label: 'stolen', val: q.stolen, bg: 'bg-orange-1' },
    { label: 'expired', val: q.expired, bg: 'bg-purple-1' },
  ];
});
</script>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.94);
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
}
.border-right-light {
  border-right: 1px solid rgba(0, 0, 0, 0.08);
}
@media (max-width: 599px) {
  .border-right-light {
    border-right: none;
    border-bottom: 1px solid rgba(0, 0, 0, 0.08);
    padding-bottom: 12px;
    margin-bottom: 12px;
  }
}
.soft-qty-card {
  border: 1px solid rgba(0, 0, 0, 0.06);
}
</style>

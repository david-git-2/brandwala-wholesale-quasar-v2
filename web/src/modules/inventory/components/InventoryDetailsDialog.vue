<template>
  <q-dialog v-model="localModelValue" max-width="800px" style="min-width: 600px;">
    <q-card style="width: 750px; max-width: 95vw;">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 font-bold">Inventory Batch Details</div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section v-if="item" class="q-pt-sm">
        <div class="row q-col-gutter-md">
          <!-- Item image and key details -->
          <div class="col-12 col-sm-4 text-center">
            <q-avatar rounded size="120px" class="bg-grey-2 q-mb-sm">
              <img
                :src="item.image_url || 'https://placehold.co/120x120?text=No+Image'"
                alt="Product Image"
                style="object-fit: contain;"
              />
            </q-avatar>
            <div class="text-subtitle1 text-weight-bold">{{ item.name }}</div>
            <div class="text-caption text-grey-7">ID: {{ item.id }}</div>
            <div class="text-caption text-grey-8 q-mt-xs">
              <span class="text-weight-bold">Cost:</span> BDT {{ item.cost ?? '-' }}
            </div>
          </div>

          <!-- Product meta & quantities -->
          <div class="col-12 col-sm-8">
            <q-list dense>
              <q-item>
                <q-item-section>
                  <q-item-label caption>Barcode</q-item-label>
                  <q-item-label>{{ item.barcode ?? '-' }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-item-label caption>Product Code</q-item-label>
                  <q-item-label>{{ item.product_code ?? '-' }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-item-label caption>Shipment Source</q-item-label>
                  <q-item-label>
                    {{ item.shipment?.shipment?.name ? `#${item.shipment.shipment.id} ${item.shipment.shipment.name}` : 'Manual Entry' }}
                  </q-item-label>
                </q-item-section>
              </q-item>
            </q-list>

            <div class="text-subtitle2 q-mt-md q-mb-xs">Quantities Status</div>
            <div class="row q-col-gutter-xs">
              <div v-for="(qty, label) in formattedQuantities" :key="label" class="col-4 text-center">
                <div class="q-pa-xs rounded text-weight-bold border" :class="qty.bg">
                  <div class="text-caption text-grey-9 text-uppercase" style="font-size: 0.7rem;">{{ label }}</div>
                  <div class="text-subtitle1 font-bold">{{ qty.val }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Polymorphic Notes System -->
        <div class="q-mt-lg">
          <InventoryNotesPanel
            :inventory-item-id="item.id"
            :product-id="item.product_id ?? null"
            :tenant-id="item.tenant_id"
          />
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { InventoryItemWithStock } from '../types'
import InventoryNotesPanel from './InventoryNotesPanel.vue'

const props = defineProps<{
  modelValue: boolean
  item: InventoryItemWithStock | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
}>()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const formattedQuantities = computed<Record<string, { val: number; bg: string }>>(() => {
  if (!props.item) return {}
  return {
    usable: { val: props.item.quantities.usable, bg: 'bg-blue-1' },
    available: { val: props.item.quantities.available, bg: 'bg-green-1' },
    reserved: { val: props.item.quantities.reserved, bg: 'bg-indigo-1' },
    damaged: { val: props.item.quantities.damaged, bg: 'bg-red-1' },
    stolen: { val: props.item.quantities.stolen, bg: 'bg-orange-1' },
    expired: { val: props.item.quantities.expired, bg: 'bg-purple-1' },
  }
})
</script>

<style scoped>
.border {
  border: 1px solid rgba(0, 0, 0, 0.08);
}
</style>

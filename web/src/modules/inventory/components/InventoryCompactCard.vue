<template>
  <div class="row q-col-gutter-md q-row-gutter-md">
    <div v-for="item in items" :key="item.id" class="col-12 col-sm-6 col-md-4 col-lg-3">
      <q-card flat bordered class="compact-card">
        <q-card-section class="compact-card__body">
          <SmartImage class="compact-card__image" :src="item.image_url" />
          <div class="text-subtitle2 text-center ellipsis full-width">{{ item.name }}</div>
          <div class="text-body2">Cost: {{ item.cost ?? '-' }}</div>
          <div class="text-caption text-grey-8">
            Shipment: {{ getShipmentId(item) != null ? `#${getShipmentId(item)}` : '-' }}
          </div>
          <div class="text-h6 text-weight-bold">Usable: {{ item.quantities.usable }}</div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import SmartImage from 'src/components/SmartImage.vue'
import type { InventoryItemWithStock } from '../types'

defineProps<{
  items: InventoryItemWithStock[]
}>()

const getShipmentId = (item: InventoryItemWithStock): number | null => {
  const shipmentObj = item.shipment?.shipment
  if (!shipmentObj) return null
  const raw = shipmentObj.id
  const num = typeof raw === 'number' ? raw : Number(raw)
  return Number.isFinite(num) ? num : null
}
</script>

<style scoped>
.compact-card__body {
  display: flex;
  flex-direction: column;
  gap: 8px;
  align-items: center;
}

.compact-card__image {
  width: 1.2in;
  height: 1.2in;
  object-fit: contain;
  background: #fff;
}
</style>

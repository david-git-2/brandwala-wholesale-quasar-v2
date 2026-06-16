<template>
  <div class="row q-col-gutter-md q-row-gutter-md">
    <div v-for="item in items" :key="item.id" class="col-12 col-sm-6 col-md-4 col-lg-3">
      <q-card flat bordered class="compact-card cursor-pointer" @click="emit('view-details', item)">
        <q-card-section class="compact-card__body">
          <div class="column items-center full-width text-center" style="gap: 8px;">
            <SmartImage class="compact-card__image" :src="item.image_url" />
            <div class="text-subtitle2 full-width" style="word-break: break-word; white-space: normal;">{{ item.name }}</div>
            <div class="text-body2 text-grey-9">Cost: {{ item.cost ?? '-' }}</div>
            <div class="text-caption text-grey-8 row items-center justify-center">
              <q-icon name="directions_boat" size="16px" class="q-mr-xs" />
              <span v-if="item.shipment?.shipment">
                #{{ item.shipment.shipment.tenant_shipment_id ?? item.shipment.shipment.id }} - {{ item.shipment.shipment.name }}
              </span>
              <span v-else>-</span>
            </div>
          </div>
          
          <div class="q-mt-sm">
            <div class="text-h6 text-weight-bold text-negative" v-if="item.quantities.stolen > 0">
              Stolen: {{ item.quantities.stolen }}
            </div>
            <div class="text-h6 text-weight-bold text-warning" v-else-if="item.quantities.expired > 0">
              Expired: {{ item.quantities.expired }}
            </div>
            <div class="text-h6 text-weight-bold text-primary" v-else>
              Usable: {{ item.quantities.usable }}
            </div>
          </div>
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

const emit = defineEmits<{
  (e: 'view-details', item: InventoryItemWithStock): void
}>()


</script>

<style scoped>
.compact-card {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.compact-card__body {
  display: flex;
  flex-direction: column;
  gap: 8px;
  align-items: center;
  flex-grow: 1;
  justify-content: space-between;
}

.compact-card__image {
  width: 1.2in;
  height: 1.2in;
  object-fit: contain;
  background: #fff;
}
</style>

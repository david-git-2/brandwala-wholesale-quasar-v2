<template>
  <div class="row q-col-gutter-md">
    <div
      v-for="shipment in shipmentStore.shipments"
      :key="shipment.id"
      class="col-12 col-sm-6"
    >
      <q-card flat bordered @click="emit('select', shipment)" class="cursor-pointer">
        <q-card-section>
          <div class="text-subtitle1 text-weight-medium">
            #{{ shipment.id }} {{ shipment.name }}
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn
            flat
            color="primary"
            label="Edit"
            @click.stop="emit('edit', shipment)"
          />
          <q-btn
            flat
            color="negative"
            label="Delete"
            @click.stop="emit('delete', shipment)"
          />
        </q-card-actions>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useShipmentStore } from '../stores/shipmentStore';


const shipmentStore = useShipmentStore()

const emit = defineEmits<{
  (e: 'edit', shipment: (typeof shipmentStore.shipments)[number]): void
  (e: 'delete', shipment: (typeof shipmentStore.shipments)[number]): void
  (e: 'select', shipment: (typeof shipmentStore.shipments)[number]): void
}>()
</script>

<style scoped>
</style>

<template>
  <div class="row q-col-gutter-md">
    <div
      v-for="shipment in shipmentStore.shipments"
      :key="shipment.id"
      class="col-12 col-sm-6"
    >
      <q-card flat bordered @click="emit('select', shipment)" class="cursor-pointer">
        <q-card-section>
          <div class="row items-center justify-between q-gutter-sm">
            <div class="text-subtitle1 text-weight-medium">
              #{{ shipment.id }} {{ shipment.name }}
            </div>
            <q-chip
              dense
              square
              :color="statusChipColor(shipment.status)"
              text-color="white"
            >
              {{ shipment.status }}
            </q-chip>
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn
            flat
            round
            dense
            color="primary"
            icon="edit"
            aria-label="Edit shipment"
            @click.stop="emit('edit', shipment)"
          >
            <q-tooltip>Edit</q-tooltip>
          </q-btn>
          <q-btn
            flat
            round
            dense
            color="negative"
            icon="delete"
            aria-label="Delete shipment"
            @click.stop="emit('delete', shipment)"
          >
            <q-tooltip>Delete</q-tooltip>
          </q-btn>
        </q-card-actions>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useShipmentStore } from '../stores/shipmentStore';


const shipmentStore = useShipmentStore()

const statusChipColor = (status: string | null | undefined) => {
  if (status === 'Draft') return 'grey-7'
  if (status === 'Order Placed') return 'indigo'
  if (status === 'Proforma Generated') return 'purple-7'
  if (status === 'Payment Done') return 'teal'
  if (status === 'Delivery Date Received') return 'cyan-8'
  if (status === 'Uk Warehouse Delivery Received') return 'blue'
  if (status === 'Air Shipment Date Set') return 'orange-8'
  if (status === 'Airport Arrival') return 'deep-orange'
  if (status === 'Airport Released') return 'brown-7'
  if (status === 'Warehouse Received') return 'positive'
  return 'primary'
}

const emit = defineEmits<{
  (e: 'edit', shipment: (typeof shipmentStore.shipments)[number]): void
  (e: 'delete', shipment: (typeof shipmentStore.shipments)[number]): void
  (e: 'select', shipment: (typeof shipmentStore.shipments)[number]): void
}>()
</script>

<style scoped>
</style>

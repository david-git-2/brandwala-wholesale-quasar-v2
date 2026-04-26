<template>
  <q-dialog v-model="localOpen" persistent>
    <q-card style="min-width: 420px; max-width: 90vw">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6">Add Shipment</div>
        <q-btn flat round dense icon="close" @click="onCancel" />
      </q-card-section>

      <q-separator />

      <q-card-section class="q-gutter-md">
        <q-select
          v-model="form.shipment_id"
          :options="shipmentOptions"
          label="Shipment"
          outlined
          emit-value
          map-options
          :rules="[requiredRule]"
        />

        <q-input
          v-model.number="form.quantity"
          label="Quantity"
          type="number"
          outlined
          :rules="[requiredRule]"
        />

        <q-input
          v-model.number="form.price_gbp"
          label="Price (GBP)"
          type="number"
          step="0.01"
          outlined
        />
      </q-card-section>

      <q-separator />

      <q-card-actions align="right">
        <q-btn flat label="Cancel" color="grey-7" @click="onCancel" />
        <q-btn color="primary" label="Save" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'
import { useShipmentStore } from '../stores/shipmentStore'
type Shipment = {
  id: number
  name: string
}

const props = defineProps<{
  modelValue: boolean
  quantity?: number | null
  priceGbp?: number | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', payload: { shipment_id: number; quantity: number; price_gbp: number | null }): void
}>()

const shipmentStore = useShipmentStore()

const localOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const form = reactive<{
  shipment_id: number | null
  quantity: number | null
  price_gbp: number | null
}>({
  shipment_id: null,
  quantity: props.quantity ?? null,
  price_gbp: props.priceGbp ?? null,
})

watch(
  () => props.modelValue,
  (opened) => {
    if (opened) {
      form.shipment_id = null
      form.quantity = props.quantity ?? null
      form.price_gbp = props.priceGbp ?? null
    }
  }
)

watch(
  () => props.quantity,
  (value) => {
    if (localOpen.value) {
      form.quantity = value ?? null
    }
  }
)

watch(
  () => props.priceGbp,
  (value) => {
    if (localOpen.value) {
      form.price_gbp = value ?? null
    }
  }
)

const shipmentOptions = computed(() =>
  (shipmentStore.shipments ?? []).map((shipment: Shipment) => ({
    label: `#${shipment.id} ${shipment.name}`,
    value: shipment.id,
  }))
)

const requiredRule = (value: unknown) =>
  value !== null && value !== undefined && value !== '' || 'This field is required'

const onCancel = () => {
  localOpen.value = false
}

const onSave = () => {
  if (form.shipment_id == null || form.quantity == null) {
    return
  }

  emit('save', {
    shipment_id: form.shipment_id,
    quantity: Number(form.quantity),
    price_gbp:
      form.price_gbp === null || form.price_gbp === undefined
        ? null
        : Number(form.price_gbp),
  })

  localOpen.value = false
}
</script>

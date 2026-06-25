<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 560px; max-width: 92vw">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div class="text-h6">Shipment Item Details</div>
        <q-btn icon="close" flat round dense @click="emit('update:modelValue', false)" />
      </q-card-section>

      <q-separator />

      <q-card-section v-if="item" class="q-gutter-md">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-4">
            <div class="shipment-item-preview">
              <SmartImage
                :src="item.image_url"
                alt="shipment item"
                imgClass="shipment-item-preview__img"
                fallbackClass="shipment-item-preview__fallback"
                @image-updated="onImageUrlSave"
              />
            </div>
          </div>
          <div class="col-12 col-md-8">
            <div class="text-subtitle1 text-weight-medium q-mb-sm">{{ item.name ?? '-' }}</div>
            <div class="text-caption text-grey-7">#{{ item.id }}</div>
          </div>
        </div>

        <q-markup-table flat bordered>
          <tbody>
            <tr><td class="text-weight-medium">Method</td><td>{{ item.method ?? '-' }}</td></tr>
            <tr><td class="text-weight-medium">Order ID</td><td>{{ item.order_id ?? '-' }}</td></tr>
            <tr><td class="text-weight-medium">Product ID</td><td>{{ item.product_id ?? '-' }}</td></tr>
            <tr><td class="text-weight-medium">Barcode</td><td>{{ item.barcode ?? '-' }}</td></tr>
            <tr><td class="text-weight-medium">Product Code</td><td>{{ item.product_code ?? '-' }}</td></tr>
            <tr><td class="text-weight-medium">Quantity</td><td>{{ item.quantity }}</td></tr>
            <tr><td class="text-weight-medium">Received Quantity</td><td>{{ getReceivedQty(item) }}</td></tr>
            <tr><td class="text-weight-medium">Damaged Quantity</td><td>{{ getDamagedQty(item) }}</td></tr>
            <tr><td class="text-weight-medium">Stolen Quantity</td><td>{{ getStolenQty(item) }}</td></tr>
            <tr><td class="text-weight-medium">Price (GBP)</td><td>{{ displayNumber(item.price_gbp) }}</td></tr>
            <tr><td class="text-weight-medium">Product Weight</td><td>{{ displayNumber(item.product_weight) }}</td></tr>
            <tr><td class="text-weight-medium">Package Weight</td><td>{{ displayNumber(item.package_weight) }}</td></tr>
            <tr>
              <td class="text-weight-medium">Image URL</td>
              <td class="text-break cursor-pointer relative-position">
                <span class="q-pr-md">{{ item.image_url ?? '-' }}</span>
                <q-icon name="edit" size="xs" color="grey-6" class="absolute-right q-mr-sm" />
                <q-popup-edit
                  :model-value="item.image_url ?? ''"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="onImageUrlSave"
                >
                  <q-input
                    v-model="scope.value"
                    dense
                    outlined
                    autofocus
                    label="Image URL"
                  />
                </q-popup-edit>
              </td>
            </tr>
            <tr><td class="text-weight-medium">Created At</td><td>{{ item.created_at }}</td></tr>
            <tr><td class="text-weight-medium">Updated At</td><td>{{ item.updated_at }}</td></tr>
          </tbody>
        </q-markup-table>
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Close" @click="emit('update:modelValue', false)" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import SmartImage from 'src/components/SmartImage.vue'
import type { ShipmentItem } from '../types'
import { getReceivedQty, getDamagedQty, getStolenQty } from '../utils/splits'
import { useShipmentStore } from '../stores/shipmentStore'
import { useProductStore } from 'src/modules/products/stores/productStore'

const props = defineProps<{
  modelValue: boolean
  item: ShipmentItem | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
}>()

const shipmentStore = useShipmentStore()
const productStore = useProductStore()

const onImageUrlSave = async (newUrl: string) => {
  const currentItem = props.item
  if (!currentItem) return

  const trimmedUrl = newUrl.trim() || null

  // 1. Update Shipment Item
  const shipmentItemResult = await shipmentStore.updateShipmentItem({
    id: currentItem.id,
    patch: {
      image_url: trimmedUrl,
    },
  })

  if (!shipmentItemResult.success) {
    return
  }

  // 2. Update linked Product if present
  if (currentItem.product_id != null) {
    await productStore.updateProduct({
      id: currentItem.product_id,
      image_url: trimmedUrl,
    })
  }
}

const displayNumber = (value: number | null | undefined) =>
  value == null ? '-' : String(Number(value))
</script>

<style scoped>
.shipment-item-preview {
  width: 0.65in;
  height: 0.65in;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  overflow: hidden;
  background: #ffffff;
}

.shipment-item-preview__img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

.shipment-item-preview__fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #e5e7eb;
  color: #64748b;
}

.text-break {
  word-break: break-word;
  overflow-wrap: anywhere;
}
</style>

<template>
  <div class="row q-col-gutter-md q-row-gutter-md">
    <div v-for="item in items" :key="item.id" class="col-12 col-lg-6">
      <q-card flat bordered>
        <q-card-section horizontal class="inventory-card__top">
          <div class="inventory-card__media">
            <SmartImage class="inventory-card__image" :src="item.image_url" />
          </div>

          <q-card-section class="col">
            <div class="row items-center justify-between">
              <div class="text-caption text-grey-8">
                Shipment No: {{ getShipmentId(item) ?? '-' }}
              </div>
              <div class="text-h6 text-weight-medium text-right inventory-card__cost">
                Cost: {{ item.cost ?? '-' }}
              </div>
            </div>
            <div class="row items-start justify-between no-wrap q-col-gutter-md">
              <div>
                <div class="text-subtitle1 text-weight-medium">{{ item.name }}</div>
                <div class="text-caption text-grey-7 q-mb-sm">
                  ID: {{ item.id }} | Source: {{ item.source_type }} | Status: {{ item.status }}
                </div>
                <div>Barcode: {{ item.barcode ?? '-' }}</div>
                <div>Product Code: {{ item.product_code ?? '-' }}</div>
                <div class="inventory-card__date-row cursor-pointer">
                  <span class="text-weight-medium">Manufacturing Date:</span>
                  <span>{{ formatCardDate(item.manufacturing_date) }}</span>
                  <q-popup-proxy transition-show="scale" transition-hide="scale">
                    <q-date
                      :model-value="item.manufacturing_date"
                      mask="YYYY-MM-DD"
                      @update:model-value="(value) => onDateSave(item, 'manufacturing_date', value)"
                    >
                      <div class="row items-center justify-end q-pa-sm">
                        <q-btn v-close-popup flat label="Close" />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </div>
                <div class="inventory-card__date-row cursor-pointer">
                  <span class="text-weight-medium">Expire Date:</span>
                  <span>{{ formatCardDate(item.expire_date) }}</span>
                  <q-popup-proxy transition-show="scale" transition-hide="scale">
                    <q-date
                      :model-value="item.expire_date"
                      mask="YYYY-MM-DD"
                      @update:model-value="(value) => onDateSave(item, 'expire_date', value)"
                    >
                      <div class="row items-center justify-end q-pa-sm">
                        <q-btn v-close-popup flat label="Close" />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </div>
              </div>
              <div class="column items-end q-gutter-sm">


              </div>
            </div>
<div class="row justify-end q-mt-md"> <q-btn
                  color="negative"
                  outline
                  size="sm"
                  icon="delete"
                  label="Delete"
                  @click="emit('delete-item', item)"
                /></div>
          </q-card-section>

        </q-card-section>

        <q-separator />

        <q-card-section>
          <div class="text-subtitle2 q-mb-sm">Quantities</div>

          <table class="inventory-card__table">
            <thead>
              <tr>
                <th class="qty-col qty-col--available">Available</th>
                <th class="qty-col qty-col--reserved">Reserved</th>
                <th class="qty-col qty-col--damaged">Damaged</th>
                <th class="qty-col qty-col--stolen">Stolen</th>
                <th class="qty-col qty-col--expired">Expired</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="qty-col qty-col--available">
                  <div class="cursor-pointer inventory-card__qty-value">
                    {{ item.quantities.available }}
                    <q-popup-edit
                      :model-value="item.quantities.available"
                      buttons
                      label-set="Save"
                      label-cancel="Cancel"
                      @save="(value) => onQuantitySave(item, 'available', value)"
                      v-slot="scope"
                    >
                      <q-input v-model.number="scope.value" type="number" dense autofocus />
                    </q-popup-edit>
                  </div>
                </td>
                <td class="qty-col qty-col--reserved">
                  <div class="cursor-pointer inventory-card__qty-value">
                    {{ item.quantities.reserved }}
                    <q-popup-edit
                      :model-value="item.quantities.reserved"
                      buttons
                      label-set="Save"
                      label-cancel="Cancel"
                      @save="(value) => onQuantitySave(item, 'reserved', value)"
                      v-slot="scope"
                    >
                      <q-input v-model.number="scope.value" type="number" dense autofocus />
                    </q-popup-edit>
                  </div>
                </td>
                <td class="qty-col qty-col--damaged">
                  <div class="cursor-pointer inventory-card__qty-value">
                    {{ item.quantities.damaged }}
                    <q-popup-edit
                      :model-value="item.quantities.damaged"
                      buttons
                      label-set="Save"
                      label-cancel="Cancel"
                      @save="(value) => onQuantitySave(item, 'damaged', value)"
                      v-slot="scope"
                    >
                      <q-input v-model.number="scope.value" type="number" dense autofocus />
                    </q-popup-edit>
                  </div>
                </td>
                <td class="qty-col qty-col--stolen">
                  <div class="cursor-pointer inventory-card__qty-value">
                    {{ item.quantities.stolen }}
                    <q-popup-edit
                      :model-value="item.quantities.stolen"
                      buttons
                      label-set="Save"
                      label-cancel="Cancel"
                      @save="(value) => onQuantitySave(item, 'stolen', value)"
                      v-slot="scope"
                    >
                      <q-input v-model.number="scope.value" type="number" dense autofocus />
                    </q-popup-edit>
                  </div>
                </td>
                <td class="qty-col qty-col--expired">
                  <div class="cursor-pointer inventory-card__qty-value">
                    {{ item.quantities.expired }}
                    <q-popup-edit
                      :model-value="item.quantities.expired"
                      buttons
                      label-set="Save"
                      label-cancel="Cancel"
                      @save="(value) => onQuantitySave(item, 'expired', value)"
                      v-slot="scope"
                    >
                      <q-input v-model.number="scope.value" type="number" dense autofocus />
                    </q-popup-edit>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
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

type QuantityKey = 'available' | 'reserved' | 'damaged' | 'stolen' | 'expired'

const emit = defineEmits<{
  (e: 'save-quantity', payload: { item: InventoryItemWithStock; field: QuantityKey; value: number }): void
  (e: 'save-date', payload: { item: InventoryItemWithStock; field: 'manufacturing_date' | 'expire_date'; value: string | null }): void
  (e: 'delete-item', item: InventoryItemWithStock): void
}>()

const toNonNegativeInt = (value: unknown) => {
  const next = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(next) || next < 0) {
    return 0
  }
  return Math.floor(next)
}

const onQuantitySave = (item: InventoryItemWithStock, field: QuantityKey, value: unknown) => {
  emit('save-quantity', {
    item,
    field,
    value: toNonNegativeInt(value),
  })
}

const onDateSave = (
  item: InventoryItemWithStock,
  field: 'manufacturing_date' | 'expire_date',
  value: unknown,
) => {
  const nextValue = typeof value === 'string' && value.trim() ? value.trim() : null
  emit('save-date', { item, field, value: nextValue })
}

const formatCardDate = (value: string | null) => {
  if (!value) return '-'
  const [year, month, day] = value.split('-')
  if (!year || !month || !day) return value
  return `${day}/${month}/${year}`
}

const getShipmentId = (item: InventoryItemWithStock): number | null => {
  const shipmentObj = item.shipment?.shipment
  if (!shipmentObj) return null
  const raw = shipmentObj.id
  const num = typeof raw === 'number' ? raw : Number(raw)
  return Number.isFinite(num) ? num : null
}
</script>

<style scoped>
.inventory-card__top {
  align-items: stretch;
}

.inventory-card__media {
  width: 1in;
  min-width: 1in;
  display: flex;
  align-items: center;
  justify-content: center;
}

.inventory-card__image {
  width: 1in;
  height: 1in;
  object-fit: contain;
}

.inventory-card__cost {
  min-width: 180px;
}

.inventory-card__date-row {
  display: flex;
  gap: 6px;
  align-items: center;
}

.inventory-card__table {
  width: 100%;
  border-collapse: collapse;
}

.inventory-card__table td {
  vertical-align: top;
  padding: 8px 10px 8px 0;
}

.inventory-card__table th {
  text-align: left;
  font-weight: 600;
  padding: 0 10px 8px 0;
}

.inventory-card__qty-value {
  font-size: 1.15rem;
  font-weight: 600;
}

.qty-col {
  padding: 8px 10px !important;
  border-radius: 0;
}

.qty-col--available {
  background: #eaf7ef;
}

.qty-col--reserved {
  background: #eef4ff;
}

.qty-col--damaged {
  background: #fff1f0;
}

.qty-col--stolen {
  background: #fff8e9;
}

.qty-col--expired {
  background: #f5f1fb;
}
</style>

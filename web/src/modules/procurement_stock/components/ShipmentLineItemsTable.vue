<template>
  <div class="shipment-line-items">
    <q-card-section class="q-pa-none shipment-table-scroll-wrap">
      <q-inner-loading :showing="loading" />
      <q-markup-table flat class="shipment-details-table">
        <thead>
          <tr>
            <th class="text-right shipment-sl-col">SL</th>
            <th class="text-left shipment-image-col">Image</th>
            <th v-if="isColumnVisible('name')" class="text-left shipment-name-col">Name</th>
            <th v-if="isColumnVisible('product_id')" class="text-left shipment-product-id-col">Product ID</th>
            <th v-if="isColumnVisible('barcode')" class="text-left shipment-barcode-col">Barcode</th>
            <th v-if="isColumnVisible('product_code')" class="text-left shipment-product-code-col">Product Code</th>
            <th v-if="isColumnVisible('add_method')" class="text-left shipment-method-col">Method</th>
            <th v-if="isColumnVisible('purchase_price')" class="text-right shipment-price-col">Price {{ purchaseCurrencySymbol }}</th>
            <th v-if="isColumnVisible('cost_bdt')" class="text-right shipment-cost-col">Cost {{ costCurrencySymbol }}</th>
            <th v-if="isColumnVisible('ordered_quantity')" class="text-right shipment-qty-col shipment-qty-col--quantity">Quantity</th>
            <th v-if="isColumnVisible('product_weight')" class="text-right shipment-product-weight-col">Product Wt</th>
            <th v-if="isColumnVisible('package_weight')" class="text-right shipment-package-weight-col">Package Wt</th>
            <th v-if="isColumnVisible('actions')" class="text-right shipment-actions-col">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, index) in items" :key="item.id">
            <td class="text-right shipment-sl-col">{{ index + 1 }}</td>
            <td class="shipment-image-col">
              <div class="shipment-item-image-box">
                <SmartImage
                  :src="item.image_url"
                  alt="shipment item"
                  img-class="shipment-item-image"
                  fallback-class="shipment-item-image-fallback"
                  :enable-edit="false"
                />
              </div>
            </td>
            <td
              v-if="isColumnVisible('name')"
              class="shipment-item-name-cell shipment-name-col"
              :class="{ 'cursor-pointer': isEditable }"
              @click="isEditable && emit('edit-details', item)"
            >
              {{ item.name ?? '-' }}
            </td>
            <td v-if="isColumnVisible('product_id')" class="shipment-product-id-col">{{ item.product_id ?? '-' }}</td>
            <td v-if="isColumnVisible('barcode')" class="shipment-barcode-col">{{ item.barcode ?? '-' }}</td>
            <td v-if="isColumnVisible('product_code')" class="shipment-product-code-col">{{ item.product_code ?? '-' }}</td>
            <td v-if="isColumnVisible('add_method')" class="text-uppercase shipment-method-col">{{ item.add_method ?? '-' }}</td>
            <td v-if="isColumnVisible('purchase_price')" class="text-right shipment-price-col">
              <span :class="{ 'cursor-pointer': isEditable }">{{ formatFixed2(item.purchase_price) }}</span>
              <q-popup-edit
                v-if="isEditable"
                :model-value="item.purchase_price"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                v-slot="scope"
                @save="(value) => onNumericSave(item, 'purchase_price', value, { decimals: 2 })"
              >
                <q-input
                  :model-value="scope.value ?? ''"
                  type="number"
                  step="0.01"
                  dense
                  outlined
                  autofocus
                  @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </td>
            <td v-if="isColumnVisible('cost_bdt')" class="text-right shipment-cost-col">
              {{ formatFixed2(lineCostBdt(item)) }}
            </td>
            <td
              v-if="isColumnVisible('ordered_quantity')"
              class="text-right shipment-qty-col shipment-qty-col--quantity"
            >
              <span :class="{ 'cursor-pointer': isEditable }">{{ item.ordered_quantity }}</span>
              <q-popup-edit
                v-if="isEditable"
                :model-value="item.ordered_quantity"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                v-slot="scope"
                @save="(value) => onNumericSave(item, 'ordered_quantity', value)"
              >
                <q-input
                  :model-value="scope.value ?? ''"
                  type="number"
                  dense
                  outlined
                  autofocus
                  min="1"
                  @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </td>
            <td v-if="isColumnVisible('product_weight')" class="text-right shipment-product-weight-col">
              <span :class="{ 'cursor-pointer': isEditable }">{{ formatDecimal(item.product_weight) }}</span>
              <q-popup-edit
                v-if="isEditable"
                :model-value="item.product_weight"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                v-slot="scope"
                @save="(value) => onNumericSave(item, 'product_weight', value, { decimals: 3 })"
              >
                <q-input
                  :model-value="scope.value ?? ''"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  autofocus
                  @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </td>
            <td v-if="isColumnVisible('package_weight')" class="text-right shipment-package-weight-col">
              <span :class="{ 'cursor-pointer': isEditable }">{{ formatDecimal(item.package_weight) }}</span>
              <q-popup-edit
                v-if="isEditable"
                :model-value="item.package_weight"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                v-slot="scope"
                @save="(value) => onNumericSave(item, 'package_weight', value, { decimals: 3 })"
              >
                <q-input
                  :model-value="scope.value ?? ''"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  autofocus
                  @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </td>
            <td v-if="isColumnVisible('actions')" class="text-right shipment-actions-col">
              <q-btn v-if="isEditable" flat round dense icon="more_vert">
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable @click="emit('edit-details', item)">
                      <q-item-section>Edit details</q-item-section>
                    </q-item>
                    <q-item clickable class="text-negative" @click="emit('delete', item.id)">
                      <q-item-section>Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </td>
          </tr>

          <tr v-if="items.length" class="shipment-total-row">
            <td class="shipment-sl-col" />
            <td class="shipment-image-col" />
            <td v-if="isColumnVisible('name')" class="shipment-name-col" />
            <td v-if="isColumnVisible('product_id')" />
            <td v-if="isColumnVisible('barcode')" />
            <td v-if="isColumnVisible('product_code')" />
            <td v-if="isColumnVisible('add_method')" />
            <td v-if="isColumnVisible('purchase_price')" class="text-right text-weight-bold">
              {{ formatFixed2(tableTotals.price_gbp) }}
            </td>
            <td v-if="isColumnVisible('cost_bdt')" class="text-right text-weight-bold">
              {{ formatFixed2(tableTotals.cost_bdt) }}
            </td>
            <td
              v-if="isColumnVisible('ordered_quantity')"
              class="text-right shipment-qty-col shipment-qty-col--quantity text-weight-bold"
            >
              {{ tableTotals.quantity }}
            </td>
            <td v-if="isColumnVisible('product_weight')" class="text-right text-weight-bold">
              {{ formatFixed2(tableTotals.product_weight) }}
            </td>
            <td v-if="isColumnVisible('package_weight')" class="text-right text-weight-bold">
              {{ formatFixed2(tableTotals.package_weight) }}
            </td>
            <td v-if="isColumnVisible('actions')" />
          </tr>

          <tr v-if="!items.length && !loading">
            <td :colspan="tableColspan" class="text-center text-grey-6 q-pa-md">
              No shipment items yet. Use Add Items to get started.
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card-section>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useQuasar } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import type { GlobalShipment, GlobalShipmentItem } from '../repositories/globalShipmentRepository'
import { calculateLineLandedCostBdt } from '../utils/landedCost'
import { syncShipmentWeightToProduct } from '../utils/syncShipmentWeightToProduct'

const props = withDefaults(
  defineProps<{
    items: GlobalShipmentItem[]
    shipment: GlobalShipment | null
    loading?: boolean
    visibleColumns?: ColumnKey[]
    purchaseCurrencySymbol?: string
    costCurrencySymbol?: string
  }>(),
  {
    purchaseCurrencySymbol: '£',
    costCurrencySymbol: '৳',
  },
)

const emit = defineEmits<{
  'edit-details': [item: GlobalShipmentItem]
  delete: [id: number]
}>()

const $q = useQuasar()
const shipmentStore = useGlobalShipmentStore()

const baseColumnOptions = [
  { label: 'Name', value: 'name' },
  { label: 'Product ID', value: 'product_id' },
  { label: 'Barcode', value: 'barcode' },
  { label: 'Product Code', value: 'product_code' },
  { label: 'Method', value: 'add_method' },
  { label: 'Price GBP', value: 'purchase_price' },
  { label: 'Cost BDT', value: 'cost_bdt' },
  { label: 'Quantity', value: 'ordered_quantity' },
  { label: 'Product Wt', value: 'product_weight' },
  { label: 'Package Wt', value: 'package_weight' },
  { label: 'Actions', value: 'actions' },
] as const

export type ColumnKey = (typeof baseColumnOptions)[number]['value']

const internalVisibleColumns = ref<ColumnKey[]>([
  'name',
  'product_id',
  'barcode',
  'product_code',
  'add_method',
  'purchase_price',
  'cost_bdt',
  'ordered_quantity',
  'product_weight',
  'package_weight',
  'actions',
])

const activeVisibleColumns = computed(() => props.visibleColumns ?? internalVisibleColumns.value)

const isInternational = computed(() => props.shipment?.type === 'international')

const columnOptions = computed(() =>
  baseColumnOptions
    .filter((opt) => {
      if (!isInternational.value) {
        return !['purchase_price', 'product_weight', 'package_weight'].includes(opt.value)
      }
      return true
    })
    .map((opt) => {
      if (opt.value === 'purchase_price') {
        return { label: `Price ${props.purchaseCurrencySymbol}`, value: 'purchase_price' as ColumnKey }
      }
      if (opt.value === 'cost_bdt') {
        return { label: `Cost ${props.costCurrencySymbol}`, value: 'cost_bdt' as ColumnKey }
      }
      return opt
    }),
)

const isEditable = computed(() => {
  if (!props.shipment) return false
  return !props.shipment.stock_ready && props.shipment.status !== 'Ready Stock'
})

const isColumnVisible = (column: ColumnKey) => activeVisibleColumns.value.includes(column)

const tableColspan = computed(() => {
  let count = 2
  for (const opt of columnOptions.value) {
    if (isColumnVisible(opt.value)) count++
  }
  return count
})

const formatDecimal = (value: number | null | undefined) =>
  value == null ? '-' : String(Number(value))

const formatFixed2 = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const lineCostBdt = (item: GlobalShipmentItem) => {
  if (!props.shipment) return 0
  return calculateLineLandedCostBdt(item, props.shipment)
}

const tableTotals = computed(() =>
  props.items.reduce(
    (acc, item) => {
      const qty = Number(item.ordered_quantity ?? 0)
      const unitCost = lineCostBdt(item)
      acc.price_gbp += Number(item.purchase_price ?? 0) * qty
      acc.cost_bdt += unitCost * qty
      acc.quantity += qty
      acc.product_weight += Number(item.product_weight ?? 0)
      acc.package_weight += Number(item.package_weight ?? 0)
      return acc
    },
    { price_gbp: 0, cost_bdt: 0, quantity: 0, product_weight: 0, package_weight: 0 },
  ),
)

type EditableField = 'purchase_price' | 'ordered_quantity' | 'product_weight' | 'package_weight'

const roundTo = (value: number, decimals = 0) => {
  const factor = 10 ** decimals
  return Math.round(value * factor) / factor
}

const onNumericSave = async (
  item: GlobalShipmentItem,
  field: EditableField,
  value: string | number | null,
  options?: { decimals?: number },
) => {
  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed < 0) {
    $q.notify({ type: 'warning', message: 'Value must be 0 or greater.' })
    return
  }

  let normalized = options?.decimals != null ? roundTo(parsed, options.decimals) : Math.floor(parsed)
  if (field === 'ordered_quantity') {
    normalized = Math.max(1, Math.floor(parsed))
  }

  try {
    await shipmentStore.updateShipmentItem(item.id, { [field]: normalized })
    if ((field === 'product_weight' || field === 'package_weight') && item.product_id != null) {
      await syncShipmentWeightToProduct(item.product_id, field, normalized)
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to update item.'
    $q.notify({ type: 'negative', message: msg })
  }
}

defineExpose({
  columnOptions,
  internalVisibleColumns,
})
</script>

<style scoped>
.shipment-table-scroll-wrap {
  overflow: visible;
  position: relative;
}

.shipment-details-table {
  min-width: 0;
  max-width: 100%;
  height: clamp(400px, calc(100vh - 320px), 80vh);
  background: var(--bw-theme-base, #eef2f5);
  overflow: auto;
}

.shipment-details-table :deep(table) {
  table-layout: fixed;
  border-collapse: separate;
  border-spacing: 0;
  min-width: max-content;
  width: max-content;
}

.shipment-details-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
  box-shadow: inset 0 -1px 0 rgba(148, 163, 184, 0.25);
}

.shipment-item-image-box {
  width: 1in;
  height: 1in;
  display: flex;
  align-items: center;
  justify-content: center;
}

.shipment-details-table :deep(.shipment-item-image) {
  max-width: 1in;
  max-height: 1in;
  object-fit: contain;
}

.shipment-item-name-cell {
  white-space: normal;
  word-break: break-word;
  line-height: 1.25;
}

.shipment-sl-col {
  width: 60px;
  min-width: 60px;
  max-width: 60px;
}

.shipment-image-col {
  width: 1.2in;
  min-width: 1.2in;
  max-width: 1.2in;
}

.shipment-name-col {
  width: 220px;
  min-width: 220px;
  max-width: 220px;
}

.shipment-product-id-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-barcode-col,
.shipment-product-code-col {
  width: 170px;
  min-width: 170px;
  max-width: 170px;
}

.shipment-method-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-price-col,
.shipment-product-weight-col,
.shipment-package-weight-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-cost-col {
  width: 120px;
  min-width: 120px;
  max-width: 120px;
}

.shipment-actions-col {
  width: 80px;
  min-width: 80px;
  max-width: 80px;
}

.shipment-qty-col--quantity {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
  background: #eaf7ef;
}

.shipment-details-table :deep(td.shipment-qty-col--quantity) {
  background: #eaf7ef;
}

.shipment-details-table :deep(thead tr th.shipment-qty-col--quantity) {
  background: #eaf7ef;
}

.shipment-details-table :deep(td:first-child),
.shipment-details-table :deep(th:first-child) {
  position: sticky;
  left: 0;
}

.shipment-details-table :deep(td:nth-child(2)),
.shipment-details-table :deep(th:nth-child(2)) {
  position: sticky;
  left: 60px;
}

.shipment-details-table :deep(td:nth-child(3)),
.shipment-details-table :deep(th:nth-child(3)) {
  position: sticky;
  left: calc(60px + 1.2in);
}

.shipment-details-table :deep(td:first-child) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.shipment-details-table :deep(td:nth-child(2)),
.shipment-details-table :deep(td:nth-child(3)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-details-table :deep(tr:first-child th:first-child),
.shipment-details-table :deep(tr:first-child th:nth-child(2)),
.shipment-details-table :deep(tr:first-child th:nth-child(3)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-total-row td {
  background: rgba(255, 255, 255, 0.85);
  font-weight: 600;
}

@media (max-width: 1023px) {
  .shipment-details-table {
    height: clamp(320px, calc(100vh - 260px), 65vh);
  }
}

:deep(input[type="number"]::-webkit-outer-spin-button),
:deep(input[type="number"]::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(input[type="number"]) {
  -moz-appearance: textfield;
}
</style>

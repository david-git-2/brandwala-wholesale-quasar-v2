<template>
  <div class="product-based-costing-table">
    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="columns"
      row-key="id"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      class="costing-q-table"
    >
      <template #body="slotProps">
        <q-tr :props="slotProps">
          <q-td key="sl" :props="slotProps" class="col-sl text-center">
            {{ slotProps.row.sl }}
          </q-td>

          <q-td key="image" :props="slotProps" class="col-image text-center">
            <SmartImage
              :src="slotProps.row.imageUrl"
              :alt="slotProps.row.name || 'Product image'"
              img-class="table-image"
              fallback-class="table-image-placeholder"
            />
          </q-td>

          <q-td key="name" :props="slotProps" class="col-name">
            {{ slotProps.row.name }}
          </q-td>

          <q-td key="qty" :props="slotProps" class="col-qty text-center editable-cell">
            <div class="editable-value">
              {{ slotProps.row.qty }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.qty"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="(value) => {
                slotProps.row.qty = toNumber(value)
                onQtySave(slotProps.row)
              }"
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td key="barcodeText" :props="slotProps" class="col-barcode">
            {{ slotProps.row.barcodeText }}
          </q-td>

          <q-td key="website" :props="slotProps" class="col-website">
            <a
              v-if="slotProps.row.website"
              :href="slotProps.row.website"
              target="_blank"
              rel="noopener noreferrer"
            >
              Open
            </a>
            <span v-else>-</span>
          </q-td>

          <q-td key="priceGbp" :props="slotProps" class="col-price-gbp text-right">
            {{ formatNumber(slotProps.row.priceGbp) }}
          </q-td>

          <q-td key="productWeight" :props="slotProps" class="col-product-weight text-right editable-cell">
            <div class="editable-value">
              {{ formatNumber(slotProps.row.productWeight) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.productWeight"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="(value) => {
                slotProps.row.productWeight = toNumber(value)
                onProductWeightSave(slotProps.row)
              }"
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td key="packageWeight" :props="slotProps" class="col-package-weight text-right editable-cell">
            <div class="editable-value">
              {{ formatNumber(slotProps.row.packageWeight) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.packageWeight"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="(value) => {
                slotProps.row.packageWeight = toNumber(value)
                onPackageWeightSave(slotProps.row)
              }"
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td key="totalWeight" :props="slotProps" class="col-total-weight text-right">
            {{ formatNumber(getTotalWeight(slotProps.row)) }}
          </q-td>

          <q-td key="cargoRate" :props="slotProps" class="col-cargo-rate text-right">
            {{ formatNumber(slotProps.row.cargoRate) }}
          </q-td>

          <q-td key="cargoCostGbp" :props="slotProps" class="col-cargo-cost-gbp text-right">
            {{ formatNumber(getCargoCostGbp(slotProps.row)) }}
          </q-td>

          <q-td key="totalCostGbp" :props="slotProps" class="col-total-cost-gbp text-right">
            {{ formatNumber(getTotalCostGbp(slotProps.row)) }}
          </q-td>

          <q-td key="costBdt" :props="slotProps" class="col-cost-bdt text-right">
            {{ formatNumber(getCostBdt(slotProps.row)) }}
          </q-td>

          <q-td key="totalCostBdt" :props="slotProps" class="col-total-cost-bdt text-right">
            {{ formatNumber(getTotalCostBdt(slotProps.row)) }}
          </q-td>

          <q-td key="offerPriceBdt" :props="slotProps" class="col-offer-price-bdt text-right editable-cell">
            <div class="editable-value">
              {{ formatNumber(slotProps.row.offerPriceBdt) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.offerPriceBdt"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="(value) => {
                slotProps.row.offerPriceBdt = toNumber(value)
                onOfferPriceBdtSave(slotProps.row)
              }"
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td key="totalBdt" :props="slotProps" class="col-total-bdt text-right">
            {{ formatNumber(getTotalBdt(slotProps.row)) }}
          </q-td>

          <q-td key="profitBdt" :props="slotProps" class="col-profit-bdt text-right">
            {{ formatNumber(getProfitBdt(slotProps.row)) }}
          </q-td>

          <q-td key="profitRate" :props="slotProps" class="col-profit-rate text-right">
            {{ formatNumber(slotProps.row.profitRate) }}
          </q-td>

          <q-td key="status" :props="slotProps" class="col-status text-center editable-cell">
            <q-badge
              :color="getStatusColor(slotProps.row.status)"
              outline
            >
              {{ slotProps.row.status }}
            </q-badge>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.status"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="(value) => {
                slotProps.row.status = toText(value, 'pending').toLowerCase()
                onStatusSave(slotProps.row)
              }"
            >
              <q-select
                v-model="scope.value"
                :options="statusOptions"
                dense
                outlined
                emit-value
                map-options
                autofocus
              />
            </q-popup-edit>
          </q-td>

          <q-td key="action" :props="slotProps" class="col-action">
            <div class="row items-center justify-center q-gutter-xs">
              <q-btn
                icon="edit"
                flat
                round
                dense
                @click="onEdit(slotProps.row)"
              />
              <q-btn
                icon="delete"
                flat
                round
                dense
                color="negative"
                @click="onDelete(slotProps.row)"
              />
            </div>
          </q-td>
        </q-tr>
      </template>

      <template #no-data>
        <div class="full-width row flex-center q-pa-md text-grey-7">
          No items found
        </div>
      </template>
    </q-table>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useQuasar, type QTableColumn } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'

interface ProductBasedCostingItem {
  id: number
  product_based_costing_file_id: number | null
  name: string | null
  image_url: string | null
  quantity: number | null
  barcode: string | null
  product_code: string | null
  web_link: string | null
  price_gbp: number | null
  product_weight: number | null
  package_weight: number | null
  offer_price: number | null
  status: string | null
  created_at: string
  updated_at: string
}

interface ProductBasedCostingTableRow {
  id: number
  sl: number
  name: string
  imageUrl: string | null
  qty: number
  barcodeText: string
  website: string | null
  priceGbp: number
  productWeight: number
  packageWeight: number
  cargoRate: number
  conversionRate: number
  profitRate: number
  offerPriceBdt: number
  status: string
  raw: ProductBasedCostingItem
}

const props = withDefaults(
  defineProps<{
    items: ProductBasedCostingItem[]
    cargoRate?: number
    conversionRate?: number
    profitRate?: number
  }>(),
  {
    cargoRate: 0,
    conversionRate: 0,
    profitRate: 0,
  },
)

const emit = defineEmits<{
  (e: 'edit', item: ProductBasedCostingItem): void
  (e: 'delete', item: ProductBasedCostingItem): void
  (e: 'row-change', payload: {
    item: ProductBasedCostingItem
    row: ProductBasedCostingTableRow
    field: 'quantity' | 'offer_price' | 'status'
  }): void
  (e: 'product-weight-change', payload: {
    item: ProductBasedCostingItem
    row: ProductBasedCostingTableRow
    field: 'product_weight'
  }): void
  (e: 'package-weight-change', payload: {
    item: ProductBasedCostingItem
    row: ProductBasedCostingTableRow
    field: 'package_weight'
  }): void
}>()

const $q = useQuasar()

const statusOptions = [
  { label: 'Pending', value: 'pending' },
  { label: 'Accepted', value: 'accepted' },
  { label: 'Rejected', value: 'rejected' },
]

const toNumber = (value: unknown) => {
  const num = Number(value ?? 0)
  return Number.isNaN(num) ? 0 : num
}

const toText = (value: unknown, fallback = '-') => {
  if (typeof value !== 'string') return fallback
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : fallback
}

const formatNumber = (value: number | null | undefined) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return '-'
  }

  return Number(value).toFixed(2)
}

const buildRows = (): ProductBasedCostingTableRow[] => {
  return (props.items ?? []).map((item, index) => {
    const barcode = toText(item.barcode, '')
    const productCode = toText(item.product_code, '')
    const barcodeParts = [barcode, productCode, String(item.id)].filter(Boolean)

    return {
      id: item.id,
      sl: index + 1,
      name: toText(item.name),
      imageUrl: item.image_url ?? null,
      qty: toNumber(item.quantity),
      barcodeText: barcodeParts.length ? barcodeParts.join(' / ') : '-',
      website: item.web_link ?? null,
      priceGbp: toNumber(item.price_gbp),
      productWeight: toNumber(item.product_weight),
      packageWeight: toNumber(item.package_weight),
      cargoRate: toNumber(props.cargoRate),
      conversionRate: toNumber(props.conversionRate),
      profitRate: toNumber(props.profitRate),
      offerPriceBdt: toNumber(item.offer_price),
      status: toText(item.status, 'pending').toLowerCase(),
      raw: { ...item },
    }
  })
}

const tableRows = ref<ProductBasedCostingTableRow[]>([])

watch(
  () => [props.items, props.cargoRate, props.conversionRate, props.profitRate],
  () => {
    tableRows.value = buildRows()
  },
  { immediate: true, deep: true },
)

const columns = computed<QTableColumn[]>(() => [
  { name: 'sl', label: 'SL', field: 'sl', align: 'center' },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'center' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'qty', label: 'Qty', field: 'qty', align: 'center' },
  { name: 'barcodeText', label: 'Barcode / Code / Product ID', field: 'barcodeText', align: 'left' },
  { name: 'website', label: 'Website', field: 'website', align: 'left' },

  { name: 'priceGbp', label: 'Price (GBP)', field: 'priceGbp', align: 'right', classes: 'bg-gbp', headerClasses: 'bg-gbp' },
  { name: 'productWeight', label: 'Product Wt (g)', field: 'productWeight', align: 'right' },
  { name: 'packageWeight', label: 'Package Wt (g)', field: 'packageWeight', align: 'right' },
  { name: 'totalWeight', label: 'Total Wt (g)', field: 'totalWeight', align: 'right' },
  { name: 'cargoRate', label: 'Cargo Rate', field: 'cargoRate', align: 'right' },
  { name: 'cargoCostGbp', label: 'Cargo Cost (GBP)', field: 'cargoCostGbp', align: 'right', classes: 'bg-gbp', headerClasses: 'bg-gbp' },
  { name: 'totalCostGbp', label: 'Total Cost (GBP)', field: 'totalCostGbp', align: 'right', classes: 'bg-gbp', headerClasses: 'bg-gbp' },

  { name: 'costBdt', label: 'Cost (BDT)', field: 'costBdt', align: 'right', classes: 'bg-bdt', headerClasses: 'bg-bdt' },
  { name: 'totalCostBdt', label: 'Total Cost (BDT)', field: 'totalCostBdt', align: 'right', classes: 'bg-bdt', headerClasses: 'bg-bdt' },
  { name: 'offerPriceBdt', label: 'Offer Price (BDT)', field: 'offerPriceBdt', align: 'right', classes: 'bg-offer', headerClasses: 'bg-offer' },
  { name: 'totalBdt', label: 'Total (BDT)', field: 'totalBdt', align: 'right', classes: 'bg-bdt', headerClasses: 'bg-bdt' },
  { name: 'profitBdt', label: 'Profit (BDT)', field: 'profitBdt', align: 'right', classes: 'bg-bdt', headerClasses: 'bg-bdt' },

  { name: 'profitRate', label: 'Profit Rate (%)', field: 'profitRate', align: 'right' },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'action', label: 'Action', field: 'action', align: 'center' },
])

const getTotalWeight = (row: ProductBasedCostingTableRow) => {
  return (row.productWeight + row.packageWeight) * row.qty
}

const getCargoCostGbp = (row: ProductBasedCostingTableRow) => {
  return (getTotalWeight(row) / 1000) * row.cargoRate
}

const getTotalCostGbp = (row: ProductBasedCostingTableRow) => {
  return row.priceGbp + getCargoCostGbp(row)
}

const getCostBdt = (row: ProductBasedCostingTableRow) => {
  return getTotalCostGbp(row) * row.conversionRate
}

const getTotalCostBdt = (row: ProductBasedCostingTableRow) => {
  return getCostBdt(row) * row.qty
}

const getTotalBdt = (row: ProductBasedCostingTableRow) => {
  return row.offerPriceBdt > 0 ? row.offerPriceBdt * row.qty : getTotalCostBdt(row)
}

const getProfitBdt = (row: ProductBasedCostingTableRow) => {
  return getTotalBdt(row) * (row.profitRate / 100)
}

const emitRowChange = (
  row: ProductBasedCostingTableRow,
  field: 'quantity' | 'offer_price' | 'status',
) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    offer_price: row.offerPriceBdt,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
  }

  row.raw = updatedItem

  emit('row-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field,
  })
}

const emitProductWeightChange = (row: ProductBasedCostingTableRow) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    offer_price: row.offerPriceBdt,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
  }

  row.raw = updatedItem

  emit('product-weight-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field: 'product_weight',
  })
}

const emitPackageWeightChange = (row: ProductBasedCostingTableRow) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    offer_price: row.offerPriceBdt,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
  }

  row.raw = updatedItem

  emit('package-weight-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field: 'package_weight',
  })
}

const onQtySave = (row: ProductBasedCostingTableRow) => {
  row.qty = toNumber(row.qty)
  emitRowChange(row, 'quantity')
}

const onOfferPriceBdtSave = (row: ProductBasedCostingTableRow) => {
  row.offerPriceBdt = toNumber(row.offerPriceBdt)
  emitRowChange(row, 'offer_price')
}

const onStatusSave = (row: ProductBasedCostingTableRow) => {
  row.status = toText(row.status, 'pending').toLowerCase()
  emitRowChange(row, 'status')
}

const onProductWeightSave = (row: ProductBasedCostingTableRow) => {
  row.productWeight = toNumber(row.productWeight)
  emitProductWeightChange(row)
}

const onPackageWeightSave = (row: ProductBasedCostingTableRow) => {
  row.packageWeight = toNumber(row.packageWeight)
  emitPackageWeightChange(row)
}

const onEdit = (row: ProductBasedCostingTableRow) => {
  emit('edit', row.raw)
}

const onDelete = (row: ProductBasedCostingTableRow) => {
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete #${row.id} ${row.name || ''}?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    emit('delete', row.raw)
  })
}

const getStatusColor = (status: string | null) => {
  switch ((status || '').toLowerCase()) {
    case 'pending':
      return 'warning'
    case 'accepted':
      return 'positive'
    case 'rejected':
      return 'negative'
    default:
      return 'grey'
  }
}
</script>

<style scoped>
.product-based-costing-table {
  width: 100%;
}

.costing-q-table {
  max-width: 100%;
}

:deep(.q-table) {
  min-width: 2200px;
}

.table-image {
  width: 96px;
  height: 96px;
  margin: 0 auto;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fff;
}

.table-image-placeholder {
  width: 96px;
  height: 96px;
  margin: 0 auto;
  border: 1px dashed #bbb;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  color: #777;
  background: #fafafa;
}

.editable-cell {
  cursor: pointer;
}

.editable-value {
  min-height: 24px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.col-sl {
  min-width: 60px;
  width: 60px;
  background: #f8f9fa;
}

.col-image {
  min-width: 130px;
  width: 130px;
  background: #fcfcfc;
}

.col-name {
  min-width: 200px;
  background: #ffffff;
}

.col-qty {
  min-width: 100px;
  width: 100px;
  background: #f8f9fa;
}

.col-barcode {
  min-width: 180px;
  background: #ffffff;
}

.col-website {
  min-width: 120px;
  background: #f8f9fa;
}

.col-price-gbp {
  min-width: 110px;
  background: #ffffff;
}

.col-product-weight {
  min-width: 120px;
  background: #f8f9fa;
}

.col-package-weight {
  min-width: 130px;
  background: #ffffff;
}

.col-total-weight {
  min-width: 120px;
  background: #f8f9fa;
}

.col-cargo-rate {
  min-width: 100px;
  background: #ffffff;
}

.col-cargo-cost-gbp {
  min-width: 130px;
  background: #f8f9fa;
}

.col-total-cost-gbp {
  min-width: 130px;
  background: #ffffff;
}

.col-cost-bdt {
  min-width: 110px;
  background: #f8f9fa;
}

.col-total-cost-bdt {
  min-width: 130px;
  background: #ffffff;
}

.col-offer-price-bdt {
  min-width: 150px;
  background: #f8f9fa;
}

.col-total-bdt {
  min-width: 110px;
  background: #ffffff;
}

.col-profit-bdt {
  min-width: 110px;
  background: #f8f9fa;
}

.col-profit-rate {
  min-width: 110px;
  background: #ffffff;
}

.col-status {
  min-width: 150px;
  background: #f8f9fa;
}

.col-action {
  min-width: 100px;
  background: #ffffff;
}

:deep(.bg-gbp) {
  background-color: #e6f4ea !important;
}

:deep(.bg-bdt) {
  background-color: #fff8e1 !important;
}

:deep(.bg-offer) {
  background-color: #f3e5f5 !important;
}
</style>

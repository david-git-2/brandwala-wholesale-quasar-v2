<template>
  <div class="customer-order-table">
    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="columns"
      row-key="id"
      :pagination="{ rowsPerPage: 0 }"
      hide-bottom
      :table-style="{ maxHeight: '72vh' }"
      class="order-q-table"
    >
      <template #body="props">
        <q-tr :props="props">
          <q-td key="sl" :props="props">
            {{ props.row.sl }}
          </q-td>

          <q-td key="image_url" :props="props">
            <div class="order-table-image-box">
              <SmartImage
                :src="props.row.image_url"
                alt="product"
                imgClass="order-table-image"
                fallbackClass="order-table-image-fallback"
              />
            </div>
          </q-td>

          <q-td key="name" :props="props" class="col-name">
            <div class="whitespace-normal customer-order-name-cell">
              {{ props.row.name }}
            </div>
          </q-td>

          <q-td key="quantity" :props="props">
            <span :class="canEditQuantity ? 'cursor-pointer' : ''">
              {{ draftQuantityById[props.row.id] ?? '-' }}
            </span>
            <q-popup-edit
              v-if="canEditQuantity"
              :model-value="draftQuantityById[props.row.id]"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              v-slot="scope"
              @save="(value) => onQuantityPopupSave(props.row.id, value)"
            >
              <div class="row items-center q-gutter-sm">
                <q-btn
                  dense
                  round
                  color="primary"
                  icon="remove"
                  @click="scope.value = adjustQuantityByStep(scope.value, -1, props.row.minimum_quantity)"
                />
                <div class="text-subtitle2 text-center" style="min-width: 72px">
                  {{ Number(scope.value ?? 0) || 0 }}
                </div>
                <q-btn
                  dense
                  round
                  color="primary"
                  icon="add"
                  @click="scope.value = adjustQuantityByStep(scope.value, 1, props.row.minimum_quantity)"
                />
              </div>
            </q-popup-edit>
          </q-td>

          <q-td key="first_offered_price" :props="props">
            {{ props.row.first_offered_price ?? '-' }}
          </q-td>

          <q-td key="customer_offer_bdt" :props="props">
            <span :class="canEditCustomerOffer ? 'cursor-pointer' : ''">
              {{ draftOfferById[props.row.id] ?? '-' }}
            </span>

            <q-popup-edit
              v-if="canEditCustomerOffer"
              :model-value="draftOfferById[props.row.id]"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              v-slot="scope"
              @save="(value) => onCustomerOfferPopupSave(props.row.id, value)"
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
              />
            </q-popup-edit>
          </q-td>

          <q-td key="final_offer_bdt" :props="props">
            {{ props.row.final_offer_bdt ?? props.row.display_customer_offer_bdt ?? props.row.first_offered_price ?? '-' }}
          </q-td>
        </q-tr>
      </template>

      <template #no-data>
        <div class="full-width row flex-center q-pa-md text-grey-6">
          No items found
        </div>
      </template>
    </q-table>

    <div class="row justify-end q-mt-md">
      <q-btn
      v-if="canEditCustomerOffer"
        color="primary"
        no-caps
        label="Save Customer Offers"
        :loading="orderStore.saving"
        @click="onSaveCustomerOffers"
      />
      <q-btn
        v-if="canEditQuantity"
        color="positive"
        no-caps
        label="Place Order"
        class="q-ml-sm"
        :loading="orderStore.saving"
        @click="onPlaceOrder"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { QTableColumn } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import { useOrderStore } from '../stores/orderStore'

type OrderStatus =
  | 'customer_submit'
  | 'direct_priced'
  | 'priced'
  | 'negotiate'
  | 'final_offered'
  | 'processing'
  | 'invoicing'
  | 'invoiced'
  | 'ordered'

type OrderItem = {
  id: number
  name: string
  image_url: string | null
  minimum_quantity?: number | null
  first_offer_bdt?: number | null
  customer_offer_bdt?: number | null
  final_offer_bdt?: number | null
  ordered_quantity?: number | null
}

type TableRow = OrderItem & {
  sl: number
  first_offered_price: number | null
  display_customer_offer_bdt: number | null
}

const props = withDefaults(
  defineProps<{
    items?: OrderItem[]
    status?: OrderStatus
    negotiateEnabled?: boolean
  }>(),
  {
    items: () => [],
    status: 'customer_submit',
    negotiateEnabled: true,
  }
)

const orderStore = useOrderStore()
const draftOfferById = ref<Record<number, number | null>>({})
const initialDisplayOfferById = ref<Record<number, number | null>>({})
const draftQuantityById = ref<Record<number, number | null>>({})
const initialQuantityById = ref<Record<number, number | null>>({})

const tableRows = computed<TableRow[]>(() =>
  props.items.map((item, index) => {
    const firstOfferedPrice = item.first_offer_bdt ?? null
    const displayCustomerOffer = item.customer_offer_bdt ?? firstOfferedPrice

    return {
      ...item,
      sl: index + 1,
      first_offered_price: firstOfferedPrice,
      display_customer_offer_bdt: displayCustomerOffer,
    }
  })
)

watch(
  tableRows,
  (rows) => {
    const draft: Record<number, number | null> = {}
    const initial: Record<number, number | null> = {}
    const quantityDraft: Record<number, number | null> = {}
    const quantityInitial: Record<number, number | null> = {}

    rows.forEach((row) => {
      draft[row.id] = row.display_customer_offer_bdt ?? null
      initial[row.id] = row.display_customer_offer_bdt ?? null
      quantityDraft[row.id] = row.ordered_quantity ?? null
      quantityInitial[row.id] = row.ordered_quantity ?? null
    })

    draftOfferById.value = draft
    initialDisplayOfferById.value = initial
    draftQuantityById.value = quantityDraft
    initialQuantityById.value = quantityInitial
  },
  { immediate: true },
)

const allColumns: QTableColumn[] = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'center',

    style: 'width: 50px; max-width: 50px;',
    headerStyle: 'width: 50px; max-width: 50px;',
  },
  { name: 'image_url', label: 'Image', field: 'image_url', align: 'center', sortable: false },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'center',

    style: 'min-width: 360px; width: 360px; max-width: 360px; text-align: left;',
    headerStyle: 'min-width: 360px; width: 360px; max-width: 360px;',
    classes: 'col-name',
    headerClasses: 'col-name-wrap',
  },
  {
    name: 'quantity',
    label: 'Quantity',
    field: 'ordered_quantity',
    align: 'center',

    style: 'background-color:#f2f4f7;font-weight:bold;min-width:90px;width:90px;max-width:90px;',
    headerStyle: 'background-color:#f2f4f7;min-width:90px;width:90px;max-width:90px;',
    headerClasses: 'text-center',
  },
  { name: 'first_offered_price', label: 'First Offered Price', field: 'first_offered_price', align: 'center', style: 'background-color:#e0f2f6;font-weight:bold',
  headerStyle: 'background-color:#e0f2f6;',},
  { name: 'customer_offer_bdt', label: 'Customer Offer', field: 'display_customer_offer_bdt', align: 'center',  style: 'background-color:#f8e8d5;font-weight:bold',
  headerStyle: 'background-color:#f8e8d5;', },
  {
    name: 'final_offer_bdt',
    label: 'Final Offer (BDT)',
    field: 'final_offer_bdt',
    align: 'center',
    style: 'background-color:#e8e2f8;font-weight:bold',
  headerStyle: 'background-color:#e8e2f8;',


  },

]

const statusColumnMapWithNegotiation: Record<OrderStatus, string[]> = {
  customer_submit: ['sl', 'image_url', 'name', 'quantity'],
  direct_priced: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
  priced: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price', 'customer_offer_bdt'],
  negotiate: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price', 'customer_offer_bdt'],
  final_offered: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price','customer_offer_bdt','final_offer_bdt'],
  processing: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price','customer_offer_bdt','final_offer_bdt'],
  invoicing: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price','customer_offer_bdt','final_offer_bdt'],
  invoiced: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price','customer_offer_bdt','final_offer_bdt'],
  ordered: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price','customer_offer_bdt','final_offer_bdt'],
}

const statusColumnMapWithoutNegotiation: Record<OrderStatus, string[]> = {
  customer_submit: ['sl', 'image_url', 'name', 'quantity'],
  direct_priced: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
  priced: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
  negotiate: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
  final_offered: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
  processing: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
  invoicing: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
  invoiced: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
  ordered: ['sl', 'image_url', 'name', 'quantity', 'final_offer_bdt'],
}

const columns = computed(() => {
  const visibleColumnNames = (
    props.negotiateEnabled ? statusColumnMapWithNegotiation : statusColumnMapWithoutNegotiation
  )[props.status ?? 'customer_submit']
  return allColumns.filter((column) => visibleColumnNames.includes(column.name))
})
const canEditCustomerOffer = computed(() => props.negotiateEnabled && props.status === 'priced')
const canEditQuantity = computed(() => props.status === 'final_offered')

const onDraftChange = (id: number, value: string | number | null) => {
  if (value == null || value === '') {
    draftOfferById.value[id] = null
    return
  }

  const parsed = Number(value)
  draftOfferById.value[id] = Number.isFinite(parsed) ? parsed : null
}

const onQuantityDraftChange = (id: number, value: string | number | null) => {
  if (value == null || value === '') {
    draftQuantityById.value[id] = null
    return
  }

  const parsed = Number(value)
  if (!Number.isFinite(parsed)) {
    draftQuantityById.value[id] = null
    return
  }

  draftQuantityById.value[id] = Math.max(0, Math.floor(parsed))
}

const adjustQuantityByStep = (
  currentValue: string | number | null,
  direction: 1 | -1,
  minimumQuantity?: number | null,
) => {
  const stepRaw = Number(minimumQuantity ?? 1)
  const step = Number.isFinite(stepRaw) && stepRaw > 0 ? Math.floor(stepRaw) : 1
  const currentRaw = Number(currentValue ?? 0)
  const current = Number.isFinite(currentRaw) ? Math.floor(currentRaw) : 0
  const next = current + direction * step
  return Math.max(0, next)
}

const onSaveCustomerOffers = async () => {
  const payload = tableRows.value.map((row) => ({
    id: row.id,
    customer_offer_bdt: draftOfferById.value[row.id] ?? null,
  }))

  if (!payload.length) {
    return
  }

  console.log('bulk-save-customer-offers', payload)

  const result = await orderStore.bulkUpdateOrderItemsRaw(payload)
  if (!result.success) {
    return
  }

  payload.forEach((entry) => {
    initialDisplayOfferById.value[entry.id] = entry.customer_offer_bdt
  })

  const shouldNegotiate = orderStore.selected?.negotiate !== false
  await orderStore.updateOrder({
    id: orderStore.selected?.id || 0,
    patch: {
      status: shouldNegotiate ? 'negotiate' : 'direct_priced',
    },
  })
}

const onCustomerOfferPopupSave = async (id: number, value: string | number | null) => {
  onDraftChange(id, value)
  const nextOffer = draftOfferById.value[id]

  const result = await orderStore.updateOrderItemRaw({
    id,
    patch: {
      customer_offer_bdt: nextOffer ?? null,
    },
  })

  if (!result.success) {
    return
  }

  initialDisplayOfferById.value[id] = nextOffer ?? null
}

const onQuantityPopupSave = async (id: number, value: string | number | null) => {
  onQuantityDraftChange(id, value)
  const nextQuantity = draftQuantityById.value[id]

  if (nextQuantity == null) {
    return
  }

  const result = await orderStore.updateOrderItemRaw({
    id,
    patch: {
      ordered_quantity: nextQuantity,
    },
  })

  if (!result.success) {
    return
  }

  initialQuantityById.value[id] = nextQuantity
}

const onPlaceOrder = async () => {
  if (!orderStore.selected?.id) {
    return
  }

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      status: 'ordered',
    },
  })
}
</script>

<style scoped>
.customer-order-table {
  width: 100%;
}

.order-q-table {
  max-width: 100%;
  max-height: 72vh;
  background: var(--bw-theme-base, #eef2f5);
}

:deep(.q-table) {
  min-width: 1020px;
  table-layout: fixed;
}

.customer-order-table :deep(.order-q-table thead tr th) {
  position: sticky;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
}

.customer-order-table :deep(.order-q-table thead tr:first-child th) {
  top: 0;
  z-index: 3;
}

.customer-order-table :deep(.order-q-table td:first-child),
.customer-order-table :deep(.order-q-table th:first-child) {
  position: sticky;
  left: 0;
}

.customer-order-table :deep(.order-q-table td:nth-child(2)),
.customer-order-table :deep(.order-q-table th:nth-child(2)) {
  position: sticky;
  left: 50px;
}

.customer-order-table :deep(.order-q-table td:first-child) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.customer-order-table :deep(.order-q-table td:nth-child(2)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.customer-order-table :deep(.order-q-table tr:first-child th:first-child) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.customer-order-table :deep(.order-q-table tr:first-child th:nth-child(2)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

:deep(.q-table thead th) {
  text-align: center !important;
  vertical-align: middle;
  height: auto;
  padding-top: 8px;
  padding-bottom: 8px;
  white-space: normal !important;
  overflow: hidden;
}

:deep(.q-table thead th .q-table__th-content) {
  display: flex !important;
  flex-wrap: wrap;
  justify-content: center;
  align-items: center;
  column-gap: 4px;
  width: 100%;
  white-space: normal !important;
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.25;
  text-align: center;
  overflow: hidden;
}

:deep(.q-table th),
:deep(.q-table td) {
  min-width: 120px;
  background: var(--bw-theme-surface, #fff);
}

:deep(.q-table th:nth-child(1)),
:deep(.q-table td:nth-child(1)) {
  min-width: 50px !important;
  width: 50px !important;
  max-width: 50px !important;
}

:deep(.q-table th:nth-child(3)),
:deep(.q-table td:nth-child(3)) {
  min-width: 360px !important;
  width: 360px !important;
  max-width: 360px !important;
}

:deep(.q-table th:nth-child(2)),
:deep(.q-table td:nth-child(2)) {
  min-width: 120px !important;
  width: 120px !important;
  max-width: 120px !important;
  padding-right: 8px !important;
  padding-left: 8px !important;
}

:deep(.q-table th:nth-child(3)),
:deep(.q-table td:nth-child(3)) {
  padding-left: 18px !important;
}

.customer-order-name-cell {
  white-space: normal;
  word-break: break-word;
  line-height: 1.35;
}

.order-table-image-box {
  width: 96px;
  height: 96px;
  min-width: 96px;
  min-height: 96px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--bw-theme-surface, #fff);
  border: 1px solid #e5e7eb;
}

:deep(.q-table__container),
:deep(.q-table__middle),
:deep(.q-table__middle table),
:deep(.q-table__bottom) {
  background: var(--bw-theme-base, #eef2f5);
}

.order-table-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

.order-table-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #e5e7eb;
  font-size: 12px;
}

.col-name {
  min-width: 360px !important;
  width: 360px !important;
  max-width: 360px !important;
}

.col-name-wrap {
  white-space: normal !important;
  word-break: break-word;
  line-height: 1.2;
}
</style>

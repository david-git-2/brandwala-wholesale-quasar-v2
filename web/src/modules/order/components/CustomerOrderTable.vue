<template>
  <div>
    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="columns"
      row-key="id"
      :pagination="{ rowsPerPage: 0 }"
      hide-bottom
      class="bg-white"
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
  | 'priced'
  | 'negotiate'
  | 'final_offered'
  | 'ordered'
  | 'placed'

type OrderItem = {
  id: number
  name: string
  image_url: string | null
  minimum_quantity?: number | null
  first_offer_bdt?: number | null
  customer_offer_bdt?: number | null
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
  }>(),
  {
    items: () => [],
    status: 'customer_submit',
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
  { name: 'sl', label: 'SL', field: 'sl', align: 'left', sortable: false },
  { name: 'image_url', label: 'Image', field: 'image_url', align: 'left', sortable: false },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left',
    sortable: true,
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
    sortable: true,
    style: 'background-color:#E7E7E7;font-weight:bold',
    headerStyle: 'background-color:#E7E7E7;',
    headerClasses: 'text-center',
  },
  { name: 'first_offered_price', label: 'First Offered Price', field: 'first_offered_price', align: 'left', sortable: true ,style: 'background-color:#9bf6ff;font-weight:bold',
  headerStyle: 'background-color:#9bf6ff;',},
  { name: 'customer_offer_bdt', label: 'Customer Offer', field: 'display_customer_offer_bdt', align: 'left', sortable: true, style: 'background-color:#ffd6a5;font-weight:bold',
  headerStyle: 'background-color:#ffd6a5;', },
  {
    name: 'final_offer_bdt',
    label: 'Final Offer (BDT)',
    field: 'final_offer_bdt',
    align: 'center',
    style: 'background-color:#bdb2ff;font-weight:bold',
  headerStyle: 'background-color:#bdb2ff;',


  },

]

const statusColumnMap: Record<OrderStatus, string[]> = {
  customer_submit: ['sl', 'image_url', 'name', 'quantity'],
  priced: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price', 'customer_offer_bdt'],
  negotiate: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price', 'customer_offer_bdt'],
  final_offered: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price'],
  ordered: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price'],
  placed: ['sl', 'image_url', 'name', 'quantity', 'first_offered_price'],
}

const columns = computed(() => {
  const visibleColumnNames = statusColumnMap[props.status ?? 'customer_submit']
  return allColumns.filter((column) => visibleColumnNames.includes(column.name))
})
const canEditCustomerOffer = computed(() => props.status === 'priced')
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

  const result = await orderStore.bulkUpdateOrderItems(payload)
  if (!result.success) {
    return
  }

  payload.forEach((entry) => {
    initialDisplayOfferById.value[entry.id] = entry.customer_offer_bdt
  })

  await orderStore.updateOrder({
    id: orderStore.selected?.id ||0,
    patch: {
      status:'negotiate',
    },
  })
}

const onCustomerOfferPopupSave = async (id: number, value: string | number | null) => {
  onDraftChange(id, value)
  const nextOffer = draftOfferById.value[id]

  const result = await orderStore.updateOrderItem({
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

  const result = await orderStore.updateOrderItem({
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
:deep(.q-table) {
  min-width: 1020px;
  table-layout: fixed;
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
  min-width: 140px;
}

:deep(.q-table th:nth-child(3)),
:deep(.q-table td:nth-child(3)) {
  min-width: 360px !important;
  width: 360px !important;
  max-width: 360px !important;
}

:deep(.q-table th:nth-child(2)),
:deep(.q-table td:nth-child(2)) {
  min-width: 1in !important;
  width: 1in !important;
  max-width: 1in !important;
}

.customer-order-name-cell {
  white-space: normal;
  word-break: break-word;
  line-height: 1.35;
}

.order-table-image-box {
  width: 1in;
  height: 1in;
  min-width: 1in;
  min-height: 1in;
  border-radius: 8px;
  overflow: hidden;
  background: #ffffff;
  border: 1px solid #e5e7eb;
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

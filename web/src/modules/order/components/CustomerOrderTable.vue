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
            <SmartImage
              :src="props.row.image_url"
              alt="product"
              imgClass="w-12 h-12 object-cover rounded"
              fallbackClass="w-12 h-12 flex items-center justify-center bg-gray-200 text-xs"
            />
          </q-td>

          <q-td key="name" :props="props">
            <div class="whitespace-normal" style="min-width: 260px">
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
              @save="(value) => onDraftChange(props.row.id, value)"
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
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'quantity', label: 'Quantity', field: 'ordered_quantity', align: 'left', sortable: true },
  { name: 'first_offered_price', label: 'First Offered Price', field: 'first_offered_price', align: 'left', sortable: true },
  { name: 'customer_offer_bdt', label: 'Customer Offer', field: 'display_customer_offer_bdt', align: 'left', sortable: true },
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

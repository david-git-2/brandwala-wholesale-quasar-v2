<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-sm">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Orders"
        @click="onBackToOrders"
      />
    </div>
    <div class="text-h5">#{{orderStore.selected?.id}} {{orderStore.selected?.name}} Order Details</div>

    <div class="q-mt-md q-mb-md row justify-end" >
      <q-select
        v-model="selectedStatus"
        outlined
        dense
        label="Order Status"
        :options="statusOptions"
        :loading="orderStore.saving"
        @update:model-value="onStatusChange"
      />
    </div>

    <div v-if="orderStore.selected?.negotiate !== false" class="row q-gutter-sm q-my-sm">
      <q-toggle
        :model-value="orderStore.selected?.negotiate ?? true"
        label="Enable Negotiation"
        :disable="!orderStore.selected?.id || orderStore.saving"
        @update:model-value="onNegotiationToggle"
      />
    </div>
    <div v-else class="row q-gutter-sm q-my-sm">
      <q-chip dense color="negative" text-color="white" icon="block">
        Negotiation Disabled
      </q-chip>
    </div>

    <div class="row q-gutter-sm q-my-sm">
      <q-input
        outlined
        dense
        v-model="conversionRate"
        type="number"
        label="Conversion Rate"
      />
      <q-input
        outlined
        dense
        v-model="cargoRate"
        type="number"
        label="Cargo Rate / KG"
      />
      <q-input
        outlined
        dense
        v-model="profitRate"
        type="number"
        label="Profit Rate"
      />
      <q-btn
        color="primary"
        dense
        no-caps
        label="Save Rates"
        class="q-px-sm"
        :loading="orderStore.saving"
        @click="onSaveRates"
      />

    </div>
    <div class="row items-center q-mb-sm">
      <q-btn
        v-if="selectedItemIds.length"
        class="q-mr-auto"
        color="negative"
        no-caps
        icon="delete"
        :label="`Delete Selected (${selectedItemIds.length})`"
        :loading="orderStore.saving"
        @click="confirmDeleteSelectedOpen = true"
      />
      <q-btn-toggle
        class="q-ml-auto"
        v-model="tableViewMode"
        no-caps
        unelevated
        toggle-color="primary"
        :options="tableViewOptions"
      />
    </div>
    <CompactOrderItemTable
      v-if="tableViewMode === 'compact'"
      v-model:selected-ids="selectedItemIds"
      :items="orderStore.selected?.order_items ?? []"
      :status="selectedStatus ?? 'customer_submit'"
      :conversion-rate="Number(conversionRate) || 0"
      :cargo-rate="Number(cargoRate) || 0"
      :profit-rate="Number(profitRate) || 0"
      @ship="onShipItem"
    />
    <OrderItemsTable
      v-else
      v-model:selected-ids="selectedItemIds"
      :items="orderStore.selected?.order_items ?? []"
      :status="selectedStatus ?? 'customer_submit'"
      :conversion-rate="Number(conversionRate) || 0"
      :cargo-rate="Number(cargoRate) || 0"
      :profit-rate="Number(profitRate) || 0"
      @ship="onShipItem"
    />

    <q-dialog v-model="confirmDisableNegotiationOpen">
      <q-card style="min-width: 360px">
        <q-card-section class="text-h6">Disable Negotiation?</q-card-section>
        <q-card-section>
          If you disable negotiation, priced and negotiate states will be removed and offers will be prefilled to final offer.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            label="Disable"
            :loading="orderStore.saving"
            @click="onConfirmDisableNegotiation"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="confirmDeleteSelectedOpen">
      <q-card style="min-width: 360px">
        <q-card-section class="text-h6">Delete Selected Items?</q-card-section>
        <q-card-section>
          This will permanently delete {{ selectedItemIds.length }} selected item(s).
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            label="Delete"
            :loading="orderStore.saving"
            @click="onConfirmDeleteSelected"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="confirmRemoveShipmentOpen">
      <q-card style="min-width: 360px">
        <q-card-section class="text-h6">Remove From Shipment?</q-card-section>
        <q-card-section>
          This will remove the selected item from its shipment.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            label="Remove"
            :loading="orderStore.saving || shipmentStore.saving"
            @click="onConfirmRemoveShipment"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
    <ShipmentItemCompactDialog v-model="showAddShipmentDialog"
  :quantity="selectedQuantity"
  :price-gbp="selectedPriceGbp"
  @save="onSaveShipment"/>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useOrderStore } from '../stores/orderStore'
import { useRoute, useRouter } from 'vue-router'
import OrderItemsTable from '../components/OrderItemsTable.vue'
import type { OrderItem, OrderStatus } from '../types'
import CompactOrderItemTable from '../components/CompactOrderItemTable.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import ShipmentItemCompactDialog from 'src/modules/shipment/components/ShipmentItemCompactDialog.vue'




const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const orderStore = useOrderStore()
const shipmentStore = useShipmentStore()
const tenantStore = useTenantStore()

const selectedStatus = ref<OrderStatus | null>(null)
const tableViewMode = ref<'compact' | 'detailed'>('compact')
const confirmDisableNegotiationOpen = ref(false)
const confirmDeleteSelectedOpen = ref(false)
const confirmRemoveShipmentOpen = ref(false)
const selectedItemIds = ref<number[]>([])
const showAddShipmentDialog = ref(false)
const selectedQuantity = ref<number | null>(null)
const selectedPriceGbp = ref<number | null>(null)
const selectedShipItemId = ref<number | null>(null)
const pendingRemoveShipItemId = ref<number | null>(null)

const allStatusOptions: OrderStatus[] = [
  'customer_submit',
  'priced',
  'negotiate',
  'final_offered',
  'ordered',
  'processing',
  'placed',
]
const statusOptions = computed<OrderStatus[]>(() =>
  orderStore.selected?.negotiate === false
    ? allStatusOptions.filter((status) => status !== 'priced' && status !== 'negotiate')
    : allStatusOptions,
)

const tableViewOptions = [
  { label: 'Compact', value: 'compact' },
  { label: 'Detailed', value: 'detailed' },
]

const normalizeNumericInput = (value: unknown) => {
  if (value == null) {
    return null
  }

  if (typeof value === 'string' && value.trim() === '') {
    return null
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

onMounted(async () => {
  await orderStore.fetchOrderById({ id: Number(route.params.id) })
  await shipmentStore.fetchShipments(tenantStore.selectedTenant?.id ?? 1)
})

watch(
  () => orderStore.selected?.status,
  (status) => {
    selectedStatus.value = status ?? null
  },
  { immediate: true }
)

watch(
  () => orderStore.selected?.order_items ?? [],
  (items) => {
    const valid = new Set(items.map((item) => item.id))
    selectedItemIds.value = selectedItemIds.value.filter((id) => valid.has(id))
  },
  { immediate: true },
)

const conversionRate = computed({
  get: () => orderStore.selected?.conversion_rate ?? null,
  set: (value) => {
    if (orderStore.selected) {
      orderStore.selected.conversion_rate = normalizeNumericInput(value)
    }
  },
})

const cargoRate = computed({
  get: () => orderStore.selected?.cargo_rate ?? null,
  set: (value) => {
    if (orderStore.selected) {
      orderStore.selected.cargo_rate = normalizeNumericInput(value)
    }
  },
})

const profitRate = computed({
  get: () => orderStore.selected?.profit_rate ?? null,
  set: (value) => {
    if (orderStore.selected) {
      orderStore.selected.profit_rate = normalizeNumericInput(value)
    }
  },
})

const conversionRateRef = computed(() => Number(conversionRate.value) || 0)
const cargoRateRef = computed(() => Number(cargoRate.value) || 0)
const profitRateRef = computed(() => Number(profitRate.value) || 0)

const selectedItems = computed(() => orderStore.selected?.order_items ?? [])

const ceil2 = (n: number) => Math.ceil(n * 100) / 100
const ceilInt = (n: number) => Math.ceil(n)
const roundUpTo5 = (n: number) => Math.ceil(n / 5) * 5

const onStatusChange = async (status: OrderStatus | null) => {
  if (!status || !orderStore.selected?.id) return
  if (
    orderStore.selected.negotiate === false &&
    (status === 'priced' || status === 'negotiate')
  ) {
    return
  }

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      status,
    },
  })
}

const applyNegotiationToggle = async (nextValue: boolean) => {
  if (!orderStore.selected?.id) {
    return
  }

  const shouldMoveToFinalOffered =
    !nextValue &&
    ['customer_submit', 'priced', 'negotiate'].includes(orderStore.selected.status)

  if (!nextValue) {
    const conversion = Number(conversionRate.value) || 0
    const cargo = Number(cargoRate.value) || 0
    const profit = Number(profitRate.value) || 0

    const prefillPayload = selectedItems.value.map((item) => {
      const productWeight = Number(item.product_weight || 0)
      const packageWeight = Number(item.package_weight || 0)
      const totalWeight = productWeight + packageWeight
      const priceGbp = Number(item.price_gbp || 0)

      const unitLineCostGbp = ceil2((totalWeight / 1000) * cargo + priceGbp)
      const costBdt = ceilInt(unitLineCostGbp * conversion)
      const firstOfferBdt =
        item.first_offer_bdt ?? roundUpTo5((costBdt * profit) / 100 + costBdt)

      return {
        id: item.id,
        first_offer_bdt: firstOfferBdt,
        customer_offer_bdt: firstOfferBdt,
        final_offer_bdt: firstOfferBdt,
      }
    })

    const prefillResult = await orderStore.bulkUpdateOrderItems(prefillPayload)
    if (!prefillResult.success) {
      return
    }
  }

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      negotiate: nextValue,
      ...(shouldMoveToFinalOffered ? { status: 'final_offered' as OrderStatus } : {}),
    },
  })
}

const onNegotiationToggle = (nextValue: boolean) => {
  if (nextValue) {
    return
  }
  confirmDisableNegotiationOpen.value = true
}

const onConfirmDisableNegotiation = async () => {
  confirmDisableNegotiationOpen.value = false
  await applyNegotiationToggle(false)
}

const onConfirmDeleteSelected = async () => {
  const ids = [...selectedItemIds.value]
  if (!ids.length) {
    confirmDeleteSelectedOpen.value = false
    return
  }

  for (const id of ids) {
    await orderStore.deleteOrderItem({ id })
  }

  selectedItemIds.value = []
  confirmDeleteSelectedOpen.value = false
}

const onBackToOrders = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/orders`)
}

const openShipDialogForItem = (itemId: number) => {
  const rowItem = orderStore.selected?.order_items?.find((item) => item.id === itemId) ?? null
  if (!rowItem) {
    return
  }
  selectedShipItemId.value = rowItem.id
  showAddShipmentDialog.value = true
  selectedQuantity.value = rowItem?.ordered_quantity ?? null
  selectedPriceGbp.value = rowItem?.price_gbp ?? null
}

const onShipItem = (itemId: number) => {
  const rowItem = orderStore.selected?.order_items?.find((item) => item.id === itemId) ?? null
  if (!rowItem) {
    return
  }

  if (rowItem.shipment_id == null) {
    openShipDialogForItem(itemId)
    return
  }

  pendingRemoveShipItemId.value = itemId
  confirmRemoveShipmentOpen.value = true
}

const onSaveRates = async () => {
  if (!orderStore.selected?.id) return
  const negotiateEnabled = orderStore.selected.negotiate !== false
  const hasRequiredRates =
    orderStore.selected.cargo_rate != null &&
    orderStore.selected.conversion_rate != null &&
    orderStore.selected.profit_rate != null

  const orderUpdateResult = await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      cargo_rate: orderStore.selected.cargo_rate ?? null,
      conversion_rate: orderStore.selected.conversion_rate ?? null,
      profit_rate: orderStore.selected.profit_rate ?? null,
    },
  })

  if (!orderUpdateResult.success) {
    return
  }

  const conversion = conversionRateRef.value
  const cargo = cargoRateRef.value
  const profit = profitRateRef.value

  const recalculatedPayload = selectedItems.value.map((item) => {
    const productWeight = Number(item.product_weight || 0)
    const packageWeight = Number(item.package_weight || 0)
    const totalWeight = productWeight + packageWeight
    const priceGbp = Number(item.price_gbp || 0)

    const unitLineCostGbp = ceil2((totalWeight / 1000) * cargo + priceGbp)
    const costBdt = ceilInt(unitLineCostGbp * conversion)
    const firstOfferBdt = roundUpTo5((costBdt * profit) / 100 + costBdt)

    return {
      id: item.id,
      cost_gbp: unitLineCostGbp,
      cost_bdt: costBdt,
      first_offer_bdt: firstOfferBdt,
      customer_offer_bdt: negotiateEnabled ? item.customer_offer_bdt : firstOfferBdt,
      final_offer_bdt: negotiateEnabled ? item.final_offer_bdt : firstOfferBdt,
    }
  })

  const itemsUpdateResult = await orderStore.bulkUpdateOrderItems(recalculatedPayload)
  if (!itemsUpdateResult.success) {
    return
  }

  if (
    !negotiateEnabled &&
    hasRequiredRates &&
    orderStore.selected.status === 'customer_submit'
  ) {
    await orderStore.updateOrder({
      id: orderStore.selected.id,
      patch: {
        status: 'final_offered',
      },
    })
  }
}


const onSaveShipment = async (data: {
  shipment_id: number
  quantity: number
  price_gbp: number | null
}) => {
  const itemId = selectedShipItemId.value
  if (!itemId) {
    return
  }

  const rowItem = orderStore.selected?.order_items?.find((item) => item.id === itemId) as
    | OrderItem
    | undefined
  if (!rowItem) {
    return
  }

  const quantity = Math.max(0, Number(data.quantity) || 0)
  if (quantity <= 0) {
    return
  }

  const addShipmentResult = await shipmentStore.addShipmentItemManual({
    shipment_id: data.shipment_id,
    order_id: rowItem.order_id,
    method: 'order',
    name: rowItem.name ?? null,
    quantity,
    barcode: rowItem.barcode ?? null,
    product_code: rowItem.product_code ?? null,
    product_id: rowItem.product_id ?? null,
    image_url: rowItem.image_url ?? null,
    product_weight: rowItem.product_weight ?? null,
    package_weight: rowItem.package_weight ?? null,
    price_gbp: data.price_gbp,
    received_quantity: 0,
    damaged_quantity: 0,
    stolen_quantity: 0,
  })

  if (!addShipmentResult.success) {
    return
  }

  const updateOrderItemResult = await orderStore.updateOrderItemRaw({
    id: itemId,
    patch: {
      shipment_id: data.shipment_id,
    },
  })

  if (!updateOrderItemResult.success) {
    return
  }

  selectedShipItemId.value = null
  selectedQuantity.value = null
  selectedPriceGbp.value = null
}

const onConfirmRemoveShipment = async () => {
  const itemId = pendingRemoveShipItemId.value
  if (!itemId) {
    confirmRemoveShipmentOpen.value = false
    return
  }

  const rowItem = orderStore.selected?.order_items?.find((item) => item.id === itemId) as
    | OrderItem
    | undefined
  if (!rowItem || rowItem.shipment_id == null) {
    confirmRemoveShipmentOpen.value = false
    pendingRemoveShipItemId.value = null
    return
  }

  const shipmentId = rowItem.shipment_id
  const itemsResult = await shipmentStore.fetchShipmentItems(shipmentId)
  if (!itemsResult.success) {
    return
  }

  const shipmentItems = shipmentStore.shipmentItems ?? []
  const exactProductMatch = shipmentItems.find(
    (item) =>
      item.order_id === rowItem.order_id &&
      rowItem.product_id != null &&
      item.product_id === rowItem.product_id,
  )
  const nameMatch = shipmentItems.find(
    (item) => item.order_id === rowItem.order_id && item.name === rowItem.name,
  )
  const fallbackByOrder = shipmentItems.find((item) => item.order_id === rowItem.order_id)
  const shipmentItemToDelete = exactProductMatch ?? nameMatch ?? fallbackByOrder ?? null

  if (shipmentItemToDelete) {
    const deleteResult = await shipmentStore.deleteShipmentItem({ id: shipmentItemToDelete.id })
    if (!deleteResult.success) {
      return
    }
  }

  const updateOrderItemResult = await orderStore.updateOrderItemRaw({
    id: itemId,
    patch: {
      shipment_id: null,
    },
  })

  if (!updateOrderItemResult.success) {
    return
  }

  confirmRemoveShipmentOpen.value = false
  pendingRemoveShipItemId.value = null
}


</script>

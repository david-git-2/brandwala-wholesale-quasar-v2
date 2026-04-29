<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Shipment"
        @click="onBack"
      />
    </div>

    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5">
        #{{ shipmentStore.selectedShipment?.id }} {{ shipmentStore.selectedShipment?.name }}
      </div>
      <div class="row items-center q-gutter-sm">
        <q-btn
          v-if="canAddToInventory"
          color="positive"
          no-caps
          label="Add To Inventory"
          :loading="shipmentStore.saving"
          @click="onAddToInventory"
        />
        <q-btn
          color="secondary"
          flat
          round
          icon="info"
          aria-label="Shipment info"
          @click="goToShipmentInfo"
        />
        <q-btn color="primary" no-caps label="Add Item" @click="openAddItemDialog" />
      </div>
    </div>

    <div v-if="shipmentStore.selectedShipment" class="q-mb-md row justify-end">
      <q-select
        v-model="selectedStatus"
        :options="statusOptions"
        label="Shipment Status"
        outlined
        dense
        class="shipment-status-select"
        :disable="shipmentStore.saving"
        @update:model-value="onStatusChange"
      />
    </div>

    <PageInitialLoader v-if="initialLoading" />

    <q-banner v-else-if="shipmentStore.loading" class="bg-grey-2 text-grey-8 q-mb-md">
      Loading shipment details...
    </q-banner>

    <q-banner v-if="!initialLoading && shipmentStore.error" class="bg-red-1 text-negative q-mb-md">
      {{ shipmentStore.error }}
    </q-banner>

    <q-card v-if="!initialLoading" flat bordered>
      <q-card-section class="q-pa-none">
        <q-markup-table flat class="shipment-details-table">
          <thead>
            <tr>
              <th class="text-right shipment-sl-col">SL</th>
              <th class="text-left shipment-image-col">Image</th>
              <th class="text-left shipment-name-col">Name</th>
              <th class="text-left">Method</th>
              <th class="text-right">Price GBP</th>
              <th class="text-right">Cost BDT</th>
              <th class="text-right shipment-qty-col shipment-qty-col--quantity">Quantity</th>
              <th class="text-right shipment-qty-col shipment-qty-col--received">Received Qty</th>
              <th class="text-right shipment-qty-col shipment-qty-col--damaged">Damaged Qty</th>
              <th class="text-right shipment-qty-col shipment-qty-col--stolen">Stolen Qty</th>
              <th class="text-right">Product Wt</th>
              <th class="text-right">Package Wt</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, index) in shipmentStore.shipmentItems" :key="item.id">
              <td class="text-right shipment-sl-col">{{ index + 1 }}</td>
              <td class="shipment-image-col">
                <div class="shipment-item-image-box">
                  <SmartImage
                    :src="item.image_url"
                    alt="shipment item"
                    imgClass="shipment-item-image"
                    fallbackClass="shipment-item-image-fallback"
                  />
                </div>
              </td>
              <td class="shipment-item-name-cell shipment-name-col" @click="openItemDetailsDialog(item)">
                {{ item.name ?? '-' }}
              </td>
              <td class="text-uppercase">{{ item.method ?? '-' }}</td>
              <td class="text-right">
                <span class="cursor-pointer">{{ formatDecimal(item.price_gbp) }}</span>
                <q-popup-edit
                  :model-value="item.price_gbp"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'price_gbp', value, { decimals: 2 })"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    step="0.01"
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </td>
              <td class="text-right">
                {{ formatFixed2(calculateItemCostBdt(item)) }}
              </td>
              <td class="text-right shipment-qty-col shipment-qty-col--quantity">
                <span class="cursor-pointer">{{ item.quantity }}</span>
                <q-popup-edit
                  :model-value="item.quantity"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'quantity', value)"
                >
                  <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
                </q-popup-edit>
              </td>
              <td class="text-right shipment-qty-col shipment-qty-col--received">
                <span class="cursor-pointer">{{ item.received_quantity }}</span>
                <q-popup-edit
                  :model-value="item.received_quantity"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'received_quantity', value)"
                >
                  <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
                </q-popup-edit>
              </td>
              <td class="text-right shipment-qty-col shipment-qty-col--damaged">
                <span class="cursor-pointer">{{ item.damaged_quantity }}</span>
                <q-popup-edit
                  :model-value="item.damaged_quantity"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'damaged_quantity', value)"
                >
                  <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
                </q-popup-edit>
              </td>
              <td class="text-right shipment-qty-col shipment-qty-col--stolen">
                <span class="cursor-pointer">{{ item.stolen_quantity }}</span>
                <q-popup-edit
                  :model-value="item.stolen_quantity"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'stolen_quantity', value)"
                >
                  <q-input v-model.number="scope.value" type="number" dense outlined autofocus />
                </q-popup-edit>
              </td>
              <td class="text-right">
                <span class="cursor-pointer">{{ formatDecimal(item.product_weight) }}</span>
                <q-popup-edit
                  :model-value="item.product_weight"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'product_weight', value, { decimals: 3 })"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    step="0.001"
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </td>
              <td class="text-right">
                <span class="cursor-pointer">{{ formatDecimal(item.package_weight) }}</span>
                <q-popup-edit
                  :model-value="item.package_weight"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericPopupSave(item, 'package_weight', value, { decimals: 3 })"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    step="0.001"
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </td>
              <td class="text-right">
                <q-btn
                  flat
                  dense
                  color="primary"
                  round
                  icon="edit"
                  @click="openEditItemDialog(item)"
                >
                  <q-tooltip>Edit</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  dense
                  color="negative"
                  round
                  icon="delete"
                  @click="openDeleteDialog(item)"
                >
                  <q-tooltip>Delete</q-tooltip>
                </q-btn>
              </td>
            </tr>
            <tr v-if="shipmentStore.shipmentItems.length" class="shipment-total-row">
              <td class="shipment-sl-col"></td>
              <td class="shipment-image-col"></td>
              <td class="shipment-name-col"></td>
              <td></td>
              <td class="text-right text-weight-bold">
                {{ formatDecimal(totals.price_gbp) }}
              </td>
              <td class="text-right text-weight-bold">
                {{ formatFixed2(totals.cost_bdt) }}
              </td>
              <td class="text-right shipment-qty-col shipment-qty-col--quantity text-weight-bold">
                {{ totals.quantity }}
              </td>
              <td class="text-right shipment-qty-col shipment-qty-col--received text-weight-bold">
                {{ totals.received_quantity }}
              </td>
              <td class="text-right shipment-qty-col shipment-qty-col--damaged text-weight-bold">
                {{ totals.damaged_quantity }}
              </td>
              <td class="text-right shipment-qty-col shipment-qty-col--stolen text-weight-bold">
                {{ totals.stolen_quantity }}
              </td>
              <td class="text-right text-weight-bold">
                {{ formatDecimal(totals.product_weight) }}
              </td>
              <td class="text-right text-weight-bold">
                {{ formatDecimal(totals.package_weight) }}
              </td>
              <td></td>
            </tr>
            <tr v-if="!shipmentStore.shipmentItems.length">
              <td colspan="13" class="text-center text-grey-6 q-pa-md">No shipment items yet</td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card-section>
    </q-card>

    <q-dialog v-model="showAddItemDialog">
      <q-card style="min-width: 420px; max-width: 90vw">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6">{{ editingItemId ? 'Edit Shipment Item' : 'Add Shipment Item' }}</div>
          <q-btn icon="close" flat round dense @click="showAddItemDialog = false" />
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="itemForm.name" label="Name" outlined dense autofocus />
          <q-input v-model.number="itemForm.quantity" label="Quantity" type="number" outlined dense />
          <q-input v-model="itemForm.barcode" label="Barcode" outlined dense />
          <q-input v-model="itemForm.product_code" label="Product Code" outlined dense />
          <q-input v-model="itemForm.image_url" label="Image URL" outlined dense />
          <q-select
            v-model="itemForm.method"
            :options="methodOptions"
            label="Method"
            emit-value
            map-options
            outlined
            dense
          />
          <q-input
            v-model.number="itemForm.order_id"
            label="Order ID (Optional)"
            type="number"
            outlined
            dense
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="showAddItemDialog = false" />
          <q-btn
            color="primary"
            :label="editingItemId ? 'Update Item' : 'Add Item'"
            :loading="shipmentStore.saving"
            @click="onSubmitItem"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="showDeleteDialog" persistent>
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Shipment Item</q-card-section>
        <q-card-section>
          Are you sure you want to delete
          <strong>{{ pendingDeleteItem?.name ?? 'this item' }}</strong
          >?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="showDeleteDialog = false" />
          <q-btn
            color="negative"
            label="Delete"
            :loading="shipmentStore.saving"
            @click="onConfirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <ShipmentItemDetailsDialog
      v-model="showItemDetailsDialog"
      :item="selectedDetailsItem"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import ShipmentItemDetailsDialog from '../components/ShipmentItemDetailsDialog.vue'
import { calculateCostBdt } from '../utils/costing'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useProductStore } from 'src/modules/products/stores/productStore'
import { useShipmentStore } from '../stores/shipmentStore'
import { SHIPMENT_STATUS_OPTIONS, type ShipmentItem, type ShipmentItemMethod, type ShipmentStatus } from '../types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const productStore = useProductStore()
const $q = useQuasar()

const showAddItemDialog = ref(false)
const showDeleteDialog = ref(false)
const showItemDetailsDialog = ref(false)
const initialLoading = ref(true)
const editingItemId = ref<number | null>(null)
const pendingDeleteItem = ref<ShipmentItem | null>(null)
const selectedDetailsItem = ref<ShipmentItem | null>(null)
const selectedStatus = ref<ShipmentStatus>('Draft')
const methodOptions: Array<{ label: string; value: ShipmentItemMethod }> = [
  { label: 'Order', value: 'order' },
  { label: 'Costing', value: 'costing' },
  { label: 'Manual', value: 'manual' },
]
const itemForm = reactive({
  name: '',
  quantity: 1,
  barcode: '',
  product_code: '',
  image_url: '',
  method: 'manual' as ShipmentItemMethod,
  order_id: null as number | null,
})

const shipmentId = computed(() => Number(route.params.id))
const statusOptions = SHIPMENT_STATUS_OPTIONS
const canAddToInventory = computed(
  () =>
    shipmentStore.selectedShipment?.status === 'Warehouse Received' &&
    shipmentStore.selectedShipment?.inventory_added !== true,
)

const onBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment`)
}

const goToShipmentInfo = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipmentId.value}/info`)
}

const resetItemForm = () => {
  editingItemId.value = null
  itemForm.name = ''
  itemForm.quantity = 1
  itemForm.barcode = ''
  itemForm.product_code = ''
  itemForm.image_url = ''
  itemForm.method = 'manual'
  itemForm.order_id = null
}

const openAddItemDialog = () => {
  resetItemForm()
  showAddItemDialog.value = true
}

const openEditItemDialog = (item: ShipmentItem) => {
  editingItemId.value = item.id
  itemForm.name = item.name ?? ''
  itemForm.quantity = item.quantity
  itemForm.barcode = item.barcode ?? ''
  itemForm.product_code = item.product_code ?? ''
  itemForm.image_url = item.image_url ?? ''
  itemForm.method = item.method ?? 'manual'
  itemForm.order_id = item.order_id ?? null
  showAddItemDialog.value = true
}

const openDeleteDialog = (item: ShipmentItem) => {
  pendingDeleteItem.value = item
  showDeleteDialog.value = true
}

const openItemDetailsDialog = (item: ShipmentItem) => {
  selectedDetailsItem.value = item
  showItemDetailsDialog.value = true
}

const onStatusChange = async (value: ShipmentStatus | null) => {
  const selectedShipment = shipmentStore.selectedShipment
  if (!selectedShipment || !value || value === selectedShipment.status) {
    return
  }

  await shipmentStore.updateShipmentField({
    id: selectedShipment.id,
    field: 'status',
    value,
  })
}

const onAddToInventory = async () => {
  await shipmentStore.addShipmentToInventory()
}

const onSubmitItem = async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }

  const quantity = Number(itemForm.quantity || 0)
  if (!itemForm.name.trim()) {
    $q.notify({ type: 'warning', message: 'Name is required.' })
    return
  }
  if (!Number.isFinite(quantity) || quantity <= 0) {
    $q.notify({ type: 'warning', message: 'Quantity must be greater than 0.' })
    return
  }

  let result:
    | {
        success: boolean
      }
    | undefined

  const editingId = editingItemId.value
  if (editingId != null) {
    result = await shipmentStore.updateShipmentItem({
      id: editingId,
      patch: {
        name: itemForm.name.trim(),
        quantity,
        barcode: itemForm.barcode.trim() || null,
        product_code: itemForm.product_code.trim() || null,
        image_url: itemForm.image_url.trim() || null,
        method: itemForm.method,
        order_id: itemForm.order_id,
      },
    })
  } else {
    result = await shipmentStore.addShipmentItemManual({
      shipment_id: shipmentId.value,
      name: itemForm.name.trim(),
      quantity,
      barcode: itemForm.barcode.trim() || null,
      product_code: itemForm.product_code.trim() || null,
      image_url: itemForm.image_url.trim() || null,
      method: itemForm.method,
      order_id: itemForm.order_id,
    })
  }

  if (!result.success) {
    return
  }

  showAddItemDialog.value = false
  resetItemForm()
}

const onConfirmDelete = async () => {
  const pendingDelete = pendingDeleteItem.value
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0 || !pendingDelete) {
    showDeleteDialog.value = false
    return
  }

  const result = await shipmentStore.deleteShipmentItem({ id: pendingDelete.id })
  if (!result.success) {
    return
  }

  pendingDeleteItem.value = null
  showDeleteDialog.value = false
}

type EditableNumericField =
  | 'price_gbp'
  | 'quantity'
  | 'received_quantity'
  | 'damaged_quantity'
  | 'stolen_quantity'
  | 'product_weight'
  | 'package_weight'

const formatDecimal = (value: number | null | undefined) =>
  value == null ? '-' : String(Number(value))

const formatFixed2 = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const roundTo = (value: number, decimals = 0) => {
  const factor = 10 ** decimals
  return Math.round(value * factor) / factor
}

const calculateItemCostBdt = (item: ShipmentItem) => {
  const shipment = shipmentStore.selectedShipment
  return calculateCostBdt({
    productWeight: item.product_weight,
    packageWeight: item.package_weight,
    cargoRate: shipment?.cargo_rate,
    priceGbp: item.price_gbp,
    productConversionRate: shipment?.product_conversion_rate,
    cargoConversionRate: shipment?.cargo_conversion_rate,
  })
}

const totals = computed(() => {
  return shipmentStore.shipmentItems.reduce(
    (acc, item) => {
      acc.price_gbp += Number(item.price_gbp ?? 0)
      acc.cost_bdt += calculateItemCostBdt(item)
      acc.quantity += Number(item.quantity ?? 0)
      acc.received_quantity += Number(item.received_quantity ?? 0)
      acc.damaged_quantity += Number(item.damaged_quantity ?? 0)
      acc.stolen_quantity += Number(item.stolen_quantity ?? 0)
      acc.product_weight += Number(item.product_weight ?? 0)
      acc.package_weight += Number(item.package_weight ?? 0)
      return acc
    },
    {
      price_gbp: 0,
      cost_bdt: 0,
      quantity: 0,
      received_quantity: 0,
      damaged_quantity: 0,
      stolen_quantity: 0,
      product_weight: 0,
      package_weight: 0,
    },
  )
})

const onNumericPopupSave = async (
  item: ShipmentItem,
  field: EditableNumericField,
  value: string | number | null,
  options?: { decimals?: number },
) => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }

  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed < 0) {
    $q.notify({ type: 'warning', message: 'Value must be 0 or greater.' })
    return
  }

  const normalized =
    field === 'quantity' ||
    field === 'received_quantity' ||
    field === 'damaged_quantity' ||
    field === 'stolen_quantity'
      ? Math.floor(parsed)
      : roundTo(parsed, options?.decimals ?? 0)

  const result = await shipmentStore.updateShipmentItem({
    id: item.id,
    patch: {
      [field]: normalized,
    },
  })

  if (!result.success) {
    return
  }

  if (field === 'product_weight' && item.product_id != null) {
    const productId = item.product_id
    await productStore.updateProduct({
      id: productId,
      product_weight: normalized,
    })
  }
}

onMounted(async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }
  try {
    await shipmentStore.fetchShipmentById(shipmentId.value)
  } finally {
    initialLoading.value = false
  }
})

watch(
  () => shipmentStore.selectedShipment?.status,
  (value) => {
    selectedStatus.value = value ?? 'Draft'
  },
  { immediate: true },
)
</script>

<style scoped>
.shipment-item-image-box {
  width: 64px;
  height: 64px;
  min-width: 64px;
  min-height: 64px;
  border-radius: 6px;
  overflow: hidden;
  background: #ffffff;
  border: 1px solid #e5e7eb;
}

.shipment-item-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

.shipment-item-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #e5e7eb;
  font-size: 11px;
}

.shipment-item-name-cell {
  white-space: normal;
  word-break: break-word;
  cursor: pointer;
}

.shipment-status-select {
  min-width: 260px;
  width: fit-content;
  max-width: 100%;
}

.shipment-name-col {
  width: 200px;
  min-width: 200px;
  max-width: 200px;
}

.shipment-sl-col {
  width: 60px;
  min-width: 60px;
  max-width: 60px;
}

.shipment-image-col {
  width: 88px;
  min-width: 88px;
  max-width: 88px;
}

.shipment-details-table :deep(th) {
  background: #fff;
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

.shipment-details-table :deep(td:first-child) {
  z-index: 1;
  background: #fff;
}

.shipment-details-table :deep(td:nth-child(2)) {
  z-index: 1;
  background: #fff;
}

.shipment-details-table :deep(tr:first-child th:first-child) {
  z-index: 3;
}

.shipment-details-table :deep(tr:first-child th:nth-child(2)) {
  z-index: 3;
}

.shipment-qty-col--quantity {
  background: #eaf7ef;
}

.shipment-qty-col--received {
  background: #eef4ff;
}

.shipment-qty-col--damaged {
  background: #fff1f0;
}

.shipment-qty-col--stolen {
  background: #fff8e9;
}

.shipment-details-table :deep(th.shipment-qty-col--quantity) {
  background: #eaf7ef;
}

.shipment-details-table :deep(th.shipment-qty-col--received) {
  background: #eef4ff;
}

.shipment-details-table :deep(th.shipment-qty-col--damaged) {
  background: #fff1f0;
}

.shipment-details-table :deep(th.shipment-qty-col--stolen) {
  background: #fff8e9;
}

</style>

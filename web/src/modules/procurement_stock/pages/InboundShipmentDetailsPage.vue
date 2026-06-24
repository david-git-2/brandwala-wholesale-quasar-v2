<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Page Header -->
      <AppPageHeader
        eyebrow="Procurement & Stock"
        :title="shipmentStore.currentShipment ? `Shipment: ${shipmentStore.currentShipment.name}` : 'Shipment Details'"
        subtitle="Review rates, line weights, conversion rules, and status workflow"
      >
        <template #action>
          <div v-if="shipmentStore.currentShipment" class="row items-center q-gutter-x-sm">
            <q-btn
              flat
              round
              dense
              icon="arrow_back"
              @click="goBack"
            />
            <q-btn
              color="secondary"
              outline
              icon="edit"
              label="Edit Details"
              no-caps
              @click="openEditShipment"
            />
            <q-btn
              color="negative"
              outline
              icon="delete"
              label="Delete Shipment"
              no-caps
              @click="confirmDeleteShipment"
            />
          </div>
        </template>
      </AppPageHeader>

      <!-- Loading / Error States -->
      <div v-if="shipmentStore.loading && !shipmentStore.currentShipment" class="text-center q-pa-xl">
        <q-spinner color="primary" size="3em" />
        <div class="text-grey-6 q-mt-md">Loading shipment details...</div>
      </div>

      <div v-else-if="shipmentStore.error && !shipmentStore.currentShipment" class="q-pa-md">
        <q-banner class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
          <template #action>
            <q-btn flat color="white" label="Go Back" @click="goBack" />
          </template>
        </q-banner>
      </div>

      <div v-else-if="shipmentStore.currentShipment" class="q-gutter-y-md">
        <!-- Error banner for actions -->
        <q-banner v-if="shipmentStore.error" class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
        </q-banner>

        <!-- Visual Status Stepper Card -->
        <q-card flat bordered class="q-pa-md">
          <div class="row items-center justify-between q-mb-md">
            <div class="text-subtitle1 text-weight-bold text-primary">Shipment Workflow Status</div>
            <div class="row q-gutter-x-sm">
              <q-btn
                v-if="canRevertStatus"
                color="grey-8"
                outline
                dense
                no-caps
                label="Revert Status"
                icon="arrow_left"
                class="q-px-sm"
                @click="onRevertStatus"
                :loading="updatingStatus"
              />
              <q-btn
                v-if="canAdvanceStatus"
                color="primary"
                unelevated
                dense
                no-caps
                :label="advanceStatusLabel"
                icon-right="arrow_right"
                class="q-px-sm"
                @click="onAdvanceStatus"
                :loading="updatingStatus"
              />
            </div>
          </div>

          <!-- Stepper progress bar -->
          <div class="row no-wrap items-center justify-between q-py-sm scroll-x" style="overflow-x: auto; gap: 8px;">
            <div
              v-for="(status, index) in statuses"
              :key="status"
              class="row no-wrap items-center text-caption text-weight-bold cursor-pointer"
              :class="index <= currentStatusIndex ? 'text-primary' : 'text-grey-5'"
              style="white-space: nowrap;"
            >
              <q-icon
                :name="index < currentStatusIndex ? 'check_circle' : (index === currentStatusIndex ? 'play_circle' : 'radio_button_unchecked')"
                size="18px"
                class="q-mr-xs"
              />
              <span>{{ status }}</span>
              <q-icon v-if="index < statuses.length - 1" name="chevron_right" size="14px" class="q-ml-xs text-grey-4" />
            </div>
          </div>
        </q-card>

        <div class="row q-col-gutter-md">
          <!-- Left Column: Summary and Costing Rates -->
          <div class="col-12 col-md-4 q-gutter-y-md">
            <!-- Shipment Summary -->
            <q-card flat bordered class="q-pa-md">
              <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">Shipment Summary</div>
              <q-list dense separator>
                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Display ID</q-item-label>
                    <q-item-label class="text-weight-bold">
                      #{{ shipmentStore.currentShipment.tenant_shipment_id || shipmentStore.currentShipment.id }}
                    </q-item-label>
                  </q-item-section>
                </q-item>
                
                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Status</q-item-label>
                    <q-item-label>
                      <q-chip
                        square
                        dense
                        :color="statusChipColor(shipmentStore.currentShipment.status)"
                        text-color="white"
                        class="text-weight-bold"
                      >
                        {{ shipmentStore.currentShipment.status }}
                      </q-chip>
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Type</q-item-label>
                    <q-item-label class="text-weight-bold text-capitalize">
                      {{ shipmentStore.currentShipment.type }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Stock Ready</q-item-label>
                    <q-item-label>
                      <q-chip
                        dense
                        square
                        :color="shipmentStore.currentShipment.stock_ready ? 'green-1' : 'grey-2'"
                        :text-color="shipmentStore.currentShipment.stock_ready ? 'green-9' : 'grey-8'"
                      >
                        {{ shipmentStore.currentShipment.stock_ready ? 'Ready' : 'Not Ready' }}
                      </q-chip>
                    </q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card>

            <!-- Rates & Weights -->
            <q-card flat bordered class="q-pa-md">
              <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">Rates & Weights</div>
              <q-list dense separator>
                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Product Conversion Rate</q-item-label>
                    <q-item-label class="text-weight-bold">
                      {{ shipmentStore.currentShipment.product_conversion_rate }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Cargo Conversion Rate</q-item-label>
                    <q-item-label class="text-weight-bold">
                      {{ shipmentStore.currentShipment.cargo_conversion_rate }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Cargo Rate</q-item-label>
                    <q-item-label class="text-weight-bold">
                      {{ shipmentStore.currentShipment.cargo_rate }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Transaction Rate</q-item-label>
                    <q-item-label class="text-weight-bold">
                      {{ shipmentStore.currentShipment.transaction_rate || '-' }}
                    </q-item-label>
                  </q-item-section>
                </q-item>

                <q-item class="q-py-sm">
                  <q-item-section>
                    <q-item-label class="text-grey-7 text-caption">Received Weight</q-item-label>
                    <q-item-label class="text-weight-bold">
                      {{ shipmentStore.currentShipment.received_weight !== null ? `${shipmentStore.currentShipment.received_weight} kg` : '-' }}
                    </q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card>

            <!-- Cost Summary Card -->
            <q-card flat bordered class="q-pa-md bg-primary text-white">
              <div class="text-subtitle1 text-weight-bold q-mb-md">Landed Cost Summary</div>
              <div class="q-gutter-y-sm">
                <div class="row justify-between">
                  <span class="text-caption text-blue-1">Total Ordered Qty:</span>
                  <span class="text-subtitle2 text-weight-bold">{{ totals.quantity }} pcs</span>
                </div>
                <div class="row justify-between">
                  <span class="text-caption text-blue-1">Total weight:</span>
                  <span class="text-subtitle2 text-weight-bold">{{ totals.weightKg.toFixed(2) }} kg</span>
                </div>
                <div class="row justify-between" v-if="shipmentStore.currentShipment.type === 'international'">
                  <span class="text-caption text-blue-1">Live Tx Rate:</span>
                  <span class="text-subtitle2 text-weight-bold">{{ totals.liveTxRate ? totals.liveTxRate.toFixed(4) : '-' }}</span>
                </div>
                <q-separator color="blue-8" class="q-my-xs" />
                <div class="row justify-between items-end">
                  <span class="text-subtitle2 text-weight-bold">Est. Landed Cost BDT:</span>
                  <span class="text-h6 text-weight-bolder">৳{{ totals.landedCostBdt.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}</span>
                </div>
              </div>
            </q-card>
          </div>

          <!-- Right Column: Shipment Line Items -->
          <div class="col-12 col-md-8">
            <q-card flat bordered class="q-pa-none">
              <q-card-section class="row items-center justify-between q-pb-none q-pa-md">
                <div class="text-subtitle1 text-weight-bold text-primary">Shipment Line Items</div>
                <q-btn
                  color="primary"
                  icon="add"
                  label="Add Item"
                  unelevated
                  dense
                  no-caps
                  class="q-px-md"
                  @click="openAddItem"
                />
              </q-card-section>

              <q-card-section class="q-pa-none q-mt-sm">
                <q-table
                  flat
                  :rows="shipmentStore.currentShipmentItems"
                  :columns="itemColumns"
                  row-key="id"
                  :loading="shipmentStore.loading"
                  :pagination="{ rowsPerPage: 10 }"
                >
                  <template #body-cell-image="props">
                    <q-td :props="props">
                      <q-avatar rounded size="42px" class="bg-grey-2">
                        <img
                          :src="props.row.image_url || 'https://placehold.co/56x56?text=No+Image'"
                          alt="Product Image"
                          style="object-fit: contain;"
                        />
                      </q-avatar>
                    </q-td>
                  </template>

                  <template #body-cell-product="props">
                    <q-td :props="props">
                      <div class="text-weight-bold text-grey-9">{{ props.row.name }}</div>
                      <div class="text-caption text-grey-6 row q-gutter-x-sm">
                        <span v-if="props.row.product_code">Code: {{ props.row.product_code }}</span>
                        <span v-if="props.row.barcode">Barcode: {{ props.row.barcode }}</span>
                      </div>
                    </q-td>
                  </template>

                  <template #body-cell-vendor="props">
                    <q-td :props="props">
                      {{ getVendorName(props.row.vendor_id) }}
                    </q-td>
                  </template>

                  <template #body-cell-weights="props">
                    <q-td :props="props">
                      <div class="text-caption">
                        Prod: {{ props.row.product_weight }}g
                      </div>
                      <div class="text-caption text-grey-6">
                        Pkg: {{ props.row.package_weight }}g
                      </div>
                    </q-td>
                  </template>

                  <template #body-cell-landed_cost="props">
                    <q-td :props="props" class="text-weight-bold text-secondary text-right">
                      ৳{{ formatMoney(calculateLineLandedCostBdt(props.row, shipmentStore.currentShipment)) }}
                    </q-td>
                  </template>

                  <template #body-cell-actions="props">
                    <q-td :props="props" align="center">
                      <q-btn
                        flat
                        round
                        dense
                        color="primary"
                        icon="edit"
                        @click="openEditItem(props.row)"
                      />
                      <q-btn
                        flat
                        round
                        dense
                        color="negative"
                        icon="delete"
                        @click="confirmDeleteItem(props.row.id)"
                      />
                    </q-td>
                  </template>

                  <template #no-data>
                    <div class="full-width text-center text-grey-7 q-py-lg">
                      <q-icon name="shopping_bag" size="48px" class="q-mb-sm text-grey-4" />
                      <div>No line items found. Add items to this shipment.</div>
                    </div>
                  </template>
                </q-table>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar, type QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository'
import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import ShipmentFormDialog from '../components/ShipmentFormDialog.vue'
import ShipmentItemFormDialog from '../components/ShipmentItemFormDialog.vue'
import ReceiveShipmentDialog from '../components/ReceiveShipmentDialog.vue'
import { calculateLineLandedCostBdt, calculateTransactionRate } from '../utils/landedCost'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()
const vendorStore = useVendorStore()
const shipmentStore = useGlobalShipmentStore()

const getVendorName = (vendorId: number | null) => {
  if (!vendorId) return 'None'
  const v = vendorStore.items.find((x) => x.id === vendorId)
  return v ? v.name : `ID: ${vendorId}`
}

const shipmentId = Number(route.params.id)
const updatingStatus = ref(false)

const statuses = [
  'Draft',
  'Order Placed',
  'Proforma Generated',
  'Payment Done',
  'Delivery Date Received',
  'Uk Warehouse Delivery Received',
  'Air Shipment Date Set',
  'Airport Arrival',
  'Airport Released',
  'Warehouse Received',
  'Ready Stock',
]

const currentStatusIndex = computed(() => {
  if (!shipmentStore.currentShipment) return -1
  return statuses.indexOf(shipmentStore.currentShipment.status)
})

const canRevertStatus = computed(() => {
  return currentStatusIndex.value > 0 && shipmentStore.currentShipment?.status !== 'Ready Stock'
})

const canAdvanceStatus = computed(() => {
  if (!shipmentStore.currentShipment) return false
  return currentStatusIndex.value < statuses.length - 1
})

const advanceStatusLabel = computed(() => {
  if (!shipmentStore.currentShipment) return 'Advance Status'
  const nextStatus = statuses[currentStatusIndex.value + 1]
  if (nextStatus === 'Ready Stock') {
    return 'Receive to Stock'
  }
  return `Promote: ${nextStatus}`
})

const itemColumns: QTableColumn[] = [
  { name: 'image', label: 'Image', field: 'image_url', align: 'left', sortable: false },
  { name: 'product', label: 'Product Details', field: 'name', align: 'left', sortable: true },
  { name: 'vendor', label: 'Vendor', field: 'vendor_id', align: 'left', sortable: true },
  { name: 'ordered_quantity', label: 'Qty', field: 'ordered_quantity', align: 'center', sortable: true },
  { name: 'purchase_price', label: 'Price', field: 'purchase_price', align: 'right', sortable: true },
  { name: 'weights', label: 'Weights (g)', field: 'product_weight', align: 'left', sortable: false },
  { name: 'landed_cost', label: 'Est. Landed Cost', field: 'id', align: 'right', sortable: false },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const totals = computed(() => {
  const shipment = shipmentStore.currentShipment
  const items = shipmentStore.currentShipmentItems
  if (!shipment) return { quantity: 0, weightKg: 0, landedCostBdt: 0, liveTxRate: null }

  let totalQty = 0
  let totalWeightKg = 0
  let totalLandedCost = 0

  for (const item of items) {
    const qty = item.ordered_quantity || 0
    totalQty += qty
    totalWeightKg += ((item.product_weight || 0) + (item.package_weight || 0)) * qty / 1000
    totalLandedCost += calculateLineLandedCostBdt(item, shipment) * qty
  }

  const liveTxRate = calculateTransactionRate(shipment, items)

  return {
    quantity: totalQty,
    weightKg: totalWeightKg,
    landedCostBdt: totalLandedCost,
    liveTxRate,
  }
})

const loadShipmentDetails = () => {
  if (!Number.isNaN(shipmentId)) {
    void shipmentStore.fetchShipmentDetails(shipmentId)
  }
}

onMounted(() => {
  loadShipmentDetails()
  if (authStore.tenantId) {
    void vendorStore.fetchVendors(authStore.tenantId)
  }
})

const goBack = () => {
  router.back()
}

const formatMoney = (val: number) => {
  return val.toFixed(2)
}

const onAdvanceStatus = async () => {
  if (!shipmentStore.currentShipment) return
  const nextStatus = statuses[currentStatusIndex.value + 1]
  if (!nextStatus) return

  if (nextStatus === 'Ready Stock') {
    $q.dialog({
      component: ReceiveShipmentDialog,
      componentProps: {
        shipmentId,
      },
    }).onOk(() => {
      loadShipmentDetails()
    })
    return
  }

  updatingStatus.value = true
  try {
    // Calculate live transaction rate to auto-save if needed
    const txRate = totals.value.liveTxRate
    const updatePayload: any = { status: nextStatus }
    if (txRate !== null) {
      updatePayload.transaction_rate = txRate
    }

    await shipmentStore.updateShipment(shipmentId, updatePayload)
    $q.notify({ type: 'positive', message: `Shipment advanced to: ${nextStatus}` })
    loadShipmentDetails()
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Failed to update status' })
  } finally {
    updatingStatus.value = false
  }
}

const onRevertStatus = async () => {
  if (!shipmentStore.currentShipment) return
  const prevStatus = statuses[currentStatusIndex.value - 1]
  if (!prevStatus) return

  updatingStatus.value = true
  try {
    await shipmentStore.updateShipment(shipmentId, { status: prevStatus })
    $q.notify({ type: 'positive', message: `Shipment status reverted to: ${prevStatus}` })
    loadShipmentDetails()
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Failed to update status' })
  } finally {
    updatingStatus.value = false
  }
}

const openEditShipment = () => {
  if (!shipmentStore.currentShipment) return
  $q.dialog({
    component: ShipmentFormDialog,
    componentProps: {
      shipment: shipmentStore.currentShipment,
    },
  }).onOk(() => {
    loadShipmentDetails()
  })
}

const confirmDeleteShipment = () => {
  $q.dialog({
    title: 'Confirm Deletion',
    message: 'Are you sure you want to delete this shipment? All shipment items will be deleted. This action cannot be undone.',
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      await shipmentStore.deleteShipment(shipmentId)
      $q.notify({ type: 'positive', message: 'Shipment deleted successfully' })
      goBack()
    } catch (err: any) {
      $q.notify({ type: 'negative', message: err.message || 'Failed to delete shipment' })
    }
  })
}

const openAddItem = () => {
  $q.dialog({
    component: ShipmentItemFormDialog,
    componentProps: {
      shipmentId,
    },
  }).onOk(() => {
    loadShipmentDetails()
  })
}

const openEditItem = (item: GlobalShipmentItem) => {
  $q.dialog({
    component: ShipmentItemFormDialog,
    componentProps: {
      shipmentId,
      item,
    },
  }).onOk(() => {
    loadShipmentDetails()
  })
}

const confirmDeleteItem = (itemId: number) => {
  $q.dialog({
    title: 'Confirm Deletion',
    message: 'Are you sure you want to delete this line item?',
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      await shipmentStore.deleteShipmentItem(itemId)
      $q.notify({ type: 'positive', message: 'Item deleted successfully' })
      loadShipmentDetails()
    } catch (err: any) {
      $q.notify({ type: 'negative', message: err.message || 'Failed to delete item' })
    }
  })
}

const statusChipColor = (status: string) => {
  switch (status) {
    case 'Draft': return 'grey-7'
    case 'Order Placed': return 'blue-6'
    case 'Payment Done': return 'indigo-6'
    case 'Warehouse Received': return 'orange-8'
    case 'Ready Stock': return 'green-7'
    default: return 'primary'
  }
}
</script>

<template>
  <q-page class="q-pa-xs q-sm-pa-sm" style="max-width: 100%; overflow-x: hidden;">
    <section class="q-gutter-y-sm" style="width: 100%; min-width: 0; overflow: hidden;">
      
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

      <div v-else-if="shipmentStore.currentShipment" class="q-gutter-y-md" style="min-width: 0; width: 100%;">
        <!-- Error banner for actions -->
        <q-banner v-if="shipmentStore.error" class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
        </q-banner>

        <!-- Compact Header & Workflow Status Card -->
        <q-card flat class="q-mb-sm floating-surface hero-surface shadow-1">
          <q-card-section class="q-py-sm">
            <div class="row items-center justify-between q-col-gutter-sm">
              <!-- Left Side: ID, Title, and Subtitle Meta -->
              <div class="col-12 col-sm">
                <div class="row items-center q-gutter-sm">
                  <q-badge color="primary" outline class="text-weight-medium q-px-sm">
                    #{{ shipmentStore.currentShipment.tenant_shipment_id || shipmentStore.currentShipment.id }}
                  </q-badge>
                  <div class="text-subtitle1 text-weight-bold text-grey-9">
                    {{ shipmentStore.currentShipment.name }}
                  </div>
                </div>
                <div class="text-caption text-grey-7 q-mt-xs q-pl-xs row items-center q-gutter-x-sm wrap">
                  <span>Type: <strong class="text-capitalize">{{ shipmentStore.currentShipment.type }}</strong></span>
                  <span>|</span>
                  <span>Weight: <strong>{{ shipmentStore.currentShipment.received_weight !== null ? `${shipmentStore.currentShipment.received_weight} kg` : '-' }}</strong></span>
                  <span>|</span>
                  <q-chip
                    dense
                    square
                    :color="shipmentStore.currentShipment.stock_ready ? 'green-1' : 'grey-2'"
                    :text-color="shipmentStore.currentShipment.stock_ready ? 'green-9' : 'grey-8'"
                    class="q-ma-none text-weight-bold"
                    style="font-size: 11px;"
                  >
                    {{ shipmentStore.currentShipment.stock_ready ? 'Stock Ready' : 'Stock Not Ready' }}
                  </q-chip>
                </div>
              </div>

              <!-- Right Side: Workflow & Action Buttons -->
              <div class="col-12 col-sm-auto row items-center q-gutter-sm justify-start justify-sm-end q-mt-xs q-mt-sm-none wrap">
                <!-- Workflow Status Selector Chip -->
                <q-chip
                  dense
                  square
                  clickable
                  :style="statusChipStyle(shipmentStore.currentShipment.status)"
                  class="q-px-md q-py-sm text-weight-bold q-ma-none"
                >
                  <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(shipmentStore.currentShipment.status) }" />
                  {{ shipmentStore.currentShipment.status }}
                  <q-icon name="arrow_drop_down" class="q-ml-xs" size="16px" />
                  <q-menu>
                    <q-list dense style="min-width: 180px">
                      <q-item
                        v-for="status in statuses"
                        :key="status"
                        clickable
                        v-close-popup
                        @click="changeStatus(status)"
                      >
                        <q-item-section>{{ status }}</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-chip>

                <!-- Edit / Delete flat buttons with icons only -->
                <q-btn
                  color="secondary"
                  flat
                  round
                  dense
                  icon="edit"
                  @click="openEditShipment"
                >
                  <q-tooltip>Edit Details</q-tooltip>
                </q-btn>
                <q-btn
                  color="negative"
                  flat
                  round
                  dense
                  icon="delete"
                  @click="confirmDeleteShipment"
                >
                  <q-tooltip>Delete Shipment</q-tooltip>
                </q-btn>
              </div>
            </div>
          </q-card-section>
        </q-card>

        <div class="row q-col-gutter-md">
          <!-- Left Column: Summary and Costing Rates -->
          <div v-if="isLeftColumnVisible" class="col-12 col-md-4 q-gutter-y-md">
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

            <!-- Shipment Weight Balance Card -->
            <ShipmentWeightBalanceCard
              :shipment-id="shipmentId"
              @applied="loadShipmentDetails"
            />
          </div>


          <!-- Right Column: Shipment Line Items -->
          <div class="col-12" :class="isLeftColumnVisible ? 'col-md-8' : ''">
            <q-card flat bordered class="q-pa-none line-items-card">
              <q-card-section class="row items-center justify-between q-pb-none q-pa-md">
                <div class="row items-center">
                  <q-btn
                    flat
                    round
                    dense
                    color="primary"
                    :icon="isLeftColumnVisible ? 'keyboard_double_arrow_left' : 'keyboard_double_arrow_right'"
                    @click="isLeftColumnVisible = !isLeftColumnVisible"
                    class="q-mr-sm"
                  >
                    <q-tooltip>{{ isLeftColumnVisible ? 'Collapse Sidebar' : 'Expand Sidebar' }}</q-tooltip>
                  </q-btn>
                  <div class="text-subtitle1 text-weight-bold text-primary">Shipment Line Items</div>
                </div>
                <div class="row items-center q-gutter-x-sm">
                  <q-btn
                    color="primary"
                    outline
                    no-caps
                    size="sm"
                    icon="view_column"
                    dense
                    label="Columns"
                    class="q-px-sm"
                  >
                    <q-menu>
                      <q-list style="min-width: 220px" class="q-py-xs">
                        <q-item>
                          <q-item-section>
                            <div class="text-subtitle2 text-weight-bold text-primary">Show Columns</div>
                          </q-item-section>
                        </q-item>
                        <q-item clickable>
                          <q-item-section>
                            <q-checkbox
                              v-model="allColumnsSelected"
                              label="Select / Deselect All"
                            />
                          </q-item-section>
                        </q-item>
                        <q-separator />
                        <q-item v-for="col in availableColumnOptions" :key="col.value" clickable>
                          <q-item-section>
                            <q-checkbox
                              v-model="visibleColumns"
                              :val="col.value"
                              :label="col.label"
                            />
                          </q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-btn>
                  <q-btn
                    color="primary"
                    icon="add_shopping_cart"
                    label="Add Items"
                    unelevated
                    dense
                    no-caps
                    class="q-px-md"
                    @click="openAddItems"
                  />
                </div>
              </q-card-section>

              <ShipmentLineItemsTable
                :items="shipmentStore.currentShipmentItems"
                :shipment="shipmentStore.currentShipment"
                :loading="shipmentStore.loading"
                :visible-columns="visibleColumns"
                @edit-details="openEditItem"
                @delete="confirmDeleteItem"
              />
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
import { useQuasar } from 'quasar'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import type { GlobalShipment, GlobalShipmentItem } from '../repositories/globalShipmentRepository'
import ShipmentFormDialog from '../components/ShipmentFormDialog.vue'
import ShipmentItemFormDialog from '../components/ShipmentItemFormDialog.vue'
import ReceiveShipmentDialog from '../components/ReceiveShipmentDialog.vue'
import AddShipmentItemsDrawer from '../components/AddShipmentItemsDrawer.vue'
import ShipmentLineItemsTable, { type ColumnKey } from '../components/ShipmentLineItemsTable.vue'
import ShipmentWeightBalanceCard from '../components/ShipmentWeightBalanceCard.vue'
import { calculateLineLandedCostBdt, calculateTransactionRate } from '../utils/landedCost'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const shipmentStore = useGlobalShipmentStore()

const isLeftColumnVisible = ref(true)

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

const baseColumnOptions = [
  { label: 'Name', value: 'name' as ColumnKey },
  { label: 'Product ID', value: 'product_id' as ColumnKey },
  { label: 'Barcode', value: 'barcode' as ColumnKey },
  { label: 'Product Code', value: 'product_code' as ColumnKey },
  { label: 'Method', value: 'add_method' as ColumnKey },
  { label: 'Price GBP', value: 'purchase_price' as ColumnKey },
  { label: 'Cost BDT', value: 'cost_bdt' as ColumnKey },
  { label: 'Quantity', value: 'ordered_quantity' as ColumnKey },
  { label: 'Product Wt', value: 'product_weight' as ColumnKey },
  { label: 'Package Wt', value: 'package_weight' as ColumnKey },
  { label: 'Actions', value: 'actions' as ColumnKey },
]

const availableColumnOptions = computed(() => {
  const isIntl = shipmentStore.currentShipment?.type === 'international'
  return baseColumnOptions.filter((col) => {
    if (!isIntl) {
      return !['purchase_price', 'product_weight', 'package_weight'].includes(col.value)
    }
    return true
  })
})

const visibleColumns = ref<ColumnKey[]>([
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

const allColumnsSelected = computed({
  get: () => availableColumnOptions.value.every((col) => visibleColumns.value.includes(col.value)),
  set: (val) => {
    visibleColumns.value = val
      ? availableColumnOptions.value.map((col) => col.value)
      : ['name', 'actions']
  },
})

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
})

const goBack = () => {
  router.back()
}

const changeStatus = (newStatus: string) => {
  if (!shipmentStore.currentShipment) return
  if (shipmentStore.currentShipment.status === newStatus) return

  if (newStatus === 'Ready Stock') {
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

  $q.dialog({
    title: 'Confirm Status Change',
    message: `Are you sure you want to change the status of this shipment to "${newStatus}"?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      updatingStatus.value = true
      try {
        const txRate = totals.value.liveTxRate
        const updatePayload: Partial<Omit<GlobalShipment, 'id' | 'created_at' | 'updated_at' | 'parent_tenant_id'>> = { status: newStatus }
        if (txRate !== null) {
          updatePayload.transaction_rate = txRate
        }

        await shipmentStore.updateShipment(shipmentId, updatePayload)
        $q.notify({ type: 'positive', message: `Shipment status updated to: ${newStatus}` })
        loadShipmentDetails()
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        $q.notify({ type: 'negative', message: message || 'Failed to update status' })
      } finally {
        updatingStatus.value = false
      }
    })()
  })
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
  }).onOk(() => {
    void (async () => {
      try {
        await shipmentStore.deleteShipment(shipmentId)
        $q.notify({ type: 'positive', message: 'Shipment deleted successfully' })
        goBack()
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        $q.notify({ type: 'negative', message: message || 'Failed to delete shipment' })
      }
    })()
  })
}

const openAddItems = () => {
  $q.dialog({
    component: AddShipmentItemsDrawer,
    componentProps: { shipmentId },
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
  }).onOk(() => {
    void (async () => {
      try {
        await shipmentStore.deleteShipmentItem(itemId)
        $q.notify({ type: 'positive', message: 'Item deleted successfully' })
        loadShipmentDetails()
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        $q.notify({ type: 'negative', message: message || 'Failed to delete item' })
      }
    })()
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

const statusChipStyle = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase()
  switch (value) {
    case 'draft':
      return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db', borderRadius: '6px' }
    case 'order placed':
      return { backgroundColor: '#eff6ff', color: '#1d4ed8', border: '1px solid #bfdbfe', borderRadius: '6px' }
    case 'proforma generated':
      return { backgroundColor: '#f0fdf4', color: '#15803d', border: '1px solid #bbf7d0', borderRadius: '6px' }
    case 'payment done':
      return { backgroundColor: '#faf5ff', color: '#7e22ce', border: '1px solid #e9d5ff', borderRadius: '6px' }
    case 'delivery date received':
      return { backgroundColor: '#fdf2f8', color: '#be185d', border: '1px solid #fbcfe8', borderRadius: '6px' }
    case 'uk warehouse delivery received':
      return { backgroundColor: '#fff7ed', color: '#c2410c', border: '1px solid #ffedd5', borderRadius: '6px' }
    case 'air shipment date set':
      return { backgroundColor: '#ecfdf5', color: '#047857', border: '1px solid #a7f3d0', borderRadius: '6px' }
    case 'airport arrival':
      return { backgroundColor: '#f0fdfa', color: '#0f766e', border: '1px solid #99f6e4', borderRadius: '6px' }
    case 'airport released':
      return { backgroundColor: '#f5f3ff', color: '#6d28d9', border: '1px solid #ddd6fe', borderRadius: '6px' }
    case 'warehouse received':
      return { backgroundColor: '#fffbeb', color: '#b45309', border: '1px solid #fde68a', borderRadius: '6px' }
    case 'ready stock':
      return { backgroundColor: '#f0fdf4', color: '#166534', border: '1px solid #bbf7d0', borderRadius: '6px' }
    default:
      return { backgroundColor: '#f9fafb', color: '#1f2937', border: '1px solid #e5e7eb', borderRadius: '6px' }
  }
}

const statusDotColor = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase()
  switch (value) {
    case 'draft': return '#4b5563'
    case 'order placed': return '#2563eb'
    case 'proforma generated': return '#16a34a'
    case 'payment done': return '#9333ea'
    case 'delivery date received': return '#db2777'
    case 'uk warehouse delivery received': return '#ea580c'
    case 'air shipment date set': return '#059669'
    case 'airport arrival': return '#0d9488'
    case 'airport released': return '#7c3aed'
    case 'warehouse received': return '#d97706'
    case 'ready stock': return '#15803d'
    default: return '#9ca3af'
  }
}
</script>

<style scoped>
.line-items-card {
  min-width: 0;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>

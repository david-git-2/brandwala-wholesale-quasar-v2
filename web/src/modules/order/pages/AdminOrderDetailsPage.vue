<template>
  <q-page class="q-pa-md order-details-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-start q-col-gutter-sm">
          <div class="col">
            <div class="row items-center q-gutter-sm">
              <q-btn flat round dense color="primary" icon="arrow_back" aria-label="Back" @click="onBackToOrders" />
              <q-badge color="primary" outline class="text-weight-medium">
                #{{ orderStore.selected?.id ?? '-' }}
              </q-badge>
              <div class="text-h6 text-weight-bold">
                {{ orderStore.selected?.name ?? 'Order Details' }}
              </div>
            </div>
            <div class="text-caption text-grey-8 q-mt-xs">
              Customer Group: {{ orderStore.selected?.customer_group_name ?? 'N/A' }}
            </div>
          </div>
          <div class="col-auto row items-center q-gutter-sm order-header-status-left">
            <q-btn
              v-if="tableViewMode === 'detailed'"
              color="primary"
              outline
              no-caps
              size="sm"
              icon="view_column"
              dense
              label="Columns"
              aria-label="Select columns"
              class="q-px-md q-py-sm"
            >
              <q-menu>
                <q-list style="min-width: 240px">
                  <q-item>
                    <q-item-section>
                      <div class="text-subtitle2">Show Columns</div>
                    </q-item-section>
                  </q-item>
                  <q-item>
                    <q-item-section>
                      <q-option-group
                        v-model="selectedDetailColumns"
                        type="checkbox"
                        :options="detailColumnSelectorOptions"
                      />
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
            <q-chip
              dense
              square
              clickable
              :style="statusChipStyle(selectedStatus)"
              class="order-status-chip q-px-md q-py-sm"
            >
              <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(selectedStatus) }" />
              {{ selectedStatus ?? '-' }}
              <q-menu>
                <q-list dense style="min-width: 170px">
                  <q-item v-for="option in statusOptions" :key="option" clickable v-close-popup @click="onStatusChange(option)">
                    <q-item-section>{{ option }}</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-chip>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="orderStore.loading" />

    <template v-else>
    <q-card flat class="q-mb-sm floating-surface shadow-1">
      <q-card-section class="q-py-xs">
    <div class="row q-gutter-sm q-my-sm items-end">
      <q-input
        filled
        dense
        v-model="conversionRate"
        type="number"
        class="soft-input"
        label="Conversion Rate"
        :disable="isRateEditingLocked"
      />
      <q-input
        filled
        dense
        v-model="cargoRate"
        type="number"
        class="soft-input"
        label="Cargo Rate / KG"
        :disable="isRateEditingLocked"
      />
      <q-input
        filled
        dense
        v-model="profitRate"
        type="number"
        class="soft-input"
        label="Profit Rate"
        :disable="isRateEditingLocked"
      />
      <q-btn
        color="primary"
        dense
        no-caps
        label="Save Rates"
        class="pill-btn slim-btn q-px-sm"
        :loading="orderStore.saving"
        :disable="isRateEditingLocked"
        @click="onSaveRates"
      />
      <q-btn
        color="secondary"
        dense
        no-caps
        :label="showSummary ? 'Hide Summary' : 'Show Summary'"
        class="pill-btn slim-btn"
        @click="showSummary = !showSummary"
      />

    </div>
      </q-card-section>
    </q-card>
    <q-card v-if="showSummary" flat bordered class="q-mt-sm q-mb-md bg-white">
      <q-card-section class="row q-pa-none admin-summary-grid">
        <div class="col-4 admin-summary-cell admin-summary-bg-qty">
          <div class="text-caption text-grey-8 admin-summary-label">Total Quantity</div>
          <div class="text-subtitle1 text-weight-bold admin-summary-value">{{ adminSummary.totalQuantity }}</div>
        </div>
        <div class="col-4 admin-summary-cell admin-summary-bg-gbp">
          <div class="text-caption text-grey-8 admin-summary-label">Total Price GBP</div>
          <div class="text-subtitle1 text-weight-bold admin-summary-value">{{ formatFixed2(adminSummary.totalPriceGbp) }}</div>
        </div>
        <div class="col-4 admin-summary-cell admin-summary-bg-bdt">
          <div class="text-caption text-grey-8 admin-summary-label">Total Cost BDT</div>
          <div class="text-subtitle1 text-weight-bold admin-summary-value">{{ formatFixed2(adminSummary.totalCostBdt) }}</div>
        </div>
        <div class="col-4 admin-summary-cell admin-summary-bg-first">
          <div class="text-caption text-grey-8 admin-summary-label">First Offer Total BDT</div>
          <div class="text-subtitle1 text-weight-bold admin-summary-value">{{ formatFixed2(adminSummary.totalFirstOfferBdt) }}</div>
        </div>
        <div class="col-4 admin-summary-cell admin-summary-bg-customer">
          <div class="text-caption text-grey-8 admin-summary-label">Customer Offer Total BDT</div>
          <div class="text-subtitle1 text-weight-bold admin-summary-value">{{ formatFixed2(adminSummary.totalCustomerOfferBdt) }}</div>
        </div>
        <div class="col-4 admin-summary-cell admin-summary-bg-final">
          <div class="text-caption text-grey-8 admin-summary-label">Final Offer Total BDT</div>
          <div class="text-subtitle1 text-weight-bold admin-summary-value">{{ formatFixed2(adminSummary.totalFinalOfferBdt) }}</div>
        </div>
      </q-card-section>
    </q-card>
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
      v-model:visible-column-names="selectedDetailColumns"
      :items="orderStore.selected?.order_items ?? []"
      :status="selectedStatus ?? 'customer_submit'"
      :conversion-rate="Number(conversionRate) || 0"
      :cargo-rate="Number(cargoRate) || 0"
      :profit-rate="Number(profitRate) || 0"
      :show-column-selector="false"
      :visible-column-names="selectedDetailColumns"
      @ship="onShipItem"
    />

    <q-dialog v-model="confirmDisableNegotiationOpen">
      <q-card style="min-width: 360px">
        <q-card-section class="text-h6">Disable Negotiation?</q-card-section>
        <q-card-section>
          If you disable negotiation, negotiate state will be removed and offers will be prefilled.
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

    <q-dialog v-model="showNegotiationDialog" persistent>
      <q-card style="min-width: 360px">
        <q-card-section class="text-h6">Negotiation Setting</q-card-section>
        <q-card-section>
          <div class="q-mb-sm">Select negotiation mode for this order.</div>
          <q-option-group
            v-model="negotiationChoice"
            :options="negotiationOptions"
            type="radio"
            color="primary"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn
            color="primary"
            label="Save"
            :loading="orderStore.saving"
            @click="onSaveNegotiationFromDialog"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
    </template>
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
import PageInitialLoader from 'src/components/PageInitialLoader.vue'




const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const orderStore = useOrderStore()
const shipmentStore = useShipmentStore()
const tenantStore = useTenantStore()

const selectedStatus = ref<OrderStatus | null>(null)
const tableViewMode = ref<'compact' | 'detailed'>('detailed')
const confirmDisableNegotiationOpen = ref(false)
const confirmDeleteSelectedOpen = ref(false)
const confirmRemoveShipmentOpen = ref(false)
const selectedItemIds = ref<number[]>([])
const showAddShipmentDialog = ref(false)
const selectedQuantity = ref<number | null>(null)
const selectedPriceGbp = ref<number | null>(null)
const selectedShipItemId = ref<number | null>(null)
const pendingRemoveShipItemId = ref<number | null>(null)
const showNegotiationDialog = ref(false)
const showSummary = ref(false)
const selectedDetailColumns = ref<string[]>([])
const negotiationChoice = ref<boolean>(false)
const negotiationDialogShownForOrderId = ref<number | null>(null)

const negotiationOptions = [
  { label: 'Enable Negotiation', value: true },
  { label: 'Disable Negotiation', value: false },
]

const allStatusOptions: OrderStatus[] = [
  'customer_submit',
  'direct_priced',
  'priced',
  'negotiate',
  'final_offered',
  'ordered',
  'processing',
  'invoicing',
  'invoiced',
]
const statusOptions = computed<OrderStatus[]>(() =>
  orderStore.selected?.negotiate === false
    ? allStatusOptions.filter((status) => status !== 'negotiate' && status !== 'priced')
    : allStatusOptions.filter((status) => status !== 'direct_priced'),
)

const tableViewOptions = [
  { icon: 'view_agenda', value: 'compact' },
  { icon: 'table_rows', value: 'detailed' },
]

const detailColumnLabelMap: Record<string, string> = {
  name: 'Name',
  ship: 'Ship',
  product_meta: 'Product Details',
  ordered_quantity: 'Ordered Qty',
  product_weight: 'Product Weight',
  package_weight: 'Package Weight',
  total_weight: 'Total Weight',
  price_gbp: 'Price (GBP)',
  line_total_purchese_cost_gbp: 'Line Purchase Cost GBP',
  cargo_rate: 'Cargo Rate',
  unit_line_cost_gbp: 'Unit Cost GBP',
  cost_bdt: 'Cost BDT',
  line_total_cost_bdt: 'Line Cost BDT',
  seller_first_offer_bdt: 'First Offer',
  seller_first_offer_bdt_total: 'First Offer Total',
  seller_first_offer_profit_pc: 'First Offer Profit/Unit',
  seler_first_offer_profit_pc_perc: 'First Offer Profit %',
  seller_first_offer_profit_total: 'First Offer Profit Total',
  customer_offer_bdt: 'Customer Offer',
  customer_offer_bdt_total: 'Customer Offer Total',
  customer_offer_profit_pc: 'Customer Offer Profit/Unit',
  customer_offer_profit_total: 'Customer Offer Profit Total',
  customer_offer_profit_pc_perc: 'Customer Offer Profit %',
  final_offer_bdt: 'Final Offer',
  final_offer_bdt_total: 'Final Offer Total',
  final_offer_profit_pc: 'Final Offer Profit/Unit',
  final_offer_profit_total: 'Final Offer Profit Total',
  final_offer_profit_pc_perc: 'Final Offer Profit %',
}

const statusDetailColumns: Record<string, string[]> = {
  customer_submit: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total'],
  direct_priced: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total'],
  priced: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total', 'customer_offer_bdt', 'customer_offer_bdt_total', 'customer_offer_profit_pc', 'customer_offer_profit_total', 'customer_offer_profit_pc_perc'],
  negotiate: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total', 'customer_offer_bdt', 'customer_offer_bdt_total', 'customer_offer_profit_pc', 'customer_offer_profit_total', 'customer_offer_profit_pc_perc', 'final_offer_bdt', 'final_offer_bdt_total', 'final_offer_profit_pc', 'final_offer_profit_total', 'final_offer_profit_pc_perc'],
  final_offered: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total', 'customer_offer_bdt', 'customer_offer_bdt_total', 'customer_offer_profit_pc', 'customer_offer_profit_total', 'customer_offer_profit_pc_perc', 'final_offer_bdt', 'final_offer_bdt_total', 'final_offer_profit_pc', 'final_offer_profit_total', 'final_offer_profit_pc_perc'],
  ordered: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total', 'customer_offer_bdt', 'customer_offer_bdt_total', 'customer_offer_profit_pc', 'customer_offer_profit_total', 'customer_offer_profit_pc_perc', 'final_offer_bdt', 'final_offer_bdt_total', 'final_offer_profit_pc', 'final_offer_profit_total', 'final_offer_profit_pc_perc'],
  processing: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total', 'customer_offer_bdt', 'customer_offer_bdt_total', 'customer_offer_profit_pc', 'customer_offer_profit_total', 'customer_offer_profit_pc_perc', 'final_offer_bdt', 'final_offer_bdt_total', 'final_offer_profit_pc', 'final_offer_profit_total', 'final_offer_profit_pc_perc'],
  invoicing: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total', 'customer_offer_bdt', 'customer_offer_bdt_total', 'customer_offer_profit_pc', 'customer_offer_profit_total', 'customer_offer_profit_pc_perc', 'final_offer_bdt', 'final_offer_bdt_total', 'final_offer_profit_pc', 'final_offer_profit_total', 'final_offer_profit_pc_perc'],
  invoiced: ['name', 'ship', 'product_meta', 'ordered_quantity', 'product_weight', 'package_weight', 'total_weight', 'price_gbp', 'line_total_purchese_cost_gbp', 'cargo_rate', 'unit_line_cost_gbp', 'cost_bdt', 'line_total_cost_bdt', 'seller_first_offer_bdt', 'seller_first_offer_bdt_total', 'seller_first_offer_profit_pc', 'seler_first_offer_profit_pc_perc', 'seller_first_offer_profit_total', 'customer_offer_bdt', 'customer_offer_bdt_total', 'customer_offer_profit_pc', 'customer_offer_profit_total', 'customer_offer_profit_pc_perc', 'final_offer_bdt', 'final_offer_bdt_total', 'final_offer_profit_pc', 'final_offer_profit_total', 'final_offer_profit_pc_perc'],
}

const detailColumnSelectorOptions = computed(() => {
  const status = selectedStatus.value ?? 'customer_submit'
  const names = statusDetailColumns[status] ?? statusDetailColumns.customer_submit
  return names.map((name) => ({
    label: detailColumnLabelMap[name] ?? name,
    value: name,
  }))
})

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
    const nextStatus = status ?? 'customer_submit'
    if (!selectedDetailColumns.value.length) {
      selectedDetailColumns.value = [...(statusDetailColumns[nextStatus] ?? statusDetailColumns.customer_submit)]
    }
  },
  { immediate: true }
)

watch(
  () => orderStore.selected,
  (selected) => {
    if (!selected?.id) {
      return
    }

    negotiationChoice.value = selected.negotiate !== false

    if (
      selected.status === 'customer_submit' &&
      negotiationDialogShownForOrderId.value !== selected.id
    ) {
      showNegotiationDialog.value = true
      negotiationDialogShownForOrderId.value = selected.id
    }
  },
  { immediate: true },
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
const isRateEditingLocked = computed(() =>
  ['ordered', 'processing', 'invoicing', 'invoiced'].includes(orderStore.selected?.status ?? ''),
)

const selectedItems = computed(() => orderStore.selected?.order_items ?? [])
const adminSummary = computed(() => {
  return selectedItems.value.reduce(
    (acc, item) => {
      const qty = Number(item.ordered_quantity ?? 0)
      acc.totalQuantity += qty
      acc.totalPriceGbp += qty * Number(item.price_gbp ?? 0)
      acc.totalCostGbp += qty * Number(item.cost_gbp ?? 0)
      acc.totalCostBdt += qty * Number(item.cost_bdt ?? 0)
      acc.totalFirstOfferBdt += qty * Number(item.first_offer_bdt ?? 0)
      acc.totalCustomerOfferBdt += qty * Number(item.customer_offer_bdt ?? 0)
      acc.totalFinalOfferBdt += qty * Number(item.final_offer_bdt ?? 0)
      return acc
    },
    {
      totalQuantity: 0,
      totalPriceGbp: 0,
      totalCostGbp: 0,
      totalCostBdt: 0,
      totalFirstOfferBdt: 0,
      totalCustomerOfferBdt: 0,
      totalFinalOfferBdt: 0,
    },
  )
})

const ceil2 = (n: number) => Math.ceil(n * 100) / 100
const ceilInt = (n: number) => Math.ceil(n)
const roundUpTo5 = (n: number) => Math.ceil(n / 5) * 5
const formatFixed2 = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const statusChipStyle = (status: OrderStatus | null) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'customer_submit') return { backgroundColor: '#efd399', color: '#6a4a14', border: '1px solid #d8b672' }
  if (value === 'direct_priced') return { backgroundColor: '#d8e4ff', color: '#2b4b85', border: '1px solid #bdd0f7' }
  if (value === 'priced') return { backgroundColor: '#bde9f4', color: '#1e5f71', border: '1px solid #9fd8e7' }
  if (value === 'negotiate') return { backgroundColor: '#f4c8ba', color: '#7f3420', border: '1px solid #e7ab98' }
  if (value === 'final_offered') return { backgroundColor: '#dccdfa', color: '#4e2d86', border: '1px solid #c6b1f1' }
  if (value === 'ordered') return { backgroundColor: '#c4d5fa', color: '#274a8d', border: '1px solid #a9c2f2' }
  if (value === 'processing') return { backgroundColor: '#c3e8d2', color: '#1f5d3c', border: '1px solid #9fd4b7' }
  if (value === 'invoicing') return { backgroundColor: '#f7d6af', color: '#7a4516', border: '1px solid #ecc08f' }
  if (value === 'invoiced') return { backgroundColor: '#b9e3ca', color: '#194f35', border: '1px solid #95cfaf' }
  return { backgroundColor: '#dbe5f3', color: '#3b4b66', border: '1px solid #b9c8dd' }
}

const statusDotColor = (status: OrderStatus | null) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'customer_submit') return '#9a6a24'
  if (value === 'direct_priced') return '#3d5f9e'
  if (value === 'priced') return '#308ca6'
  if (value === 'negotiate') return '#b65336'
  if (value === 'final_offered') return '#6f4ab2'
  if (value === 'ordered') return '#3f67b3'
  if (value === 'processing') return '#2f8b5d'
  if (value === 'invoicing') return '#b86d23'
  if (value === 'invoiced') return '#25784d'
  return '#66758c'
}

const onStatusChange = async (status: OrderStatus | null) => {
  if (!status || !orderStore.selected?.id) return
  if (
    orderStore.selected.negotiate === false &&
    (status === 'negotiate' || status === 'priced')
  ) {
    return
  }
  if (orderStore.selected.negotiate !== false && status === 'direct_priced') {
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
  let nextStatusPatch: OrderStatus | undefined

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

    if (
      orderStore.selected.status === 'customer_submit' ||
      orderStore.selected.status === 'negotiate' ||
      orderStore.selected.status === 'priced'
    ) {
      nextStatusPatch = 'direct_priced'
    }
  } else if (orderStore.selected.status === 'direct_priced') {
    nextStatusPatch = 'priced'
  }

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      negotiate: nextValue,
      ...(nextStatusPatch ? { status: nextStatusPatch } : {}),
    },
  })
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

  if (!negotiateEnabled && orderStore.selected.status === 'customer_submit') {
    await orderStore.updateOrder({
      id: orderStore.selected.id,
      patch: {
        status: 'direct_priced',
      },
    })
  }
}

const onSaveNegotiationFromDialog = async () => {
  if (!orderStore.selected?.id) {
    return
  }

  await applyNegotiationToggle(negotiationChoice.value)

  showNegotiationDialog.value = false
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

<style scoped>
.order-details-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.order-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.order-header-status-left {
  padding-left: 8px;
}

.admin-summary-cell {
  width: calc(33.3333% - 8px);
  border-radius: 6px;
  padding: 10px 12px;
  margin: 4px;
  box-sizing: border-box;
}

.admin-summary-label {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.admin-summary-value {
  margin-top: 2px;
}

.admin-summary-bg-qty {
  background: #f2f4f7;
}

.admin-summary-bg-gbp {
  background: #e6f4ea;
}

.admin-summary-bg-bdt {
  background: #f8f4d9;
}

.admin-summary-bg-first {
  background: #e0f2f6;
}

.admin-summary-bg-customer {
  background: #f8e8d5;
}

.admin-summary-bg-final {
  background: #e8e2f8;
}
</style>

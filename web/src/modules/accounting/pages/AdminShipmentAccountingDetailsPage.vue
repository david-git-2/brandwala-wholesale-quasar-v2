<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Shipment Accounting"
        @click="onBack"
      />
    </div>

    <PageInitialLoader v-if="shipmentStore.loading" />

    <q-banner v-else-if="shipmentStore.error" class="bg-red-1 text-negative q-mb-md">
      {{ shipmentStore.error }}
    </q-banner>

    <template v-else-if="shipmentStore.selectedShipment">
      <p class="text-h6 text-weight-bold q-mb-sm">
        #{{ shipmentStore.selectedShipment.tenant_shipment_id ?? shipmentStore.selectedShipment.id }} {{ shipmentStore.selectedShipment.name }}
      </p>
      <p class="text-body2 text-grey-8 q-mb-xs">Status: {{ shipmentStore.selectedShipment.status }}</p>
      <p class="text-body2 text-grey-8 q-mb-md">Items: {{ shipmentStore.shipmentItems.length }}</p>

      <q-banner v-if="accountingError" class="bg-red-1 text-negative q-mb-md">
        {{ accountingError }}
      </q-banner>

      <div class="text-subtitle1 text-weight-medium q-mb-sm">Shipment Cost Side</div>
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Shipment Cost Total (BDT)</div>
              <div class="text-h6 text-weight-bold">{{ formatFixed2(totalReceivedCostBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Damage/Stolen Loss (BDT)</div>
              <div class="text-h6 text-weight-bold text-negative">{{ formatFixed2(totalLossBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Usable Inventory Cost (BDT)</div>
              <div class="text-h6 text-weight-bold">{{ formatFixed2(usableCostBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Sold COGS (BDT)</div>
              <div class="text-h6 text-weight-bold">{{ formatFixed2(totalInvoiceCogsBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div class="text-subtitle1 text-weight-medium q-mb-sm">Invoice Earning Side</div>
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Invoice Revenue (BDT)</div>
              <div class="text-h6 text-weight-bold">{{ formatFixed2(totalInvoiceRevenueBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Realized Gross Profit (BDT)</div>
              <div
                class="text-h6 text-weight-bold"
                :class="totalRealizedProfitBdt >= 0 ? 'text-positive' : 'text-negative'"
              >
                {{ formatFixed2(totalRealizedProfitBdt) }}
              </div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Paid Amount (BDT)</div>
              <div class="text-h6 text-weight-bold text-primary">{{ formatFixed2(totalInvoicePaidBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Remaining Inventory Cost (BDT)</div>
              <div class="text-h6 text-weight-bold">{{ formatFixed2(remainingInventoryCostBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">P/L vs Shipment Cost (BDT)</div>
              <div
                class="text-h6 text-weight-bold"
                :class="profitLossVsShipmentCostBdt >= 0 ? 'text-positive' : 'text-negative'"
              >
                {{ formatFixed2(profitLossVsShipmentCostBdt) }}
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div class="text-subtitle1 text-weight-medium q-mb-sm">Shipment Cost Breakdown</div>
      <q-markup-table flat bordered wrap-cells>
        <thead>
          <tr>
            <th class="text-left">SL</th>
            <th class="text-left">Name</th>
            <th class="text-right">Cost/Unit (BDT)</th>
            <th class="text-right">Qty</th>
            <th class="text-right">Qty Total (BDT)</th>
            <th class="text-right">Received Total (BDT)</th>
            <th class="text-right">Loss Total (BDT)</th>
            <th class="text-right">Received</th>
            <th class="text-right">Damaged</th>
            <th class="text-right">Stolen</th>
            <th class="text-right">Usable</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!shipmentStore.shipmentItems.length">
            <td colspan="11" class="text-center text-grey-7">No shipment items found.</td>
          </tr>
          <tr v-for="(item, index) in shipmentRows" :key="item.id">
            <td>{{ index + 1 }}</td>
            <td>{{ item.name ?? '-' }}</td>
            <td class="text-right">{{ formatFixed2(item.costPerUnitBdt) }}</td>
            <td class="text-right">{{ item.quantity }}</td>
            <td class="text-right">{{ formatFixed2(item.quantityTotalBdt) }}</td>
            <td class="text-right">{{ formatFixed2(item.receivedTotalBdt) }}</td>
            <td class="text-right text-negative">{{ formatFixed2(item.lossTotalBdt) }}</td>
            <td class="text-right">{{ item.received_quantity }}</td>
            <td class="text-right">{{ item.damaged_quantity }}</td>
            <td class="text-right">{{ item.stolen_quantity }}</td>
            <td class="text-right">{{ item.usableQuantity }}</td>
          </tr>
          <tr v-if="shipmentRows.length" class="text-weight-bold">
            <td colspan="4" class="text-right">Total</td>
            <td class="text-right">{{ formatFixed2(totalQuantityCostBdt) }}</td>
            <td class="text-right">{{ formatFixed2(totalReceivedCostBdt) }}</td>
            <td class="text-right text-negative">{{ formatFixed2(totalLossBdt) }}</td>
            <td colspan="4"></td>
          </tr>
        </tbody>
      </q-markup-table>

      <div class="text-subtitle1 text-weight-medium q-mt-lg q-mb-sm">
        Invoice Accounting Entries (Shipment)
      </div>
      <q-markup-table flat bordered wrap-cells>
        <thead>
          <tr>
            <th class="text-left">SL</th>
            <th class="text-left">Invoice ID</th>
            <th class="text-left">Entry Date</th>
            <th class="text-right">Qty</th>
            <th class="text-right">COGS (BDT)</th>
            <th class="text-right">Revenue (BDT)</th>
            <th class="text-right">Gross Profit (BDT)</th>
            <th class="text-left">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="accountingLoading">
            <td colspan="8" class="text-center text-grey-7">Loading accounting entries...</td>
          </tr>
          <tr v-else-if="!shipmentAccountingEntries.length">
            <td colspan="8" class="text-center text-grey-7">No invoice accounting entries for this shipment.</td>
          </tr>
          <tr v-for="(row, index) in shipmentAccountingEntries" :key="row.id">
            <td>{{ index + 1 }}</td>
            <td>
              {{ row.invoice_id ? `#${row.invoice_id}` : '-' }}
              <span v-if="row.type" class="text-caption text-grey-6 text-lowercase q-ml-xs">
                ({{ row.type }})
              </span>
            </td>
            <td>{{ row.entry_date ?? '-' }}</td>
            <td class="text-right">{{ row.quantity }}</td>
            <td class="text-right">{{ formatFixed2(row.total_cost_amount) }}</td>
            <td class="text-right">{{ formatFixed2(row.total_sell_amount) }}</td>
            <td
              class="text-right"
              :class="Number(row.gross_profit_amount ?? 0) >= 0 ? 'text-positive' : 'text-negative'"
            >
              {{ formatFixed2(row.gross_profit_amount) }}
            </td>
            <td class="text-capitalize">{{ row.status }}</td>
          </tr>
          <tr v-if="!accountingLoading && shipmentAccountingEntries.length" class="text-weight-bold">
            <td colspan="3" class="text-right">Total</td>
            <td class="text-right">{{ totalSoldQuantity }}</td>
            <td class="text-right">{{ formatFixed2(totalInvoiceCogsBdt) }}</td>
            <td class="text-right">{{ formatFixed2(totalInvoiceRevenueBdt) }}</td>
            <td
              class="text-right"
              :class="totalRealizedProfitBdt >= 0 ? 'text-positive' : 'text-negative'"
            >
              {{ formatFixed2(totalRealizedProfitBdt) }}
            </td>
            <td></td>
          </tr>
        </tbody>
      </q-markup-table>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { supabase } from 'src/boot/supabase'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { accountingService } from 'src/modules/accounting/services/accountingService'
import type { InventoryAccountingEntry } from 'src/modules/accounting/types'
import { useInvoiceStore } from 'src/modules/invoice/stores/invoiceStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { calculateCostBdt } from 'src/modules/shipment/utils/costing'
import { formatAmountBdt } from 'src/utils/currency'

import { getReceivedQty, getDamagedQty, getStolenQty } from 'src/modules/shipment/utils/splits'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const invoiceStore = useInvoiceStore()
const shipmentAccountingEntries = ref<InventoryAccountingEntry[]>([])
const accountingLoading = ref(false)
const accountingError = ref<string | null>(null)
const shipmentInvoicePaidById = ref<Record<string, number>>({})

const shipmentId = computed(() => {
  const parsed = Number(route.params.id)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
})

const shipmentRows = computed(() => {
  const shipment = shipmentStore.selectedShipment
  return (shipmentStore.shipmentItems ?? []).map((item) => {
    const costPerUnitBdt = shipment && !shipment.is_gbp
      ? Number(item.cost_bdt ?? 0)
      : calculateCostBdt({
          productWeight: item.product_weight,
          packageWeight: item.package_weight,
          cargoRate: shipment?.cargo_rate,
          priceGbp: item.price_gbp,
          transactionRate: shipment?.transaction_rate,
          productConversionRate: shipment?.product_conversion_rate,
          cargoConversionRate: shipment?.cargo_conversion_rate,
        })
    const recQty = getReceivedQty(item)
    const damQty = getDamagedQty(item)
    const stQty = getStolenQty(item)
    return {
      ...item,
      costPerUnitBdt,
      quantityTotalBdt: costPerUnitBdt * Number(item.quantity ?? 0),
      receivedTotalBdt: costPerUnitBdt * recQty,
      lossTotalBdt: costPerUnitBdt * (stQty + damQty),
      usableQuantity: Math.max(0, recQty - stQty - damQty),
      received_quantity: recQty,
      damaged_quantity: damQty,
      stolen_quantity: stQty,
    }
  })
})

const totalQuantityCostBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.quantityTotalBdt, 0),
)

const totalReceivedCostBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.receivedTotalBdt, 0),
)

const totalLossBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.lossTotalBdt, 0),
)

const usableCostBdt = computed(() => Math.max(0, totalReceivedCostBdt.value - totalLossBdt.value))

const totalInvoiceRevenueBdt = computed(() =>
  shipmentAccountingEntries.value.reduce((sum, row) => sum + Number(row.total_sell_amount ?? 0), 0),
)

const totalInvoiceCogsBdt = computed(() =>
  shipmentAccountingEntries.value.reduce((sum, row) => sum + Number(row.total_cost_amount ?? 0), 0),
)

const totalRealizedProfitBdt = computed(() =>
  shipmentAccountingEntries.value.reduce((sum, row) => sum + Number(row.gross_profit_amount ?? 0), 0),
)

const totalSoldQuantity = computed(() =>
  shipmentAccountingEntries.value.reduce((sum, row) => sum + Number(row.quantity ?? 0), 0),
)
const totalInvoicePaidBdt = computed(() =>
  Object.values(shipmentInvoicePaidById.value).reduce((sum, value) => sum + Number(value ?? 0), 0),
)

const remainingInventoryCostBdt = computed(() =>
  Math.max(0, usableCostBdt.value - totalInvoiceCogsBdt.value),
)

const profitLossVsShipmentCostBdt = computed(
  () => totalInvoiceRevenueBdt.value - totalReceivedCostBdt.value,
)

const formatFixed2 = (value: number | null | undefined) => formatAmountBdt(value)

const fetchDetails = async () => {
  if (!shipmentId.value) {
    return
  }
  await Promise.all([shipmentStore.fetchShipmentById(shipmentId.value), fetchAccountingEntries()])
}

const fetchAccountingEntries = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) {
    shipmentAccountingEntries.value = []
    return
  }

  accountingLoading.value = true
  accountingError.value = null

  try {
    const result = await accountingService.listInventoryAccountingEntries({
      tenant_id: tenantId,
      filters: { shipment_id: shipmentId.value },
      operators: { shipment_id: 'eq' },
      page: 1,
      page_size: 1000,
      sortBy: 'id',
      sortOrder: 'desc',
    })

    if (!result.success) {
      accountingError.value = result.error ?? 'Failed to load shipment accounting entries.'
      shipmentAccountingEntries.value = []
      return
    }

    shipmentAccountingEntries.value = result.data?.data ?? []
    await fetchShipmentInvoicePaidAmounts()
  } finally {
    accountingLoading.value = false
  }
}

const fetchShipmentInvoicePaidAmounts = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    shipmentInvoicePaidById.value = {}
    return
  }

  const normalInvoiceIds = Array.from(
    new Set(
      shipmentAccountingEntries.value
        .filter((row) => row.type === 'normal')
        .map((row) => Number(row.invoice_id))
        .filter((id) => Number.isFinite(id) && id > 0),
    ),
  )

  const commerceInvoiceIds = Array.from(
    new Set(
      shipmentAccountingEntries.value
        .filter((row) => row.type === 'commerce')
        .map((row) => Number(row.invoice_id))
        .filter((id) => Number.isFinite(id) && id > 0),
    ),
  )

  const paidAmounts: Record<string, number> = {}

  // Fetch normal invoice paid amounts
  if (normalInvoiceIds.length > 0) {
    const invoicesResult = await invoiceStore.fetchInvoices({
      tenant_id: tenantId,
      filters: { id: normalInvoiceIds },
      operators: { id: 'in' },
      page: 1,
      page_size: Math.max(normalInvoiceIds.length, 100),
      sortBy: 'id',
      sortOrder: 'asc',
    })
    if (invoicesResult.success) {
      ;(invoiceStore.invoices ?? []).forEach((invoice) => {
        paidAmounts[`normal_${invoice.id}`] = Number(invoice.paid_amount ?? 0)
      })
    }
  }

  // Fetch commerce invoice paid amounts
  if (commerceInvoiceIds.length > 0) {
    const { data: commerceInvoices, error: commerceErr } = await supabase
      .from('commerce_invoices')
      .select('id, amount_paid')
      .in('id', commerceInvoiceIds)
    if (!commerceErr && commerceInvoices) {
      commerceInvoices.forEach((invoice) => {
        paidAmounts[`commerce_${invoice.id}`] = Number(invoice.amount_paid ?? 0)
      })
    }
  }

  shipmentInvoicePaidById.value = paidAmounts
}

const onBack = async () => {
  await router.push({
    name: 'app-accounting-shipment-page',
    params: { tenantSlug: route.params.tenantSlug },
  })
}

onMounted(() => {
  void fetchDetails()
})

watch(
  () => route.params.id,
  () => {
    void fetchDetails()
  },
)
</script>

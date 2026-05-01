<template>
  <q-page class="q-pa-md">
    <q-btn flat no-caps color="primary" icon="arrow_back" label="Back to Invoices" @click="goBack" class="q-mb-md" />

    <PageInitialLoader v-if="loading" />

    <q-banner v-else-if="!invoice" class="bg-grey-2 text-grey-8">
      Invoice not found.
    </q-banner>

    <template v-else>
      <q-card flat bordered class="q-mb-md">
        <q-card-section>
          <div class="text-h6">#{{ invoice.id }} {{ invoice.invoice_no }}</div>
          <div class="row items-center q-col-gutter-md q-mt-sm q-mb-xs">
            <div class="col-12 col-sm-4">
              <q-select
                outlined
                dense
                emit-value
                map-options
                label="Status"
                :options="statusOptions"
                :model-value="selectedStatus"
                :loading="savingStatus"
                @update:model-value="onStatusChange"
              />
            </div>
            <div class="col-12 col-sm-4 text-caption text-grey-7">
              Payment: {{ invoice.payment_status }}
            </div>
            <div class="col-12 col-sm-auto">
              <q-btn
                outline
                color="primary"
                no-caps
                label="Open Preview"
                @click="openPreviewPage"
              />
            </div>
            <div class="col-12 col-sm-auto">
              <q-btn
                outline
                color="primary"
                no-caps
                label="Open Accounting"
                @click="openAccountingPage"
              />
            </div>
            <div class="col-12 col-sm-auto">
              <q-btn
                v-if="invoice.status === 'draft'"
                color="primary"
                no-caps
                label="Allocate Inventory (FIFO)"
                :loading="allocatingInventory"
                :disable="rollingBackQuantity"
                @click="onAllocateInventoryFifo"
              />
            </div>
            <div class="col-12 col-sm-auto">
              <q-btn
                v-if="invoice.status === 'draft'"
                color="negative"
                flat
                no-caps
                label="Rollback Quantity"
                :loading="rollingBackQuantity"
                :disable="allocatingInventory"
                @click="onRollbackQuantity"
              />
            </div>
          </div>
          <div class="text-caption text-grey-7">Source: {{ invoice.source_type }} | Source ID: {{ invoice.source_id }}</div>
          <div class="text-caption text-grey-7">Invoice Date: {{ invoice.invoice_date }} | Due: {{ invoice.due_date || 'N/A' }}</div>
          <div class="text-body2 q-mt-sm">Subtotal: {{ invoice.subtotal_amount }} | Total: {{ invoice.total_amount }} | Paid: {{ invoice.paid_amount }}</div>
          <q-banner
            v-if="invoice.status === 'draft'"
            dense
            rounded
            class="bg-blue-1 text-blue-10 q-mt-sm"
          >
            FIFO Allocation will:
            <br />
            1. Allocate by shipment ID ascending (older shipment first)
            <br />
            2. Update invoice item inventory links (and split rows when needed)
            <br />
            3. Deduct available stock
            <br />
            4. Create inventory accounting entries using inventory cost and invoice sell price
          </q-banner>
        </q-card-section>
      </q-card>

      <q-card flat bordered>
        <q-card-section class="text-subtitle1">Items</q-card-section>
        <q-separator />
        <q-list separator>
          <q-item v-for="row in items" :key="row.id">
            <q-item-section>
              <q-item-label>{{ row.name_snapshot }}</q-item-label>
              <q-item-label caption>
                Requested: {{ row.quantity }} | Allocated: {{ getAllocatedQuantity(row.id) }} | Left:
                {{ getRemainingQuantity(row) }} | Cost: {{ row.cost_amount }} | Sell:
                {{ row.sell_price_amount }}
              </q-item-label>
              <div
                v-if="invoice?.status === 'draft' && row.product_id != null"
                class="q-mt-xs text-caption text-grey-8"
              >
                <div class="text-weight-medium q-mb-xs">Matched Inventory:</div>
                <div v-if="inventoryByProductId[row.product_id]?.length">
                  <div
                    v-for="inventoryRow in inventoryByProductId[row.product_id]"
                    :key="inventoryRow.id"
                  >
                    Inventory ID: {{ inventoryRow.id }} | Shipment ID:
                    {{ inventoryRow.shipment?.shipment?.id ?? 'N/A' }} |
                    Available Unit: {{ inventoryRow.quantities.available }}
                  </div>
                </div>
                <div v-else>No inventory found for this product.</div>

                <div class="text-weight-medium q-mt-sm q-mb-xs">FIFO Deduction Preview:</div>
                <div v-if="allocationPreview.plansByItemId.get(row.id)?.allocations.length">
                  <div
                    v-for="previewRow in allocationPreview.plansByItemId.get(row.id)?.allocations ?? []"
                    :key="`${row.id}-${previewRow.stockId}`"
                  >
                    Stock #{{ previewRow.stockId }}
                    (Inventory #{{ previewRow.inventoryItem.id }}, Shipment
                    #{{ previewRow.inventoryItem.shipment?.shipment?.id ?? 'N/A' }}):
                    -{{ previewRow.quantity }}
                  </div>
                </div>
                <div v-else>No stock will be deducted for this item.</div>
                <div
                  v-if="(allocationPreview.plansByItemId.get(row.id)?.shortage ?? 0) > 0"
                  class="text-negative"
                >
                  Shortage: {{ allocationPreview.plansByItemId.get(row.id)?.shortage ?? 0 }}
                </div>
              </div>
            </q-item-section>
            <q-item-section side class="text-weight-medium">{{ row.line_total_amount }}</q-item-section>
          </q-item>
        </q-list>
      </q-card>

    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import { requestConfirmation, showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'
import { invoiceService } from '../services/invoiceService'
import type {
  CreateInventoryAccountingEntryInput,
  Invoice,
  InvoiceItem,
  InvoiceStatus,
} from '../types'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const loading = ref(false)
const savingStatus = ref(false)
const allocatingInventory = ref(false)
const rollingBackQuantity = ref(false)
const invoices = ref<Invoice[]>([])
const items = ref<InvoiceItem[]>([])
const accountingRows = ref<
  Array<{
    id: number
    invoice_item_id: number | null
    inventory_item_id: number
    quantity: number
  }>
>([])
const inventoryByProductId = ref<Record<number, InventoryItemWithStock[]>>({})
const selectedStatus = ref<InvoiceStatus>('draft')

const statusOptions: Array<{ label: string; value: InvoiceStatus }> = [
  { label: 'Draft', value: 'draft' },
  { label: 'Issued', value: 'issued' },
  { label: 'Partially Paid', value: 'partially_paid' },
  { label: 'Paid', value: 'paid' },
  { label: 'Overdue', value: 'overdue' },
  { label: 'Cancelled', value: 'cancelled' },
]

const invoice = computed(() => invoices.value[0] ?? null)
const allocatedQuantityByInvoiceItemId = computed(() => {
  const map = new Map<number, number>()
  for (const row of accountingRows.value) {
    if (row.invoice_item_id == null) continue
    const current = map.get(row.invoice_item_id) ?? 0
    map.set(row.invoice_item_id, current + Math.max(0, toNumber(row.quantity)))
  }
  return map
})

const getAllocatedQuantity = (invoiceItemId: number) =>
  Math.max(0, allocatedQuantityByInvoiceItemId.value.get(invoiceItemId) ?? 0)

const getRemainingQuantity = (row: InvoiceItem) =>
  Math.max(0, toNumber(row.quantity) - getAllocatedQuantity(row.id))

const loadDetails = async () => {
  const invoiceId = Number(route.params.id)
  if (!invoiceId || !authStore.tenantId) return

  loading.value = true
  try {
    const [invoiceResult, itemResult] = await Promise.all([
      invoiceService.listInvoices({
        tenant_id: authStore.tenantId,
        filters: { id: invoiceId },
        operators: { id: 'eq' },
        page: 1,
        page_size: 1,
      }),
      invoiceService.listInvoiceItems({
        tenant_id: authStore.tenantId,
        filters: { invoice_id: invoiceId },
        operators: { invoice_id: 'eq' },
        page: 1,
        page_size: 200,
        sortBy: 'id',
        sortOrder: 'asc',
      }),
    ])

    if (invoiceResult.success) {
      invoices.value = invoiceResult.data?.data ?? []
      selectedStatus.value = invoices.value[0]?.status ?? 'draft'
    }
    if (itemResult.success) items.value = itemResult.data?.data ?? []
    accountingRows.value = await fetchAllAccountingEntriesForInvoice(invoiceId, authStore.tenantId)
    await loadInventoryMatches()
  } finally {
    loading.value = false
  }
}

const loadInventoryMatches = async () => {
  if (!authStore.tenantId || invoice.value?.status !== 'draft') {
    inventoryByProductId.value = {}
    return
  }

  const uniqueProductIds = Array.from(
    new Set(
      items.value
        .map((row) => row.product_id)
        .filter((id): id is number => typeof id === 'number'),
    ),
  )

  if (!uniqueProductIds.length) {
    inventoryByProductId.value = {}
    return
  }

  const tenantId = Number(authStore.tenantId)
  const result = await inventoryService.listInventoryItems({
    tenant_id: tenantId,
    page: 1,
    page_size: 1000,
    sortBy: 'id',
    sortOrder: 'desc',
  })

  if (!result.success) {
    inventoryByProductId.value = {}
    return
  }

  const productIdSet = new Set(uniqueProductIds)
  const allRows = result.data?.data ?? []
  const filteredRows = allRows.filter(
    (row) => row.product_id != null && productIdSet.has(row.product_id),
  )

  const nextMap: Record<number, InventoryItemWithStock[]> = {}
  for (const productId of uniqueProductIds) {
    nextMap[productId] = filteredRows
      .filter((row) => row.product_id === productId)
      .sort((a, b) => {
        const aShipmentId = Number(a.shipment?.shipment?.id ?? Number.POSITIVE_INFINITY)
        const bShipmentId = Number(b.shipment?.shipment?.id ?? Number.POSITIVE_INFINITY)
        return aShipmentId - bShipmentId
      })
  }

  inventoryByProductId.value = nextMap
}

const onStatusChange = async (nextStatus: InvoiceStatus) => {
  if (!invoice.value || nextStatus === invoice.value.status) {
    return
  }

  savingStatus.value = true
  try {
    let patch: {
      status: InvoiceStatus
      subtotal_amount?: number
      total_amount?: number
    } = { status: nextStatus }

    if (nextStatus === 'issued') {
      const tenantId = authStore.tenantId
      if (!tenantId) {
        showWarningDialog('Tenant context is missing.')
        selectedStatus.value = invoice.value.status
        return
      }

      const accountingRows = await fetchAllAccountingEntriesForInvoice(invoice.value.id, tenantId)
      const subtotalFromAccounting = Number(
        accountingRows
          .reduce((sum, row) => sum + toNumber(row.total_sell_amount), 0)
          .toFixed(2),
      )

      patch = {
        status: nextStatus,
        subtotal_amount: subtotalFromAccounting,
        total_amount: subtotalFromAccounting,
      }
    }

    const result = await invoiceService.updateInvoice({
      id: invoice.value.id,
      patch,
    })

    if (result.success && result.data) {
      invoices.value = [result.data]
      selectedStatus.value = result.data.status
      await loadInventoryMatches()
      return
    }

    selectedStatus.value = invoice.value.status
  } finally {
    savingStatus.value = false
  }
}

type AllocationRow = {
  inventoryItem: InventoryItemWithStock
  stockId: number
  quantity: number
  unitCost: number
}

type AllocationPlan = {
  requested: number
  allocated: number
  shortage: number
  allocations: AllocationRow[]
}

type InvoiceAllocationPreview = {
  plansByItemId: Map<number, AllocationPlan>
  stockInitialById: Map<number, number>
  stockRemainingById: Map<number, number>
  totalAllocated: number
}

const toNumber = (value: unknown): number => {
  const n = Number(value)
  return Number.isFinite(n) ? n : 0
}

const readPositiveNumber = (value: unknown): number | null => {
  const n = Number(value)
  if (!Number.isFinite(n) || n <= 0) return null
  return n
}

const getShipmentTrace = (inventoryItem: InventoryItemWithStock) => {
  const shipmentRecord =
    inventoryItem.shipment &&
    typeof inventoryItem.shipment === 'object' &&
    !Array.isArray(inventoryItem.shipment)
      ? inventoryItem.shipment
      : null

  const shipmentData =
    shipmentRecord?.shipment &&
    typeof shipmentRecord.shipment === 'object' &&
    !Array.isArray(shipmentRecord.shipment)
      ? shipmentRecord.shipment
      : null

  const shipmentItemData =
    shipmentRecord?.shipment_item &&
    typeof shipmentRecord.shipment_item === 'object' &&
    !Array.isArray(shipmentRecord.shipment_item)
      ? shipmentRecord.shipment_item
      : null

  const shipmentId = readPositiveNumber(shipmentData?.id)
  const shipmentItemId =
    readPositiveNumber(shipmentItemData?.id) ??
    (inventoryItem.source_type === 'shipment' ? readPositiveNumber(inventoryItem.source_id) : null)

  return {
    shipment_id: shipmentId,
    shipment_item_id: shipmentItemId,
  }
}

const buildInvoiceAllocationPreview = (): InvoiceAllocationPreview => {
  const plansByItemId = new Map<number, AllocationPlan>()
  const stockInitialById = new Map<number, number>()
  const stockRemainingById = new Map<number, number>()
  let totalAllocated = 0

  for (const row of items.value) {
    const requested = Math.max(0, getRemainingQuantity(row))
    const plan: AllocationPlan = {
      requested,
      allocated: 0,
      shortage: requested,
      allocations: [],
    }

    if (requested <= 0 || row.product_id == null) {
      plansByItemId.set(row.id, plan)
      continue
    }

    const matched = inventoryByProductId.value[row.product_id] ?? []
    let remaining = requested

    for (const inventoryRow of matched) {
      if (remaining <= 0) break
      if (!inventoryRow.stock?.id) continue

      const stockId = inventoryRow.stock.id
      const initial = stockInitialById.has(stockId)
        ? (stockInitialById.get(stockId) ?? 0)
        : Math.max(0, toNumber(inventoryRow.stock.available_quantity))

      if (!stockInitialById.has(stockId)) {
        stockInitialById.set(stockId, initial)
        stockRemainingById.set(stockId, initial)
      }

      const availableNow = Math.max(0, stockRemainingById.get(stockId) ?? 0)
      if (availableNow <= 0) continue

      const take = Math.min(remaining, availableNow)
      plan.allocations.push({
        inventoryItem: inventoryRow,
        stockId,
        quantity: take,
        unitCost: Math.max(0, toNumber(inventoryRow.cost)),
      })
      plan.allocated += take
      totalAllocated += take
      stockRemainingById.set(stockId, availableNow - take)
      remaining -= take
    }

    plan.shortage = Math.max(0, requested - plan.allocated)
    plansByItemId.set(row.id, plan)
  }

  return {
    plansByItemId,
    stockInitialById,
    stockRemainingById,
    totalAllocated,
  }
}

const allocationPreview = computed(() => buildInvoiceAllocationPreview())

const fetchAllAccountingEntriesForInvoice = async (invoiceId: number, tenantId: number) => {
  const pageSize = 200
  let page = 1
  const allRows: Array<{
    id: number
    invoice_item_id: number | null
    inventory_item_id: number
    quantity: number
    total_sell_amount: number
  }> = []

  while (true) {
    const result = await invoiceService.listInventoryAccountingEntries({
      tenant_id: tenantId,
      filters: { invoice_id: invoiceId },
      operators: { invoice_id: 'eq' },
      page,
      page_size: pageSize,
      sortBy: 'id',
      sortOrder: 'asc',
    })

    if (!result.success) {
      throw new Error(result.error ?? 'Failed to load accounting entries.')
    }

    const rows = result.data?.data ?? []
    allRows.push(
      ...rows.map((row) => ({
        id: row.id,
        invoice_item_id: row.invoice_item_id,
        inventory_item_id: row.inventory_item_id,
        quantity: toNumber(row.quantity),
        total_sell_amount: toNumber(row.total_sell_amount),
      })),
    )

    const totalPages = result.data?.meta.total_pages ?? 1
    if (page >= totalPages) break
    page += 1
  }

  return allRows
}

const fetchAllInvoiceItemsForInvoice = async (invoiceId: number, tenantId: number) => {
  const pageSize = 200
  let page = 1
  const allRows: InvoiceItem[] = []

  while (true) {
    const result = await invoiceService.listInvoiceItems({
      tenant_id: tenantId,
      filters: { invoice_id: invoiceId },
      operators: { invoice_id: 'eq' },
      page,
      page_size: pageSize,
      sortBy: 'id',
      sortOrder: 'asc',
    })

    if (!result.success) {
      throw new Error(result.error ?? 'Failed to load invoice items.')
    }

    allRows.push(...(result.data?.data ?? []))

    const totalPages = result.data?.meta.total_pages ?? 1
    if (page >= totalPages) break
    page += 1
  }

  return allRows
}

const onRollbackQuantity = async () => {
  const currentInvoice = invoice.value
  const tenantId = authStore.tenantId
  if (!currentInvoice || !tenantId) {
    showWarningDialog('Invoice context is missing.')
    return
  }

  const confirmed = await requestConfirmation(
    'This will restore deducted inventory quantity from this invoice and remove its accounting entries. Continue?',
    'Rollback Quantity',
    'Rollback',
  )
  if (!confirmed) {
    return
  }

  rollingBackQuantity.value = true
  try {
    const accountingRows = await fetchAllAccountingEntriesForInvoice(currentInvoice.id, tenantId)
    if (!accountingRows.length) {
      showWarningDialog('No accounting entries found to rollback.')
      return
    }

    const qtyByInventoryItemId = new Map<number, number>()
    for (const row of accountingRows) {
      const current = qtyByInventoryItemId.get(row.inventory_item_id) ?? 0
      qtyByInventoryItemId.set(row.inventory_item_id, current + Math.max(0, row.quantity))
    }

    const inventoryItemIds = [...qtyByInventoryItemId.keys()]
    const stockResult = await inventoryService.listInventoryStocks({
      filters: { inventory_item_id: inventoryItemIds },
      operators: { inventory_item_id: 'in' },
      page: 1,
      page_size: Math.max(200, inventoryItemIds.length + 20),
      sortBy: 'id',
      sortOrder: 'asc',
    })
    if (!stockResult.success) {
      throw new Error(stockResult.error ?? 'Failed to load inventory stocks.')
    }

    const stocks = stockResult.data?.data ?? []
    const stockByInventoryItemId = new Map<number, (typeof stocks)[number]>()
    for (const stock of stocks) {
      stockByInventoryItemId.set(stock.inventory_item_id, stock)
    }

    for (const [inventoryItemId, rollbackQty] of qtyByInventoryItemId.entries()) {
      const stock = stockByInventoryItemId.get(inventoryItemId)
      if (!stock) {
        throw new Error(`Stock not found for inventory item #${inventoryItemId}.`)
      }

      const nextAvailable = Math.max(0, toNumber(stock.available_quantity) + rollbackQty)
      const updateResult = await inventoryService.updateInventoryStock({
        id: stock.id,
        patch: { available_quantity: nextAvailable },
      })
      if (!updateResult.success) {
        throw new Error(updateResult.error ?? 'Failed to restore inventory quantity.')
      }
    }

    for (const row of [...accountingRows].reverse()) {
      const deleteResult = await invoiceService.deleteInventoryAccountingEntry({ id: row.id })
      if (!deleteResult.success) {
        throw new Error(deleteResult.error ?? 'Failed to delete accounting entry.')
      }
    }

    const invoiceRows = await fetchAllInvoiceItemsForInvoice(currentInvoice.id, tenantId)
    const groupMap = new Map<string, InvoiceItem[]>()
    for (const row of invoiceRows) {
      const key = `${row.source_item_type}:${row.source_item_id}:${row.product_id ?? 'null'}`
      const current = groupMap.get(key) ?? []
      current.push(row)
      groupMap.set(key, current)
    }

    for (const groupRows of groupMap.values()) {
      if (!groupRows.length) continue

      const baseRow = [...groupRows].sort((a, b) => a.id - b.id)[0]
      if (!baseRow) continue

      const totalQuantity = groupRows.reduce((sum, row) => sum + Math.max(0, toNumber(row.quantity)), 0)
      const sellPrice = Math.max(0, toNumber(baseRow.sell_price_amount))
      const resetBaseResult = await invoiceService.updateInvoiceItem({
        id: baseRow.id,
        patch: {
          inventory_item_id: null,
          quantity: totalQuantity,
          line_total_amount: sellPrice * totalQuantity,
        },
      })
      if (!resetBaseResult.success) {
        throw new Error(resetBaseResult.error ?? 'Failed to normalize invoice item.')
      }

      const duplicateRows = groupRows.filter((row) => row.id !== baseRow.id)
      for (const duplicateRow of duplicateRows) {
        const deleteInvoiceItemResult = await invoiceService.deleteInvoiceItem({ id: duplicateRow.id })
        if (!deleteInvoiceItemResult.success) {
          throw new Error(deleteInvoiceItemResult.error ?? 'Failed to remove duplicate invoice item.')
        }
      }
    }

    await loadDetails()
    showSuccessNotification('Quantity rollback completed successfully.')
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to rollback quantity.'
    showWarningDialog(message)
  } finally {
    rollingBackQuantity.value = false
  }
}

const onAllocateInventoryFifo = async () => {
  const currentInvoice = invoice.value
  const tenantId = authStore.tenantId
  if (!currentInvoice || !tenantId) {
    showWarningDialog('Invoice context is missing.')
    return
  }

  const confirmed = await requestConfirmation(
    'This will allocate inventory by shipment FIFO, deduct stock, and create accounting entries. Continue?',
    'Allocate Inventory',
    'Allocate',
  )
  if (!confirmed) {
    return
  }

  allocatingInventory.value = true
  const updatedOriginalByItemId = new Map<
    number,
    Pick<InvoiceItem, 'inventory_item_id' | 'quantity' | 'cost_amount' | 'line_total_amount'>
  >()
  const createdInvoiceItemIds: number[] = []
  const createdAccountingEntryIds: number[] = []
  const stockOriginalById = new Map<number, number>()
  const updatedStockIds: number[] = []
  let hasMutations = false

  const rollbackAllocations = async (): Promise<string[]> => {
    const rollbackErrors: string[] = []

    for (const stockId of [...updatedStockIds].reverse()) {
      const originalAvailable = stockOriginalById.get(stockId)
      if (originalAvailable == null) continue
      const restoreStock = await inventoryService.updateInventoryStock({
        id: stockId,
        patch: { available_quantity: originalAvailable },
      })
      if (!restoreStock.success) {
        rollbackErrors.push(
          restoreStock.error ?? `Failed to rollback stock #${stockId}.`,
        )
      }
    }

    for (const accountingEntryId of [...createdAccountingEntryIds].reverse()) {
      const deleteAccounting = await invoiceService.deleteInventoryAccountingEntry({
        id: accountingEntryId,
      })
      if (!deleteAccounting.success) {
        rollbackErrors.push(
          deleteAccounting.error ??
            `Failed to rollback accounting entry #${accountingEntryId}.`,
        )
      }
    }

    for (const createdInvoiceItemId of [...createdInvoiceItemIds].reverse()) {
      const deleteInvoiceItem = await invoiceService.deleteInvoiceItem({
        id: createdInvoiceItemId,
      })
      if (!deleteInvoiceItem.success) {
        rollbackErrors.push(
          deleteInvoiceItem.error ??
            `Failed to rollback invoice item #${createdInvoiceItemId}.`,
        )
      }
    }

    for (const [invoiceItemId, snapshot] of updatedOriginalByItemId.entries()) {
      const restoreInvoiceItem = await invoiceService.updateInvoiceItem({
        id: invoiceItemId,
        patch: snapshot,
      })
      if (!restoreInvoiceItem.success) {
        rollbackErrors.push(
          restoreInvoiceItem.error ??
            `Failed to rollback invoice item update #${invoiceItemId}.`,
        )
      }
    }

    return rollbackErrors
  }

  try {
    const existingAccounting = await invoiceService.listInventoryAccountingEntries({
      tenant_id: tenantId,
      filters: { invoice_id: currentInvoice.id },
      operators: { invoice_id: 'eq' },
      page: 1,
      page_size: 1,
    })
    if (!existingAccounting.success) {
      throw new Error(existingAccounting.error ?? 'Failed to verify accounting entries.')
    }
    if ((existingAccounting.data?.meta.total ?? 0) > 0) {
      showWarningDialog('This invoice is already allocated in accounting.')
      return
    }

    await loadInventoryMatches()
    const preview = buildInvoiceAllocationPreview()
    if (preview.totalAllocated <= 0) {
      showWarningDialog('No available stock to allocate.')
      return
    }

    const accountingPayloads: CreateInventoryAccountingEntryInput[] = []

    for (const row of items.value) {
      const plan = preview.plansByItemId.get(row.id)
      const allocations = plan?.allocations ?? []
      if (!allocations.length) continue

      const firstAllocation = allocations[0]
      if (!firstAllocation) {
        throw new Error('Allocation error: missing first allocation row.')
      }
      const firstSellPrice = Math.max(0, toNumber(row.sell_price_amount))
      const requestedQuantity = Math.max(0, toNumber(row.quantity))
      const totalAllocatedQuantity = allocations.reduce(
        (sum, allocation) => sum + Math.max(0, toNumber(allocation.quantity)),
        0,
      )
      const weightedCost =
        totalAllocatedQuantity > 0
          ? allocations.reduce(
              (sum, allocation) =>
                sum + Math.max(0, toNumber(allocation.quantity)) * Math.max(0, toNumber(allocation.unitCost)),
              0,
            ) / totalAllocatedQuantity
          : Math.max(0, toNumber(row.cost_amount))
      if (!updatedOriginalByItemId.has(row.id)) {
        updatedOriginalByItemId.set(row.id, {
          inventory_item_id: row.inventory_item_id,
          quantity: row.quantity,
          cost_amount: row.cost_amount,
          line_total_amount: row.line_total_amount,
        })
      }

      hasMutations = true
      const updateExistingItem = await invoiceService.updateInvoiceItem({
        id: row.id,
        patch: {
          inventory_item_id: firstAllocation.inventoryItem.id,
          quantity: requestedQuantity,
          cost_amount: weightedCost,
          line_total_amount: firstSellPrice * requestedQuantity,
        },
      })
      if (!updateExistingItem.success) {
        throw new Error(updateExistingItem.error ?? 'Failed to update invoice item.')
      }

      for (const allocation of allocations) {
        const quantity = Math.max(0, toNumber(allocation.quantity))
        if (quantity <= 0) continue
        accountingPayloads.push({
          tenant_id: tenantId,
          invoice_id: currentInvoice.id,
          invoice_item_id: row.id,
          inventory_item_id: allocation.inventoryItem.id,
          ...getShipmentTrace(allocation.inventoryItem),
          product_id: row.product_id,
          quantity,
          cost_amount: allocation.unitCost,
          sell_price_amount: firstSellPrice,
          total_cost_amount: allocation.unitCost * quantity,
          total_sell_amount: firstSellPrice * quantity,
          gross_profit_amount: (firstSellPrice - allocation.unitCost) * quantity,
          status: 'due',
          entry_date: new Date().toISOString().slice(0, 10),
          note: `Invoice ${currentInvoice.invoice_no} allocation`,
          created_by: null,
        })
      }
    }

    if (accountingPayloads.length > 0) {
      const accountingInsert =
        await invoiceService.createInventoryAccountingEntriesBulk(accountingPayloads)
      if (!accountingInsert.success || !accountingInsert.data) {
        throw new Error(accountingInsert.error ?? 'Failed to create accounting entries.')
      }
      createdAccountingEntryIds.push(...accountingInsert.data.map((entry) => entry.id))
    }

    for (const [stockId, nextAvailable] of preview.stockRemainingById.entries()) {
      const initialAvailable = preview.stockInitialById.get(stockId)
      if (initialAvailable == null || initialAvailable === nextAvailable) {
        continue
      }
      stockOriginalById.set(stockId, initialAvailable)

      const stockUpdate = await inventoryService.updateInventoryStock({
        id: stockId,
        patch: { available_quantity: nextAvailable },
      })
      if (!stockUpdate.success) {
        throw new Error(stockUpdate.error ?? 'Failed to deduct inventory stock.')
      }
      updatedStockIds.push(stockId)
    }

    await loadDetails()
    const totalShortage = items.value.reduce(
      (sum, row) => sum + Math.max(0, preview.plansByItemId.get(row.id)?.shortage ?? 0),
      0,
    )
    showSuccessNotification(
      totalShortage > 0
        ? `Inventory allocated partially. Shortage: ${totalShortage}`
        : 'Inventory allocated successfully.',
    )
  } catch (error) {
    let rollbackMessage = ''
    if (hasMutations) {
      const rollbackErrors = await rollbackAllocations()
      if (rollbackErrors.length > 0) {
        rollbackMessage = ` Rollback completed with issues: ${rollbackErrors[0]}`
      }
      await loadDetails()
    }
    const message = error instanceof Error ? error.message : 'Failed to allocate inventory.'
    showWarningDialog(`${message}${rollbackMessage}`)
  } finally {
    allocatingInventory.value = false
  }
}

const goBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/invoices`)
}

const openPreviewPage = async () => {
  const invoiceId = Number(route.params.id)
  if (!invoiceId) return
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/invoices/${invoiceId}/preview`)
}

const openAccountingPage = async () => {
  const invoiceId = Number(route.params.id)
  if (!invoiceId) return
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/invoice-accounting/${invoiceId}`)
}

onMounted(loadDetails)
</script>

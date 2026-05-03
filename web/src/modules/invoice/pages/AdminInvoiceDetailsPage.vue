<template>
  <q-page class="q-pa-md">
    <div class="text-h5 text-weight-bold q-mb-md">Invoice Details</div>
    <div v-if="invoice" class="q-gutter-md">
        <div>
          <div class="text-caption text-grey-7">Invoice Name</div>
          <div class="text-body1 text-weight-medium">{{ invoice.invoice_no }}</div>
        </div>
        <div>
          <div class="text-caption text-grey-7 q-mb-xs">Status</div>
          <div class="row justify-end items-center q-gutter-sm">
            <q-select
              v-model="selectedStatus"
              :options="statusOptions"
              outlined
              dense
              emit-value
              map-options
              option-value="value"
              option-label="label"
              :loading="invoiceStore.saving"
              style="width: 220px"
              @update:model-value="onUpdateStatus"
            />
            <q-btn
              color="primary"
              no-caps
              icon="search"
              label="Search Stock"
              @click="searchDialogOpen = true"
            />
          </div>
        </div>

        <q-separator />

        <div class="q-gutter-sm">
          <div class="text-subtitle2">Invoice Item List</div>
          <div v-if="!invoiceStore.invoiceItems.length && !invoiceStore.loading" class="text-grey-7">
            No invoice items added yet.
          </div>
          <q-markup-table v-else flat bordered wrap-cells>
            <thead>
              <tr>
                <th class="text-left" style="width: 56px">SL</th>
                <th class="text-left" style="width: 72px">Image</th>
                <th class="text-left">Name</th>
                <th class="text-right">Cost</th>
                <th class="text-right">Sell Price</th>
                <th class="text-right">Quantity</th>
                <th class="text-right">Line Total</th>
                <th class="text-right" style="width: 90px">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in invoiceStore.invoiceItems" :key="row.id">
                <td>{{ index + 1 }}</td>
                <td>
                  <q-avatar rounded size="1in">
                    <img :src="invoiceItemImageMap[row.inventory_item_id ?? -1] ?? fallbackImageUrl" alt="item image" />
                  </q-avatar>
                </td>
                <td style="white-space: normal; word-break: break-word; min-width: 260px;">
                  {{ row.name_snapshot }}
                </td>
                <td class="text-right">{{ row.cost_amount }}</td>
                <td class="text-right">
                  <span class="cursor-pointer text-primary">{{ row.sell_price_amount }}</span>
                  <q-popup-edit
                    :model-value="row.sell_price_amount"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="(value) => onInlineUpdateSellPrice(row.id, value)"
                  >
                    <q-input
                      :model-value="row.sell_price_amount"
                      type="number"
                      dense
                      autofocus
                      @update:model-value="(value) => row.sell_price_amount = Number(value ?? 0)"
                    />
                  </q-popup-edit>
                </td>
                <td class="text-right">
                  <span class="cursor-pointer text-primary">{{ row.quantity }}</span>
                  <q-popup-edit
                    :model-value="row.quantity"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="(value) => onInlineUpdateQuantity(row.id, value)"
                  >
                    <q-input
                      :model-value="row.quantity"
                      type="number"
                      dense
                      autofocus
                      @update:model-value="(value) => row.quantity = Math.max(1, Math.floor(Number(value ?? 1)))"
                    />
                  </q-popup-edit>
                </td>
                <td class="text-right">{{ calculateLineTotal(row.sell_price_amount, row.quantity) }}</td>
                <td class="text-right">
                  <q-btn
                    flat
                    round
                    icon="delete"
                    color="negative"
                    @click="openDeleteInvoiceItem(row.id)"
                  />
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </div>

        <q-separator />
    </div>
    <div v-else class="text-body1 text-grey-8">
        Invoice not found.
    </div>

    <q-dialog v-model="searchDialogOpen">
      <q-card style="width: 1000px; max-width: 92vw; max-height: 85vh">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">Search Stock</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />

        <q-card-section class="q-gutter-md scroll" style="max-height: calc(85vh - 72px)">
          <div class="row no-wrap q-col-gutter-sm items-start">
            <div style="width: 220px; min-width: 220px">
              <q-select
                v-model="searchBy"
                :options="searchByOptions"
                label="Search By"
                outlined
                dense
                emit-value
                map-options
                option-value="value"
                option-label="label"
              />
            </div>
            <div class="col">
              <q-input
                v-model="searchTerm"
                label="Type to search..."
                outlined
                dense
                autofocus
                @keyup.enter="onSearchStock"
              />
            </div>
          </div>

          <div v-if="!sortedSearchItems.length && !inventoryStore.loading" class="text-center text-grey-7 q-py-lg">
            No stock items found.
          </div>

          <div v-else class="q-gutter-sm">
            <q-card
              v-for="item in sortedSearchItems"
              :key="item.id"
              flat
              bordered
            >
              <q-card-section class="row items-center justify-between q-col-gutter-md">
                <div class="row items-center no-wrap col">
                  <q-avatar rounded size="56px" class="q-mr-md">
                    <img :src="item.image_url || fallbackImageUrl" alt="product image" />
                  </q-avatar>
                  <div>
                    <div class="text-body1 text-weight-medium">{{ item.name }}</div>
                    <div class="text-caption text-grey-7">
                      Shipment ID: {{ item.shipment?.shipment?.id ?? '-' }}
                    </div>
                    <div class="text-caption text-grey-7">
                      Cost: {{ item.cost ?? 0 }}
                    </div>
                    <div class="text-caption text-grey-7">
                      Available: {{ item.quantities.available }}
                    </div>
                  </div>
                </div>
                <div>
                  <div class="row items-center q-gutter-sm">
                    <q-input
                      :model-value="getAddQuantity(item.id)"
                      type="number"
                      label="Quantity *"
                      dense
                      outlined
                      min="1"
                      :max="item.quantities.available"
                      style="width: 90px"
                      lazy-rules
                      :rules="[
                        (value: string | number | null) => Number(value ?? 0) > 0 || 'Quantity is required',
                      ]"
                      @update:model-value="(value) => setAddQuantity(item.id, value)"
                    />
                    <q-input
                      :model-value="getSellPrice(item.id)"
                      type="number"
                      dense
                      outlined
                      min="0"
                      label="Sell Price *"
                      style="width: 120px"
                      lazy-rules
                      :rules="[
                        (value: string | number | null) =>
                          value !== null && value !== '' && Number(value) >= 0 || 'Sell price is required',
                      ]"
                      @update:model-value="(value) => setSellPrice(item.id, value)"
                    />
                    <q-btn
                      color="primary"
                      no-caps
                      label="Add To Invoice"
                      :loading="Boolean(addLoadingByItemId[item.id])"
                      :disable="item.quantities.available <= 0 || !invoice"
                      @click="addItemToInvoice(item.id)"
                    />
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteInvoiceItemOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Invoice Item</q-card-section>
        <q-card-section>Are you sure you want to delete this item from invoice?</q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="negative" no-caps label="Delete" :loading="invoiceStore.saving" @click="onDeleteInvoiceItem" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { accountingService } from 'src/modules/accounting/services/accountingService'
import type { InventoryAccountingEntry } from 'src/modules/accounting/types'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import { useInventoryStore } from 'src/modules/inventory/stores/inventoryStore'
import { showWarningDialog } from 'src/utils/appFeedback'
import { useInvoiceStore } from '../stores/invoiceStore'
import type { InvoiceStatus } from '../types/index'

const route = useRoute()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const inventoryStore = useInventoryStore()
const searchDialogOpen = ref(false)
const addLoadingByItemId = ref<Record<number, boolean>>({})
const addQuantityByItemId = ref<Record<number, number | null>>({})
const sellPriceByItemId = ref<Record<number, number | null>>({})
const invoiceItemImageMap = ref<Record<number, string>>({})
const deleteInvoiceItemOpen = ref(false)
const selectedInvoiceItemId = ref<number | null>(null)
const fallbackImageUrl = 'https://placehold.co/56x56?text=No+Image'

const selectedStatus = ref<InvoiceStatus | null>(null)
type StockSearchField = 'product_id' | 'name' | 'barcode' | 'product_code'
const searchBy = ref<StockSearchField>('product_id')
const searchTerm = ref('')
const searchByOptions: { label: string; value: StockSearchField }[] = [
  { label: 'Product ID', value: 'product_id' },
  { label: 'Name', value: 'name' },
  { label: 'Barcode', value: 'barcode' },
  { label: 'Product Code', value: 'product_code' },
]
const statusOptions: { label: string; value: InvoiceStatus }[] = [
  { label: 'Draft', value: 'draft' },
  { label: 'Issued', value: 'issued' },
  { label: 'Partially Paid', value: 'partially_paid' },
  { label: 'Paid', value: 'paid' },
  { label: 'Overdue', value: 'overdue' },
  { label: 'Cancelled', value: 'cancelled' },
]

const invoiceId = computed(() => Number(route.params.invoiceId))
const invoice = computed(() =>
  invoiceStore.invoices.find((row) => row.id === invoiceId.value) ?? null,
)
const sortedSearchItems = computed(() =>
  [...inventoryStore.items].sort((a, b) => {
    const shipmentIdA = Number(a.shipment?.shipment?.id ?? Number.MAX_SAFE_INTEGER)
    const shipmentIdB = Number(b.shipment?.shipment?.id ?? Number.MAX_SAFE_INTEGER)
    return shipmentIdA - shipmentIdB
  }),
)

const load = async () => {
  if (!authStore.tenantId || !Number.isFinite(invoiceId.value)) return
  await invoiceStore.fetchInvoices({
    tenant_id: authStore.tenantId,
    filters: { id: invoiceId.value },
    operators: { id: 'eq' },
    page: 1,
    page_size: 1,
  })
  await invoiceStore.fetchInvoiceItems({
    tenant_id: authStore.tenantId,
    filters: { invoice_id: invoiceId.value },
    operators: { invoice_id: 'eq' },
    page: 1,
    page_size: 100,
    sortBy: 'created_at',
    sortOrder: 'desc',
  })
  await loadInvoiceItemImages()
}

const onUpdateStatus = async (value: InvoiceStatus | null) => {
  if (!invoice.value || !value || value === invoice.value.status) return
  await invoiceStore.updateInvoice({
    id: invoice.value.id,
    patch: { status: value },
  })
}

const onSearchStock = async () => {
  if (!authStore.tenantId) return

  const trimmed = searchTerm.value.trim()
  if (!trimmed) {
    await inventoryStore.fetchInventoryItems({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 20,
      sortBy: 'id',
      sortOrder: 'desc',
    })
    return
  }

  const isProductIdSearch = searchBy.value === 'product_id'
  const productIdValue = Number(trimmed)
  if (isProductIdSearch && !Number.isFinite(productIdValue)) {
    return
  }

  await inventoryStore.fetchInventoryItems({
    tenant_id: authStore.tenantId,
    filters: {
      [searchBy.value]: isProductIdSearch ? productIdValue : trimmed,
    },
    operators: {
      [searchBy.value]: isProductIdSearch ? 'eq' : 'ilike',
    },
    page: 1,
    page_size: 20,
    sortBy: 'id',
    sortOrder: 'asc',
  })
}

const addItemToInvoice = async (inventoryItemId: number) => {
  if (!authStore.tenantId || !invoice.value) return
  const item = inventoryStore.items.find((row) => row.id === inventoryItemId)
  if (!item) return

  const stock = item.stock
  if (!stock) {
    showWarningDialog('Stock record is missing for this item.')
    return
  }

  const previousAvailable = Number(item.quantities.available ?? 0)
  if (previousAvailable <= 0) {
    showWarningDialog('No available stock left for this item.')
    return
  }
  const quantity = getAddQuantity(inventoryItemId)
  if (quantity == null || !Number.isFinite(quantity) || quantity <= 0) {
    showWarningDialog('Please enter a valid quantity.')
    return
  }
  if (quantity > previousAvailable) {
    showWarningDialog('Quantity is greater than available stock.')
    return
  }

  addLoadingByItemId.value = { ...addLoadingByItemId.value, [inventoryItemId]: true }

  try {
    const sellPriceAmount = getSellPrice(inventoryItemId)
    if (sellPriceAmount == null || !Number.isFinite(sellPriceAmount) || sellPriceAmount < 0) {
      showWarningDialog('Please enter a valid sell price.')
      return
    }
    const costAmount = Number(item.cost ?? 0)
    const createInvoiceItemResult = await invoiceStore.createInvoiceItem({
      tenant_id: authStore.tenantId,
      invoice_id: invoice.value.id,
      shipment_id: (item.shipment?.shipment?.id as number | null | undefined) ?? null,
      source_item_type: 'product_based_costing_item',
      source_item_id: item.id,
      inventory_item_id: item.id,
      product_id: item.product_id ?? null,
      name_snapshot: item.name,
      barcode_snapshot: item.barcode ?? null,
      product_code_snapshot: item.product_code ?? null,
      quantity,
      cost_amount: costAmount,
      sell_price_amount: sellPriceAmount,
      line_discount_amount: 0,
      line_tax_amount: 0,
      line_total_amount: 0,
    })

    if (!createInvoiceItemResult.success) {
      return
    }
    const createdInvoiceItem = createInvoiceItemResult.data
    if (!createdInvoiceItem) {
      showWarningDialog('Failed to resolve created invoice item.')
      return
    }

    const nextAvailable = previousAvailable - quantity
    const updateStockResult = await inventoryStore.updateInventoryStock({
      id: stock.id,
      patch: {
        available_quantity: nextAvailable,
      },
    })

    if (!updateStockResult.success) {
      return
    }

    await inventoryStore.createInventoryMovement({
      inventory_item_id: item.id,
      type: 'sold',
      quantity,
      previous_quantity: previousAvailable,
      new_quantity: nextAvailable,
      note: `Auto-deducted from invoice #${invoice.value.invoice_no}`,
      created_by: authStore.user?.id ?? null,
    })

    const totalCostAmount = Number((costAmount * quantity).toFixed(2))
    const totalSellAmount = Number((sellPriceAmount * quantity).toFixed(2))
    await accountingService.createInventoryAccountingEntry({
      tenant_id: authStore.tenantId,
      invoice_id: invoice.value.id,
      invoice_item_id: createdInvoiceItem.id,
      inventory_item_id: item.id,
      shipment_id: (item.shipment?.shipment?.id as number | null | undefined) ?? null,
      shipment_item_id: (item.shipment?.shipment_item?.id as number | null | undefined) ?? null,
      product_id: item.product_id ?? null,
      quantity,
      cost_amount: costAmount,
      sell_price_amount: sellPriceAmount,
      total_cost_amount: totalCostAmount,
      total_sell_amount: totalSellAmount,
      gross_profit_amount: Number((totalSellAmount - totalCostAmount).toFixed(2)),
      status: 'due',
      entry_date: toDateOnly(new Date()),
      note: `Created from invoice #${invoice.value.invoice_no}`,
      created_by: authStore.user?.id ?? null,
    })

    addQuantityByItemId.value = { ...addQuantityByItemId.value, [inventoryItemId]: null }
    sellPriceByItemId.value = { ...sellPriceByItemId.value, [inventoryItemId]: null }
    searchTerm.value = ''
    inventoryStore.items = []
    await invoiceStore.fetchInvoiceItems({
      tenant_id: authStore.tenantId,
      filters: { invoice_id: invoice.value.id },
      operators: { invoice_id: 'eq' },
      page: 1,
      page_size: 100,
      sortBy: 'created_at',
      sortOrder: 'desc',
    })
    await loadInvoiceItemImages()
  } finally {
    addLoadingByItemId.value = { ...addLoadingByItemId.value, [inventoryItemId]: false }
  }
}

const getAddQuantity = (itemId: number) => addQuantityByItemId.value[itemId] ?? null

const setAddQuantity = (itemId: number, value: string | number | null) => {
  if (value === null || value === '') {
    addQuantityByItemId.value = { ...addQuantityByItemId.value, [itemId]: null }
    return
  }
  const parsed = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(parsed) || parsed <= 0) {
    addQuantityByItemId.value = { ...addQuantityByItemId.value, [itemId]: null }
    return
  }
  addQuantityByItemId.value = { ...addQuantityByItemId.value, [itemId]: Math.floor(parsed) }
}

const getSellPrice = (itemId: number) => sellPriceByItemId.value[itemId] ?? null

const setSellPrice = (itemId: number, value: string | number | null) => {
  if (value === null || value === '') {
    sellPriceByItemId.value = { ...sellPriceByItemId.value, [itemId]: null }
    return
  }
  const parsed = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(parsed) || parsed < 0) {
    sellPriceByItemId.value = { ...sellPriceByItemId.value, [itemId]: null }
    return
  }
  sellPriceByItemId.value = { ...sellPriceByItemId.value, [itemId]: parsed }
}

const calculateLineTotal = (sellPrice: number, quantity: number) =>
  Number((Number(sellPrice || 0) * Number(quantity || 0)).toFixed(2))

const toDateOnly = (value: Date) => value.toISOString().slice(0, 10)

const findAccountingEntryByInvoiceItemId = async (
  invoiceItemId: number,
): Promise<InventoryAccountingEntry | null> => {
  if (!authStore.tenantId) return null
  const result = await accountingService.listInventoryAccountingEntries({
    tenant_id: authStore.tenantId,
    filters: { invoice_item_id: invoiceItemId },
    operators: { invoice_item_id: 'eq' },
    page: 1,
    page_size: 1,
    sortBy: 'id',
    sortOrder: 'desc',
  })
  if (!result.success) return null
  return result.data?.data?.[0] ?? null
}

const resetSearchDialogState = () => {
  searchBy.value = 'product_id'
  searchTerm.value = ''
  addLoadingByItemId.value = {}
  addQuantityByItemId.value = {}
  sellPriceByItemId.value = {}
  inventoryStore.items = []
}

const loadInvoiceItemImages = async () => {
  const ids = Array.from(
    new Set(
      invoiceStore.invoiceItems
        .map((item) => item.inventory_item_id)
        .filter((id): id is number => typeof id === 'number'),
    ),
  )
  if (!ids.length) {
    invoiceItemImageMap.value = {}
    return
  }

  const entries = await Promise.all(
    ids.map(async (id) => {
      const result = await inventoryService.getInventoryItemById(id)
      return [id, result.success ? (result.data?.image_url ?? fallbackImageUrl) : fallbackImageUrl] as const
    }),
  )
  invoiceItemImageMap.value = Object.fromEntries(entries)
}

const onInlineUpdateSellPrice = async (invoiceItemId: number, value: string | number | null) => {
  if (!authStore.tenantId) return
  const row = invoiceStore.invoiceItems.find((item) => item.id === invoiceItemId)
  if (!row) return
  const sellPriceAmount = Math.max(0, Number(value ?? 0))
  const result = await invoiceStore.updateInvoiceItem({
    id: invoiceItemId,
    patch: {
      sell_price_amount: sellPriceAmount,
      line_total_amount: 0,
    },
  })
  if (!result.success) return

  const accountingEntry = await findAccountingEntryByInvoiceItemId(invoiceItemId)
  if (!accountingEntry) return
  const quantity = Number(row.quantity ?? 0)
  const totalSellAmount = Number((sellPriceAmount * quantity).toFixed(2))
  const totalCostAmount = Number((Number(row.cost_amount ?? 0) * quantity).toFixed(2))
  await accountingService.updateInventoryAccountingEntry({
    id: accountingEntry.id,
    patch: {
      sell_price_amount: sellPriceAmount,
      total_sell_amount: totalSellAmount,
      total_cost_amount: totalCostAmount,
      gross_profit_amount: Number((totalSellAmount - totalCostAmount).toFixed(2)),
    },
  })
}

const onInlineUpdateQuantity = async (invoiceItemId: number, value: string | number | null) => {
  if (!authStore.tenantId) return
  const row = invoiceStore.invoiceItems.find((item) => item.id === invoiceItemId)
  if (!row) return
  const quantity = Math.max(1, Math.floor(Number(value ?? 1)))
  const previousQuantity = Number(row.quantity ?? 0)
  const quantityDelta = quantity - previousQuantity

  if (quantityDelta === 0) return

  const inventoryItemId = row.inventory_item_id
  if (!inventoryItemId) {
    showWarningDialog('This invoice item has no linked inventory item.')
    return
  }

  const stockResult = await inventoryService.listInventoryStocks({
    tenant_id: authStore.tenantId,
    filters: { inventory_item_id: inventoryItemId },
    operators: { inventory_item_id: 'eq' },
    page: 1,
    page_size: 1,
  })

  if (!stockResult.success || !stockResult.data?.data.length) {
    showWarningDialog(stockResult.error ?? 'Failed to load stock for this item.')
    return
  }

  const stock = stockResult.data?.data?.[0]
  if (!stock) {
    showWarningDialog('Failed to resolve stock record for this item.')
    return
  }
  const currentAvailable = Number(stock.available_quantity ?? 0)
  const nextAvailable = currentAvailable - quantityDelta

  if (nextAvailable < 0) {
    showWarningDialog('Not enough available stock for this quantity.')
    return
  }

  const result = await invoiceStore.updateInvoiceItem({
    id: invoiceItemId,
    patch: {
      quantity,
      line_total_amount: 0,
    },
  })
  if (!result.success) return

  const updateStockResult = await inventoryStore.updateInventoryStock({
    id: stock.id,
    patch: {
      available_quantity: nextAvailable,
    },
  })

  if (!updateStockResult.success) {
    await invoiceStore.updateInvoiceItem({
      id: invoiceItemId,
      patch: {
        quantity: previousQuantity,
        line_total_amount: 0,
      },
    })
    return
  }

  await inventoryStore.createInventoryMovement({
    inventory_item_id: inventoryItemId,
    type: quantityDelta > 0 ? 'sold' : 'adjustment',
    quantity: Math.abs(quantityDelta),
    previous_quantity: currentAvailable,
    new_quantity: nextAvailable,
    note: `Invoice quantity changed from ${previousQuantity} to ${quantity}.`,
    created_by: authStore.user?.id ?? null,
  })

  const accountingEntry = await findAccountingEntryByInvoiceItemId(invoiceItemId)
  if (!accountingEntry) return
  const sellPriceAmount = Number(row.sell_price_amount ?? 0)
  const costAmount = Number(row.cost_amount ?? 0)
  const totalSellAmount = Number((sellPriceAmount * quantity).toFixed(2))
  const totalCostAmount = Number((costAmount * quantity).toFixed(2))
  await accountingService.updateInventoryAccountingEntry({
    id: accountingEntry.id,
    patch: {
      quantity,
      sell_price_amount: sellPriceAmount,
      cost_amount: costAmount,
      total_sell_amount: totalSellAmount,
      total_cost_amount: totalCostAmount,
      gross_profit_amount: Number((totalSellAmount - totalCostAmount).toFixed(2)),
    },
  })
}

const openDeleteInvoiceItem = (id: number) => {
  selectedInvoiceItemId.value = id
  deleteInvoiceItemOpen.value = true
}

const onDeleteInvoiceItem = async () => {
  if (!selectedInvoiceItemId.value) return
  const accountingEntry = await findAccountingEntryByInvoiceItemId(selectedInvoiceItemId.value)
  const result = await invoiceStore.deleteInvoiceItem({ id: selectedInvoiceItemId.value })
  if (result.success) {
    if (accountingEntry) {
      await accountingService.deleteInventoryAccountingEntry({ id: accountingEntry.id })
    }
    deleteInvoiceItemOpen.value = false
    selectedInvoiceItemId.value = null
    await loadInvoiceItemImages()
  }
}

watch(
  invoice,
  (nextInvoice) => {
    selectedStatus.value = nextInvoice?.status ?? null
  },
  { immediate: true },
)

watch(searchDialogOpen, (open) => {
  if (!open) {
    resetSearchDialogState()
  }
})

onMounted(load)
</script>

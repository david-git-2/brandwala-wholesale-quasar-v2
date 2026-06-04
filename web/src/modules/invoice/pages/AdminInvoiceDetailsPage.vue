<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5 text-weight-bold">Invoice Details</div>
      <q-btn
        outline
        no-caps
        icon="arrow_back"
        label="Back"
        @click="goBack"
      />
    </div>
    <div v-if="invoice" class="q-gutter-md">
        <div>
          <div class="text-caption text-grey-7">Invoice Name</div>
          <div class="text-body1 text-weight-medium">{{ invoice.invoice_no }}</div>
        </div>
        <div>
          <div class="text-caption text-grey-7 q-mb-xs">Status</div>
          <div class="row justify-end items-center q-gutter-sm">
            <q-btn
              v-if="invoice?.status === 'issued'"
              color="secondary"
              no-caps
              icon="visibility"
              label="Preview"
              @click="openInvoicePreview"
            />
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
            <q-btn
              color="secondary"
              no-caps
              icon="payments"
              label="Customer Payment"
              :disable="!invoice?.billing_profile_id"
              @click="openCustomerPaymentDetails"
            />
          </div>
        </div>

        <q-separator />

        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-3">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Total Sell</div>
                <div class="text-h6 text-weight-bold">{{ formatAmount(totalSellAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-3">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Total Cost</div>
                <div class="text-h6 text-weight-bold">{{ formatAmount(totalCostAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-3">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Total Profit</div>
                <div class="text-h6 text-weight-bold text-positive">{{ formatAmount(totalProfitAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-3">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Paid Amount</div>
                <div class="text-h6 text-weight-bold text-primary">{{ formatAmount(Number(invoice?.paid_amount ?? 0)) }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Total Returned Amount</div>
                <div class="text-h6 text-weight-bold text-warning">{{ formatAmount(totalReturnedAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Discount</div>
                <div class="text-h6 text-weight-bold text-orange cursor-pointer">
                  {{ formatAmount(Number(invoice?.discount_amount ?? 0)) }}
                  <q-popup-edit
                    :model-value="Number(invoice?.discount_amount ?? 0)"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="onUpdateDiscount"
                  >
                    <q-input
                      :model-value="Number(invoice?.discount_amount ?? 0)"
                      type="number"
                      dense
                      autofocus
                      min="0"
                      label="Invoice Discount"
                    />
                  </q-popup-edit>
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Outstanding Amount</div>
                <div class="text-h6 text-weight-bold text-negative">{{ formatAmount(outstandingAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>

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
                <th class="text-right">Returned</th>
                <th class="text-right">Return Amount</th>
                <th class="text-right">Line Total</th>
                <th class="text-right" style="width: 90px">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in invoiceStore.invoiceItems" :key="row.id">
                <td>{{ index + 1 }}</td>
                <td>
                  <q-avatar rounded size="1in">
                    <img
                      :src="invoiceItemImageMap[row.inventory_item_id ?? -1] ?? fallbackImageUrl"
                      alt="item image"
                      class="invoice-image"
                    />
                  </q-avatar>
                </td>
                <td style="white-space: normal; word-break: break-word; min-width: 260px;">
                  {{ row.name_snapshot }}
                </td>
                <td class="text-right">{{ formatAmountBdt(row.cost_amount) }}</td>
                <td class="text-right">
                  <span class="cursor-pointer text-primary">{{ formatAmountBdt(row.sell_price_amount) }}</span>
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
                <td class="text-right">{{ formatQuantity(getReturnedQuantity(row)) }}</td>
                <td class="text-right">{{ formatAmount(Number(row.return_amount ?? 0)) }}</td>
                <td class="text-right">{{ formatAmount(getNetSellAmount(row)) }}</td>
                <td class="text-right">
                  <q-btn
                    flat
                    round
                    icon="assignment_return"
                    color="warning"
                    @click="openReturnDialog(row.id)"
                  >
                    <q-tooltip>Return</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    icon="o_delete"
                    color="negative"
                    @click="openDeleteInvoiceItem(row.id)"
                  >
                    <q-tooltip>Delete</q-tooltip>
                  </q-btn>
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
                    <img
                      :src="item.image_url || fallbackImageUrl"
                      alt="product image"
                      class="invoice-image"
                    />
                  </q-avatar>
                  <div>
                    <div class="text-body1 text-weight-medium">
                      {{ item.name }}
                      <span v-if="item.tenant_name" class="text-caption text-grey-7">({{ item.tenant_name }})</span>
                    </div>
                    <div class="text-caption text-grey-7">
                      Shipment ID: {{ item.shipment?.shipment?.id ?? '-' }}
                    </div>
                    <div class="text-caption text-grey-7">
                      Cost: {{ item.cost ?? 0 }}
                    </div>
                    <div class="invoice-search__usable text-grey-8">
                      Usable: {{ item.quantities.usable }}
                    </div>
                    <div class="invoice-search__usable text-grey-8">
                      Open Box: {{ item.quantities.open_box }}
                    </div>
                  </div>
                </div>
                <div>
                  <div class="row items-center q-gutter-sm">
                    <q-checkbox
                      :model-value="isOpenBoxFirstEnabled(item.id)"
                      label="Open box first"
                      @update:model-value="(value) => setOpenBoxFirst(item.id, Boolean(value))"
                    />
                    <q-input
                      :model-value="getAddQuantity(item.id)"
                      type="number"
                      label="Quantity *"
                      dense
                      outlined
                      min="1"
                      :max="item.quantities.usable"
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
                      :disable="item.quantities.usable <= 0 || !invoice"
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

    <q-dialog v-model="returnDialogOpen">
      <q-card style="min-width: 420px; width: 92vw; max-width: 540px">
        <q-card-section class="text-h6">Invoice Item Return</q-card-section>
        <q-card-section class="q-gutter-sm">
          <div v-if="selectedReturnInvoiceItem" class="text-caption text-grey-8">
            <div><strong>{{ selectedReturnInvoiceItem.name_snapshot }}</strong></div>
            <div>Sold Qty: {{ formatQuantity(selectedReturnInvoiceItem.quantity) }}</div>
            <div>Already Returned Qty: {{ formatQuantity(getReturnedQuantity(selectedReturnInvoiceItem)) }}</div>
            <div>Remaining Return Qty: {{ formatQuantity(getRemainingReturnQty(selectedReturnInvoiceItem)) }}</div>
            <div>Remaining Return Amount: {{ formatAmount(getRemainingReturnAmount(selectedReturnInvoiceItem)) }}</div>
          </div>
          <div class="text-caption text-grey-7">
            Returned qty cannot exceed sold qty. Normal, open box, and damaged returns are tracked separately.
          </div>
          <q-input
            v-model.number="returnNormalQtyInput"
            type="number"
            outlined
            dense
            min="0"
            label="Normal Return Qty"
          />
          <q-input
            v-model.number="returnOpenBoxQtyInput"
            type="number"
            outlined
            dense
            min="0"
            label="Open Box Return Qty"
          />
          <q-input
            v-model.number="returnDamagedQtyInput"
            type="number"
            outlined
            dense
            min="0"
            label="Damaged Return Qty"
          />
          <q-input
            v-model="returnNoteInput"
            type="text"
            outlined
            dense
            label="Return Note / Reason"
            placeholder="Enter reason for return..."
          />
          <q-checkbox
            v-model="returnToNewBatchInput"
            label="Return to a new separate batch (group)"
            color="warning"
            class="q-my-xs"
          />
          <q-input
            v-model.number="returnAmountInput"
            type="number"
            outlined
            dense
            min="0"
            label="Return Amount"
          />
          <div class="row q-gutter-sm">
            <q-btn
              flat
              dense
              no-caps
              color="warning"
              label="Use Max Remaining Qty"
              @click="setMaxRemainingQtyForReturn"
            />
            <q-btn
              flat
              dense
              no-caps
              color="warning"
              label="Use Max Remaining Amount"
              @click="setMaxRemainingAmountForReturn"
            />
          </div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="warning"
            no-caps
            label="Apply Return"
            :loading="invoiceStore.saving || inventoryStore.saving"
            @click="onConfirmReturn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { accountingService } from 'src/modules/accounting/services/accountingService'
import type { InventoryAccountingEntry } from 'src/modules/accounting/types'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import { useInventoryStore } from 'src/modules/inventory/stores/inventoryStore'
import { showWarningDialog } from 'src/utils/appFeedback'
import { useInvoiceStore } from '../stores/invoiceStore'
import type { InvoiceStatus } from '../types/index'
import { formatAmountBdt } from 'src/utils/currency'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const inventoryStore = useInventoryStore()
const searchDialogOpen = ref(false)
const addLoadingByItemId = ref<Record<number, boolean>>({})
const addQuantityByItemId = ref<Record<number, number | null>>({})
const sellPriceByItemId = ref<Record<number, number | null>>({})
const openBoxFirstByItemId = ref<Record<number, boolean>>({})
const invoiceItemImageMap = ref<Record<number, string>>({})
const deleteInvoiceItemOpen = ref(false)
const selectedInvoiceItemId = ref<number | null>(null)
const returnDialogOpen = ref(false)
const selectedReturnInvoiceItemId = ref<number | null>(null)
const returnNormalQtyInput = ref<number>(0)
const returnOpenBoxQtyInput = ref<number>(0)
const returnDamagedQtyInput = ref<number>(0)
const returnAmountInput = ref<number>(0)
const returnNoteInput = ref<string>('')
const returnToNewBatchInput = ref<boolean>(false)
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
const getReturnedQuantity = (row: { return_normal_quantity?: number; return_open_box_quantity?: number; return_damaged_quantity?: number }) =>
  Number(row.return_normal_quantity ?? 0) + Number(row.return_open_box_quantity ?? 0) + Number(row.return_damaged_quantity ?? 0)
const getNetQuantity = (row: { quantity: number; return_normal_quantity?: number; return_open_box_quantity?: number; return_damaged_quantity?: number }) =>
  Math.max(0, Number(row.quantity ?? 0) - getReturnedQuantity(row))
const getNetSellAmount = (row: { quantity: number; sell_price_amount: number; return_amount?: number }) =>
  Math.max(0, Number(row.quantity ?? 0) * Number(row.sell_price_amount ?? 0) - Number(row.return_amount ?? 0))
const getNetCostAmount = (row: { quantity: number; cost_amount: number; return_normal_quantity?: number; return_open_box_quantity?: number; return_damaged_quantity?: number }) =>
  Math.max(0, getNetQuantity(row) * Number(row.cost_amount ?? 0))
const totalSellAmount = computed(() =>
  invoiceStore.invoiceItems.reduce(
    (sum, row) => sum + getNetSellAmount(row),
    0,
  ),
)
const totalCostAmount = computed(() =>
  invoiceStore.invoiceItems.reduce(
    (sum, row) => sum + getNetCostAmount(row),
    0,
  ),
)
const totalReturnedAmount = computed(() =>
  invoiceStore.invoiceItems.reduce(
    (sum, row) => sum + Number(row.return_amount ?? 0),
    0,
  ),
)
const outstandingAmount = computed(() =>
  Math.max(0, Number(invoice.value?.total_amount ?? 0) - Number(invoice.value?.paid_amount ?? 0)),
)
const totalProfitAmount = computed(() => totalSellAmount.value - totalCostAmount.value)
const selectedReturnInvoiceItem = computed(() =>
  invoiceStore.invoiceItems.find((item) => item.id === selectedReturnInvoiceItemId.value) ?? null,
)
const getRemainingReturnQty = (row: { quantity: number; return_normal_quantity?: number; return_open_box_quantity?: number; return_damaged_quantity?: number }) =>
  Math.max(0, Number(row.quantity ?? 0) - getReturnedQuantity(row))
const getRemainingReturnAmount = (row: { quantity: number; sell_price_amount: number; return_amount?: number }) =>
  Math.max(0, Number(row.quantity ?? 0) * Number(row.sell_price_amount ?? 0) - Number(row.return_amount ?? 0))

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
  const nextTotal = Number(totalSellAmount.value.toFixed(2))
  await invoiceStore.updateInvoice({
    id: invoice.value.id,
    patch: {
      status: value,
      subtotal_amount: nextTotal,
      total_amount: nextTotal,
    },
  })
}

const openInvoicePreview = async () => {
  if (!invoice.value) return
  await router.push({
    name: 'app-invoice-preview-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      invoiceId: invoice.value.id,
    },
  })
}

const openCustomerPaymentDetails = async () => {
  const billingProfileId = Number(invoice.value?.billing_profile_id ?? 0)
  if (!billingProfileId) return
  await router.push({
    name: 'app-accounting-customer-payment-details-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      billingProfileId,
    },
  })
}

const goBack = async () => {
  if (window.history.length > 1) {
    router.back()
    return
  }
  await router.push({
    name: 'app-invoice-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
    },
  })
}

const onSearchStock = async () => {
  const trimmed = searchTerm.value.trim()
  if (!trimmed) {
    await inventoryStore.fetchGlobalInventoryItems({
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

  await inventoryStore.fetchGlobalInventoryItems({
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

  const previousAvailable = Number(stock.available_quantity ?? 0)
  const previousOpenBox = Number(stock.open_box_quantity ?? 0)
  const previousUsable = Math.max(0, previousAvailable - Number(stock.reserved_quantity ?? 0))
  const totalUsablePool = previousUsable + previousOpenBox
  if (totalUsablePool <= 0) {
    showWarningDialog('No usable stock left for this item.')
    return
  }
  const quantity = getAddQuantity(inventoryItemId)
  if (quantity == null || !Number.isFinite(quantity) || quantity <= 0) {
    showWarningDialog('Please enter a valid quantity.')
    return
  }
  if (quantity > totalUsablePool) {
    showWarningDialog('Quantity is greater than usable stock.')
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
      return_normal_quantity: 0,
      return_open_box_quantity: 0,
      return_damaged_quantity: 0,
      return_amount: 0,
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

    let nextAvailable = previousAvailable
    let nextOpenBox = previousOpenBox

    if (isOpenBoxFirstEnabled(inventoryItemId)) {
      if (quantity <= previousOpenBox) {
        nextOpenBox = previousOpenBox - quantity
      } else {
        nextOpenBox = 0
        nextAvailable = previousAvailable - (quantity - previousOpenBox)
      }
    } else {
      nextAvailable = previousAvailable - quantity
    }

    const updateStockResult = await inventoryStore.updateInventoryStock({
      id: stock.id,
      patch: {
        available_quantity: nextAvailable,
        open_box_quantity: nextOpenBox,
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
      tenant_id: item.tenant_id,
      invoice_id: invoice.value.id,
      invoice_item_id: createdInvoiceItem.id,
      inventory_item_id: item.id,
      shipment_id: (item.shipment?.shipment?.id as number | null | undefined) ?? null,
      shipment_item_id: (item.shipment?.shipment_item?.id as number | null | undefined) ?? null,
      product_id: item.product_id ?? null,
      quantity,
      return_quantity: 0,
      return_amount: 0,
      cost_amount: costAmount,
      sell_price_amount: sellPriceAmount,
      total_cost_amount: totalCostAmount,
      total_sell_amount: totalSellAmount,
      gross_profit_amount: Number((totalSellAmount - totalCostAmount).toFixed(2)),
      status: 'due',
      entry_date: toDateOnly(new Date()),
      note: `Created from invoice #${invoice.value.invoice_no} (Sold via Tenant: ${authStore.selectedTenant?.name || authStore.tenantId})`,
      created_by: authStore.user?.id ?? null,
    })

    addQuantityByItemId.value = { ...addQuantityByItemId.value, [inventoryItemId]: null }
    sellPriceByItemId.value = { ...sellPriceByItemId.value, [inventoryItemId]: null }
    openBoxFirstByItemId.value = { ...openBoxFirstByItemId.value, [inventoryItemId]: false }
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
    await syncInvoiceSellTotal()
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

const isOpenBoxFirstEnabled = (itemId: number) => Boolean(openBoxFirstByItemId.value[itemId])
const setOpenBoxFirst = (itemId: number, value: boolean) => {
  openBoxFirstByItemId.value = { ...openBoxFirstByItemId.value, [itemId]: value }
}

const openReturnDialog = (invoiceItemId: number) => {
  selectedReturnInvoiceItemId.value = invoiceItemId
  returnNormalQtyInput.value = 0
  returnOpenBoxQtyInput.value = 0
  returnDamagedQtyInput.value = 0
  returnAmountInput.value = 0
  returnNoteInput.value = ''
  returnToNewBatchInput.value = false
  returnDialogOpen.value = true
}

const setMaxRemainingQtyForReturn = () => {
  const item = selectedReturnInvoiceItem.value
  if (!item) return
  returnNormalQtyInput.value = getRemainingReturnQty(item)
  returnOpenBoxQtyInput.value = 0
  returnDamagedQtyInput.value = 0
}

const setMaxRemainingAmountForReturn = () => {
  const item = selectedReturnInvoiceItem.value
  if (!item) return
  returnAmountInput.value = Number(getRemainingReturnAmount(item).toFixed(2))
}

const getDefaultReturnAmount = () => {
  const item = selectedReturnInvoiceItem.value
  if (!item) return 0
  const totalQty =
    Number(returnNormalQtyInput.value ?? 0) +
    Number(returnOpenBoxQtyInput.value ?? 0) +
    Number(returnDamagedQtyInput.value ?? 0)
  const amount = totalQty * Number(item.sell_price_amount ?? 0)
  return Number(Math.max(0, amount).toFixed(2))
}

const onConfirmReturn = async () => {
  if (!authStore.tenantId || !invoice.value || !selectedReturnInvoiceItemId.value) return
  const invoiceItem = invoiceStore.invoiceItems.find((item) => item.id === selectedReturnInvoiceItemId.value)
  if (!invoiceItem) {
    showWarningDialog('Invoice item not found.')
    return
  }
  if (!invoiceItem.inventory_item_id) {
    showWarningDialog('Inventory item is missing for this invoice item.')
    return
  }

  const returnNormal = Math.max(0, Number(returnNormalQtyInput.value ?? 0))
  const returnOpenBox = Math.max(0, Number(returnOpenBoxQtyInput.value ?? 0))
  const returnDamaged = Math.max(0, Number(returnDamagedQtyInput.value ?? 0))
  const returnAmount = Math.max(0, Number(returnAmountInput.value ?? 0))
  const returnQty = returnNormal + returnOpenBox + returnDamaged

  if (returnQty <= 0 && returnAmount <= 0) {
    showWarningDialog('Enter return quantity or return amount.')
    return
  }

  const existingReturnedQty = getReturnedQuantity(invoiceItem)
  const nextReturnedQty = existingReturnedQty + returnQty
  const soldQty = Number(invoiceItem.quantity ?? 0)
  const remainingQty = getRemainingReturnQty(invoiceItem)

  if (returnQty > remainingQty || nextReturnedQty > soldQty) {
    showWarningDialog('Return quantity exceeds remaining returnable quantity.')
    return
  }

  const nextReturnAmount = Number(invoiceItem.return_amount ?? 0) + returnAmount
  const remainingAmount = getRemainingReturnAmount(invoiceItem)
  const maxSellAmount = Number(invoiceItem.quantity ?? 0) * Number(invoiceItem.sell_price_amount ?? 0)
  if (returnAmount > remainingAmount || nextReturnAmount > maxSellAmount) {
    showWarningDialog('Return amount exceeds remaining returnable amount.')
    return
  }

  const applyReturnResult = await invoiceStore.applyInvoiceItemReturn({
    tenant_id: authStore.tenantId,
    invoice_item_id: invoiceItem.id,
    return_normal_quantity: Number(returnNormal.toFixed(3)),
    return_open_box_quantity: Number(returnOpenBox.toFixed(3)),
    return_damaged_quantity: Number(returnDamaged.toFixed(3)),
    return_amount: Number(returnAmount.toFixed(2)),
    note: returnNoteInput.value?.trim() || null,
    actor: authStore.user?.id ?? null,
    return_to_new_batch: returnToNewBatchInput.value,
  })
  if (!applyReturnResult.success) return

  returnDialogOpen.value = false
  selectedReturnInvoiceItemId.value = null
  returnNormalQtyInput.value = 0
  returnOpenBoxQtyInput.value = 0
  returnDamagedQtyInput.value = 0
  returnAmountInput.value = 0
  returnNoteInput.value = ''
  await invoiceStore.fetchInvoiceItems({
    tenant_id: authStore.tenantId,
    filters: { invoice_id: invoice.value.id },
    operators: { invoice_id: 'eq' },
    page: 1,
    page_size: 100,
    sortBy: 'created_at',
    sortOrder: 'desc',
  })
  await syncInvoiceSellTotal()
}

const formatAmount = (value: number) => formatAmountBdt(value)
const formatQuantity = (value: number) => Number(value ?? 0).toFixed(3)

const onUpdateDiscount = async (value: string | number | null) => {
  if (!invoice.value) return
  const discountVal = Math.max(0, Number(value ?? 0))
  const nextSubtotal = Number(totalSellAmount.value.toFixed(2))
  const nextTotal = Number(Math.max(0, nextSubtotal - discountVal).toFixed(2))
  await invoiceStore.updateInvoice({
    id: invoice.value.id,
    patch: {
      discount_amount: discountVal,
      total_amount: nextTotal,
    },
  })
  if (authStore.tenantId) {
    await invoiceStore.fetchInvoices({
      tenant_id: authStore.tenantId,
      filters: { id: invoice.value.id },
      operators: { id: 'eq' },
      page: 1,
      page_size: 1,
    })
    // Reload items to get latest line discounts
    await invoiceStore.fetchInvoiceItems({
      tenant_id: authStore.tenantId,
      filters: { invoice_id: invoice.value.id },
      operators: { invoice_id: 'eq' },
      page: 1,
      page_size: 100,
      sortBy: 'created_at',
      sortOrder: 'desc',
    })
  }
}

const toDateOnly = (value: Date) => value.toISOString().slice(0, 10)

const findAccountingEntryByInvoiceItemId = async (
  invoiceItemId: number,
): Promise<InventoryAccountingEntry | null> => {
  const result = await accountingService.listInventoryAccountingEntries({
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
  openBoxFirstByItemId.value = {}
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
  const soldQuantity = Number(row.quantity ?? 0)
  const returnedQuantity = getReturnedQuantity(row)
  const netQuantity = Math.max(0, soldQuantity - returnedQuantity)
  const returnAmount = Number(row.return_amount ?? 0)
  const totalSellAmount = Number(Math.max(0, sellPriceAmount * soldQuantity - returnAmount).toFixed(2))
  const totalCostAmount = Number((Number(row.cost_amount ?? 0) * netQuantity).toFixed(2))
  await accountingService.updateInventoryAccountingEntry({
    id: accountingEntry.id,
    patch: {
      quantity: netQuantity,
      sell_price_amount: sellPriceAmount,
      return_quantity: Number(returnedQuantity.toFixed(3)),
      return_amount: Number(returnAmount.toFixed(2)),
      total_sell_amount: totalSellAmount,
      total_cost_amount: totalCostAmount,
      gross_profit_amount: Number((totalSellAmount - totalCostAmount).toFixed(2)),
    },
  })
  await syncInvoiceSellTotal()
}

const onInlineUpdateQuantity = async (invoiceItemId: number, value: string | number | null) => {
  if (!authStore.tenantId) return
  const row = invoiceStore.invoiceItems.find((item) => item.id === invoiceItemId)
  if (!row) return
  const quantity = Math.max(1, Math.floor(Number(value ?? 1)))
  const returnedQuantity = getReturnedQuantity(row)
  if (quantity < returnedQuantity) {
    showWarningDialog('Quantity cannot be less than already returned quantity.')
    return
  }
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
  const currentUsable = Math.max(0, currentAvailable - Number(stock.reserved_quantity ?? 0))
  if (quantityDelta > currentUsable) {
    showWarningDialog('Not enough usable stock for this quantity.')
    return
  }
  const nextAvailable = currentAvailable - quantityDelta

  if (nextAvailable < 0) {
    showWarningDialog('Not enough usable stock for this quantity.')
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
  const returnAmount = Number(row.return_amount ?? 0)
  const netQuantity = Math.max(0, quantity - returnedQuantity)
  const totalSellAmount = Number(Math.max(0, sellPriceAmount * quantity - returnAmount).toFixed(2))
  const totalCostAmount = Number((costAmount * netQuantity).toFixed(2))
  await accountingService.updateInventoryAccountingEntry({
    id: accountingEntry.id,
    patch: {
      quantity: netQuantity,
      sell_price_amount: sellPriceAmount,
      cost_amount: costAmount,
      return_quantity: Number(returnedQuantity.toFixed(3)),
      return_amount: Number(returnAmount.toFixed(2)),
      total_sell_amount: totalSellAmount,
      total_cost_amount: totalCostAmount,
      gross_profit_amount: Number((totalSellAmount - totalCostAmount).toFixed(2)),
    },
  })
  await syncInvoiceSellTotal()
}

const openDeleteInvoiceItem = (id: number) => {
  selectedInvoiceItemId.value = id
  deleteInvoiceItemOpen.value = true
}

const onDeleteInvoiceItem = async () => {
  if (!selectedInvoiceItemId.value) return
  if (!authStore.tenantId) return
  const row = invoiceStore.invoiceItems.find((item) => item.id === selectedInvoiceItemId.value)
  if (!row) return

  const netQuantity = Math.max(0, Number(row.quantity ?? 0) - getReturnedQuantity(row))
  let stockIdToUpdate: number | null = null
  let previousAvailable = 0

  if (row.inventory_item_id && netQuantity > 0) {
    const stockResult = await inventoryService.listInventoryStocks({
      tenant_id: authStore.tenantId,
      filters: { inventory_item_id: row.inventory_item_id },
      operators: { inventory_item_id: 'eq' },
      page: 1,
      page_size: 1,
    })
    if (!stockResult.success || !stockResult.data?.data.length) {
      showWarningDialog(stockResult.error ?? 'Failed to load stock for delete rollback.')
      return
    }
    const stock = stockResult.data.data[0]
    if (!stock) {
      showWarningDialog('Stock record is missing for this invoice item.')
      return
    }
    stockIdToUpdate = stock.id
    previousAvailable = Number(stock.available_quantity ?? 0)
  }

  const accountingEntry = await findAccountingEntryByInvoiceItemId(selectedInvoiceItemId.value)
  const result = await invoiceStore.deleteInvoiceItem({ id: selectedInvoiceItemId.value })
  if (result.success) {
    if (stockIdToUpdate != null && netQuantity > 0) {
      const nextAvailable = previousAvailable + netQuantity
      const updateStockResult = await inventoryStore.updateInventoryStock({
        id: stockIdToUpdate,
        patch: { available_quantity: nextAvailable },
      })
      if (updateStockResult.success && row.inventory_item_id) {
        await inventoryStore.createInventoryMovement({
          inventory_item_id: row.inventory_item_id,
          type: 'adjustment',
          quantity: netQuantity,
          previous_quantity: previousAvailable,
          new_quantity: nextAvailable,
          note: `Invoice item deleted from #${invoice.value?.invoice_no ?? '-'}`,
          created_by: authStore.user?.id ?? null,
        })
      }
    }

    if (accountingEntry) {
      await accountingService.deleteInventoryAccountingEntry({ id: accountingEntry.id })
    }
    deleteInvoiceItemOpen.value = false
    selectedInvoiceItemId.value = null
    await syncInvoiceSellTotal()
    await loadInvoiceItemImages()
  }
}

const syncInvoiceSellTotal = async () => {
  if (!invoice.value) return
  const nextSubtotal = Number(totalSellAmount.value.toFixed(2))
  const discountAmount = Number(invoice.value.discount_amount ?? 0)
  const nextTotal = Number(Math.max(0, nextSubtotal - discountAmount).toFixed(2))
  const updateResult = await invoiceStore.updateInvoice({
    id: invoice.value.id,
    patch: {
      subtotal_amount: nextSubtotal,
      total_amount: nextTotal,
    },
  })
  if (!updateResult.success) return
  await invoiceStore.recomputeInvoicePaymentStatus(invoice.value.id)
  if (!authStore.tenantId) return
  await invoiceStore.fetchInvoices({
    tenant_id: authStore.tenantId,
    filters: { id: invoice.value.id },
    operators: { id: 'eq' },
    page: 1,
    page_size: 1,
  })
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

watch(
  [returnNormalQtyInput, returnOpenBoxQtyInput, returnDamagedQtyInput, selectedReturnInvoiceItem],
  () => {
    returnAmountInput.value = getDefaultReturnAmount()
  },
)

onMounted(load)
</script>

<style scoped>
.invoice-search__usable {
  font-size: 1.05rem;
  font-weight: 700;
}

.invoice-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  background: #fff;
}
</style>

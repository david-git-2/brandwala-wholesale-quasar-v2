<template>
  <q-page class="q-pa-md commerce-invoice-details-page">
    <!-- Loading State -->
    <PageInitialLoader v-if="loading" />

    <!-- Error State -->
    <div v-else-if="error" class="column items-center justify-center q-pa-xl text-black empty-state-block floating-surface shadow-1">
      <q-icon name="error_outline" size="64px" class="q-mb-sm text-red" />
      <div class="text-subtitle1 text-weight-medium text-black">{{ error }}</div>
    </div>

    <!-- Details View -->
    <div v-else-if="invoice" class="invoice-details-wrap">
      <!-- Header Hero Card -->
      <q-card flat class="hero-surface floating-surface shadow-1 q-mb-md q-pa-md">
        <div class="row items-center justify-between">
          <div class="row items-center">
            <div>
              <div class="text-h6 text-weight-bold text-black">Invoice #{{ invoice.id }}</div>
              <div class="text-caption text-black">Order Ref: #{{ invoice.order_id }} | Created on {{ formatDate(invoice.created_at) }}</div>
            </div>
          </div>
          <div class="row items-center q-gutter-sm">
            <q-btn color="negative" icon="o_delete" flat round dense class="pill-btn slim-btn" @click="onDeleteInvoice">
              <q-tooltip>Delete Invoice</q-tooltip>
            </q-btn>
            <q-btn color="primary" icon="o_search" flat round dense class="pill-btn slim-btn" @click="openSearchDialogForAdd">
              <q-tooltip>Add From Inventory</q-tooltip>
            </q-btn>
            <!-- Invoice Status Chip -->
            <q-chip
              square
              dense
              clickable
              :style="statusChipStyle(invoice.status)"
              class="status-chip text-weight-bold"
            >
              <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(invoice.status) }"></span>
              {{ formatStatusLabel(invoice.status).toUpperCase() }}
              <q-menu auto-close>
                <q-list dense style="min-width: 150px">
                  <q-item
                     v-for="opt in statusOptions"
                     :key="opt"
                     clickable
                     v-close-popup
                     @click="onStatusMenuSelect(invoice.id, opt)"
                  >
                    <q-item-section>{{ formatStatusLabel(opt).toUpperCase() }}</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-chip>
            <q-chip
              square
              dense
              :color="invoice.is_customer_group_paid ? 'green' : 'red'"
              text-color="white"
              class="text-weight-bold status-chip"
            >
              {{ invoice.is_customer_group_paid ? 'PAID' : 'UNPAID' }}
            </q-chip>
          </div>
        </div>
      </q-card>

      <!-- Main Breakdown Grid -->
      <div class="column q-gutter-md q-mb-md">
        <!-- Recipient Information Card -->
        <div class="col-12">
          <q-card flat class="floating-surface shadow-1 q-pa-md full-height">
            <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">
              <q-icon name="assignment" class="q-mr-xs" /> Recipient Details
            </div>
            <div v-if="order" class="row q-col-gutter-md">
              <div class="col-12 col-sm-6">
                <div class="text-subtitle2 text-grey-7">Recipient Name</div>
                <div class="text-body1 text-weight-medium text-grey-9">{{ order.recipient_name }}</div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="text-subtitle2 text-grey-7">Recipient Phone</div>
                <div class="text-body1 text-weight-medium text-grey-9">{{ order.recipient_phone }}</div>
              </div>
              <div class="col-12">
                <div class="text-subtitle2 text-grey-7">Shipping Address</div>
                <div class="text-body1 text-grey-9">{{ order.shipping_address }}</div>
              </div>
            </div>
            <div v-else class="text-grey-6">No associated order details found.</div>
          </q-card>
        </div>

        <!-- Charges & Payment details -->
        <div class="col-12">
          <q-card flat class="floating-surface shadow-1 q-pa-md full-height">
            <div class="row items-center justify-between q-mb-md">
              <div class="text-subtitle1 text-weight-bold text-primary">
                <q-icon name="local_atm" class="q-mr-xs" /> Invoice Summary
              </div>
            </div>
            <div class="row q-col-gutter-md q-mb-sm">
              <div class="col-12 col-md-2">
                <div class="text-subtitle2 text-grey-7">Subtotal</div>
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ formatAmount(subtotalAmount) }}</div>
              </div>
              <div class="col-12 col-md-2">
                <div class="text-subtitle2 text-grey-7">Discount</div>
                <div class="text-body1 text-weight-medium text-negative">৳{{ formatAmount(Number(invoice.discount_amount || 0)) }}</div>
              </div>
              <div class="col-12 col-md-3">
                <div class="text-subtitle2 text-grey-7">Grand Total</div>
                <div class="text-h6 text-weight-bold text-primary">৳{{ formatAmount(Number(invoice.total_amount || 0)) }}</div>
              </div>
              <div class="col-12 col-md-3">
                <div class="text-subtitle2 text-grey-7">Amount Due</div>
                <div class="text-h6 text-weight-bold text-red-7">৳{{ formatAmount(Number(invoice.amount_due || 0)) }}</div>
              </div>
              <div class="col-12 col-md-2">
                <div class="text-subtitle2 text-grey-7">Paid Status</div>
                <q-chip
                  :color="invoice.is_customer_group_paid ? 'green' : 'red'"
                  text-color="white"
                  class="text-weight-bold q-mt-xs"
                >
                  {{ invoice.is_customer_group_paid ? 'PAID' : 'UNPAID' }}
                </q-chip>
              </div>
            </div>

            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-2">
                <q-input
                  v-model.number="chargesForm.delivery_charge"
                  type="number"
                  step="0.01"
                  label="Delivery Charge"
                  outlined
                  dense
                  class="soft-input"
                  :rules="[val => val >= 0 || 'Must be >= 0']"
                  @update:model-value="markChargesDirty"
                />
              </div>
              <div class="col-12 col-md-2">
                <q-input
                  v-model="chargesForm.delivered_by"
                  label="Delivered By"
                  outlined
                  dense
                  class="soft-input"
                  @update:model-value="markChargesDirty"
                />
              </div>
              <div class="col-12 col-md-2">
                <q-input
                  v-model.number="chargesForm.wrapping_charge"
                  type="number"
                  step="0.01"
                  label="Wrapping"
                  outlined
                  dense
                  class="soft-input"
                  :rules="[val => val >= 0 || 'Must be >= 0']"
                  @update:model-value="markChargesDirty"
                />
              </div>
              <div class="col-12 col-md-2">
                <q-input
                  v-model.number="chargesForm.cod"
                  type="number"
                  step="0.01"
                  label="COD"
                  outlined
                  dense
                  class="soft-input"
                  :rules="[val => val >= 0 || 'Must be >= 0']"
                  @update:model-value="markChargesDirty"
                />
              </div>
              <div class="col-12 col-md-2">
                <q-input
                  v-model.number="chargesForm.discount_amount"
                  type="number"
                  step="0.01"
                  label="Discount"
                  outlined
                  dense
                  class="soft-input"
                  :rules="[val => val >= 0 || 'Must be >= 0']"
                  @update:model-value="markChargesDirty"
                />
              </div>
              <div class="col-12 col-md-2">
                <q-input
                  v-model.number="chargesForm.amount_paid"
                  type="number"
                  step="0.01"
                  label="Amount Paid"
                  outlined
                  dense
                  class="soft-input"
                  :rules="[val => val >= 0 || 'Must be >= 0']"
                  @update:model-value="markChargesDirty"
                />
              </div>
            </div>

            <div class="row justify-end q-mt-md">
              <q-btn
                v-if="chargesDirty"
                label="Save Changes"
                color="primary"
                unelevated
                class="pill-btn slim-btn"
                :loading="savingCharges"
                @click="saveCharges"
              />
            </div>
          </q-card>
        </div>
      </div>

      <!-- Items List -->
      <div class="text-subtitle1 text-weight-bold text-primary q-mb-sm">
        <q-icon name="shopping_bag" class="q-mr-xs" /> Invoice Items ({{ items.length }})
      </div>
      <q-card flat class="floating-surface shadow-1">
        <div v-if="!items.length" class="text-grey-7 q-pa-md text-center">
          No items on this invoice. Click "Add From Inventory" to add.
        </div>
        <q-markup-table v-else flat wrap-cells class="invoice-items-table">
          <thead>
            <tr>
              <th class="text-left" style="width: 56px">SL</th>
              <th class="text-left" style="width: 72px">Image</th>
              <th class="text-left">Product / ID</th>
              <th class="text-right">Cost Price</th>
              <th class="text-right">Sell Price</th>
              <th class="text-right">Recipient Price</th>
              <th class="text-right">Qty</th>
              <th class="text-right">Line Total</th>
              <th class="text-right" style="width: 90px">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, idx) in items" :key="row.id">
              <td>{{ idx + 1 }}</td>
              <td>
                <q-avatar rounded size="48px" class="bg-grey-2 border-all">
                  <img :src="row.image_url || 'https://placehold.co/48x48?text=No+Image'" alt="" />
                </q-avatar>
              </td>
              <td>
                <div class="text-weight-bold text-grey-9">{{ row.products?.name || 'Product ID: ' + row.product_id }}</div>
                <div class="text-caption text-grey-7">Code: {{ row.products?.product_code || '-' }}</div>
                <div class="text-caption text-grey-7">
                  Shipment:
                  <template v-if="row.source_type === 'shipment' && row.source_id">
                    #{{ row.source_id }}
                  </template>
                  <template v-else>
                    -
                  </template>
                </div>
                <div class="text-caption text-grey-7">
                  Inventory:
                  <template v-if="row.inventory_item_id">
                    #{{ row.inventory_item_id }} - {{ row.inventory_items?.name || 'Assigned' }}
                  </template>
                  <template v-else>
                    Not assigned
                  </template>
                </div>
              </td>
              <td class="text-right">৳{{ formatAmount(Number(row.cost_bdt || 0)) }}</td>
              <td class="text-right">৳{{ formatAmount(Number(row.sell_price_bdt || 0)) }}</td>
              <td class="text-right text-weight-medium text-primary">৳{{ formatAmount(Number(row.recipient_price_bdt || 0)) }}</td>
              <td class="text-right">{{ row.quantity }}</td>
              <td class="text-right text-weight-bold">৳{{ formatAmount(Number(row.quantity || 0) * Number(row.recipient_price_bdt || 0)) }}</td>
              <td class="text-right">
                <q-btn
                  flat
                  round
                  :icon="row.inventory_item_id ? 'o_link_off' : 'o_inventory_2'"
                  :color="row.inventory_item_id ? 'negative' : 'primary'"
                  @click="row.inventory_item_id ? unassignInventoryItem(row) : openSearchDialogForAssign(row)"
                >
                  <q-tooltip>{{ row.inventory_item_id ? 'Unassign Inventory' : 'Assign Inventory' }}</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  round
                  icon="o_delete"
                  color="negative"
                  @click="removeItem(row.id)"
                >
                  <q-tooltip>Remove from Invoice</q-tooltip>
                </q-btn>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>
    </div>

    <!-- Inventory Search Dialog -->
    <q-dialog v-model="searchDialogOpen">
      <q-card style="width: 800px; max-width: 92vw; max-height: 85vh" class="rounded-borders">
        <q-card-section class="row items-center justify-between bg-primary text-white">
          <div class="text-h6">{{ searchMode === 'assign' ? 'Assign Inventory Item' : 'Add Item From Inventory' }}</div>
          <q-btn flat round dense icon="close" v-close-popup color="white" />
        </q-card-section>
        <q-separator />

        <q-card-section class="q-pa-md">
          <div class="row q-col-gutter-sm items-center q-mb-md">
            <div class="col-auto" style="width: 180px">
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
                class="soft-input"
              />
            </div>
            <div class="col">
              <q-input
                v-model="searchTerm"
                label="Search inventory..."
                outlined
                dense
                autofocus
                class="soft-input"
                @keyup.enter="searchInventoryItems"
              />
            </div>
            <div class="col-auto">
              <q-btn color="primary" icon="o_search" flat round dense class="pill-btn slim-btn" :loading="searchingInventory" @click="searchInventoryItems">
                <q-tooltip>Search</q-tooltip>
              </q-btn>
            </div>
          </div>

          <div v-if="searchingInventory" class="row justify-center q-my-lg">
            <q-spinner-dots size="40px" color="primary" />
          </div>

          <div v-else-if="!searchResults.length" class="text-center text-grey-6 q-py-xl">
            No inventory items found.
          </div>

          <div v-else class="scroll q-gutter-y-sm" style="max-height: 50vh;">
            <q-card
              v-for="item in searchResults"
              :key="item.id"
              flat
              bordered
              class="product-search-item"
            >
              <q-card-section class="row items-center justify-between q-col-gutter-md q-pa-sm">
                <div class="row items-center no-wrap col">
                  <q-avatar rounded size="56px" class="q-mr-md bg-grey-2">
                    <img :src="item.image_url || 'https://placehold.co/56x56?text=No+Image'" alt="" />
                  </q-avatar>
                  <div>
                    <div class="text-body1 text-weight-bold text-grey-9">
                      {{ item.name }}
                      <span v-if="item.tenant_name" class="text-caption text-grey-7">({{ item.tenant_name }})</span>
                    </div>
                    <div class="text-caption text-grey-7">Code: {{ item.product_code || '-' }} | ID: {{ item.id }}</div>
                    <div class="text-caption text-grey-7">
                      Usable: {{ Number(item.quantities?.usable || 0) }} | Cost: ৳{{ formatAmount(Number(item.cost || 0)) }}
                    </div>
                  </div>
                </div>

                <div class="col-auto row items-center q-gutter-x-sm">
                  <q-input
                    v-if="searchMode === 'add'"
                    :model-value="getFormValue(item.id, 'qty')"
                    @update:model-value="(val) => setFormValue(item.id, 'qty', val)"
                    type="number"
                    label="Qty *"
                    dense
                    outlined
                    min="1"
                    style="width: 80px"
                    class="soft-input"
                  />
                  <q-input
                    v-if="searchMode === 'add'"
                    :model-value="getFormValue(item.id, 'sell')"
                    @update:model-value="(val) => setFormValue(item.id, 'sell', val)"
                    type="number"
                    label="Sell Price *"
                    dense
                    outlined
                    min="0"
                    style="width: 110px"
                    class="soft-input"
                  />
                  <q-input
                    v-if="searchMode === 'add'"
                    :model-value="getFormValue(item.id, 'recipient')"
                    @update:model-value="(val) => setFormValue(item.id, 'recipient', val)"
                    type="number"
                    label="Recipient Price *"
                    dense
                    outlined
                    min="0"
                    style="width: 120px"
                    class="soft-input"
                  />
                  <q-btn
                    color="secondary"
                    no-caps
                    unelevated
                    :label="searchMode === 'assign' ? 'Assign' : 'Add'"
                    class="pill-btn slim-btn"
                    :loading="addItemLoading[item.id]"
                    @click="onSelectInventoryItem(item)"
                  />
                </div>
              </q-card-section>
            </q-card>
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, reactive } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceInvoiceService } from '../services/commerceInvoiceService'
import { useInventoryStore } from 'src/modules/inventory/stores/inventoryStore'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const inventoryStore = useInventoryStore()
const $q = useQuasar()

type CommerceInvoiceRow = {
  id: number
  order_id: number
  delivery_charge: number
  wrapping_charge: number
  cod: number
  total_amount: number
  amount_paid: number
  amount_due: number
  is_customer_group_paid: boolean
  delivered_by: string | null
  created_at: string
  status: 'draft' | 'ready' | 'handed_to_customer'
  discount_amount?: number
}

type CommerceOrderRow = {
  recipient_name: string
  recipient_phone: string
  shipping_address: string
  invoice_ids?: number[] | null
}

type CommerceInvoiceItemRow = {
  id: number
  product_id: number
  quantity: number
  cost_bdt: number
  sell_price_bdt: number
  recipient_price_bdt: number
  image_url: string | null
  inventory_item_id: number | null
  source_type?: 'manual' | 'shipment' | null
  source_id?: number | null
  products?: {
    name?: string | null
    product_code?: string | null
  } | null
  inventory_items?: {
    name?: string | null
  } | null
}

// State
const loading = ref(true)
const error = ref<string | null>(null)
const invoice = ref<CommerceInvoiceRow | null>(null)
const order = ref<CommerceOrderRow | null>(null)
const items = ref<CommerceInvoiceItemRow[]>([])

const savingCharges = ref(false)
const chargesDirty = ref(false)
const chargesForm = reactive({
  delivery_charge: 0,
  wrapping_charge: 0,
  cod: 0,
  delivered_by: '',
  amount_paid: 0,
  discount_amount: 0,
})

// Search states
const searchDialogOpen = ref(false)
const searchMode = ref<'add' | 'assign'>('add')
const selectedOrderItem = ref<CommerceInvoiceItemRow | null>(null)
const searchTerm = ref('')
const searchBy = ref<'name' | 'product_id' | 'product_code' | 'barcode'>('name')
const searchByOptions = [
  { label: 'Name', value: 'name' },
  { label: 'Product ID', value: 'product_id' },
  { label: 'Product Code', value: 'product_code' },
  { label: 'Barcode', value: 'barcode' },
]
const searchingInventory = ref(false)
const searchResults = ref<InventoryItemWithStock[]>([])
const addItemForms = ref<Record<number, { qty: number; sell: number; recipient: number }>>({})
const addItemLoading = ref<Record<number, boolean>>({})

const invoiceId = computed(() => Number(route.params.invoiceId))

const subtotalAmount = computed(() => {
  return items.value.reduce((sum, item) => sum + (Number(item.quantity) * Number(item.recipient_price_bdt)), 0)
})

const loadInvoiceDetails = async () => {
  if (Number.isNaN(invoiceId.value)) {
    error.value = 'Invalid Invoice ID.'
    loading.value = false
    return
  }

  loading.value = true
  error.value = null
  try {
    const res = await commerceInvoiceService.getCommerceInvoiceDetails(invoiceId.value)
    if (res.success && res.data) {
      invoice.value = res.data.invoice as CommerceInvoiceRow
      order.value = res.data.order
      items.value = res.data.items
      startEditCharges()
    } else {
      error.value = res.error || 'Failed to load commerce invoice details.'
    }
  } finally {
    loading.value = false
  }
}

const statusOptions: ('draft' | 'ready' | 'handed_to_customer')[] = ['draft', 'ready', 'handed_to_customer']

const formatStatusLabel = (status?: string | null) => {
  if (!status) return 'draft'
  if (status === 'handed_to_customer') return 'handed to customer'
  return status
}

const statusChipStyle = (status?: 'draft' | 'ready' | 'handed_to_customer' | null) => {
  const currentStatus = status || 'draft'
  switch (currentStatus) {
    case 'ready':
      return {
        backgroundColor: '#c8d8f8',
        color: '#27487a',
        border: '1px solid #a9c4f3',
        boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
      }
    case 'handed_to_customer':
      return {
        backgroundColor: '#c3e8d2',
        color: '#1f5d3c',
        border: '1px solid #9fd4b7',
        boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
      }
    default:
      return {
        backgroundColor: '#dbe5f3',
        color: '#3b4b66',
        border: '1px solid #b9c8dd',
        boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
      }
  }
}

const statusDotColor = (status?: 'draft' | 'ready' | 'handed_to_customer' | null) => {
  const currentStatus = status || 'draft'
  switch (currentStatus) {
    case 'ready': return '#3f67b3'
    case 'handed_to_customer': return '#2f8b5d'
    default: return '#66758c'
  }
}

const onStatusMenuSelect = async (invoiceId: number, nextStatus: 'draft' | 'ready' | 'handed_to_customer') => {
  loading.value = true
  try {
    const res = await commerceInvoiceService.updateCommerceInvoiceStatus(invoiceId, nextStatus)
    if (res.success) {
      showSuccessNotification('Invoice status updated successfully.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to update invoice status.')
    }
  } finally {
    loading.value = false
  }
}

const startEditCharges = () => {
  if (!invoice.value) return
  chargesForm.delivery_charge = Number(invoice.value.delivery_charge) || 0
  chargesForm.wrapping_charge = Number(invoice.value.wrapping_charge) || 0
  chargesForm.cod = Number(invoice.value.cod) || 0
  chargesForm.delivered_by = invoice.value.delivered_by || ''
  chargesForm.amount_paid = Number(invoice.value.amount_paid) || 0
  chargesForm.discount_amount = Number(invoice.value.discount_amount) || 0
  chargesDirty.value = false
}

const saveCharges = async () => {
  if (!invoice.value) return
  savingCharges.value = true
  try {
    const res = await commerceInvoiceService.updateCommerceInvoiceCharges(invoice.value.id, {
      delivery_charge: chargesForm.delivery_charge,
      wrapping_charge: chargesForm.wrapping_charge,
      cod: chargesForm.cod,
      delivered_by: chargesForm.delivered_by,
      amount_paid: chargesForm.amount_paid,
      discount_amount: chargesForm.discount_amount,
    })
    if (res.success) {
      showSuccessNotification('Charges updated successfully.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to update charges.')
    }
  } finally {
    savingCharges.value = false
  }
}

const onDeleteInvoice = () => {
  if (!invoice.value) return

  const linkedInvoicesText = order.value?.invoice_ids?.length
    ? `This order currently has linked invoice(s): ${order.value.invoice_ids.map((id) => `#${id}`).join(', ')}.`
    : 'This order does not have any linked invoices listed yet.'

  $q.dialog({
    title: 'Delete Invoice?',
    message: `This will permanently delete Invoice #${invoice.value.id}, remove its related accounting records, unassign and restock any linked inventory items, and remove the invoice ID from the order. ${linkedInvoicesText}`,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: true,
    },
    cancel: {
      label: 'Cancel',
      color: 'grey-7',
      flat: true,
    },
  }).onOk(() => {
    void (async () => {
      loading.value = true
      try {
        const res = await commerceInvoiceService.deleteCommerceInvoice(invoice.value!.id)
        if (res.success) {
          showSuccessNotification(`Invoice #${invoice.value!.id} deleted successfully.`)
          await router.push({
            path: (() => {
              const tenantSlugParam = route.params.tenantSlug
              const tenantSlug = Array.isArray(tenantSlugParam) ? tenantSlugParam[0] : tenantSlugParam
              return tenantSlug ? `/${tenantSlug}/app/commerce-shop/invoices` : '/app/commerce-shop/invoices'
            })(),
          })
        } else {
          showWarningDialog(res.error || 'Failed to delete invoice.')
        }
      } finally {
        loading.value = false
      }
    })()
  })
}

const markChargesDirty = () => {
  chargesDirty.value = true
}

const removeItem = async (orderItemId: number) => {
  loading.value = true
  try {
    const res = await commerceInvoiceService.removeCommerceInvoiceItem(orderItemId, invoiceId.value)
    if (res.success) {
      showSuccessNotification('Item removed from invoice.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to remove item.')
    }
  } finally {
    loading.value = false
  }
}

const unassignInventoryItem = async (row: CommerceInvoiceItemRow) => {
  if (!invoice.value) return
  const confirm = window.confirm('Unassign this inventory item and restock it?')
  if (!confirm) return

  loading.value = true
  try {
    const res = await commerceInvoiceService.unassignOrderItemInventory(invoiceId.value, row.id)
    if (res.success) {
      showSuccessNotification('Inventory item unassigned and restocked.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to unassign inventory item.')
    }
  } finally {
    loading.value = false
  }
}

const resetSearchDialogState = () => {
  searchMode.value = 'add'
  selectedOrderItem.value = null
  searchTerm.value = ''
  searchBy.value = 'name'
  searchResults.value = []
  addItemForms.value = {}
  addItemLoading.value = {}
}

const openSearchDialogForAdd = () => {
  resetSearchDialogState()
  searchMode.value = 'add'
  searchDialogOpen.value = true
}

const openSearchDialogForAssign = (row: CommerceInvoiceItemRow) => {
  resetSearchDialogState()
  searchMode.value = 'assign'
  selectedOrderItem.value = row
  searchBy.value = 'product_id'
  searchTerm.value = String(row.product_id || '')
  searchDialogOpen.value = true
  void searchInventoryItems()
}

const searchInventoryItems = async () => {
  if (!authStore.tenantId) return
  searchingInventory.value = true
  try {
    const filters: Record<string, unknown> = {}
    const trimmed = searchTerm.value.trim()

    if (searchMode.value === 'assign' && selectedOrderItem.value?.product_id) {
      filters.product_id = Number(selectedOrderItem.value.product_id)
    }

    if (trimmed) {
      if (searchBy.value === 'product_id') {
        const parsed = Number(trimmed)
        if (!Number.isFinite(parsed) || parsed <= 0) {
          showWarningDialog('Product ID must be a valid number.')
          searchResults.value = []
          return
        }
        filters.product_id = Math.floor(parsed)
      } else {
        filters[searchBy.value] = trimmed
      }
    }

    const res = await inventoryStore.fetchGlobalInventoryItems({
      filters,
      page: 1,
      page_size: 50,
      sortBy: 'source_id',
      sortOrder: 'asc',
    })

    if (res.success && res.data?.data) {
      searchResults.value = res.data.data
      searchResults.value.forEach((inv) => {
        addItemForms.value[inv.id] = {
          qty: Math.max(1, Number(selectedOrderItem.value?.quantity || 1)),
          sell: Number(selectedOrderItem.value?.sell_price_bdt || inv.cost || 0),
          recipient: Number(selectedOrderItem.value?.recipient_price_bdt || inv.cost || 0),
        }
        addItemLoading.value[inv.id] = false
      })
    } else {
      searchResults.value = []
    }
  } finally {
    searchingInventory.value = false
  }
}

const addInventoryItemToInvoice = async (inventoryItem: InventoryItemWithStock) => {
  if (!invoice.value) return
  if (!inventoryItem.product_id) {
    showWarningDialog('Selected inventory item is not linked to a product.')
    return
  }

  const form = addItemForms.value[inventoryItem.id]
  if (!form || form.qty <= 0) {
    showWarningDialog('Please enter a valid quantity.')
    return
  }
  if (form.sell < 0 || form.recipient < 0) {
    showWarningDialog('Sell and recipient prices must be zero or higher.')
    return
  }
  if (form.qty > Number(inventoryItem.quantities?.usable || 0)) {
    showWarningDialog('Quantity is greater than usable stock for this inventory item.')
    return
  }

  addItemLoading.value[inventoryItem.id] = true
  try {
    const res = await commerceInvoiceService.addCommerceInvoiceItem(invoiceId.value, invoice.value.order_id, {
      product_id: Number(inventoryItem.product_id),
      quantity: form.qty,
      cost_bdt: Number(inventoryItem.cost || 0),
      sell_price_bdt: form.sell,
      recipient_price_bdt: form.recipient,
      image_url: inventoryItem.image_url,
      inventory_item_id: inventoryItem.id,
    })

    if (res.success) {
      showSuccessNotification(`Added "${inventoryItem.name}" from inventory to invoice.`)
      await loadInvoiceDetails()
      searchDialogOpen.value = false
    } else {
      showWarningDialog(res.error || 'Failed to add inventory item.')
    }
  } finally {
    addItemLoading.value[inventoryItem.id] = false
  }
}

const assignInventoryItemToOrderItem = async (inventoryItem: InventoryItemWithStock) => {
  const row = selectedOrderItem.value
  if (!row) {
    showWarningDialog('Please choose an order item first.')
    return
  }

  const requiredQty = Math.max(1, Number(row.quantity || 1))
  if (requiredQty > Number(inventoryItem.quantities?.usable || 0)) {
    showWarningDialog('Not enough usable stock for this order item quantity.')
    return
  }

  addItemLoading.value[inventoryItem.id] = true
  try {
    const res = await commerceInvoiceService.updateOrderItemInventoryAssignment(
      invoiceId.value,
      Number(row.id),
      Number(inventoryItem.id),
    )

    if (res.success) {
      showSuccessNotification('Inventory item assigned and cost updated.')
      await loadInvoiceDetails()
      searchDialogOpen.value = false
      selectedOrderItem.value = null
    } else {
      showWarningDialog(res.error || 'Failed to assign inventory item.')
    }
  } finally {
    addItemLoading.value[inventoryItem.id] = false
  }
}

const onSelectInventoryItem = async (inventoryItem: InventoryItemWithStock) => {
  if (searchMode.value === 'assign') {
    await assignInventoryItemToOrderItem(inventoryItem)
    return
  }
  await addInventoryItemToInvoice(inventoryItem)
}

const formatAmount = (val: number) => Number(val || 0).toFixed(2)

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString()
}

const getFormValue = (inventoryItemId: number, key: 'qty' | 'sell' | 'recipient') => {
  if (!addItemForms.value[inventoryItemId]) {
    addItemForms.value[inventoryItemId] = { qty: 1, sell: 0, recipient: 0 }
  }
  return addItemForms.value[inventoryItemId][key]
}

const setFormValue = (
  inventoryItemId: number,
  key: 'qty' | 'sell' | 'recipient',
  val: string | number | null,
) => {
  if (!addItemForms.value[inventoryItemId]) {
    addItemForms.value[inventoryItemId] = { qty: 1, sell: 0, recipient: 0 }
  }
  addItemForms.value[inventoryItemId][key] = Number(val)
}

onMounted(() => {
  void loadInvoiceDetails()
})
</script>

<style scoped>
.commerce-invoice-details-page {
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

.empty-state-block {
  text-align: center;
  background: rgba(255, 255, 255, 0.7);
}

.border-all {
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.invoice-items-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
  font-weight: 600;
  color: #2c3e50;
}

.product-search-item {
  border-radius: 10px;
  transition: all 0.2s ease;
}

.product-search-item:hover {
  background-color: rgba(34, 56, 101, 0.02);
}

.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  color: #2c3e50 !important;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>

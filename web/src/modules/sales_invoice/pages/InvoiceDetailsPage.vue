<template>
  <q-page class="q-pa-md global-invoice-details-page">
    <PageInitialLoader v-if="loading" />

    <div v-else-if="error" class="text-center q-pa-xl text-negative">{{ error }}</div>

    <div v-else-if="invoice" class="q-gutter-y-md">
      <!-- Header Hero Card -->
      <q-card flat class="hero-surface floating-surface shadow-1 q-pa-sm q-px-md">
        <div class="row items-center justify-between wrap q-gutter-sm">
          <div>
            <div class="row items-center q-gutter-x-sm">
              <div class="text-h6 text-weight-bold text-black">{{ invoice.invoice_no }}</div>
              <q-chip
                dense
                square
                :color="invoice.invoice_status === 'posted' ? 'green-2' : invoice.invoice_status === 'voided' ? 'red-2' : 'orange-2'"
                :text-color="invoice.invoice_status === 'posted' ? 'green-10' : invoice.invoice_status === 'voided' ? 'red-10' : 'orange-10'"
                class="text-weight-bold text-uppercase"
              >
                {{ invoice.invoice_status }}
              </q-chip>
            </div>
            <div class="text-caption text-grey-8">
              Invoice #{{ invoice.id }} · {{ invoice.invoice_date }}
            </div>
          </div>
          
          <!-- Lifecycle Action Buttons -->
          <div class="row items-center q-gutter-sm">
            <q-btn
              v-if="showPreview"
              flat
              dense
              color="secondary"
              icon="o_visibility"
              class="pill-btn slim-btn"
              @click="openPreview"
            >
              <q-tooltip>Preview</q-tooltip>
            </q-btn>
            
            <q-btn
              v-if="invoice.invoice_status === 'draft'"
              color="positive"
              icon="send"
              label="Post Invoice"
              no-caps
              class="pill-btn slim-btn shadow-1"
              :loading="postingInvoice"
              @click="onPostInvoice"
            />
            
            <q-btn
              v-if="invoice.invoice_status === 'posted' && invoice.paid_amount === 0"
              color="negative"
              icon="cancel"
              label="Void Invoice"
              no-caps
              class="pill-btn slim-btn shadow-1"
              :loading="voidingInvoice"
              @click="onVoidInvoice"
            />

            <q-btn
              v-if="invoice.invoice_status === 'draft'"
              color="negative"
              outline
              icon="delete"
              label="Delete Draft"
              no-caps
              class="pill-btn slim-btn"
              :loading="deletingInvoice"
              @click="onDeleteInvoice"
            />

            <q-btn
              v-if="invoice.invoice_status === 'draft'"
              color="primary"
              icon="add"
              label="Add Stock"
              no-caps
              class="pill-btn slim-btn"
              @click="stockDialog = true"
            />
            
            <q-chip square dense class="status-chip text-weight-bold text-capitalize">
              {{ invoice.invoice_type }}
            </q-chip>
            <q-chip square dense class="status-chip text-weight-bold text-uppercase">
              {{ invoice.payment_status }}
            </q-chip>
          </div>
        </div>
      </q-card>

      <div class="row q-col-gutter-md">
        <!-- Lines Table -->
        <div class="col-12 col-md-8">
          <q-card flat class="floating-surface shadow-1">
            <q-card-section class="text-subtitle1 text-weight-bold">Items ({{ items.length }})</q-card-section>
            <q-separator />
            <q-card-section v-if="!items.length" class="text-grey-7 text-center q-pa-lg">
              No items yet. Add from global stock.
            </q-card-section>
            <q-markup-table v-else flat dense wrap-cells>
              <thead>
                <tr>
                  <th class="text-left">Product</th>
                  <th class="text-right">Qty</th>
                  <th class="text-right">Sell</th>
                  <th v-if="isDropship" class="text-right">Recipient</th>
                  <th class="text-right">Total</th>
                  <th v-if="invoice.invoice_status === 'draft'" style="width: 50px"></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in items" :key="row.id">
                  <td>{{ row.name_snapshot }}</td>
                  <td class="text-right">
                    <span>{{ row.quantity }}</span>
                    <div v-if="row.return_quantity > 0" class="text-caption text-orange text-weight-bold">
                      Returned: {{ row.return_quantity }}
                    </div>
                  </td>
                  <td class="text-right">{{ formatAmount(row.sell_price_amount) }}</td>
                  <td v-if="isDropship" class="text-right">
                    {{ formatAmount(row.recipient_price_amount ?? row.sell_price_amount) }}
                  </td>
                  <td class="text-right">{{ formatAmount(row.line_total_amount) }}</td>
                  <td v-if="invoice.invoice_status === 'draft'" class="text-right">
                    <q-btn
                      flat
                      round
                      dense
                      color="negative"
                      icon="delete"
                      size="sm"
                      @click="onRemoveItem(row.id)"
                    >
                      <q-tooltip>Remove Item</q-tooltip>
                    </q-btn>
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>
        </div>

        <!-- Sidebar Actions & Meta -->
        <div class="col-12 col-md-4 q-gutter-y-md">
          <!-- Billing Profile Details -->
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Billing Profile</div>
            <div class="text-body2 text-weight-medium">{{ invoice.billing_profiles?.name || '—' }}</div>
            <div v-if="invoice.billing_profiles?.email" class="text-caption">{{ invoice.billing_profiles.email }}</div>
            <div v-if="invoice.billing_profiles?.phone" class="text-caption">{{ invoice.billing_profiles.phone }}</div>
          </q-card>

          <!-- Recipient / Delivery Details -->
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Recipient Delivery</div>
            <div v-if="invoice.invoice_status === 'draft'" class="q-gutter-y-xs">
              <q-input v-model="form.recipient_name" label="Name *" dense outlined class="soft-input" @blur="onHeaderUpdate" />
              <q-input v-model="form.recipient_phone" label="Phone" dense outlined class="soft-input" @blur="onHeaderUpdate" />
              <q-input v-model="form.recipient_address" label="Address" type="textarea" rows="2" dense outlined class="soft-input" @blur="onHeaderUpdate" />
            </div>
            <div v-else>
              <div class="text-body2 text-weight-medium">{{ invoice.recipient_name || '—' }}</div>
              <div v-if="invoice.recipient_phone" class="text-caption">{{ invoice.recipient_phone }}</div>
              <div v-if="invoice.recipient_address" class="text-caption">{{ invoice.recipient_address }}</div>
            </div>
          </q-card>

          <!-- Editable Charges (Draft Only) -->
          <q-card v-if="showCharges" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Charges & Discounts</div>
            <div class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">Delivery Charge</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.shipping_charge"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">{{ formatAmount(invoice.shipping_charge) }}</div>
              </div>
            </div>
            <div class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">COD Charge</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.cod_charge"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">{{ formatAmount(invoice.cod_charge) }}</div>
              </div>
            </div>
            <div class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">Wrapping Charge</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.wrapping_charge"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">{{ formatAmount(invoice.wrapping_charge) }}</div>
              </div>
            </div>
            <div class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">Print Charge</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.print_charge"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">{{ formatAmount(invoice.print_charge) }}</div>
              </div>
            </div>
            <div class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium text-primary text-weight-bold">Discount</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.discount_amount"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">{{ formatAmount(invoice.discount_amount) }}</div>
              </div>
            </div>
          </q-card>

          <!-- Dropship Settlements (Payouts & Collections) -->
          <q-card v-if="isDropship" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Dropship Settlement</div>
            <div class="text-caption text-grey-8">Collection: {{ invoice.collection_source || 'recipient' }}</div>
            <div class="text-body2 q-mt-xs text-weight-medium">
              Middle-man payout: {{ formatAmount(invoice.middle_man_payout_amount ?? 0) }}
            </div>
            <div class="text-caption text-uppercase text-weight-bold" :class="invoice.middle_man_payout_status === 'paid' ? 'text-positive' : 'text-grey-7'">
              Payout status: {{ invoice.middle_man_payout_status || 'pending' }}
            </div>
            <div class="row q-gutter-sm q-mt-sm">
              <q-btn
                v-if="showPayments && invoice.invoice_status === 'posted' && invoice.due_amount > 0"
                class="col pill-btn slim-btn"
                color="primary"
                no-caps
                label="Record COD"
                @click="codDialog = true"
              />
              <q-btn
                v-if="showPayments && invoice.invoice_status === 'posted' && invoice.middle_man_payout_status !== 'paid' && (invoice.middle_man_payout_amount ?? 0) > 0"
                class="col pill-btn slim-btn"
                color="secondary"
                no-caps
                label="Payout"
                outline
                @click="payoutDialog = true"
              />
            </div>
          </q-card>

          <!-- Retail / Wholesale Payments -->
          <q-card v-if="showPayments && !isDropship && invoice.invoice_status === 'posted' && invoice.due_amount > 0" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Collections</div>
            <q-btn color="primary" no-caps class="pill-btn slim-btn" label="Record Payment" @click="paymentDialog = true" />
          </q-card>

          <!-- Totals Breakdown Card -->
          <q-card flat class="floating-surface shadow-1 q-pa-md q-gutter-y-xs">
            <div class="row justify-between text-body2"><span>Subtotal</span><span>{{ formatAmount(invoice.subtotal_amount) }}</span></div>
            <div v-if="isDropship" class="row justify-between text-caption text-grey-7">
              <span>Face subtotal</span><span>{{ formatAmount(invoice.face_subtotal_amount ?? 0) }}</span>
            </div>
            <q-separator class="q-my-xs" />
            <div class="row justify-between text-subtitle1 text-weight-bold text-primary"><span>Total</span><span>{{ formatAmount(invoice.total_amount) }}</span></div>
            <div class="row justify-between text-body2 text-grey-9"><span>Paid</span><span>{{ formatAmount(invoice.paid_amount) }}</span></div>
            <div class="row justify-between text-subtitle1 text-weight-bold">
              <span>Due</span>
              <span :class="invoice.due_amount > 0 ? 'text-negative' : 'text-positive'">{{ formatAmount(invoice.due_amount) }}</span>
            </div>
          </q-card>

          <!-- Returns Card -->
          <q-card v-if="showReturns && invoice.invoice_status === 'posted'" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Returns</div>
            <q-btn color="orange" no-caps outline class="pill-btn slim-btn" label="Add Return" @click="returnDialog = true" />
          </q-card>

          <!-- Note Area -->
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-xs">Invoice Note</div>
            <q-input
              v-if="invoice.invoice_status === 'draft'"
              v-model="form.note"
              type="textarea"
              rows="2"
              dense
              outlined
              class="soft-input"
              @blur="onHeaderUpdate"
            />
            <div v-else class="text-body2 text-grey-8">{{ invoice.note || '—' }}</div>
          </q-card>
        </div>
      </div>
    </div>

    <!-- Add From Stock Dialog -->
    <q-dialog v-model="stockDialog" persistent>
      <q-card style="min-width: 560px; max-width: 95vw; border-radius: 16px;" class="floating-surface q-pa-sm">
        <q-card-section class="text-h6 text-weight-bold">Add From Stock</q-card-section>
        <q-card-section class="q-pt-none">
          <NetworkStockSearchPanel
            v-if="invoice && stockDialog"
            mode="invoice"
            :context-tenant-id="invoice.tenant_id"
            selectable
            :show-search-controls="true"
            @select="onSelectStockRow"
          />
          <div v-if="selectedStock" class="q-mt-md q-gutter-y-sm">
            <div class="text-subtitle2 text-weight-bold">
              Selected: {{ selectedStock.name }}
              <span v-if="selectedStockHoldingLabel" class="text-caption text-grey-7 q-ml-sm">
                ({{ selectedStockHoldingLabel }})
              </span>
            </div>
            <q-input v-model.number="addQty" type="number" label="Quantity" dense outlined min="1" class="soft-input" />
            <q-input v-model.number="addSellPrice" type="number" label="Sell price" dense outlined min="0" class="soft-input" />
            <q-input
              v-if="isDropship"
              v-model.number="addRecipientPrice"
              type="number"
              label="Recipient price"
              dense
              outlined
              min="0"
              class="soft-input"
            />
          </div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn color="primary" label="Add" :loading="addingItem" :disable="!selectedStock" @click="onAddItem" class="pill-btn" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Record Payment Dialog -->
    <q-dialog v-model="paymentDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px;">
        <q-card-section class="text-h6 text-weight-bold">Record Payment</q-card-section>
        <q-card-section>
          <q-input v-model.number="paymentAmount" type="number" label="Amount" outlined dense min="0" class="soft-input" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn color="primary" label="Save" :loading="paymentSaving" @click="onRecordPayment" class="pill-btn" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Record COD Dialog -->
    <q-dialog v-model="codDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px;">
        <q-card-section class="text-h6 text-weight-bold">Record COD Collection</q-card-section>
        <q-card-section>
          <q-input v-model.number="codAmount" type="number" label="Amount collected" outlined dense min="0" class="soft-input" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn color="primary" label="Save" :loading="paymentSaving" @click="onRecordCod" class="pill-btn" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Pay Middle Man Dialog -->
    <q-dialog v-model="payoutDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px;">
        <q-card-section class="text-h6 text-weight-bold">Pay Middle Man</q-card-section>
        <q-card-section>
          <q-input v-model.number="payoutAmount" type="number" label="Payout amount" outlined dense min="0" class="soft-input" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn color="primary" label="Save" :loading="paymentSaving" @click="onRecordPayout" class="pill-btn" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Add Return Dialog -->
    <q-dialog v-model="returnDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 400px; border-radius: 16px;">
        <q-card-section class="text-h6 text-weight-bold">Add Return</q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <q-select
            v-model="returnItemId"
            :options="returnItemOptions"
            label="Invoice item"
            outlined
            dense
            emit-value
            map-options
            class="soft-input"
          />
          <q-input v-model.number="returnQty" type="number" label="Quantity" outlined dense min="0" class="soft-input" />
          <q-input v-model.number="returnFaceAmount" type="number" label="Customer Refund Amount (Face)" outlined dense min="0" class="soft-input" />
          <q-input v-model.number="returnAccountingAmount" type="number" label="Seller Deduction Amount (Accounting)" outlined dense min="0" class="soft-input" />
          <q-input v-model.number="returnCharge" type="number" label="Return charge (optional)" outlined dense min="0" class="soft-input" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn color="primary" label="Save" :loading="returnSaving" @click="onAddReturn" class="pill-btn" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch, reactive } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'

import { invoiceRepository } from '../repositories/invoiceRepository'
import NetworkStockSearchPanel from '../components/NetworkStockSearchPanel.vue'
import type { StockNetworkRow } from 'src/modules/global/types'
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from '../types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const loading = ref(true)
const error = ref<string | null>(null)
const invoice = ref<GlobalInvoiceDetail | null>(null)
const items = ref<GlobalInvoiceItemRow[]>([])

const stockDialog = ref(false)
const selectedStock = ref<StockNetworkRow | null>(null)
const addQty = ref(1)
const addSellPrice = ref(0)
const addRecipientPrice = ref(0)
const addingItem = ref(false)

const paymentDialog = ref(false)
const codDialog = ref(false)
const payoutDialog = ref(false)
const paymentAmount = ref(0)
const codAmount = ref(0)
const payoutAmount = ref(0)
const paymentSaving = ref(false)

const returnDialog = ref(false)
const returnItemId = ref<number | null>(null)
const returnQty = ref(1)
const returnFaceAmount = ref(0)
const returnAccountingAmount = ref(0)
const returnCharge = ref(0)
const returnSaving = ref(false)

const postingInvoice = ref(false)
const voidingInvoice = ref(false)
const deletingInvoice = ref(false)

const showPreview = true
const showPayments = true
const showReturns = true

// Reactive form representing currently saved values on header
const form = reactive({
  discount_amount: 0,
  shipping_charge: 0,
  cod_charge: 0,
  wrapping_charge: 0,
  print_charge: 0,
  recipient_name: '',
  recipient_phone: '',
  recipient_address: '',
  note: ''
})

const invoiceId = computed(() => Number(route.params.id))

const isDropship = computed(() => invoice.value?.invoice_type === 'dropship')
const isWholesale = computed(() => invoice.value?.invoice_type === 'wholesale')
const showCharges = computed(() => !isWholesale.value)

const returnItemOptions = computed(() =>
  items.value.map((row) => ({ label: row.name_snapshot, value: row.id })),
)

const formatAmount = (value: number) => formatAmountBdt(value)

const loadInvoice = async () => {
  loading.value = true
  error.value = null
  try {
    const [inv, invItems] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(invoiceId.value),
      invoiceRepository.listGlobalInvoiceItems(invoiceId.value),
    ])
    invoice.value = inv
    items.value = invItems

    // Sync form values
    form.discount_amount = inv.discount_amount
    form.shipping_charge = inv.shipping_charge
    form.cod_charge = inv.cod_charge
    form.wrapping_charge = inv.wrapping_charge
    form.print_charge = inv.print_charge
    form.recipient_name = inv.recipient_name || ''
    form.recipient_phone = inv.recipient_phone || ''
    form.recipient_address = inv.recipient_address || ''
    form.note = inv.note || ''
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load invoice.'
  } finally {
    loading.value = false
  }
}

const selectedStockHoldingLabel = computed(() => {
  if (!selectedStock.value) return ''
  if (selectedStock.value.is_own_tenant && selectedStock.value.allocated_qty === 0) {
    return 'Available via network'
  }
  return selectedStock.value.holding_tenant_name ?? ''
})

const onSelectStockRow = (row: StockNetworkRow) => {
  selectedStock.value = row
  addSellPrice.value = row.cost
  addRecipientPrice.value = row.cost
}

const onAddItem = async () => {
  if (!invoice.value || !selectedStock.value || addQty.value <= 0) return
  addingItem.value = true
  try {
    const payload = {
      invoice_id: invoice.value.id,
      global_stock_id: selectedStock.value.global_stock_id,
      quantity: addQty.value,
      sell_price_amount: addSellPrice.value || selectedStock.value.cost,
    }
    if (isDropship.value) {
      await invoiceRepository.addGlobalInvoiceItem({
        ...payload,
        recipient_price_amount: addRecipientPrice.value,
      })
    } else {
      await invoiceRepository.addGlobalInvoiceItem(payload)
    }
    stockDialog.value = false
    selectedStock.value = null
    await loadInvoice()
    showSuccessNotification('Item added.')
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to add item.')
  } finally {
    addingItem.value = false
  }
}

const onRemoveItem = async (itemId: number) => {
  if (!invoice.value) return
  try {
    await invoiceRepository.removeGlobalInvoiceItem(itemId)
    await loadInvoice()
    showSuccessNotification('Item removed from invoice.')
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to remove item.')
  }
}

const onHeaderUpdate = async () => {
  if (!invoice.value) return
  try {
    await invoiceRepository.updateGlobalInvoiceHeader({
      id: invoice.value.id,
      discount_amount: form.discount_amount,
      shipping_charge: form.shipping_charge,
      cod_charge: form.cod_charge,
      wrapping_charge: form.wrapping_charge,
      print_charge: form.print_charge,
      recipient_name: form.recipient_name.trim() || null,
      recipient_phone: form.recipient_phone.trim() || null,
      recipient_address: form.recipient_address.trim() || null,
      note: form.note.trim() || null
    })
    await loadInvoice()
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to update invoice details.')
  }
}

const onPostInvoice = async () => {
  if (!invoice.value) return
  postingInvoice.value = true
  try {
    await invoiceRepository.postGlobalInvoice(invoice.value.id)
    await loadInvoice()
    showSuccessNotification('Invoice posted successfully.')
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to post invoice.')
  } finally {
    postingInvoice.value = false
  }
}

const onVoidInvoice = async () => {
  if (!invoice.value) return
  voidingInvoice.value = true
  try {
    await invoiceRepository.voidGlobalInvoice(invoice.value.id)
    await loadInvoice()
    showSuccessNotification('Invoice voided successfully.')
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to void invoice.')
  } finally {
    voidingInvoice.value = false
  }
}

const onDeleteInvoice = async () => {
  if (!invoice.value) return
  deletingInvoice.value = true
  try {
    await invoiceRepository.deleteGlobalInvoice(invoice.value.id)
    showSuccessNotification('Draft invoice deleted successfully.')
    void router.push({
      name: 'app-global-invoices-page',
      params: { tenantSlug: authStore.tenantSlug }
    })
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to delete invoice.')
  } finally {
    deletingInvoice.value = false
  }
}

const openPreview = () => {
  void router.push({
    name: 'app-global-invoice-preview',
    params: { tenantSlug: authStore.tenantSlug, id: invoiceId.value },
  })
}

const onRecordPayment = async () => {
  if (!invoice.value?.billing_profile_id) return
  paymentSaving.value = true
  try {
    await invoiceRepository.recordBillingProfilePayment({
      tenant_id: invoice.value.tenant_id,
      billing_profile_id: invoice.value.billing_profile_id,
      amount: paymentAmount.value,
      allocations: [{ global_invoice_id: invoice.value.id, amount: paymentAmount.value }],
    })
    paymentDialog.value = false
    await loadInvoice()
    showSuccessNotification('Payment recorded.')
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Payment failed.')
  } finally {
    paymentSaving.value = false
  }
}

const onRecordCod = async () => {
  if (!invoice.value) return
  paymentSaving.value = true
  try {
    await invoiceRepository.recordRecipientInvoiceCollection(invoice.value.id, codAmount.value)
    codDialog.value = false
    await loadInvoice()
    showSuccessNotification('COD recorded.')
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'COD recording failed.')
  } finally {
    paymentSaving.value = false
  }
}

const onRecordPayout = async () => {
  if (!invoice.value?.billing_profile_id) return
  paymentSaving.value = true
  try {
    await invoiceRepository.createMiddleManPayout({
      tenant_id: invoice.value.tenant_id,
      billing_profile_id: invoice.value.billing_profile_id,
      global_invoice_id: invoice.value.id,
      amount: payoutAmount.value,
    })
    payoutDialog.value = false
    await loadInvoice()
    showSuccessNotification('Payout recorded.')
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Payout failed.')
  } finally {
    paymentSaving.value = false
  }
}

const onAddReturn = async () => {
  if (!invoice.value || !returnItemId.value) return
  returnSaving.value = true
  try {
    await invoiceRepository.addGlobalReturnItem({
      invoice_id: invoice.value.id,
      invoice_item_id: returnItemId.value,
      quantity: returnQty.value,
      return_face_amount: returnFaceAmount.value,
      return_accounting_amount: returnAccountingAmount.value,
      return_charge_amount: returnCharge.value || 0,
    })
    returnDialog.value = false
    await loadInvoice()
    showSuccessNotification('Return recorded.')
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Return failed.')
  } finally {
    returnSaving.value = false
  }
}

watch(stockDialog, (open) => {
  if (!open) {
    selectedStock.value = null
  }
})

watch(
  [returnItemId, returnQty],
  () => {
    if (!returnItemId.value) return
    const item = items.value.find((i) => i.id === returnItemId.value)
    if (item) {
      const qty = Number(returnQty.value || 0)
      const sellPrice = Number(item.sell_price_amount || 0)
      const recipientPrice = Number(item.recipient_price_amount || sellPrice)
      
      returnAccountingAmount.value = sellPrice * qty
      returnFaceAmount.value = recipientPrice * qty
    }
  }
)

onMounted(() => {
  void loadInvoice()
})
</script>

<style scoped>
.status-chip {
  border-radius: 6px !important;
}
.hero-surface {
  border-radius: 16px;
}
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
.pill-btn {
  border-radius: 999px;
}
.slim-btn {
  min-height: 32px;
  padding-left: 14px;
  padding-right: 14px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>

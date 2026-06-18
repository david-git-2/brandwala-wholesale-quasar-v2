<template>
  <q-page class="q-pa-md global-invoice-details-page">
    <PageInitialLoader v-if="loading" />

    <div v-else-if="error" class="text-center q-pa-xl text-negative">{{ error }}</div>

    <div v-else-if="invoice" class="q-gutter-y-sm">
      <q-card flat class="hero-surface floating-surface shadow-1 q-pa-sm q-px-md">
        <div class="row items-center justify-between wrap q-gutter-sm">
          <div>
            <div class="text-h6 text-weight-bold text-black">{{ invoice.invoice_no }}</div>
            <div class="text-caption text-grey-8">
              Invoice #{{ invoice.id }} · {{ invoice.invoice_date }}
            </div>
          </div>
          <div class="row items-center q-gutter-xs">
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
            <q-btn color="primary" icon="add" label="Add Stock" no-caps class="pill-btn slim-btn" @click="stockDialog = true" />
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
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in items" :key="row.id">
                  <td>{{ row.name_snapshot }}</td>
                  <td class="text-right">{{ row.quantity }}</td>
                  <td class="text-right">{{ formatAmount(row.sell_price_amount) }}</td>
                  <td v-if="isDropship" class="text-right">
                    {{ formatAmount(row.recipient_price_amount ?? row.sell_price_amount) }}
                  </td>
                  <td class="text-right">{{ formatAmount(row.line_total_amount) }}</td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>
        </div>

        <div class="col-12 col-md-4 q-gutter-y-md">
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Billing Profile</div>
            <div class="text-body2 text-weight-medium">{{ invoice.billing_profiles?.name || '—' }}</div>
            <div v-if="invoice.billing_profiles?.email" class="text-caption">{{ invoice.billing_profiles.email }}</div>
            <div v-if="invoice.billing_profiles?.phone" class="text-caption">{{ invoice.billing_profiles.phone }}</div>
          </q-card>

          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Recipient</div>
            <div class="text-body2">{{ invoice.recipient_name || '—' }}</div>
            <div v-if="invoice.recipient_phone" class="text-caption">{{ invoice.recipient_phone }}</div>
            <div v-if="invoice.recipient_address" class="text-caption">{{ invoice.recipient_address }}</div>
          </q-card>

          <q-card v-if="showCharges" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Charges</div>
            <div v-for="charge in chargeFields" :key="charge.type" class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">{{ charge.label }}</div>
              <div class="col">
                <q-input
                  :model-value="chargeAmount(charge.type)"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @update:model-value="(v) => onChargeUpdate(charge.type, Number(v ?? 0))"
                />
              </div>
            </div>
          </q-card>

          <q-card v-if="isDropship" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Dropship Settlement</div>
            <div class="text-caption">Collection: {{ invoice.collection_source || 'recipient' }}</div>
            <div class="text-body2 q-mt-xs">
              Middle-man payout: {{ formatAmount(invoice.middle_man_payout_amount ?? 0) }}
            </div>
            <div class="text-caption text-uppercase">{{ invoice.middle_man_payout_status || 'due' }}</div>
            <q-btn
              v-if="showPayments"
              class="q-mt-sm pill-btn slim-btn"
              color="primary"
              no-caps
              label="Record COD"
              @click="codDialog = true"
            />
            <q-btn
              v-if="showPayments"
              class="q-mt-sm pill-btn slim-btn"
              color="secondary"
              no-caps
              label="Pay Middle Man"
              outline
              @click="payoutDialog = true"
            />
          </q-card>

          <q-card v-if="showPayments && !isDropship" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Payments</div>
            <q-btn color="primary" no-caps class="pill-btn slim-btn" label="Record Payment" @click="paymentDialog = true" />
          </q-card>

          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="row justify-between"><span>Subtotal</span><span>{{ formatAmount(invoice.subtotal_amount) }}</span></div>
            <div v-if="isDropship" class="row justify-between text-caption text-grey-7">
              <span>Face subtotal</span><span>{{ formatAmount(invoice.face_subtotal_amount ?? 0) }}</span>
            </div>
            <div class="row justify-between q-mt-xs"><span>Total</span><span class="text-weight-bold text-primary">{{ formatAmount(invoice.total_amount) }}</span></div>
            <div class="row justify-between"><span>Paid</span><span>{{ formatAmount(invoice.paid_amount) }}</span></div>
            <div class="row justify-between"><span>Due</span><span class="text-negative text-weight-bold">{{ formatAmount(invoice.due_amount) }}</span></div>
          </q-card>

          <q-card v-if="showReturns" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Returns</div>
            <q-btn color="orange" no-caps outline class="pill-btn slim-btn" label="Add Return" @click="returnDialog = true" />
          </q-card>
        </div>
      </div>
    </div>

    <q-dialog v-model="stockDialog" persistent>
      <q-card style="min-width: 520px; max-width: 95vw" class="floating-surface q-pa-sm">
        <q-card-section class="text-h6 text-weight-bold">Add From Stock</q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <q-input v-model="stockSearch" label="Search stock" dense outlined clearable class="soft-input" />
          <q-list bordered separator style="max-height: 320px; overflow: auto">
            <q-item v-for="stock in stockResults" :key="stock.id" clickable @click="selectedStock = stock">
              <q-item-section>
                <q-item-label>{{ stock.name }}</q-item-label>
                <q-item-label caption>Qty: {{ stock.total_qty }} · Cost: {{ formatAmount(stock.cost) }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-icon v-if="selectedStock?.id === stock.id" name="check_circle" color="primary" />
              </q-item-section>
            </q-item>
          </q-list>
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
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Add" :loading="addingItem" @click="onAddItem" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="paymentDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px">
        <q-card-section class="text-h6">Record Payment</q-card-section>
        <q-card-section>
          <q-input v-model.number="paymentAmount" type="number" label="Amount" outlined dense min="0" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Save" :loading="paymentSaving" @click="onRecordPayment" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="codDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px">
        <q-card-section class="text-h6">Record COD Collection</q-card-section>
        <q-card-section>
          <q-input v-model.number="codAmount" type="number" label="Amount collected" outlined dense min="0" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Save" :loading="paymentSaving" @click="onRecordCod" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="payoutDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px">
        <q-card-section class="text-h6">Pay Middle Man</q-card-section>
        <q-card-section>
          <q-input v-model.number="payoutAmount" type="number" label="Payout amount" outlined dense min="0" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Save" :loading="paymentSaving" @click="onRecordPayout" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="returnDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 400px">
        <q-card-section class="text-h6">Add Return</q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <q-select
            v-model="returnItemId"
            :options="returnItemOptions"
            label="Invoice item"
            outlined
            dense
            emit-value
            map-options
          />
          <q-input v-model.number="returnQty" type="number" label="Quantity" outlined dense min="0" />
          <q-input v-model.number="returnCharge" type="number" label="Return charge (optional)" outlined dense min="0" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Save" :loading="returnSaving" @click="onAddReturn" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'

import { globalRepository } from '../repositories/globalRepository'
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow, GlobalStockRow, InvoiceChargeLineRow } from '../types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const loading = ref(true)
const error = ref<string | null>(null)
const invoice = ref<GlobalInvoiceDetail | null>(null)
const items = ref<GlobalInvoiceItemRow[]>([])
const charges = ref<InvoiceChargeLineRow[]>([])

const stockDialog = ref(false)
const stockSearch = ref('')
const stockResults = ref<GlobalStockRow[]>([])
const selectedStock = ref<GlobalStockRow | null>(null)
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
const returnCharge = ref(0)
const returnSaving = ref(false)

const showPreview = true
const showPayments = true
const showReturns = true

const invoiceId = computed(() => Number(route.params.id))

const isDropship = computed(() => invoice.value?.invoice_type === 'dropship')
const isWholesale = computed(() => invoice.value?.invoice_type === 'wholesale')
const showCharges = computed(() => !isWholesale.value)

const chargeFields = [
  { type: 'delivery', label: 'Delivery' },
  { type: 'cod', label: 'COD' },
  { type: 'print', label: 'Print' },
  { type: 'packing', label: 'Wrapping' },
] as const

const returnItemOptions = computed(() =>
  items.value.map((row) => ({ label: row.name_snapshot, value: row.id })),
)

const formatAmount = (value: number) => formatAmountBdt(value)

const chargeAmount = (type: string) => charges.value.find((c) => c.charge_type === type)?.amount ?? 0

const loadInvoice = async () => {
  loading.value = true
  error.value = null
  try {
    const [inv, invItems, invCharges] = await Promise.all([
      globalRepository.getGlobalInvoiceById(invoiceId.value),
      globalRepository.listGlobalInvoiceItems(invoiceId.value),
      globalRepository.listInvoiceChargeLines(invoiceId.value),
    ])
    invoice.value = inv
    items.value = invItems
    charges.value = invCharges
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load invoice.'
  } finally {
    loading.value = false
  }
}

const searchStock = async () => {
  if (!invoice.value) return
  const result = await globalRepository.listGlobalStockPage({
    tenant_id: invoice.value.parent_tenant_id,
    search: stockSearch.value,
    page_size: 30,
  })
  stockResults.value = result.data
}

const onAddItem = async () => {
  if (!invoice.value || !selectedStock.value || addQty.value <= 0) return
  addingItem.value = true
  try {
    await globalRepository.addGlobalInvoiceItem({
      invoice_id: invoice.value.id,
      global_stock_id: selectedStock.value.id,
      quantity: addQty.value,
      sell_price_amount: addSellPrice.value || selectedStock.value.cost,
      recipient_price_amount: isDropship.value ? addRecipientPrice.value : undefined,
    })
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

const onChargeUpdate = async (chargeType: string, amount: number) => {
  if (!invoice.value) return
  try {
    await globalRepository.upsertInvoiceChargeLine(invoice.value.id, chargeType, amount)
    await loadInvoice()
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to update charge.')
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
    await globalRepository.recordBillingProfilePayment({
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
    await globalRepository.recordRecipientInvoiceCollection(invoice.value.id, codAmount.value)
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
    await globalRepository.createMiddleManPayout({
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
    await globalRepository.addGlobalReturnItem({
      invoice_id: invoice.value.id,
      invoice_item_id: returnItemId.value,
      quantity: returnQty.value,
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
  if (open) void searchStock()
})

watch(stockSearch, () => {
  void searchStock()
})

onMounted(() => {
  void loadInvoice()
})
</script>

<style scoped>
.status-chip {
  border-radius: 6px !important;
}
</style>

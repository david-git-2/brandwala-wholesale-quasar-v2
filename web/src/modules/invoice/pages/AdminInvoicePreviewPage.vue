<template>
  <q-page class="invoice-preview-page q-pa-md">
    <div class="row q-col-gutter-md">
      <!-- Left Panel: Customization Panel (no-print) -->
      <div class="col-12 col-md-4 no-print">
        <q-card flat class="customizer-card q-pa-md floating-surface shadow-1">
          <div class="row items-center justify-between q-mb-md">
            <div class="text-subtitle1 text-weight-bold row items-center q-gutter-xs" :style="{ color: customizerBrandColor }">
              <q-icon name="tune" size="20px" :style="{ color: customizerBrandColor }" />
              <span>Customize Invoice</span>
            </div>
            <q-btn
              :style="{ backgroundColor: customizerBrandColor, color: '#fff' }"
              icon="print"
              label="Print Invoice"
              no-caps
              class="pill-btn shadow-1"
              @click="printInvoice"
            />
          </div>

          <q-separator class="q-mb-md" />

          <!-- Brand Selection & Details -->
          <div class="q-mb-md">
            <div class="text-caption text-weight-bold q-mb-xs" :style="{ color: customizerBrandColor }">Brand Information</div>
            <q-select
              v-model="selectedBrandId"
              :options="invoiceStore.brands"
              option-value="id"
              option-label="name"
              label="Select Pre-configured Brand"
              outlined
              dense
              clearable
              emit-value
              map-options
              stack-label
              class="soft-input q-mb-xs"
              @update:model-value="onBrandSelect"
            />
            <div class="row justify-end q-mb-xs">
              <router-link
                :to="{ name: 'app-invoice-brands-page', params: { tenantSlug: route.params.tenantSlug } }"
                target="_blank"
                class="text-caption text-weight-medium cursor-pointer"
                :style="{ color: customizerBrandColor, textDecoration: 'underline' }"
              >
                Add/Manage Brands
              </router-link>
            </div>
            <q-input
              v-model="brandName"
              label="Custom Brand Name"
              outlined
              dense
              stack-label
              class="soft-input q-mb-xs"
            />
            <q-input
              v-model="brandAddress"
              label="Custom Address"
              type="textarea"
              outlined
              dense
              stack-label
              rows="2"
              class="soft-input"
            />
          </div>

          <!-- Billing Info & Custom Client Details -->
          <div class="q-mb-md">
            <div class="text-caption text-weight-bold q-mb-xs" :style="{ color: customizerBrandColor }">Client Information</div>
            <q-input
              :model-value="originalClientName"
              label="Original Client Name"
              outlined
              dense
              stack-label
              readonly
              disable
              class="soft-input q-mb-xs"
            />
            <q-input
              v-model="customClientName"
              label="Customize Client Name (Override)"
              outlined
              dense
              stack-label
              class="soft-input q-mb-xs"
            />
            <q-input
              v-model="clientTr"
              label="Customize Client TR"
              outlined
              dense
              stack-label
              class="soft-input"
            />
          </div>

          <!-- Box Details -->
          <div class="q-mb-md">
            <div class="text-caption text-weight-bold q-mb-xs" :style="{ color: customizerBrandColor }">Box Details</div>
            <div class="row q-col-gutter-xs">
              <div class="col-12">
                <q-input
                  v-model.number="totalBoxes"
                  type="number"
                  label="Total Boxes Number"
                  outlined
                  dense
                  stack-label
                  class="soft-input q-mb-xs"
                />
              </div>
            </div>

            <!-- Add Box Weights -->
            <div class="bg-grey-2 q-pa-sm rounded-borders q-mt-sm border-light">
              <div class="text-caption text-weight-bold text-grey-9 q-mb-xs" :style="{ color: customizerBrandColor }">Manage Box Weights</div>
              <div class="row q-col-gutter-xs items-center">
                <div class="col-5">
                  <q-input
                    v-model="newBoxNumber"
                    label="Box #"
                    placeholder="e.g. 1"
                    outlined
                    dense
                    stack-label
                    bg-color="white"
                    class="soft-input"
                  />
                </div>
                <div class="col-5">
                  <q-input
                    v-model.number="newBoxWeight"
                    type="number"
                    label="Weight (kg)"
                    outlined
                    dense
                    stack-label
                    bg-color="white"
                    class="soft-input"
                  />
                </div>
                <div class="col-2 text-center">
                  <q-btn
                    :style="{ color: customizerBrandColor }"
                    icon="add"
                    dense
                    flat
                    round
                    @click="addBoxWeight"
                  >
                    <q-tooltip>Add Box</q-tooltip>
                  </q-btn>
                </div>
              </div>

              <!-- List of added boxes -->
              <div v-if="invoiceStore.boxes.length" class="q-mt-sm q-gutter-y-xs scroll" style="max-height: 120px;">
                <div
                  v-for="box in invoiceStore.boxes"
                  :key="box.id"
                  class="row items-center justify-between q-px-sm q-py-xs bg-white rounded-borders shadow-1 border-light"
                >
                  <div class="text-caption text-black">
                    Box <strong>{{ box.box_number }}</strong>: {{ box.weight }} kg
                  </div>
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="close"
                    size="xs"
                    @click="deleteBoxWeight(box.id)"
                  />
                </div>
              </div>
              <div v-else class="text-caption text-grey-6 text-center q-mt-xs">
                No individual box details added.
              </div>
            </div>
          </div>

          <!-- Billing Details -->
          <div class="q-mb-md">
            <div class="text-caption text-weight-bold q-mb-xs" :style="{ color: customizerBrandColor }">Billing Adjustments</div>
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model.number="deliveryCharge"
                  type="number"
                  label="Delivery Charge"
                  outlined
                  dense
                  stack-label
                  class="soft-input"
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model.number="advanceAmount"
                  type="number"
                  label="Advance Amount"
                  outlined
                  dense
                  stack-label
                  class="soft-input"
                />
              </div>
              <div class="col-12">
                <q-input
                  v-model.number="previousDue"
                  type="number"
                  label="Previous Due"
                  outlined
                  dense
                  stack-label
                  class="soft-input"
                />
              </div>
            </div>
          </div>

          <!-- Product Item Customization List -->
          <div class="q-mb-md">
            <div class="text-caption text-weight-bold q-mb-xs" :style="{ color: customizerBrandColor }">Item Customizations</div>
            <div class="q-gutter-y-xs scroll" style="max-height: 240px; border: 1px solid rgba(0,0,0,0.08); border-radius: 8px; padding: 6px;">
              <div
                v-for="item in localItems"
                :key="item.id"
                class="q-pa-xs rounded-borders bg-grey-1 border-light q-mb-xs"
              >
                <div class="text-caption text-weight-bold text-black ellipsis">{{ item.name_snapshot }}</div>
                <div class="row q-col-gutter-xs q-mt-xs">
                  <div class="col-6">
                    <q-input
                      v-model="item.unit"
                      label="Unit"
                      outlined
                      dense
                      stack-label
                      readonly
                      disable
                      class="soft-input dense-input"
                    />
                  </div>
                  <div class="col-6">
                    <q-input
                      v-model.number="item.sell_price_amount"
                      type="number"
                      label="Rate (BDT)"
                      outlined
                      dense
                      stack-label
                      readonly
                      disable
                      class="soft-input dense-input"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Message customize -->
          <div class="q-mb-md">
            <q-input
              v-model="thankYouMessage"
              label="Thank You Message"
              type="textarea"
              outlined
              dense
              stack-label
              rows="2"
              class="soft-input"
            />
          </div>

          <q-btn
            :style="{ backgroundColor: customizerBrandColor, color: '#fff' }"
            label="Save Changes"
            no-caps
            class="full-width pill-btn shadow-1 q-py-xs"
            :loading="savingChanges"
            @click="saveCustomizations"
          />
        </q-card>
      </div>

      <!-- Right Panel: Invoice Print layout -->
      <div class="col-12 col-md-8">
        <div class="invoice-sheet shadow-2">
          <!-- Invoice Header -->
          <div class="row justify-between items-start q-mb-sm">
            <!-- Brand Section -->
            <div class="col-7">
              <div class="text-subtitle1 text-weight-bold brand-title">{{ brandName || 'COMPANY BRAND' }}</div>
              <div class="text-caption text-grey-9 brand-address" style="white-space: pre-wrap; font-size: 11px; line-height: 1.25;">{{ brandAddress || 'Brand Address details...' }}</div>
            </div>

            <!-- Invoice meta info -->
            <div class="col-5 text-right" style="font-size: 11px; line-height: 1.25;">
              <div class="text-subtitle1 text-weight-bold text-green-accent q-mb-xs" style="line-height: 1.1;">INVOICE</div>
              <div class="text-black"><strong>Invoice No:</strong> {{ invoice?.invoice_no ?? '-' }}</div>
              <div class="text-grey-8"><strong>SL Code:</strong> {{ slCode }}</div>
              <div class="text-grey-8"><strong>Date:</strong> {{ invoice?.invoice_date ?? '-' }}</div>
              <div class="text-grey-8" v-if="invoice?.due_date"><strong>Due Date:</strong> {{ invoice?.due_date }}</div>
              <div class="text-grey-8" v-if="totalBoxes"><strong>Total Boxes:</strong> {{ totalBoxes }}</div>
            </div>
          </div>

          <!-- Billing Info (Name : TR and taking less space) -->
          <div class="billing-profile-box border-light q-pa-sm rounded-borders bg-grey-1 q-mb-xs">
            
            <div class="row items-center q-col-gutter-x-md wrap" style="font-size: 11px;">
              <div><strong>Name:</strong> <span class="text-weight-bold text-black">{{ customClientName || originalClientName || '-' }}</span></div>
              <template v-if="clientTr && clientTr !== '-'">
                <div class="text-grey-4">|</div>
                <div><strong>TR:</strong> <span class="text-weight-bold text-black">{{ clientTr }}</span></div>
              </template>
            </div>

            <div class="row items-center q-gutter-x-sm text-grey-7 q-mt-none wrap" style="font-size: 10px; line-height: 1.2; margin-top: 4px;">
              <span v-if="billingProfile?.phone">Phone: {{ billingProfile.phone }}</span>
              <span class="text-grey-4" v-if="billingProfile?.phone && (billingProfile?.email || billingProfile?.address)">|</span>
              <span v-if="billingProfile?.email">Email: {{ billingProfile.email }}</span>
              <span class="text-grey-4" v-if="billingProfile?.email && billingProfile?.address">|</span>
              <span v-if="billingProfile?.address">Address: {{ billingProfile.address }}</span>
            </div>
          </div>

          <!-- Box Weights Table (if present) -->
          <div v-if="invoiceStore.boxes.length" class="q-mb-xs">
            <div class="text-caption text-weight-bold text-green-accent q-mb-xs" style="font-size: 11px;">BOX WEIGHT DETAILS:</div>
            <div class="q-gutter-y-xs">
              <div
                v-for="box in invoiceStore.boxes"
                :key="box.id"
              >
                <q-badge color="grey-3" text-color="black" class="q-py-xs q-px-sm text-caption" style="font-size: 10px;">
                  Box #{{ box.box_number }}: <strong>{{ box.weight }} kg</strong>
                </q-badge>
              </div>
            </div>
          </div>

          <!-- Total Weight Section (in separate div) -->
          <div v-if="invoiceStore.boxes.length" class="q-mb-xs">
            <q-badge color="primary" text-color="white" class="q-py-xs q-px-sm text-caption brand-badge" style="font-size: 10px;">
              Total Weight: <strong>{{ totalBoxWeight }} kg</strong>
            </q-badge>
          </div>

          <!-- Items Table -->
          <q-markup-table flat wrap-cells class="invoice-items-print-table q-mb-sm">
            <thead>
              <tr class="table-header text-white">
                <th class="text-left" style="width: 50px">SL</th>
                <th v-if="showImages" class="text-left" style="width: 50px">Image</th>
                <th class="text-left">Product Name</th>
                <th class="text-right" style="width: 100px">Rate</th>
                <th class="text-right" style="width: 80px">Qty</th>
                <th class="text-left" style="width: 70px">Unit</th>
                <th class="text-right" style="width: 120px">Total Price</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!aggregatedPrintItems.length">
                <td :colspan="showImages ? 7 : 6" class="text-center text-grey-7">No invoice items.</td>
              </tr>
              <tr v-for="(row, index) in aggregatedPrintItems" :key="row.name_snapshot + '_' + row.sell_price_amount + '_' + row.unit">
                <td class="text-center">{{ index + 1 }}</td>
                <td v-if="showImages" class="text-center">
                  <q-avatar rounded size="0.5in" class="bg-grey-2 border-light">
                    <img
                      :src="invoiceItemImageMap[row.inventory_item_id ?? -1] ?? fallbackImageUrl"
                      alt="item image"
                      style="object-fit: contain;"
                    />
                  </q-avatar>
                </td>
                <td class="text-black text-weight-medium" style="word-break: break-word; white-space: normal;">
                  {{ row.name_snapshot }}
                </td>
                <td class="text-right text-mono">{{ formatMoney(row.sell_price_amount) }}</td>
                <td class="text-right text-mono">{{ row.quantity }}</td>
                <td class="text-left text-capitalize">{{ row.unit || 'pcs' }}</td>
                <td class="text-right text-weight-bold text-black text-mono">{{ formatMoney(row.quantity * row.sell_price_amount) }}</td>
              </tr>
            </tbody>
          </q-markup-table>

          <!-- Calculations Summary Box -->
          <div class="row justify-end q-mt-xs">
            <div class="col-12 col-sm-5 total-summary-box border-light q-pa-xs">
              <div class="row justify-between text-grey-9" style="font-size: 11px; padding: 2px 4px;">
                <div>Sub Total:</div>
                <div class="text-mono">{{ formatMoney(subTotal) }}</div>
              </div>
              <div class="row justify-between text-grey-9" style="font-size: 11px; padding: 2px 4px;" v-if="invoice?.discount_amount">
                <div>Discount:</div>
                <div class="text-mono">- {{ formatMoney(invoice.discount_amount) }}</div>
              </div>
              <div class="row justify-between text-grey-9" style="font-size: 11px; padding: 2px 4px;" v-if="deliveryCharge">
                <div>Delivery Charge:</div>
                <div class="text-mono">{{ formatMoney(deliveryCharge) }}</div>
              </div>
              <div class="row justify-between text-grey-9" style="font-size: 11px; padding: 2px 4px;" v-if="previousDue">
                <div>Previous Due:</div>
                <div class="text-mono">{{ formatMoney(previousDue) }}</div>
              </div>
              <q-separator class="q-my-none" />
              <div class="row justify-between text-weight-bold text-black" style="font-size: 11px; padding: 2px 4px;">
                <div>Grand Total:</div>
                <div class="text-mono">{{ formatMoney(grandTotalAmount) }}</div>
              </div>
              <div class="row justify-between text-grey-9" style="font-size: 11px; padding: 2px 4px;" v-if="advanceAmount">
                <div>Advance / Paid:</div>
                <div class="text-mono">- {{ formatMoney(advanceAmount) }}</div>
              </div>
              <q-separator class="q-my-none" />
              <div class="row justify-between text-weight-bold text-negative" style="font-size: 11px; padding: 2px 4px;">
                <div>Total Due:</div>
                <div class="text-mono">{{ formatMoney(totalDueAmount) }}</div>
              </div>
            </div>
          </div>

          <!-- Bottom signatures & message -->
          <div class="q-mt-xl text-center no-print">
            <q-checkbox v-model="showImages" dense label="Show Product Images in Print" />
          </div>

          <!-- Signatures Section -->
          <div class="row justify-between signature-section text-center">
            <div class="col-5">
              <div class="signature-line"></div>
              <div class="text-caption text-grey-9 text-weight-bold">Authenticator Signature</div>
            </div>
            <div class="col-5">
              <div class="signature-line"></div>
              <div class="text-caption text-grey-9 text-weight-bold">Client Signature</div>
            </div>
          </div>

          <!-- Thankyou Message -->
          <div class="q-mt-xl text-center text-weight-bold text-grey-7 brand-message">
            {{ thankYouMessage || 'Thank you for your business!' }}
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useInvoiceStore } from '../stores/invoiceStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useBillingProfileStore } from '../stores/billingProfileStore'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import { formatAmountBdt } from 'src/utils/currency'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'
import type { InvoiceItem } from '../types/index'

const route = useRoute()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const billingProfileStore = useBillingProfileStore()

const showImages = ref(false)
const invoiceItemImageMap = ref<Record<number, string>>({})
const fallbackImageUrl = 'https://placehold.co/56x56?text=No+Image'

const selectedBrandId = ref<number | null>(null)
const brandName = ref('')
const brandAddress = ref('')
const totalBoxes = ref<number | null>(null)
const deliveryCharge = ref(0)
const advanceAmount = ref(0)
const previousDue = ref(0)
const thankYouMessage = ref('Thank you for your business!')

// Customizable client properties
const customClientName = ref('')
const originalClientName = computed(() => billingProfile.value?.name || '')
const clientTr = ref('')

// Box details state
const newBoxNumber = ref('')
const newBoxWeight = ref<number | null>(null)

// Local invoice item edit list
const localItems = ref<Array<InvoiceItem & { name_snapshot: string }>>([])
const savingChanges = ref(false)

const invoiceId = computed(() => Number(route.params.invoiceId))
const invoice = computed(() => invoiceStore.invoices.find((row) => row.id === invoiceId.value) ?? null)

const billingProfile = computed(() => {
  if (!invoice.value?.billing_profile_id) return null
  return billingProfileStore.items.find((p) => p.id === invoice.value?.billing_profile_id) ?? null
})

const customizerBrandColor = computed(() => {
  return billingProfile.value?.color || '#1b4332'
})

const slCode = computed(() => {
  if (!invoice.value) return '-'
  const tenantId = invoice.value.tenant_id
  const invoiceIdVal = invoice.value.id
  const dateStr = invoice.value.invoice_date ? invoice.value.invoice_date.replace(/-/g, '') : ''
  return `${tenantId}-${invoiceIdVal}-${dateStr}`
})

const getReturnedQuantity = (row: { return_normal_quantity?: number; return_open_box_quantity?: number; return_damaged_quantity?: number }) =>
  Number(row.return_normal_quantity ?? 0) + Number(row.return_open_box_quantity ?? 0) + Number(row.return_damaged_quantity ?? 0)
const getNetQuantity = (row: { quantity: number; return_normal_quantity?: number; return_open_box_quantity?: number; return_damaged_quantity?: number }) =>
  Math.max(0, Number(row.quantity ?? 0) - getReturnedQuantity(row))

const subTotal = computed(() =>
  localItems.value.reduce((sum, item) => sum + (getNetQuantity(item) * item.sell_price_amount), 0)
)

const aggregatedPrintItems = computed(() => {
  const groups: Record<string, {
    id: number
    name_snapshot: string
    sell_price_amount: number
    unit: string
    quantity: number
    inventory_item_id: number | null
  }> = {}

  for (const item of localItems.value) {
    const name = item.name_snapshot || ''
    const rate = Number(item.sell_price_amount ?? 0)
    const unit = (item.unit || 'pcs').toLowerCase().trim()
    const key = `${name}_${rate}_${unit}`
    const netQty = getNetQuantity(item)

    if (groups[key]) {
      groups[key].quantity += netQty
    } else {
      groups[key] = {
        id: item.id,
        name_snapshot: name,
        sell_price_amount: rate,
        unit: item.unit || 'pcs',
        quantity: netQty,
        inventory_item_id: item.inventory_item_id,
      }
    }
  }

  return Object.values(groups)
})

const grandTotalAmount = computed(() => {
  const base = subTotal.value - Number(invoice.value?.discount_amount ?? 0)
  return Math.max(0, base + Number(deliveryCharge.value ?? 0) + Number(previousDue.value ?? 0))
})

const totalDueAmount = computed(() => {
  return Math.max(0, grandTotalAmount.value - Number(advanceAmount.value ?? 0))
})

const totalBoxWeight = computed(() => {
  return Number(invoiceStore.boxes.reduce((sum, b) => sum + Number(b.weight ?? 0), 0).toFixed(2))
})

const formatMoney = (val: number | null | undefined) => formatAmountBdt(val ?? 0)

const onBrandSelect = (brandId: number | null) => {
  if (!brandId) return
  const found = invoiceStore.brands.find((b) => b.id === brandId)
  if (found) {
    brandName.value = found.name
    brandAddress.value = found.address
  }
}

const addBoxWeight = async () => {
  if (!newBoxNumber.value.trim() || newBoxWeight.value === null || newBoxWeight.value < 0) {
    showWarningDialog('Please enter a box number and weight.')
    return
  }

  const res = await invoiceStore.createInvoiceBox({
    tenant_id: authStore.tenantId ?? 0,
    invoice_id: invoiceId.value,
    box_number: newBoxNumber.value.trim(),
    weight: newBoxWeight.value,
  })

  if (res.success) {
    newBoxNumber.value = ''
    newBoxWeight.value = null
  }
}

const deleteBoxWeight = async (boxId: number) => {
  await invoiceStore.deleteInvoiceBox({ id: boxId })
}

const saveCustomizations = async () => {
  if (!invoice.value) return
  savingChanges.value = true
  try {
    const isDraftOrInvoicing = invoice.value.status === 'draft' || invoice.value.status === 'invoicing'
    // 1. Update invoice columns
    const res = await invoiceStore.updateInvoice({
      id: invoiceId.value,
      patch: {
        brand_name: brandName.value.trim() || null,
        brand_address: brandAddress.value.trim() || null,
        total_boxes: totalBoxes.value,
        delivery_charge: Number(deliveryCharge.value ?? 0),
        advance_amount: Number(advanceAmount.value ?? 0),
        previous_due: Number(previousDue.value ?? 0),
        thank_you_message: thankYouMessage.value.trim() || null,
        client_name: customClientName.value.trim() || null,
        client_tr: clientTr.value.trim() || null,
        status: isDraftOrInvoicing ? 'issued' : invoice.value.status,
      },
    })

    if (!res.success) {
      savingChanges.value = false
      return
    }

    // 2. Update line item rate/unit modifications
    for (const item of localItems.value) {
      await invoiceStore.updateInvoiceItem({
        id: item.id,
        patch: {
          unit: item.unit.trim() || 'pcs',
          sell_price_amount: Number(item.sell_price_amount ?? 0),
        },
      })
    }

    showSuccessNotification('Invoice customized and saved.')
  } catch (error) {
    console.error('Error saving customizations:', error)
  } finally {
    savingChanges.value = false
  }
}

const printInvoice = () => window.print()

const load = async () => {
  if (!authStore.tenantId || !Number.isFinite(invoiceId.value)) return

  await Promise.all([
    invoiceStore.fetchInvoiceById(invoiceId.value),
    invoiceStore.fetchInvoiceItems({
      tenant_id: authStore.tenantId,
      filters: { invoice_id: invoiceId.value },
      operators: { invoice_id: 'eq' },
      page: 1,
      page_size: 500,
      sortBy: 'created_at',
      sortOrder: 'asc',
    }),
    invoiceStore.fetchInvoiceBrands(),
    invoiceStore.fetchInvoiceBoxes({ invoice_id: invoiceId.value }),
    billingProfileStore.fetchBillingProfiles({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 100,
    }),
  ])

  // Populate local fields from invoice record
  if (invoice.value) {
    brandName.value = invoice.value.brand_name || ''
    brandAddress.value = invoice.value.brand_address || ''
    totalBoxes.value = invoice.value.total_boxes
    deliveryCharge.value = Number(invoice.value.delivery_charge ?? 0)
    advanceAmount.value = Number(invoice.value.advance_amount ?? 0)
    previousDue.value = Number(invoice.value.previous_due ?? 0)
    thankYouMessage.value = invoice.value.thank_you_message || 'Thank you for your business!'
    customClientName.value = invoice.value.client_name || ''
    clientTr.value = invoice.value.client_tr || ''

    // Fallback populated brand selection matches
    const matchedBrand = invoiceStore.brands.find((b) => b.name === invoice.value?.brand_name)
    if (matchedBrand) selectedBrandId.value = matchedBrand.id
  }

  // Populate local line items for editing
  localItems.value = invoiceStore.invoiceItems.map((item) => ({
    ...item,
    unit: item.unit || 'pcs',
    sell_price_amount: Number(item.sell_price_amount ?? 0),
  }))

  await loadInvoiceItemImages()
}

const loadInvoiceItemImages = async () => {
  const ids: number[] = Array.from(
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

  const res = await inventoryService.getInventoryItemImages(ids)
  if (res.success && res.data) {
    invoiceItemImageMap.value = Object.fromEntries(
      res.data.map((item) => [item.id, item.image_url ?? fallbackImageUrl]),
    )
  } else {
    invoiceItemImageMap.value = Object.fromEntries(
      ids.map((id) => [id, fallbackImageUrl]),
    )
  }
}

onMounted(() => {
  void load()
})
</script>

<style scoped>
.invoice-preview-page {
  background: #f4f6f9;
  min-height: 100vh;
}

.customizer-card {
  position: sticky;
  top: 16px;
  max-height: calc(100vh - 32px);
  overflow-y: auto;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.9);
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.08);
}

.soft-input :deep(.q-field__control) {
  border-radius: 8px;
  background: #ffffff;
}

.dense-input :deep(.q-field__control) {
  height: 36px;
  min-height: 36px;
}

.dense-input :deep(.q-field__marginal) {
  height: 36px;
}

.dense-input :deep(.q-field__native) {
  padding-top: 10px !important;
  padding-bottom: 0 !important;
  font-size: 11px !important;
}

.dense-input :deep(.q-field__label) {
  font-size: 12px !important;
  transform: translateY(-35%) scale(0.8) !important;
}

.invoice-sheet {
  width: 210mm;
  min-height: 297mm;
  max-width: 100%;
  margin: 0 auto;
  background: #ffffff;
  padding: 10mm;
  box-sizing: border-box;
  color: #1b4332;
  font-family: 'Inter', 'Outfit', sans-serif;
  border-radius: 8px;
}

.brand-title {
  color: #1b4332;
  line-height: 1.1;
  margin-bottom: 4px;
}

.brand-address {
  line-height: 1.25;
  color: #2b3a32;
}

.billing-profile-box {
  margin-top: 10px;
}

.invoice-items-print-table {
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 8px;
  overflow: hidden;
}

.invoice-items-print-table :deep(th) {
  font-weight: 700;
  font-size: 11px;
  background: #1b4332 !important;
  color: #ffffff !important;
  padding: 4px 6px !important;
}

.invoice-items-print-table :deep(td) {
  font-size: 11px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
  padding: 4px 6px !important;
}

.total-summary-box {
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 8px;
  background: #fbfbfc;
}

.signature-section {
  margin-top: 30px;
}

.signature-line {
  border-bottom: 1px dashed #1b4332;
  width: 60%;
  margin: 0 auto 6px auto;
}

.border-light {
  border: 1px solid rgba(0, 0, 0, 0.08);
}

.rounded-borders {
  border-radius: 8px;
}

.pill-btn {
  border-radius: 99px;
}

.slim-btn {
  min-height: 32px;
}

.text-green-accent {
  color: #1b4332 !important;
}

.brand-badge {
  background: #1b4332 !important;
}

@media print {
  @page {
    size: A4;
    margin: 10mm;
  }

  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  .no-print {
    display: none !important;
  }

  .invoice-preview-page {
    background: transparent !important;
    padding: 0 !important;
  }

  .invoice-sheet {
    box-shadow: none !important;
    border: none !important;
    margin: 0 !important;
    padding: 0 !important;
    width: 100% !important;
    min-height: auto !important;
  }

  .invoice-items-print-table :deep(th) {
    background: #1b4332 !important;
    color: #ffffff !important;
  }
}
</style>

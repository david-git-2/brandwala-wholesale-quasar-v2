<template>
  <q-page class="q-pa-md costing-details-page" style="background: transparent;">
    <PageInitialLoader v-if="initialLoading" />
    <template v-else>
      <div
        class="row items-center justify-between q-mb-md hero-surface floating-surface shadow-1 q-pa-sm q-px-md"
        :style="headerStyle"
      >
      <div>
        <div class="text-h6 text-weight-bold text-black">Invoice Details</div>
        <div v-if="invoice" class="text-caption text-grey-8 row items-center q-gutter-x-sm wrap">
          <span>Invoice Name: <span class="text-black text-weight-medium">{{ invoice.invoice_no }}</span></span>
          <q-chip
            v-if="customerGroup"
            dense
            size="xs"
            class="text-weight-bold"
            :style="{
              backgroundColor: customerGroup.accent_color || '#B45F34',
              color: getContrastYIQ(customerGroup.accent_color || '#B45F34')
            }"
          >
            {{ customerGroup.name }}
          </q-chip>
        </div>
      </div>
      <div v-if="invoice" class="row items-center q-gutter-sm">
        <!-- Status Chip Selector (Costing style) -->
        <q-chip
          dense
          square
          clickable
          :style="statusChipStyle(invoice.status)"
          class="costing-file-status-chip q-px-md q-py-sm"
        >
          <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(invoice.status) }" />
          <span class="text-capitalize text-weight-bold">{{ invoice.status.replace('_', ' ') }}</span>
          <q-menu>
            <q-list dense style="min-width: 150px">
              <q-item
                v-for="option in statusOptions"
                :key="option.value"
                clickable
                v-close-popup
                @click="onUpdateStatus(option.value)"
              >
                <q-item-section class="text-capitalize">{{ option.label }}</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-chip>

        <!-- Issue Invoice CTA Button -->
        <q-btn
          v-if="invoice?.status === 'draft' || invoice?.status === 'invoicing'"
          color="accent"
          no-caps
          label="Issue Invoice"
          class="slim-btn shadow-1 q-px-sm"
          style="border-radius: 4px !important;"
          @click="onUpdateStatus('issued')"
        >
          <q-tooltip>Mark status as Issued</q-tooltip>
        </q-btn>

        <!-- Preview Button -->
        <q-btn
          v-if="invoice?.status !== 'draft'"
          flat
          round
          dense
          color="secondary"
          icon="o_visibility"
          @click="openInvoicePreview"
        >
          <q-tooltip>Preview Invoice</q-tooltip>
        </q-btn>

        <!-- Search Stock Button -->
        <q-btn
          flat
          round
          dense
          color="primary"
          icon="o_search"
          @click="searchDialogOpen = true"
        >
          <q-tooltip>Search Stock</q-tooltip>
        </q-btn>

        <!-- Customer Payment Button -->
        <q-btn
          flat
          round
          dense
          color="secondary"
          icon="o_payments"
          :disable="!invoice?.billing_profile_id"
          @click="openCustomerPaymentDetails"
        >
          <q-tooltip>Customer Payment</q-tooltip>
        </q-btn>
      </div>
    </div>

    <div v-if="invoice" class="q-gutter-y-sm">
        <!-- Metric summaries row 1 -->
        <div class="row q-col-gutter-sm">
          <div class="col-12 col-sm-3">
            <q-card flat class="floating-surface shadow-1">
              <q-card-section class="q-pa-sm text-center">
                <div class="text-caption text-grey-8 text-weight-medium">Total Sell</div>
                <div class="text-subtitle1 text-weight-bolder text-black">{{ formatAmount(totalSellAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-3">
            <q-card flat class="floating-surface shadow-1">
              <q-card-section class="q-pa-sm text-center">
                <div class="text-caption text-grey-8 text-weight-medium">Total Cost</div>
                <div class="text-subtitle1 text-weight-bolder text-black">{{ formatAmount(totalCostAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-3">
            <q-card flat class="floating-surface shadow-1">
              <q-card-section class="q-pa-sm text-center">
                <div class="text-caption text-grey-8 text-weight-medium">Total Profit</div>
                <div class="text-subtitle1 text-weight-bolder text-positive">{{ formatAmount(totalProfitAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-3">
            <q-card flat class="floating-surface shadow-1">
              <q-card-section class="q-pa-sm text-center">
                <div class="text-caption text-grey-8 text-weight-medium">Paid Amount</div>
                <div class="text-subtitle1 text-weight-bolder text-primary">{{ formatAmount(Number(invoice?.paid_amount ?? 0)) }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Metric summaries row 2 -->
        <div class="row q-col-gutter-sm">
          <div class="col-12 col-sm-4">
            <q-card flat class="floating-surface shadow-1">
              <q-card-section class="q-pa-sm text-center">
                <div class="text-caption text-grey-8 text-weight-medium">Total Returned</div>
                <div class="text-subtitle1 text-weight-bolder text-warning">{{ formatAmount(totalReturnedAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat class="floating-surface shadow-1">
              <q-card-section class="q-pa-sm text-center">
                <div class="text-caption text-grey-8 text-weight-medium">Discount (Click to edit)</div>
                <div class="text-subtitle1 text-weight-bolder text-orange-9 cursor-pointer">
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
            <q-card flat class="floating-surface shadow-1">
              <q-card-section class="q-pa-sm text-center">
                <div class="text-caption text-grey-8 text-weight-medium">Outstanding Amount</div>
                <div class="text-subtitle1 text-weight-bolder text-negative">{{ formatAmount(outstandingAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Invoice Item list table -->
        <div class="q-mb-md">
          <div class="text-subtitle1 text-weight-bold text-black q-mb-sm">Invoice Item List</div>
          <div v-if="!invoiceStore.invoiceItems.length && !invoiceStore.loading" class="text-grey-8 floating-surface shadow-1 q-pa-md text-center">
            No invoice items added yet. Use the "Search Stock" button to add items.
          </div>
          <q-card v-else flat class="floating-surface shadow-1 q-pa-xs">
            <q-markup-table flat wrap-cells class="invoice-items-table">
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
                    <q-avatar rounded size="48px" class="bg-grey-2 shadow-1">
                      <img
                        :src="invoiceItemImageMap[row.inventory_item_id ?? -1] ?? fallbackImageUrl"
                        alt="item image"
                        class="invoice-image"
                        style="object-fit: contain;"
                      />
                    </q-avatar>
                  </td>
                  <td style="white-space: normal; word-break: break-word; min-width: 260px;" class="text-black text-weight-medium">
                    {{ row.name_snapshot }}
                  </td>
                  <td class="text-right text-black">{{ formatAmountBdt(row.cost_amount) }}</td>
                  <td class="text-right">
                    <span class="cursor-pointer text-primary text-weight-medium">{{ formatAmountBdt(row.sell_price_amount) }}</span>
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
                    <span class="cursor-pointer text-primary text-weight-medium">{{ row.quantity }}</span>
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
                  <td class="text-right text-black">{{ formatQuantity(getReturnedQuantity(row)) }}</td>
                  <td class="text-right text-black">{{ formatAmount(Number(row.return_amount ?? 0)) }}</td>
                  <td class="text-right text-black text-weight-bold">{{ formatAmount(getNetSellAmount(row)) }}</td>
                  <td class="text-right">
                    <q-btn
                      flat
                      round
                      dense
                      icon="o_assignment_return"
                      color="warning"
                      @click="openReturnDialog(row.id)"
                    >
                      <q-tooltip>Return</q-tooltip>
                    </q-btn>
                    <q-btn
                      flat
                      round
                      dense
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
          </q-card>
        </div>
    </div>
    <div v-else class="text-body1 text-grey-8">
        Invoice not found.
    </div>

    <q-dialog v-model="searchDialogOpen" backdrop-filter="blur(4px)">
      <q-card style="width: 1000px; max-width: 95vw; max-height: 85vh" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-py-sm">
          <div class="row items-center q-gutter-sm">
            <q-icon name="inventory_2" size="24px" color="primary" />
            <div class="text-h6 text-weight-bold text-black">Search Stock</div>
          </div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />

        <q-card-section class="scroll q-pt-md" style="max-height: calc(85vh - 80px)">
          <!-- Search Toolbar -->
          <div class="row items-center q-col-gutter-sm q-mb-md">
            <div class="col-12 col-sm-3">
              <q-select
                v-model="searchBy"
                :options="searchByOptions"
                label="Search By"
                outlined
                dense
                options-dense
                emit-value
                map-options
                option-value="value"
                option-label="label"
                class="soft-input"
              />
            </div>
            <div class="col-12 col-sm-9 row no-wrap items-center q-gutter-xs">
              <q-input
                v-model="searchTerm"
                placeholder="Type to search stock batch..."
                outlined
                dense
                autofocus
                class="col soft-input"
                :loading="searchLoading"
                @keyup.enter="onSearchStock"
                @update:model-value="onSearchInput"
              >
                <template #prepend>
                  <q-icon name="o_search" />
                </template>
                <template #append v-if="searchTerm">
                  <q-btn flat round dense icon="o_close" size="xs" @click="searchTerm = ''; searchResults = []" />
                </template>
              </q-input>
              <q-btn
                color="primary"
                no-caps
                label="Search"
                class="pill-btn slim-btn shadow-1"
                :loading="searchLoading"
                @click="onSearchStock"
              />
            </div>
          </div>

          <div v-if="!sortedSearchItemsGrouped.length && !searchLoading" class="text-center text-grey-7 q-py-xl">
            <q-icon name="o_inventory" size="48px" color="grey-4" class="q-mb-sm" />
            <div class="text-weight-medium">No stock items found.</div>
            <div class="text-caption text-grey-6">Try searching with a different term or field option.</div>
          </div>

          <div v-else class="q-gutter-y-md">
            <q-card
              v-for="group in sortedSearchItemsGrouped"
              :key="group.key"
              flat
              class="floating-surface shadow-1 border-light"
            >
              <q-card-section class="q-pa-md">
                <!-- Product details header -->
                <div class="row items-center no-wrap q-mb-md">
                  <q-avatar rounded size="64px" class="q-mr-md bg-grey-2 shadow-1">
                    <img
                      :src="group.image_url || fallbackImageUrl"
                      alt="product image"
                      class="invoice-image"
                    />
                  </q-avatar>
                  <div class="col">
                    <div class="text-subtitle1 text-weight-bold text-black row items-center wrap">
                      <span>{{ group.name }}</span>
                      <q-badge color="purple" outline class="q-ml-sm" v-if="group.tenant_name">
                        {{ group.tenant_name }}
                      </q-badge>
                      <q-badge outline color="primary" class="q-ml-sm" v-if="group.shipment?.shipment?.id">
                        Shipment #{{ group.shipment.shipment.id }}
                      </q-badge>
                    </div>
                    <div class="row items-center q-gutter-x-md text-caption text-grey-7 q-mt-xs">
                      <span v-if="group.product_code">Code: <strong class="text-black">{{ group.product_code }}</strong></span>
                      <span v-if="group.barcode">Barcode: <strong class="text-black">{{ group.barcode }}</strong></span>
                      <span v-if="group.product_id">Product ID: <strong class="text-black">{{ group.product_id }}</strong></span>
                    </div>
                  </div>
                </div>

                <!-- Subtype batched inventory options -->
                <div class="q-gutter-y-xs">
                  <div
                    v-for="subtype in (['standard', 'boxless', 'box_damage', 'expired'] as const)"
                    :key="subtype"
                    v-show="getSubtypeItem(group, subtype) && getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype) > 0"
                    class="row items-center justify-between q-py-sm border-top"
                  >
                    <!-- Subtype label, cost and stock badges -->
                    <div class="col-12 col-sm-4 text-subtitle2 text-grey-9 row items-center q-gutter-xs">
                      <q-icon
                        :name="getSubtypeIcon(subtype)"
                        :color="getSubtypeIconColor(subtype)"
                        size="18px"
                      />
                      <span class="text-weight-bold text-black">{{ getSubtypeLabel(subtype) }}</span>
                      <div class="q-ml-sm row items-center q-gutter-xs">
                        <q-badge color="green-2" text-color="green-10" dense>
                          Stock: {{ getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype) }}
                        </q-badge>
                        <q-badge color="grey-3" text-color="grey-9" dense>
                          Cost: {{ getSubtypeItem(group, subtype)?.cost ?? 0 }} BDT
                        </q-badge>
                      </div>
                    </div>

                    <!-- Quantity counter with +/- buttons, Sell Price, and action button -->
                    <div class="col-12 col-sm-8 row items-center justify-end q-gutter-sm q-mt-xs-sm q-mt-sm-none">
                      <!-- Quantity selector with +/- buttons -->
                      <q-input
                        :model-value="getAddQuantity(getSubtypeItem(group, subtype)?.id ?? -1)"
                        type="number"
                        label="Quantity"
                        dense
                        outlined
                        class="soft-input text-center"
                        style="width: 140px"
                        min="1"
                        :max="getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype)"
                        lazy-rules
                        :rules="[
                          (value: string | number | null) => Number(value ?? 0) > 0 || 'Required',
                          (value: string | number | null) => Number(value ?? 0) <= getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype) || 'Exceeds stock',
                        ]"
                        @update:model-value="(value) => setAddQuantity(getSubtypeItem(group, subtype)?.id ?? -1, value)"
                      >
                        <template #prepend>
                          <q-btn
                            flat
                            round
                            dense
                            icon="remove"
                            size="sm"
                            class="q-mr-xs"
                            @click="decrementQty(getSubtypeItem(group, subtype)?.id ?? -1)"
                          />
                        </template>
                        <template #append>
                          <q-btn
                            flat
                            round
                            dense
                            icon="add"
                            size="sm"
                            class="q-ml-xs"
                            @click="incrementQty(getSubtypeItem(group, subtype)?.id ?? -1, getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype))"
                          />
                        </template>
                      </q-input>

                      <!-- Sell Price input (defaults to cost) -->
                      <q-input
                        :model-value="getSellPrice(getSubtypeItem(group, subtype)?.id ?? -1)"
                        type="number"
                        dense
                        outlined
                        min="0"
                        label="Sell Price (BDT)"
                        class="soft-input"
                        style="width: 130px"
                        lazy-rules
                        :rules="[
                          (value: string | number | null) =>
                            value !== null && value !== '' && Number(value) >= 0 || 'Required',
                        ]"
                        @update:model-value="(value) => setSellPrice(getSubtypeItem(group, subtype)?.id ?? -1, value)"
                      />

                      <!-- Action Button -->
                      <q-btn
                        color="primary"
                        no-caps
                        label="Add To Invoice"
                        icon="add"
                        class="pill-btn slim-btn shadow-1"
                        :loading="Boolean(addLoadingByItemId[getSubtypeItem(group, subtype)?.id ?? -1])"
                        :disable="!invoice"
                        @click="addItemToInvoice(getSubtypeItem(group, subtype)?.id ?? -1)"
                      />
                    </div>
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
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'
import { useRoute, useRouter } from 'vue-router'
import { accountingService } from 'src/modules/accounting/services/accountingService'
import type { InventoryAccountingEntry } from 'src/modules/accounting/types'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import { useInventoryStore } from 'src/modules/inventory/stores/inventoryStore'
import { showWarningDialog } from 'src/utils/appFeedback'
import { useInvoiceStore } from '../stores/invoiceStore'
import { useBillingProfileStore } from '../stores/billingProfileStore'
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore'
import type { InvoiceStatus } from '../types/index'
import { formatAmountBdt } from 'src/utils/currency'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const inventoryStore = useInventoryStore()
const billingProfileStore = useBillingProfileStore()
const customerGroupStore = useCustomerGroupStore()
const initialLoading = ref(false)
const searchDialogOpen = ref(false)
const searchLoading = ref(false)
const searchResults = ref<InventoryItemWithStock[]>([])
let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null
const addLoadingByItemId = ref<Record<number, boolean>>({})
const addQuantityByItemId = ref<Record<number, number | null>>({})
const sellPriceByItemId = ref<Record<number, number | null>>({})
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
  { label: 'Invoicing', value: 'invoicing' },
  { label: 'Issued', value: 'issued' },
  { label: 'Partially Paid', value: 'partially_paid' },
  { label: 'Paid', value: 'paid' },
  { label: 'Overdue', value: 'overdue' },
  { label: 'Cancelled', value: 'cancelled' },
]

const statusChipStyle = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase()
  if (value === 'draft') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
    }
  }
  if (value === 'invoicing') {
    return {
      backgroundColor: '#e1bee7',
      color: '#4a148c',
      border: '1px solid #ce93d8',
    }
  }
  if (value === 'issued') {
    return {
      backgroundColor: '#d7e7f6',
      color: '#1a4562',
      border: '1px solid #9ebfdc',
    }
  }
  if (value === 'partially_paid') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
    }
  }
  if (value === 'paid') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    }
  }
  if (value === 'overdue') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f5f5f5',
      color: '#616161',
      border: '1px solid #e0e0e0',
    }
  }
  return {
    backgroundColor: '#dbe5f3',
    color: '#3b4b66',
    border: '1px solid #b9c8dd',
  }
}

const statusDotColor = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase()
  if (value === 'draft') return '#9a6a24'
  if (value === 'invoicing') return '#8e24aa'
  if (value === 'issued') return '#2f6e92'
  if (value === 'partially_paid') return '#3f51b5'
  if (value === 'paid') return '#2f8b5d'
  if (value === 'overdue') return '#a64c62'
  if (value === 'cancelled') return '#757575'
  return '#66758c'
}

const invoiceId = computed(() => Number(route.params.invoiceId))
const invoice = computed(() =>
  invoiceStore.invoices.find((row) => row.id === invoiceId.value) ?? null,
)

const billingProfile = computed(() => {
  if (!invoice.value?.billing_profile_id) return null
  return billingProfileStore.items.find((p) => p.id === invoice.value?.billing_profile_id) ?? null
})

const customerGroup = computed(() => {
  if (!billingProfile.value?.customer_group_id) return null
  return customerGroupStore.groups.find((g) => g.id === billingProfile.value?.customer_group_id) ?? null
})

const headerStyle = computed(() => {
  const color = billingProfile.value?.color
  if (color) {
    return {
      borderLeft: `6px solid ${color}`,
    }
  }
  return {}
})

const getContrastYIQ = (hexcolor: string) => {
  if (!hexcolor || hexcolor.length < 6) return '#000000'
  const hex = hexcolor.replace('#', '')
  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)
  const yiq = (r * 299 + g * 587 + b * 114) / 1000
  return yiq >= 128 ? '#000000' : '#ffffff'
}

interface GroupedInventoryStock {
  key: string
  name: string
  image_url: string | null
  product_id: number | null
  barcode: string | null
  product_code: string | null
  cost: number | null
  tenant_name: string | null
  tenant_id: number
  shipment: InventoryItemWithStock['shipment']
  subtypes: {
    standard?: InventoryItemWithStock
    boxless?: InventoryItemWithStock
    box_damage?: InventoryItemWithStock
    expired?: InventoryItemWithStock
  }
}

const cleanName = (name: string) => {
  return name
    .replace(/\s*\(Boxless\)$/i, '')
    .replace(/\s*\(Box Damage\)$/i, '')
    .replace(/\s*\(Expired\)$/i, '')
    .replace(/\s*\(Stolen\/Missing\)$/i, '')
    .replace(/\s*\(Stolen\)$/i, '')
}

const getSubtypeFromItem = (item: { name: string }) => {
  const name = item.name || ''
  if (name.endsWith(' (Boxless)')) return 'boxless'
  if (name.endsWith(' (Box Damage)')) return 'box_damage'
  if (name.endsWith(' (Expired)')) return 'expired'
  if (name.endsWith(' (Stolen/Missing)') || name.endsWith(' (Stolen)')) return 'stolen'
  return 'standard'
}

const sortedSearchItemsGrouped = computed<GroupedInventoryStock[]>(() => {
  const groups: Record<string, GroupedInventoryStock> = {}

  for (const item of searchResults.value) {
    const subtype = getSubtypeFromItem(item)
    if (subtype === 'stolen') continue

    const baseName = cleanName(item.name)
    const shipmentId = item.shipment?.shipment?.id ? String(Number(item.shipment.shipment.id)) : 'none'
    const key = `${item.tenant_id}_${item.product_id || baseName}_${shipmentId}`

    let group = groups[key]
    if (!group) {
      group = {
        key,
        name: baseName,
        image_url: item.image_url ?? null,
        product_id: item.product_id,
        barcode: item.barcode,
        product_code: item.product_code,
        cost: item.cost,
        tenant_name: item.tenant_name ?? null,
        tenant_id: item.tenant_id,
        shipment: item.shipment,
        subtypes: {},
      }
      groups[key] = group
    }

    group.subtypes[subtype] = item

    if (subtype === 'standard') {
      group.image_url = item.image_url || group.image_url
      group.barcode = item.barcode || group.barcode
      group.product_code = item.product_code || group.product_code
      group.cost = item.cost !== null ? item.cost : group.cost
    }
  }

  const sortedList = Object.values(groups).sort((a, b) => {
    const shipmentIdA = Number(a.shipment?.shipment?.id ?? Number.MAX_SAFE_INTEGER)
    const shipmentIdB = Number(b.shipment?.shipment?.id ?? Number.MAX_SAFE_INTEGER)
    return shipmentIdA - shipmentIdB
  })

  return sortedList
})

const getAvailableQuantityForSubtype = (item: InventoryItemWithStock | undefined, subtype: 'standard' | 'boxless' | 'box_damage' | 'expired'): number => {
  if (!item || !item.stock) return 0
  const stock = item.stock
  if (subtype === 'standard') {
    return Math.max(0, Number(stock.available_quantity ?? 0) - Number(stock.reserved_quantity ?? 0))
  }
  if (subtype === 'boxless' || subtype === 'box_damage') {
    return Math.max(0, Number(stock.open_box_quantity ?? 0))
  }
  if (subtype === 'expired') {
    return Math.max(0, Number(stock.expired_quantity ?? 0))
  }
  return 0
}

const getSubtypeItem = (
  group: GroupedInventoryStock,
  subtype: 'standard' | 'boxless' | 'box_damage' | 'expired',
) => group.subtypes[subtype] ?? null

const getSubtypeLabel = (subtype: 'standard' | 'boxless' | 'box_damage' | 'expired') => {
  switch (subtype) {
    case 'standard': return 'Standard/Usable'
    case 'boxless': return 'Boxless'
    case 'box_damage': return 'Box Damage'
    case 'expired': return 'Expired'
  }
}
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
  initialLoading.value = true
  try {
    const fetches: Promise<unknown>[] = [
      invoiceStore.fetchInvoiceById(invoiceId.value),
      invoiceStore.fetchInvoiceItems({
        tenant_id: authStore.tenantId,
        filters: { invoice_id: invoiceId.value },
        operators: { invoice_id: 'eq' },
        page: 1,
        page_size: 100,
        sortBy: 'created_at',
        sortOrder: 'desc',
      }),
      billingProfileStore.fetchBillingProfiles({
        tenant_id: authStore.tenantId,
        page: 1,
        page_size: 100,
      }),
      customerGroupStore.fetchCustomerGroupsByTenant(authStore.tenantId)
    ]
    
    await Promise.all(fetches)
    await loadInvoiceItemImages()
  } catch (error) {
    console.error('Error during initial fetch of invoice details:', error)
  } finally {
    initialLoading.value = false
  }
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

const openInvoicePreview = () => {
  if (!invoice.value) return
  const routeData = router.resolve({
    name: 'app-invoice-preview-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      invoiceId: invoice.value.id,
    },
  })
  window.open(routeData.href, '_blank')
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

const onSearchStock = async () => {
  const trimmed = searchTerm.value.trim()
  if (!trimmed) {
    searchResults.value = []
    return
  }

  searchLoading.value = true
  const isProductIdSearch = searchBy.value === 'product_id'
  const productIdValue = Number(trimmed)
  if (isProductIdSearch && !Number.isFinite(productIdValue)) {
    searchResults.value = []
    searchLoading.value = false
    return
  }

  try {
    const res = await inventoryService.listGlobalInventoryItems({
      filters: {
        [searchBy.value]: isProductIdSearch ? productIdValue : trimmed,
      },
      operators: {
        [searchBy.value]: isProductIdSearch ? 'eq' : 'ilike',
      },
      page: 1,
      page_size: 20,
      sortBy: 'id',
      sortOrder: 'desc',
    })

    searchResults.value = res.success && res.data ? res.data.data : []
  } catch (error) {
    console.error('Error during invoice stock search:', error)
    searchResults.value = []
  } finally {
    searchLoading.value = false
  }
}

const onSearchInput = () => {
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }
  searchDebounceTimer = setTimeout(() => {
    void onSearchStock()
  }, 350)
}

const addItemToInvoice = async (inventoryItemId: number) => {
  if (!authStore.tenantId || !invoice.value) return
  const item = searchResults.value.find((row) => row.id === inventoryItemId)
  if (!item) return

  const stock = item.stock
  if (!stock) {
    showWarningDialog('Stock record is missing for this item.')
    return
  }

  const previousAvailable = Number(stock.available_quantity ?? 0)
  const previousOpenBox = Number(stock.open_box_quantity ?? 0)
  const previousExpired = Number(stock.expired_quantity ?? 0)

  const subtype = getSubtypeFromItem(item)
  let usablePool = 0
  if (subtype === 'standard') {
    usablePool = Math.max(0, previousAvailable - Number(stock.reserved_quantity ?? 0))
  } else if (subtype === 'boxless' || subtype === 'box_damage') {
    usablePool = previousOpenBox
  } else if (subtype === 'expired') {
    usablePool = previousExpired
  }

  if (usablePool <= 0) {
    showWarningDialog('No usable stock left for this item subtype.')
    return
  }

  const quantity = getAddQuantity(inventoryItemId)
  if (quantity == null || !Number.isFinite(quantity) || quantity <= 0) {
    showWarningDialog('Please enter a valid quantity.')
    return
  }
  if (quantity > usablePool) {
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

    const nextAvailable = previousAvailable - quantity
    let nextOpenBox = previousOpenBox
    let nextExpired = previousExpired

    if (subtype === 'boxless' || subtype === 'box_damage') {
      nextOpenBox = previousOpenBox - quantity
    } else if (subtype === 'expired') {
      nextExpired = previousExpired - quantity
    }

    const updateStockResult = await inventoryStore.updateInventoryStock({
      id: stock.id,
      patch: {
        available_quantity: nextAvailable,
        open_box_quantity: nextOpenBox,
        expired_quantity: nextExpired,
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
    searchTerm.value = ''
    searchResults.value = []
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
  } catch (error) {
    console.error('Error during addItemToInvoice:', error)
  } finally {
    addLoadingByItemId.value = { ...addLoadingByItemId.value, [inventoryItemId]: false }
  }
}
const getAddQuantity = (itemId: number): number | null => addQuantityByItemId.value[itemId] ?? null

const incrementQty = (itemId: number, maxVal: number) => {
  const current = getAddQuantity(itemId)
  const currentVal = (current == null || !Number.isFinite(current)) ? 0 : current
  const next = currentVal + 1
  if (next <= maxVal) {
    setAddQuantity(itemId, next)
  }
}

const decrementQty = (itemId: number) => {
  const current = getAddQuantity(itemId)
  if (current == null || !Number.isFinite(current)) {
    return
  }
  const next = current - 1
  if (next >= 1) {
    setAddQuantity(itemId, next)
  }
}

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

const getSellPrice = (itemId: number): number | null => {
  if (sellPriceByItemId.value[itemId] !== undefined && sellPriceByItemId.value[itemId] !== null) {
    return sellPriceByItemId.value[itemId]
  }
  return null
}

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

const getSubtypeIcon = (subtype: 'standard' | 'boxless' | 'box_damage' | 'expired') => {
  switch (subtype) {
    case 'standard': return 'check_circle'
    case 'boxless': return 'o_archive'
    case 'box_damage': return 'warning'
    case 'expired': return 'schedule'
  }
}

const getSubtypeIconColor = (subtype: 'standard' | 'boxless' | 'box_damage' | 'expired') => {
  switch (subtype) {
    case 'standard': return 'positive'
    case 'boxless': return 'primary'
    case 'box_damage': return 'warning'
    case 'expired': return 'negative'
  }
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
    await invoiceStore.fetchInvoiceById(invoice.value.id)
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
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
    searchDebounceTimer = null
  }
  searchBy.value = 'product_id'
  searchTerm.value = ''
  searchLoading.value = false
  searchResults.value = []
  addLoadingByItemId.value = {}
  addQuantityByItemId.value = {}
  sellPriceByItemId.value = {}
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

  const subtype = getSubtypeFromItem({ name: row.name_snapshot })
  const currentAvailable = Number(stock.available_quantity ?? 0)
  const currentOpenBox = Number(stock.open_box_quantity ?? 0)
  const currentExpired = Number(stock.expired_quantity ?? 0)

  let usablePool = 0
  if (subtype === 'standard') {
    usablePool = Math.max(0, currentAvailable - Number(stock.reserved_quantity ?? 0))
  } else if (subtype === 'boxless' || subtype === 'box_damage') {
    usablePool = currentOpenBox
  } else if (subtype === 'expired') {
    usablePool = currentExpired
  }

  if (quantityDelta > usablePool) {
    showWarningDialog('Not enough usable stock for this quantity.')
    return
  }

  const nextAvailable = currentAvailable - quantityDelta
  if (nextAvailable < 0) {
    showWarningDialog('Not enough usable stock for this quantity.')
    return
  }

  let nextOpenBox = currentOpenBox
  let nextExpired = currentExpired

  if (subtype === 'boxless' || subtype === 'box_damage') {
    nextOpenBox = currentOpenBox - quantityDelta
    if (nextOpenBox < 0) {
      showWarningDialog('Not enough open box stock for this quantity.')
      return
    }
  } else if (subtype === 'expired') {
    nextExpired = currentExpired - quantityDelta
    if (nextExpired < 0) {
      showWarningDialog('Not enough expired stock for this quantity.')
      return
    }
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
      open_box_quantity: nextOpenBox,
      expired_quantity: nextExpired,
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
  let previousOpenBox = 0
  let previousExpired = 0
  let subtype: 'standard' | 'boxless' | 'box_damage' | 'expired' = 'standard'

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
    previousOpenBox = Number(stock.open_box_quantity ?? 0)
    previousExpired = Number(stock.expired_quantity ?? 0)
    subtype = getSubtypeFromItem({ name: row.name_snapshot }) as 'standard' | 'boxless' | 'box_damage' | 'expired'
  }

  const accountingEntry = await findAccountingEntryByInvoiceItemId(selectedInvoiceItemId.value)
  const result = await invoiceStore.deleteInvoiceItem({ id: selectedInvoiceItemId.value })
  if (result.success) {
    if (stockIdToUpdate != null && netQuantity > 0) {
      const nextAvailable = previousAvailable + netQuantity
      let nextOpenBox = previousOpenBox
      let nextExpired = previousExpired

      if (subtype === 'boxless' || subtype === 'box_damage') {
        nextOpenBox = previousOpenBox + netQuantity
      } else if (subtype === 'expired') {
        nextExpired = previousExpired + netQuantity
      }

      const updateStockResult = await inventoryStore.updateInventoryStock({
        id: stockIdToUpdate,
        patch: {
          available_quantity: nextAvailable,
          open_box_quantity: nextOpenBox,
          expired_quantity: nextExpired,
        },
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
  await invoiceStore.fetchInvoiceById(invoice.value.id)
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
  } else if (searchTerm.value.trim()) {
    void onSearchStock()
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

.floating-surface {
  background: rgba(255, 255, 255, 0.86) !important;
  border-radius: 14px !important;
  border: 1px solid rgba(34, 56, 101, 0.08) !important;
  backdrop-filter: blur(6px) !important;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px !important;
  background: rgba(255, 255, 255, 0.82) !important;
}

.pill-btn {
  border-radius: 999px !important;
}

.slim-btn {
  min-height: 32px !important;
  padding-left: 12px !important;
  padding-right: 12px !important;
}

.border-light {
  border: 1px solid rgba(34, 56, 101, 0.06) !important;
}

.border-top {
  border-top: 1px solid rgba(34, 56, 101, 0.08) !important;
}

.costing-file-status-chip {
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
</style>

<template>
  <q-page class="q-pa-md thrift-create-invoice-page">
    <div class="q-gutter-y-md">
      <!-- Top Navigation & Header -->
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-left"
            color="primary"
            :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/sales`"
          >
            <q-tooltip>Back to Sales</q-tooltip>
          </q-btn>
          <div>
            <div class="text-overline text-primary">Thrift / Sales</div>
            <h1 class="text-h5 text-weight-bold q-my-none">Create Sales Invoice</h1>
          </div>
        </div>

        <div class="col-auto row q-gutter-sm items-center">
          <q-btn
            outline
            color="grey-8"
            no-caps
            label="Cancel"
            :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/sales`"
          />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-check"
            label="Save Invoice"
            :loading="saving"
            :disable="selectedItems.length === 0"
            @click="onSaveInvoice"
          />
        </div>
      </div>

      <!-- Main 2-Column Content Grid -->
      <div class="row q-col-gutter-md">
        <!-- Left Column: Header Info & Item Search/Table -->
        <div class="col-12 col-lg-8 q-gutter-y-md">
          <!-- Card 1: Invoice Header Info -->
          <q-card flat bordered class="rounded-borders">
            <q-card-section class="q-pb-none">
              <div class="text-subtitle1 text-weight-bold row items-center">
                <q-icon name="ph ph-receipt" class="q-mr-xs text-primary" size="20px" />
                Invoice Header Details
              </div>
            </q-card-section>
            <q-card-section>
              <div class="row q-col-gutter-md">
                <div class="col-12 col-sm-4">
                  <q-input
                    :model-value="invoiceForm.invoiceNumber"
                    label="Invoice Number"
                    hint="Assigned on save (INV-YYYY-MM-#####)"
                    outlined
                    dense
                    readonly
                    bg-color="grey-1"
                  >
                    <template #append>
                      <q-icon name="ph ph-lock-key" size="xs" color="grey-6" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-4">
                  <q-input
                    v-model="invoiceForm.date"
                    label="Invoice Date"
                    type="date"
                    outlined
                    dense
                  />
                </div>
                <div class="col-12 col-sm-4">
                  <q-select
                    v-model="invoiceForm.paymentMethod"
                    :options="paymentMethodOptions"
                    label="Payment Method"
                    outlined
                    dense
                    emit-value
                    map-options
                  />
                </div>
                <div class="col-12 col-sm-4">
                  <q-select
                    v-model="invoiceForm.paymentStatus"
                    :options="paymentStatusOptions"
                    label="Payment Status"
                    outlined
                    dense
                    emit-value
                    map-options
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="invoiceForm.customerName"
                    label="Customer Name (Optional)"
                    outlined
                    dense
                    placeholder="e.g. John Doe"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-user" color="grey-6" size="xs" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="invoiceForm.customerPhone"
                    label="Customer Phone (Optional)"
                    outlined
                    dense
                    placeholder="e.g. +8801700000000"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-phone" color="grey-6" size="xs" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12">
                  <q-input
                    v-model="invoiceForm.notes"
                    label="Customer / Order Notes (Optional)"
                    outlined
                    dense
                    placeholder="e.g. Walk-in customer, discount applied"
                  />
                </div>
              </div>
            </q-card-section>
          </q-card>

          <!-- Card 2: Stock Item Search & Quick Add -->
          <q-card flat bordered class="rounded-borders search-card">
            <q-card-section class="q-pb-none">
              <div class="text-subtitle1 text-weight-bold row items-center justify-between">
                <span class="row items-center">
                  <q-icon name="ph ph-barcode" class="q-mr-xs text-primary" size="20px" />
                  Search & Add Thrift Items
                </span>
                <span class="text-caption text-grey-6">
                  Press Enter key or click Search button
                </span>
              </div>
            </q-card-section>
            <q-card-section class="q-gutter-y-sm">
              <!-- Manual Search Input (Triggers ONLY on Enter key or Search button click) -->
              <div class="row q-col-gutter-sm items-center">
                <div class="col">
                  <q-input
                    v-model="searchQuery"
                    outlined
                    dense
                    placeholder="Scan barcode or type item name and press Enter..."
                    :loading="loadingStock"
                    @keyup.enter="triggerStockSearch"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-barcode" color="primary" />
                    </template>
                  </q-input>
                </div>
                <div class="col-auto">
                  <q-btn
                    color="primary"
                    unelevated
                    no-caps
                    icon="ph ph-magnifying-glass"
                    label="Search"
                    :loading="loadingStock"
                    @click="triggerStockSearch"
                  />
                </div>
              </div>

              <!-- Search Results List (only shown after manual search) -->
              <div v-if="hasSearched" class="q-mt-sm">
                <div v-if="searchResults.length === 0" class="q-pa-md text-center bg-grey-1 rounded-borders text-grey-7">
                  <q-icon name="ph ph-magnifying-glass" size="24px" color="grey-5" class="q-mr-xs" />
                  No available stock items match "{{ lastSearchQuery }}"
                </div>
                <q-card v-else flat bordered class="rounded-borders overflow-hidden bg-white shadow-1">
                  <div class="q-pa-xs bg-blue-1 text-primary text-caption text-weight-bold row items-center justify-between q-px-sm">
                    <span>Search Results for "{{ lastSearchQuery }}" ({{ searchResults.length }})</span>
                    <q-btn flat round dense icon="ph ph-x" size="xs" color="grey-7" @click="clearSearchResults" />
                  </div>
                  <q-list separator class="bg-white">
                    <q-item v-for="item in searchResults" :key="item.id" class="q-py-sm">
                      <q-item-section avatar>
                        <q-avatar square size="36px" class="rounded-borders overflow-hidden bg-grey-2">
                          <img v-if="item.imageUrl" :src="item.imageUrl" style="object-fit: cover; width: 100%; height: 100%;" />
                          <q-icon v-else name="ph ph-tag" color="primary" size="20px" />
                        </q-avatar>
                      </q-item-section>
                      <q-item-section>
                        <q-item-label class="text-weight-bold text-dark text-mono">
                          Barcode: {{ item.barcode }}
                        </q-item-label>
                        <q-item-label caption class="q-mt-2xs">
                          <span
                            v-if="item.status === 'SOLD'"
                            class="text-weight-medium text-negative"
                          >
                            Sold
                          </span>
                          <span v-else class="text-weight-medium text-positive">
                            Available Qty: {{ item.availableQuantity }}
                          </span>
                        </q-item-label>
                      </q-item-section>
                      <q-item-section side class="text-right">
                        <div class="text-subtitle1 text-weight-bold text-primary q-mb-xs">
                          ৳{{ item.defaultSellPrice.toFixed(2) }}
                        </div>
                        <q-badge
                          v-if="item.status === 'SOLD'"
                          color="negative"
                          class="q-pa-xs text-weight-bold"
                        >
                          Sold
                        </q-badge>
                        <q-btn
                          v-else-if="!isItemAdded(item.id)"
                          dense
                          size="sm"
                          color="primary"
                          icon="ph ph-plus"
                          unelevated
                          no-caps
                          label="Add"
                          @click="addItemToInvoice(item)"
                        />
                        <q-badge
                          v-else
                          color="grey-3"
                          text-color="grey-8"
                          class="q-pa-xs text-weight-bold"
                        >
                          <q-icon name="ph ph-check" size="12px" class="q-mr-xs" color="positive" />
                          Added
                        </q-badge>
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-card>
              </div>
            </q-card-section>
          </q-card>

          <!-- Card 3: Line Items Table -->
          <q-card flat bordered class="rounded-borders">
            <q-card-section class="q-pb-none row items-center justify-between">
              <div class="text-subtitle1 text-weight-bold row items-center">
                <q-icon name="ph ph-list-numbers" class="q-mr-xs text-primary" size="20px" />
                Invoice Line Items ({{ selectedItems.length }})
              </div>
              <q-btn
                v-if="selectedItems.length > 0"
                flat
                dense
                no-caps
                color="negative"
                icon="ph ph-trash"
                label="Clear All"
                size="sm"
                @click="selectedItems = []"
              />
            </q-card-section>

            <q-card-section class="q-px-none">
              <!-- Empty State -->
              <div v-if="selectedItems.length === 0" class="text-center q-pa-xl">
                <q-icon name="ph ph-shopping-bag-open" size="56px" color="grey-4" />
                <div class="text-subtitle1 text-grey-7 q-mt-sm text-weight-medium">
                  No Items Added Yet
                </div>
                <div class="text-caption text-grey-5 max-w-sm q-mx-auto">
                  Use the search box above or scan barcodes to add items to this sales invoice.
                </div>
              </div>

              <!-- Table -->
              <q-markup-table v-else flat class="thrift-invoice-table">
                <thead>
                  <tr class="text-grey-7">
                    <th class="text-left">Item Details</th>
                    <th class="text-right">Landed Cost</th>
                    <th class="text-right" style="width: 130px">Sell Price (৳)</th>
                    <th v-if="canApplyDiscount" class="text-right" style="width: 120px">Discount (৳)</th>
                    <th class="text-right">Final Price</th>
                    <th class="text-right">Net Profit</th>
                    <th class="text-center" style="width: 50px"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(line, idx) in selectedItems" :key="line.stockId">
                    <!-- Item Info -->
                    <td class="text-left">
                      <div class="row items-center q-gutter-x-sm">
                        <q-avatar square size="36px" class="rounded-borders overflow-hidden bg-grey-2">
                          <img v-if="line.imageUrl" :src="line.imageUrl" style="object-fit: cover; width: 100%; height: 100%;" />
                          <q-icon v-else name="ph ph-tag" color="primary" size="18px" />
                        </q-avatar>
                        <span class="text-mono text-weight-bold text-dark">{{ line.barcode }}</span>
                      </div>
                    </td>

                    <!-- Landed Cost -->
                    <td class="text-right text-weight-medium text-grey-7">
                      ৳{{ line.landedCost.toFixed(2) }}
                    </td>

                    <!-- Editable Sell Price -->
                    <td class="text-right">
                      <q-input
                        v-model.number="line.sellPrice"
                        type="number"
                        outlined
                        dense
                        step="0.5"
                        min="0"
                        input-class="text-right text-weight-bold"
                      />
                    </td>

                    <!-- Editable Discount -->
                    <td v-if="canApplyDiscount" class="text-right">
                      <q-input
                        v-model.number="line.discountAmount"
                        type="number"
                        outlined
                        dense
                        step="0.5"
                        min="0"
                        input-class="text-right"
                      />
                    </td>

                    <!-- Final Price -->
                    <td class="text-right text-weight-bold text-primary">
                      ৳{{ getFinalPrice(line).toFixed(2) }}
                    </td>

                    <!-- Net Profit -->
                    <td class="text-right">
                      <q-badge
                        :color="getNetProfit(line) >= 0 ? 'positive' : 'negative'"
                        class="text-weight-bold q-px-sm q-py-xs"
                      >
                        {{ getNetProfit(line) >= 0 ? '+' : '' }}৳{{ getNetProfit(line).toFixed(2) }}
                      </q-badge>
                    </td>

                    <!-- Action -->
                    <td class="text-center">
                      <q-btn
                        flat
                        round
                        dense
                        icon="ph ph-x"
                        color="grey-6"
                        size="sm"
                        @click="removeItem(idx)"
                      />
                    </td>
                  </tr>
                </tbody>
              </q-markup-table>
            </q-card-section>
          </q-card>
        </div>

        <!-- Right Column: Sticky Summary & Financial Totals -->
        <div class="col-12 col-lg-4">
          <div class="sticky-summary q-gutter-y-md">
            <q-card flat bordered class="rounded-borders bg-white shadow-1">
              <q-card-section class="bg-primary text-white q-py-md">
                <div class="text-subtitle2 text-uppercase text-weight-bold opacity-8">
                  Invoice Summary
                </div>
                <div class="text-h4 text-weight-bolder q-mt-xs">
                  ৳{{ totalInvoiceAmount.toFixed(2) }}
                </div>
                <div class="text-caption opacity-9">
                  {{ selectedItems.length }} item(s) selected
                </div>
              </q-card-section>

              <q-card-section class="q-gutter-y-sm">
                <div class="row justify-between items-center text-body2">
                  <span class="text-grey-7">Gross Subtotal</span>
                  <span class="text-weight-bold">৳{{ grossSubtotal.toFixed(2) }}</span>
                </div>
                <div
                  v-if="canApplyDiscount"
                  class="row justify-between items-center text-body2"
                >
                  <span class="text-grey-7">Total Discounts</span>
                  <span class="text-weight-bold text-negative">
                    -৳{{ totalDiscounts.toFixed(2) }}
                  </span>
                </div>
                <q-separator class="q-my-xs" />
                <div class="row justify-between items-center text-body2">
                  <span class="text-grey-8 text-weight-bold">Final Invoice Total</span>
                  <span class="text-h6 text-weight-bold text-primary">
                    ৳{{ totalInvoiceAmount.toFixed(2) }}
                  </span>
                </div>
                <q-separator class="q-my-xs" />
                <div class="row justify-between items-center text-body2">
                  <span class="text-grey-7">Cost of Goods Sold (COGS)</span>
                  <span class="text-weight-bold text-grey-8">৳{{ totalCOGS.toFixed(2) }}</span>
                </div>
                <div class="row justify-between items-center text-body2 bg-green-1 q-pa-sm rounded-borders">
                  <span class="text-weight-bold text-positive row items-center">
                    <q-icon name="ph ph-trend-up" class="q-mr-xs" />
                    Est. Net Profit
                  </span>
                  <span class="text-subtitle1 text-weight-bolder text-positive">
                    +৳{{ totalNetProfit.toFixed(2) }}
                    <span class="text-caption text-weight-medium">({{ profitMarginPercent }}%)</span>
                  </span>
                </div>
              </q-card-section>

              <!-- Workflow Notice -->
              <q-card-section class="bg-grey-2 q-py-sm">
                <div class="text-caption text-grey-7 row items-start">
                  <q-icon name="ph ph-info" size="xs" color="primary" class="q-mr-xs q-mt-xs" />
                  <span>
                    Saving will create the invoice header (<strong>thrift_sales_invoices</strong>), insert line items (<strong>thrift_sales_invoice_items</strong>), and mark items as <strong>SOLD</strong>.
                  </span>
                </div>
              </q-card-section>

              <q-card-actions class="q-pa-md q-gutter-y-sm">
                <q-btn
                  color="primary"
                  unelevated
                  no-caps
                  icon="ph ph-check-circle"
                  label="Save Sales Invoice"
                  class="full-width text-weight-bold"
                  size="lg"
                  :loading="saving"
                  :disable="selectedItems.length === 0"
                  @click="onSaveInvoice"
                />
              </q-card-actions>
            </q-card>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import type { AvailableStockItem } from '../repositories/thriftSalesRepository';
import { useThriftAvailableStockSearchQuery } from '../composables/useThriftSalesQuery';
import { useCreateThriftSalesInvoiceMutation } from '../composables/useThriftSalesMutations';

const $q = useQuasar();
const router = useRouter();
const authStore = useAuthStore();
const { hasModuleAccess } = useModulePermissions();
const canApplyDiscount = computed(() =>
  hasModuleAccess('thrift_sales', 'apply_discount'),
);

const { mutateAsync: createSalesInvoice, isPending: saving } =
  useCreateThriftSalesInvoiceMutation();

const invoiceForm = ref({
  invoiceNumber: 'Auto on save',
  customerName: '',
  customerPhone: '',
  date: new Date().toISOString().split('T')[0],
  paymentMethod: 'cash',
  paymentStatus: 'paid',
  notes: '',
});

const paymentMethodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'Card / POS', value: 'card' },
  { label: 'Mobile Banking (bKash/Nagad)', value: 'mobile_banking' },
  { label: 'Bank Transfer', value: 'bank_transfer' },
];

const paymentStatusOptions = [
  { label: 'Paid', value: 'paid' },
  { label: 'Pending', value: 'pending' },
  { label: 'Partial', value: 'partial' },
];

// Manual search: input is unbound from query until Enter / Search click
const searchQuery = ref('');
const committedSearch = ref('');

const searchParams = computed(() => ({
  tenantId: authStore.tenantId ?? 0,
  search: committedSearch.value,
}));

const {
  data: searchResultsData,
  isFetching: loadingStock,
  error: searchError,
} = useThriftAvailableStockSearchQuery(searchParams);

const hasSearched = computed(() => !!committedSearch.value.trim());
const lastSearchQuery = computed(() => committedSearch.value);
const searchResults = computed(() => searchResultsData.value ?? []);

function triggerStockSearch() {
  const query = searchQuery.value.trim();
  if (!query) {
    committedSearch.value = '';
    return;
  }
  committedSearch.value = query;
}

function clearSearchResults() {
  committedSearch.value = '';
  searchQuery.value = '';
}

watch(searchError, (err) => {
  if (!err) return;
  console.error('Search stock error:', err);
  $q.notify({ type: 'negative', message: 'Failed to search stock items.' });
});

// Invoice Line Item Type
interface InvoiceLineItem {
  stockId: number;
  name: string;
  brandName?: string | undefined;
  barcode: string;
  category: string;
  type?: string | undefined;
  color?: string | undefined;
  size?: string | undefined;
  condition?: string | undefined;
  shelfCode?: string | undefined;
  boxName?: string | undefined;
  imageUrl?: string | undefined;
  shipmentId: number;
  shipmentName?: string | undefined;
  landedCost: number;
  sellPrice: number;
  discountAmount: number;
}

const selectedItems = ref<InvoiceLineItem[]>([]);

// Check if stock item is already in invoice
function isItemAdded(stockId: number): boolean {
  return selectedItems.value.some((item) => item.stockId === stockId);
}

// Add Item
function addItemToInvoice(stock: AvailableStockItem) {
  if (stock.status === 'SOLD') {
    $q.notify({ type: 'warning', message: 'This item is already sold' });
    return;
  }
  if (selectedItems.value.some((item) => item.stockId === stock.id)) {
    $q.notify({ type: 'warning', message: 'Item already added to this invoice' });
    return;
  }
  selectedItems.value.push({
    stockId: stock.id,
    name: stock.name,
    brandName: stock.brandName,
    barcode: stock.barcode,
    category: stock.category,
    type: stock.type,
    color: stock.color,
    size: stock.size,
    condition: stock.condition,
    shelfCode: stock.shelfCode,
    boxName: stock.boxName,
    imageUrl: stock.imageUrl,
    shipmentId: stock.shipmentId,
    shipmentName: stock.shipmentName,
    landedCost: stock.landedCost,
    sellPrice: stock.defaultSellPrice,
    discountAmount: 0,
  });
  clearSearchResults();
  $q.notify({
    type: 'positive',
    message: `Added item (${stock.barcode}) to invoice`,
    icon: 'ph ph-check',
    timeout: 1000,
  });
}

function removeItem(index: number) {
  selectedItems.value.splice(index, 1);
}

// Computations per line
function getFinalPrice(line: InvoiceLineItem): number {
  return Math.max(0, (line.sellPrice || 0) - (line.discountAmount || 0));
}

function getNetProfit(line: InvoiceLineItem): number {
  return getFinalPrice(line) - line.landedCost;
}

// Summary Totals
const grossSubtotal = computed(() =>
  selectedItems.value.reduce((sum, line) => sum + (line.sellPrice || 0), 0),
);

const totalDiscounts = computed(() =>
  selectedItems.value.reduce((sum, line) => sum + (line.discountAmount || 0), 0),
);

const totalInvoiceAmount = computed(() =>
  selectedItems.value.reduce((sum, line) => sum + getFinalPrice(line), 0),
);

const totalCOGS = computed(() =>
  selectedItems.value.reduce((sum, line) => sum + line.landedCost, 0),
);

const totalNetProfit = computed(() => totalInvoiceAmount.value - totalCOGS.value);

const profitMarginPercent = computed(() => {
  if (totalInvoiceAmount.value === 0) return '0';
  return ((totalNetProfit.value / totalInvoiceAmount.value) * 100).toFixed(1);
});

// Save Invoice UI Handler
async function onSaveInvoice() {
  if (selectedItems.value.length === 0) {
    $q.notify({ type: 'warning', message: 'Please add at least one thrift item to the invoice.' });
    return;
  }

  try {
    const tenantId = authStore.tenantId;
    if (!tenantId) {
      $q.notify({ type: 'negative', message: 'Tenant context is missing.' });
      return;
    }
    const userEmail = authStore.user?.email || 'cashier@brandwala.com';

    const itemsPayload = selectedItems.value.map((line) => {
      const discountAmount = canApplyDiscount.value ? line.discountAmount || 0 : 0;
      const finalPrice = Math.max(0, (line.sellPrice || 0) - discountAmount);
      const profit = finalPrice - (line.landedCost || 0);
      return {
        stockId: line.stockId,
        sellPrice: line.sellPrice || 0,
        discountAmount,
        finalPrice,
        landedUnitCostAtSale: line.landedCost || 0,
        quantity: 1,
        netProfit: profit,
      };
    });

    const result = await createSalesInvoice({
      tenantId,
      customerName: invoiceForm.value.customerName || undefined,
      customerPhone: invoiceForm.value.customerPhone || undefined,
      date: new Date(invoiceForm.value.date || Date.now()).toISOString(),
      paymentMethod: invoiceForm.value.paymentMethod,
      paymentStatus: invoiceForm.value.paymentStatus,
      notes: invoiceForm.value.notes || undefined,
      createdBy: userEmail,
      totalInvoiceAmount: totalInvoiceAmount.value,
      items: itemsPayload,
    });

    $q.notify({
      type: 'positive',
      icon: 'ph ph-check-circle',
      message: `Invoice ${result.invoiceNumber} created successfully!`,
      caption: `Created sales invoice, updated stock status to SOLD, and recorded revenue in accounting ledger.`,
      timeout: 3000,
    });

    const slug = authStore.tenantSlug || 'tenant';
    router.push(`/${slug}/app/thrift/sales/${result.id}`);
  } catch (err: any) {
    console.error('Failed to create sales invoice:', err);
    $q.notify({
      type: 'negative',
      message: err.message || 'Failed to create sales invoice.',
    });
  }
}
</script>

<style scoped>
.thrift-create-invoice-page {
  max-width: 1400px;
  margin: 0 auto;
}

.sticky-summary {
  position: sticky;
  top: 16px;
}

.opacity-8 {
  opacity: 0.8;
}

.opacity-9 {
  opacity: 0.9;
}

.max-w-sm {
  max-width: 320px;
}

.text-mono {
  font-family: monospace;
}

.thrift-invoice-table th {
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
</style>

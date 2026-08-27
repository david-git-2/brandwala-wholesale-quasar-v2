<script setup lang="ts">
import { computed } from 'vue';
import type { InvoiceBrand } from '../repositories/invoiceRepository';
import type { BillingProfile } from '../repositories/billingProfileRepository';
import type { SalesInvoiceStockItem } from '../repositories/invoiceRepository';
import type { InvoiceLineDraftItem } from '../types/wholesaleInvoiceDraft';

type BillingProfileWithTenant = BillingProfile & {
  tenant?: { id: number; name: string; slug: string } | null;
};

const props = defineProps<{
  isExistingInvoice: boolean;
  loadedInvoiceNo: string;
  loadedInvoiceStatus: string;
  effectivePaymentStatus: string;
  brandOptions: InvoiceBrand[];
  brandsLoading: boolean;
  billingProfileOptions: BillingProfileWithTenant[];
  billingProfilesLoading: boolean;
  invoiceItems: InvoiceLineDraftItem[];
  hasReturnedItems: boolean;
  isSearchingStock: boolean;
  stockSearchResults: SalesInvoiceStockItem[];
  totalQuantity: number;
  totalReturnQuantity: number;
  totalReturnCredit: number;
  subtotalAmount: number;
  totalDiscountAmount: number;
  grandTotalAmount: number;
  overallDiscountLocked: boolean;
}>();

const selectedBrandId = defineModel<number | null>('selectedBrandId', { required: true });
const selectedBillingProfileId = defineModel<number | null>('selectedBillingProfileId', { required: true });
const overallDiscountInput = defineModel<number | null>('overallDiscountInput', { required: true });
const stockSearchText = defineModel<string>('stockSearchText', { required: true });
const stockMenuOpen = defineModel<boolean>('stockMenuOpen', { required: true });

const emit = defineEmits<{
  (e: 'filter-billing-profiles', val: string, update: (fn: () => void) => void): void;
  (e: 'stock-search-input'): void;
  (e: 'search-focus'): void;
  (e: 'clear-stock-search'): void;
  (e: 'add-stock', stock: SalesInvoiceStockItem): void;
  (e: 'remove-item', index: number): void;
  (e: 'apply-overall-discount', val: string | number | null): void;
}>();

const selectedBrand = computed(
  () => props.brandOptions.find((brand) => brand.id === selectedBrandId.value) ?? null,
);

const selectedBillingProfile = computed(
  () =>
    props.billingProfileOptions.find((profile) => profile.id === selectedBillingProfileId.value) ??
    null,
);

const invoiceDateLabel = computed(() =>
  new Date().toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }),
);

const statusLabel = computed(() => {
  const status = props.loadedInvoiceStatus;
  if (status === 'proforma_generated') return 'Proforma';
  if (status === 'issued') return 'Issued';
  if (status === 'draft') return 'Draft';
  return status ? status.replace(/_/g, ' ') : 'New';
});

const formatMoney = (amount: number) =>
  `৳${amount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;

const calculateLineGross = (item: InvoiceLineDraftItem): number => {
  const sub = (item.quantity || 0) * (item.sell_price_amount || 0);
  return Math.max(0, sub - (item.line_discount_amount || 0));
};

const calculateLineTotal = (item: InvoiceLineDraftItem): number => {
  const kept = Math.max((item.quantity || 0) - (item.return_quantity || 0), 0);
  const sub = kept * (item.sell_price_amount || 0);
  const total = sub - (item.line_discount_amount || 0);
  return Math.max(0, total);
};

const isItemAlreadyAdded = (stockId: number) =>
  props.invoiceItems.some((item) => item.global_stock_id === stockId);

const formatDate = (dateStr: string) => (dateStr ? dateStr.slice(0, 10) : '');
</script>

<template>
  <article class="invoice-paper">
    <header class="invoice-paper__header">
      <div class="invoice-paper__brand">
        <div class="invoice-paper__doc-type">Wholesale invoice</div>
        <div v-if="loadedInvoiceNo" class="invoice-paper__invoice-no">
          {{ loadedInvoiceNo }}
        </div>
        <div v-if="selectedBrand" class="invoice-paper__brand-name">
          {{ selectedBrand.name }}
        </div>
        <div v-if="selectedBrand?.address" class="invoice-paper__brand-address">
          {{ selectedBrand.address }}
        </div>
      </div>

      <div class="invoice-paper__meta">
        <div class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Date</span>
          <span>{{ invoiceDateLabel }}</span>
        </div>
        <div v-if="isExistingInvoice" class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Status</span>
          <span class="text-capitalize">{{ statusLabel }}</span>
        </div>
        <div
          v-if="loadedInvoiceStatus === 'issued'"
          class="invoice-paper__meta-row"
        >
          <span class="invoice-paper__meta-label">Payment</span>
          <span class="text-uppercase">{{ effectivePaymentStatus }}</span>
        </div>
        <div class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Type</span>
          <span>Wholesale B2B</span>
        </div>
      </div>
    </header>

    <div class="invoice-paper__divider" />

    <section class="invoice-paper__addresses">
      <div class="invoice-paper__address-block">
        <div class="invoice-paper__section-label">From (brand)</div>
        <q-select
          v-model="selectedBrandId"
          :options="brandOptions"
          option-value="id"
          option-label="name"
          emit-value
          map-options
          outlined
          dense
          hide-bottom-space
          label="Invoice brand *"
          class="invoice-paper__field-input q-mt-sm"
          :loading="brandsLoading"
          :disable="brandsLoading"
        >
          <template #option="scope">
            <q-item v-bind="scope.itemProps" class="q-py-xs">
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ scope.opt.name }}</q-item-label>
                <q-item-label v-if="scope.opt.address" caption class="text-grey-6 ellipsis">
                  {{ scope.opt.address }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </template>
        </q-select>
      </div>

      <div class="invoice-paper__address-block">
        <div class="invoice-paper__section-label">Bill to</div>
        <q-select
          v-model="selectedBillingProfileId"
          :options="billingProfileOptions"
          option-value="id"
          option-label="name"
          emit-value
          map-options
          outlined
          dense
          clearable
          use-input
          input-debounce="150"
          hide-bottom-space
          label="Billing profile (customer) *"
          class="invoice-paper__field-input q-mt-sm"
          :loading="billingProfilesLoading"
          :disable="billingProfilesLoading"
          @filter="(val, update) => emit('filter-billing-profiles', val, update)"
        >
          <template #no-option>
            <q-item>
              <q-item-section class="text-grey-6 text-caption text-center q-py-sm">
                No billing profiles found
              </q-item-section>
            </q-item>
          </template>

          <template #option="scope">
            <q-item v-bind="scope.itemProps" class="q-py-xs">
              <q-item-section>
                <div class="row items-center justify-between no-wrap">
                  <q-item-label class="text-weight-medium">{{ scope.opt.name }}</q-item-label>
                  <q-badge
                    v-if="scope.opt.tenant?.name"
                    color="grey-2"
                    text-color="grey-8"
                    class="text-caption text-weight-medium q-ml-xs"
                  >
                    {{ scope.opt.tenant.name }}
                  </q-badge>
                </div>
                <q-item-label caption class="text-grey-6 ellipsis">
                  {{ scope.opt.phone || scope.opt.email || scope.opt.address || 'No details' }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </template>
        </q-select>

        <template v-if="selectedBillingProfile">
          <div class="invoice-paper__recipient-name q-mt-sm">
            {{ selectedBillingProfile.name }}
          </div>
          <div v-if="selectedBillingProfile.phone" class="invoice-paper__line">
            {{ selectedBillingProfile.phone }}
          </div>
          <div v-if="selectedBillingProfile.email" class="invoice-paper__line">
            {{ selectedBillingProfile.email }}
          </div>
          <div
            v-if="selectedBillingProfile.address"
            class="invoice-paper__line invoice-paper__line--wrap"
          >
            {{ selectedBillingProfile.address }}
          </div>
        </template>
      </div>
    </section>

    <div class="invoice-paper__divider" />

    <section class="invoice-paper__search">
      <div class="invoice-paper__section-label q-mb-sm">Add items</div>
      <q-input
        v-model="stockSearchText"
        outlined
        dense
        hide-bottom-space
        placeholder="Search stock by name, barcode, or product code..."
        class="invoice-paper__field-input"
        @update:model-value="emit('stock-search-input')"
        @focus="emit('search-focus')"
      >
        <template #prepend>
          <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-6" />
        </template>
        <template v-if="stockSearchText" #append>
          <q-icon
            name="ph ph-x-circle"
            size="16px"
            class="cursor-pointer text-grey-5"
            @click="emit('clear-stock-search')"
          />
        </template>

        <q-menu
          v-model="stockMenuOpen"
          no-focus
          fit
          anchor="bottom left"
          self="top left"
          class="stock-results-menu shadow-3 rounded-borders-8"
          style="min-width: 580px; max-height: 420px"
        >
          <q-list dense class="q-py-xs">
            <q-item v-if="isSearchingStock" class="q-py-md text-center">
              <q-item-section>
                <div class="row items-center justify-center q-gutter-sm text-grey-6 text-caption">
                  <q-spinner color="teal-7" size="20px" />
                  <span>Searching stock inventory...</span>
                </div>
              </q-item-section>
            </q-item>

            <q-item v-else-if="!stockSearchResults.length" class="q-py-md text-center">
              <q-item-section>
                <div class="text-caption text-grey-6">
                  No available stock found
                  <template v-if="stockSearchText">
                    for <strong>"{{ stockSearchText }}"</strong>
                  </template>
                </div>
              </q-item-section>
            </q-item>

            <q-item
              v-for="stock in stockSearchResults"
              :key="stock.global_stock_id"
              clickable
              class="stock-menu-item q-py-sm"
              :class="{ 'allocated-menu-row': stock.is_allocated_to_tenant }"
              @click="emit('add-stock', stock)"
            >
              <q-item-section avatar min-width="40px">
                <q-avatar size="36px" rounded color="grey-2" class="overflow-hidden">
                  <img v-if="stock.image_url" :src="stock.image_url" alt="" />
                  <q-icon v-else name="ph ph-package" color="grey-6" size="20px" />
                </q-avatar>
              </q-item-section>

              <q-item-section>
                <div class="row items-center justify-between no-wrap">
                  <q-item-label class="text-weight-bold text-body2 text-grey-9 ellipsis">
                    {{ stock.name }}
                  </q-item-label>
                  <q-badge
                    :color="stock.is_allocated_to_tenant ? 'positive' : 'grey-3'"
                    :text-color="stock.is_allocated_to_tenant ? 'white' : 'grey-9'"
                    class="text-weight-bold text-caption q-ml-xs"
                  >
                    {{
                      stock.is_allocated_to_tenant
                        ? 'Your allocation'
                        : stock.holding_tenant_name || 'Parent pool'
                    }}
                  </q-badge>
                </div>
                <q-item-label caption class="text-grey-6 row items-center q-gutter-xs q-mt-xs">
                  <span v-if="stock.barcode">Barcode: {{ stock.barcode }}</span>
                  <span v-if="stock.barcode && stock.shipment_name">•</span>
                  <span v-if="stock.shipment_name">Shipment: {{ stock.shipment_name }}</span>
                  <span>•</span>
                  <span>Received: {{ formatDate(stock.stock_created_at) }}</span>
                </q-item-label>
              </q-item-section>

              <q-item-section side class="items-end">
                <div class="row items-center q-gutter-sm">
                  <div class="text-right">
                    <div class="text-caption text-weight-bold text-teal-9">
                      {{ stock.available_atp }} in stock
                    </div>
                    <div class="text-caption text-grey-6">
                      {{ formatMoney(stock.suggested_sell_price || stock.unit_cost_price || 0) }}
                    </div>
                  </div>
                  <q-btn
                    dense
                    unelevated
                    size="sm"
                    :color="isItemAlreadyAdded(stock.global_stock_id) ? 'grey-3' : 'teal-7'"
                    :text-color="isItemAlreadyAdded(stock.global_stock_id) ? 'grey-7' : 'white'"
                    :icon="isItemAlreadyAdded(stock.global_stock_id) ? 'ph ph-check' : 'ph ph-plus'"
                    :label="isItemAlreadyAdded(stock.global_stock_id) ? 'Added' : 'Add'"
                    no-caps
                    class="text-weight-bold q-px-sm"
                    :disable="isItemAlreadyAdded(stock.global_stock_id)"
                    @click.stop="emit('add-stock', stock)"
                  />
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-menu>
      </q-input>
    </section>

    <div class="invoice-paper__divider" />

    <section>
      <div class="invoice-paper__section-label q-mb-sm">Line items</div>

      <div
        v-if="!invoiceItems.length"
        class="invoice-paper__empty"
      >
        <q-icon name="ph ph-shopping-cart" size="36px" class="text-grey-5 q-mb-sm" />
        <div class="text-weight-bold text-grey-7">No items on this invoice yet</div>
        <div class="text-caption text-grey-5 q-mt-xs">
          Search stock above to add products
        </div>
      </div>

      <div v-else class="invoice-paper__table-wrap">
        <table class="invoice-paper__table">
          <thead>
            <tr>
              <th class="col-sl">#</th>
              <th class="col-thumb"></th>
              <th class="col-item">Item</th>
              <th class="col-qty">ATP</th>
              <th class="col-money">Cost</th>
              <th class="col-money">Rate</th>
              <th class="col-qty">Qty</th>
              <th v-if="hasReturnedItems" class="col-qty">Returned</th>
              <th class="col-money">Discount</th>
              <th class="col-money">Line total</th>
              <th class="col-action"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, index) in invoiceItems" :key="item.global_stock_id">
              <td class="col-sl">{{ index + 1 }}</td>
              <td class="col-thumb">
                <div class="invoice-paper__thumb">
                  <img v-if="item.image_url" :src="item.image_url" alt="" />
                  <q-icon v-else name="ph ph-image" color="grey-5" size="18px" />
                </div>
              </td>
              <td class="col-item">
                <div class="invoice-paper__item-name">{{ item.name }}</div>
                <div
                  v-if="item.barcode || item.product_code"
                  class="invoice-paper__item-meta"
                >
                  <span v-if="item.barcode">Barcode {{ item.barcode }}</span>
                  <span v-if="item.barcode && item.product_code"> · </span>
                  <span v-if="item.product_code">Code {{ item.product_code }}</span>
                </div>
              </td>
              <td class="col-qty">{{ item.available_atp }}</td>
              <td class="col-money">{{ formatMoney(item.unit_cost_price || 0) }}</td>
              <td class="col-money">
                <q-input
                  v-model.number="item.sell_price_amount"
                  type="number"
                  outlined
                  dense
                  hide-bottom-space
                  min="0"
                  step="0.01"
                  class="invoice-paper__cell-input"
                  input-class="text-right"
                />
              </td>
              <td class="col-qty">
                <q-input
                  v-model.number="item.quantity"
                  type="number"
                  outlined
                  dense
                  hide-bottom-space
                  min="1"
                  :max="item.available_atp"
                  class="invoice-paper__cell-input invoice-paper__cell-input--qty"
                  input-class="text-center"
                />
              </td>
              <td v-if="hasReturnedItems" class="col-qty">
                <template v-if="(item.return_quantity || 0) > 0">
                  <div class="text-weight-bold">{{ item.return_quantity }}</div>
                  <div class="invoice-paper__item-meta">
                    Kept {{ item.quantity - item.return_quantity }}
                  </div>
                </template>
                <span v-else class="text-grey-5">—</span>
              </td>
              <td class="col-money">
                <q-input
                  v-model.number="item.line_discount_amount"
                  type="number"
                  outlined
                  dense
                  hide-bottom-space
                  min="0"
                  step="0.01"
                  class="invoice-paper__cell-input"
                  input-class="text-right"
                />
              </td>
              <td class="col-money text-weight-bold">
                <template v-if="(item.return_quantity || 0) > 0">
                  <div class="invoice-paper__item-meta text-strike">
                    {{ formatMoney(calculateLineGross(item)) }}
                  </div>
                  <div>{{ formatMoney(calculateLineTotal(item)) }}</div>
                </template>
                <template v-else>
                  {{ formatMoney(calculateLineTotal(item)) }}
                </template>
              </td>
              <td class="col-action">
                <q-btn
                  flat
                  round
                  dense
                  color="negative"
                  icon="ph ph-trash"
                  size="sm"
                  aria-label="Remove item"
                  @click="emit('remove-item', index)"
                >
                  <q-tooltip>Remove item</q-tooltip>
                </q-btn>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <template v-if="invoiceItems.length">
      <div class="invoice-paper__divider" />

      <section class="invoice-paper__summary">
        <div class="invoice-paper__summary-grid">
          <div class="invoice-paper__summary-row">
            <span>Total items</span>
            <span>{{ invoiceItems.length }}</span>
          </div>
          <div class="invoice-paper__summary-row">
            <span>Total units</span>
            <span>{{ totalQuantity }}</span>
          </div>
          <div v-if="hasReturnedItems" class="invoice-paper__summary-row">
            <span>Returned units</span>
            <span>{{ totalReturnQuantity }}</span>
          </div>
          <div class="invoice-paper__summary-row">
            <span>Subtotal</span>
            <span>{{ formatMoney(subtotalAmount) }}</span>
          </div>
          <div class="invoice-paper__summary-row invoice-paper__summary-row--editable">
            <span>Overall discount</span>
            <q-input
              v-model.number="overallDiscountInput"
              type="number"
              outlined
              dense
              hide-bottom-space
              min="0"
              step="0.01"
              placeholder="0.00"
              class="invoice-paper__amount-input"
              input-class="text-right"
              :disable="overallDiscountLocked"
              @update:model-value="(val) => emit('apply-overall-discount', val)"
            />
          </div>
          <div v-if="totalReturnCredit > 0" class="invoice-paper__summary-row text-negative">
            <span>Return credit</span>
            <span>−{{ formatMoney(totalReturnCredit) }}</span>
          </div>
          <div v-if="totalDiscountAmount > 0" class="invoice-paper__summary-row text-negative">
            <span>Total discount</span>
            <span>−{{ formatMoney(totalDiscountAmount) }}</span>
          </div>
          <div class="invoice-paper__summary-row invoice-paper__summary-row--grand">
            <span>Invoice total</span>
            <span>{{ formatMoney(grandTotalAmount) }}</span>
          </div>
        </div>
      </section>
    </template>
  </article>
</template>

<style scoped lang="scss">
@import '../styles/invoice-paper.scss';
</style>

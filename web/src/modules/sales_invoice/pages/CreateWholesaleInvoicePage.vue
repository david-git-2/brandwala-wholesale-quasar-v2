<template>
  <q-page class="create-wholesale-invoice-page q-pa-md">
    <div class="column no-wrap full-width" style="max-width: 1500px; margin: 0 auto">
      <!-- 1. Top Header Toolbar -->
      <div class="row items-center justify-between q-mb-sm">
        <div class="row items-center q-gutter-sm">
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-left"
            size="md"
            class="text-grey-8"
            @click="goBack"
          >
            <q-tooltip>Back to Invoices</q-tooltip>
          </q-btn>
          <div>
            <div class="text-h6 text-weight-bold text-grey-9 row items-center q-gutter-xs">
              <span>Create Wholesale Invoice</span>
              <q-badge color="purple-1" text-color="purple-9" label="Wholesale B2B" class="text-weight-bold q-ml-sm" />
            </div>
          </div>
        </div>

        <div class="row items-center q-gutter-sm">
          <q-btn
            flat
            no-caps
            label="Cancel"
            class="text-grey-8 text-weight-medium"
            @click="goBack"
          />

          <!-- Save Invoice Button opening status options menu on click -->
          <div class="relative-position">
            <q-btn-dropdown
              unelevated
              color="primary"
              icon="ph ph-floppy-disk"
              label="Save Invoice"
              no-caps
              class="action-btn text-weight-bold"
              :disable="!canSaveDraft || isSaving"
              :loading="isSaving"
            >
              <q-list dense style="min-width: 250px" class="q-py-xs">
                <q-item
                  clickable
                  v-close-popup
                  class="q-py-sm"
                  @click="handleSaveInvoice('draft')"
                >
                  <q-item-section avatar min-width="32px">
                    <q-avatar size="28px" color="grey-2" text-color="grey-9" icon="ph ph-file-dashed" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold">Save as Draft</q-item-label>
                    <q-item-label caption class="text-grey-6">Default (ATP held, no stock deduct)</q-item-label>
                  </q-item-section>
                </q-item>

                <q-item
                  clickable
                  v-close-popup
                  class="q-py-sm"
                  @click="handleSaveInvoice('proforma_generated')"
                >
                  <q-item-section avatar min-width="32px">
                    <q-avatar size="28px" color="blue-1" text-color="blue-9" icon="ph ph-file-text" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-blue-9">Proforma Generated</q-item-label>
                    <q-item-label caption class="text-grey-6">Quotation sent to customer</q-item-label>
                  </q-item-section>
                </q-item>

                <q-item
                  clickable
                  v-close-popup
                  class="q-py-sm"
                  @click="handleSaveInvoice('issued')"
                >
                  <q-item-section avatar min-width="32px">
                    <q-avatar size="28px" color="green-1" text-color="positive" icon="ph ph-check-circle" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-positive">Save & Issue Invoice</q-item-label>
                    <q-item-label caption class="text-grey-6">Deduct stock & post to AR</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-btn-dropdown>

            <!-- Tooltip indicating exact missing steps when button is disabled -->
            <q-tooltip v-if="!canSaveDraft" anchor="bottom middle" self="top middle" class="bg-grey-9 text-caption shadow-4">
              <div class="text-weight-bold q-mb-xs text-amber-3">Complete required fields to save:</div>
              <div v-for="(reason, rIdx) in validationReasons" :key="rIdx" class="q-py-xxs text-white">
                • {{ reason }}
              </div>
            </q-tooltip>
          </div>
        </div>
      </div>

      <!-- 2. Top Selectors Row: 1. Brand & 2. Billing Profile Side-by-Side -->
      <q-card flat bordered class="section-card rounded-borders-12 q-pa-sm q-mb-md">
        <div class="row q-col-gutter-md items-center">
          <!-- Selector 1: Invoice Brand -->
          <div class="col-12 col-sm-6">
            <div class="row items-center justify-between q-mb-xs">
              <div class="text-caption text-weight-bold text-grey-8 row items-center q-gutter-xs">
                <q-icon name="ph ph-paint-brush" color="primary" size="16px" />
                <span>1. Invoice Brand</span>
              </div>
              <span class="text-caption text-grey-5 ellipsis" v-if="selectedBrand?.address">
                {{ selectedBrand.address }}
              </span>
            </div>
            <q-select
              v-model="selectedBrandId"
              :options="brandOptions"
              option-value="id"
              option-label="name"
              emit-value
              map-options
              outlined
              dense
              label="Select Brand *"
              class="brand-select"
              :loading="brandsQuery.isLoading.value"
              :disable="brandsQuery.isLoading.value"
            >
              <template #prepend>
                <q-icon name="ph ph-paint-brush" size="16px" class="text-grey-6" />
              </template>

              <template #option="scope">
                <q-item v-bind="scope.itemProps" class="q-py-xs">
                  <q-item-section avatar min-width="28px">
                    <q-avatar size="24px" color="grey-3" text-color="grey-9" class="text-caption text-weight-bold">
                      {{ scope.opt.name?.slice(0, 2).toUpperCase() }}
                    </q-avatar>
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-medium">{{ scope.opt.name }}</q-item-label>
                    <q-item-label caption class="text-grey-6 ellipsis" v-if="scope.opt.address">
                      {{ scope.opt.address }}
                    </q-item-label>
                  </q-item-section>
                </q-item>
              </template>
            </q-select>
          </div>

          <!-- Selector 2: Billing Profile (Customer) -->
          <div class="col-12 col-sm-6">
            <div class="row items-center justify-between q-mb-xs">
              <div class="text-caption text-weight-bold text-grey-8 row items-center q-gutter-xs">
                <q-icon name="ph ph-users" color="purple-7" size="16px" />
                <span>2. Billing Profile (Customer)</span>
              </div>
              <q-badge
                v-if="creatorTenantName"
                color="purple-1"
                text-color="purple-9"
                class="text-caption text-weight-medium"
              >
                Created by: {{ creatorTenantName }}
              </q-badge>
            </div>
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
              label="Select Billing Profile *"
              class="billing-profile-select"
              :loading="billingProfilesQuery.isLoading.value"
              :disable="billingProfilesQuery.isLoading.value"
              @filter="filterBillingProfiles"
            >
              <template #prepend>
                <q-icon name="ph ph-user" size="16px" class="text-grey-6" />
              </template>

              <template #no-option>
                <q-item>
                  <q-item-section class="text-grey-6 text-caption text-center q-py-sm">
                    No billing profiles found
                  </q-item-section>
                </q-item>
              </template>

              <template #option="scope">
                <q-item v-bind="scope.itemProps" class="q-py-xs">
                  <q-item-section avatar min-width="28px">
                    <q-avatar size="24px" color="purple-1" text-color="purple-9" class="text-caption text-weight-bold">
                      {{ scope.opt.name?.slice(0, 2).toUpperCase() }}
                    </q-avatar>
                  </q-item-section>
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
          </div>
        </div>
      </q-card>

      <!-- 3. Full-Width Main Area: 3. Invoice Items & Live Stock Search Menu -->
      <q-card flat bordered class="section-card rounded-borders-12 full-width column">
        <q-card-section class="q-pb-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <!-- Section Title & Badge -->
            <div class="row items-center q-gutter-sm col-12 col-md-5">
              <q-avatar size="32px" color="teal-7" text-color="white" icon="ph ph-package" />
              <div>
                <div class="row items-center q-gutter-xs">
                  <span class="text-subtitle2 text-weight-bold text-grey-9">3. Invoice Items</span>
                  <q-chip
                    :color="invoiceItems.length ? 'teal-1' : 'grey-2'"
                    :text-color="invoiceItems.length ? 'teal-9' : 'grey-7'"
                    size="sm"
                    class="text-weight-bold"
                  >
                    {{ invoiceItems.length }} {{ invoiceItems.length === 1 ? 'Item' : 'Items' }} ({{ totalQuantity }} units)
                  </q-chip>
                </div>
                <div class="text-caption text-grey-6">
                  FIFO sorted & tenant allocation prioritized
                </div>
              </div>
            </div>

            <!-- Direct Stock Search Bar with Popup Menu Results -->
            <div class="col-12 col-md-7 row items-center justify-end">
              <q-input
                ref="stockSearchInputRef"
                v-model="stockSearchText"
                outlined
                rounded
                dense
                placeholder="Search stock by name, barcode, product code..."
                class="stock-search-input full-width"
                style="max-width: 440px"
                @update:model-value="onStockSearchInput"
                @focus="onSearchFocus"
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-6" />
                </template>
                <template #append v-if="stockSearchText">
                  <q-icon
                    name="ph ph-x-circle"
                    size="16px"
                    class="cursor-pointer text-grey-5"
                    @click="clearStockSearch"
                  />
                </template>

                <!-- Search Results Popup Menu -->
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
                    <!-- Loading State -->
                    <q-item v-if="isSearchingStock" class="q-py-md text-center">
                      <q-item-section>
                        <div class="row items-center justify-center q-gutter-sm text-grey-6 text-caption">
                          <q-spinner color="teal-7" size="20px" />
                          <span>Searching stock inventory...</span>
                        </div>
                      </q-item-section>
                    </q-item>

                    <!-- Empty Results State -->
                    <q-item v-else-if="!stockSearchResults.length" class="q-py-md text-center">
                      <q-item-section>
                        <div class="text-caption text-grey-6">
                          No available stock found for <strong>"{{ stockSearchText }}"</strong>
                        </div>
                      </q-item-section>
                    </q-item>

                    <!-- Stock Items Results List -->
                    <q-item
                      v-for="stock in stockSearchResults"
                      :key="stock.global_stock_id"
                      clickable
                      class="stock-menu-item q-py-sm"
                      :class="{ 'allocated-menu-row': stock.is_allocated_to_tenant }"
                      @click="addStockToInvoice(stock)"
                    >
                      <!-- Thumbnail / Icon -->
                      <q-item-section avatar min-width="40px">
                        <q-avatar size="36px" rounded color="grey-2" class="overflow-hidden">
                          <img v-if="stock.image_url" :src="stock.image_url" alt="" />
                          <q-icon v-else name="ph ph-package" color="grey-6" size="20px" />
                        </q-avatar>
                      </q-item-section>

                      <!-- Item Info -->
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
                            {{ stock.is_allocated_to_tenant ? 'Your Allocation' : (stock.holding_tenant_name || 'Parent Pool') }}
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

                      <!-- ATP & Price Details & Add Button -->
                      <q-item-section side class="items-end">
                        <div class="row items-center q-gutter-sm">
                          <div class="text-right">
                            <div class="text-caption text-weight-bold text-teal-9">
                              {{ stock.available_atp }} in stock
                            </div>
                            <div class="text-caption text-grey-6">
                              ৳{{ (stock.suggested_sell_price || stock.unit_cost_price)?.toFixed(2) }}
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
                            @click.stop="addStockToInvoice(stock)"
                          />
                        </div>
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-input>
            </div>
          </div>
        </q-card-section>

        <q-separator />

        <!-- Empty Items State -->
        <q-card-section v-if="!invoiceItems.length" class="col column justify-center items-center q-py-xl">
          <div class="placeholder-box text-center q-pa-xl rounded-borders-8 full-width" style="max-width: 550px">
            <q-icon name="ph ph-shopping-cart" size="44px" class="text-grey-4 q-mb-sm" />
            <div class="text-subtitle1 text-weight-bold text-grey-7">No items added to invoice yet</div>
            <div class="text-caption text-grey-5 q-mt-xs">
              Use the search bar above to search stock and add items to this invoice
            </div>
          </div>
        </q-card-section>

        <!-- Items Table View -->
        <div v-else class="col column justify-between">
          <q-markup-table flat wrap-cells dense class="invoice-items-table full-width">
            <thead>
              <tr>
                <th class="text-left" style="min-width: 280px">Item Details</th>
                <th class="text-center" style="width: 120px">Available (ATP)</th>
                <th class="text-right" style="width: 120px">Unit Cost</th>
                <th class="text-right" style="width: 140px">Sell Price (BDT) *</th>
                <th class="text-center" style="width: 120px">Qty *</th>
                <th class="text-right" style="width: 130px">Discount (BDT)</th>
                <th class="text-right" style="width: 140px">Line Total (BDT)</th>
                <th class="text-center" style="width: 50px"></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(item, index) in invoiceItems" :key="item.global_stock_id" class="item-row">
                <!-- Item Details -->
                <td>
                  <div class="row items-center no-wrap q-gutter-sm">
                    <q-avatar size="40px" rounded color="grey-2" class="overflow-hidden">
                      <img v-if="item.image_url" :src="item.image_url" alt="" />
                      <q-icon v-else name="ph ph-image" color="grey-5" size="22px" />
                    </q-avatar>
                    <div>
                      <div class="text-body2 text-weight-bold text-grey-9">{{ item.name }}</div>
                      <div class="text-caption text-grey-6 row items-center q-gutter-xs">
                        <span v-if="item.barcode">Barcode: {{ item.barcode }}</span>
                        <span v-if="item.barcode && item.product_code">•</span>
                        <span v-if="item.product_code">Code: {{ item.product_code }}</span>
                      </div>
                    </div>
                  </div>
                </td>

                <!-- Available ATP -->
                <td class="text-center">
                  <q-chip dense square color="blue-1" text-color="blue-9" class="text-weight-bold text-caption">
                    {{ item.available_atp }} units
                  </q-chip>
                </td>

                <!-- Unit Cost -->
                <td class="text-right text-caption text-grey-7">
                  ৳{{ item.unit_cost_price?.toFixed(2) }}
                </td>

                <!-- Sell Price Input -->
                <td class="text-right">
                  <q-input
                    v-model.number="item.sell_price_amount"
                    type="number"
                    outlined
                    dense
                    min="0"
                    step="0.01"
                    class="table-input"
                  />
                </td>

                <!-- Quantity Input -->
                <td class="text-center">
                  <q-input
                    v-model.number="item.quantity"
                    type="number"
                    outlined
                    dense
                    min="1"
                    :max="item.available_atp"
                    class="table-input"
                  />
                </td>

                <!-- Line Discount Input -->
                <td class="text-right">
                  <q-input
                    v-model.number="item.line_discount_amount"
                    type="number"
                    outlined
                    dense
                    min="0"
                    step="0.01"
                    class="table-input"
                  />
                </td>

                <!-- Line Total Amount -->
                <td class="text-right text-weight-bold text-grey-9 text-body2">
                  ৳{{ calculateLineTotal(item).toFixed(2) }}
                </td>

                <!-- Remove Action -->
                <td class="text-center">
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="ph ph-trash"
                    size="sm"
                    @click="removeInvoiceItem(index)"
                  >
                    <q-tooltip>Remove Item</q-tooltip>
                  </q-btn>
                </td>
              </tr>
            </tbody>
          </q-markup-table>

          <!-- Totals Summary Bar -->
          <div class="totals-summary-bar q-pa-md bg-grey-1 row items-center justify-between">
            <div class="row items-center q-gutter-md">
              <div class="text-caption text-grey-7">
                Total Items: <strong class="text-grey-9">{{ invoiceItems.length }}</strong>
              </div>
              <div class="text-caption text-grey-7">
                Total Units: <strong class="text-grey-9">{{ totalQuantity }}</strong>
              </div>
            </div>

            <div class="row items-center q-gutter-md">
              <div class="text-caption text-grey-7">
                Subtotal: <strong class="text-grey-9">৳{{ subtotalAmount.toFixed(2) }}</strong>
              </div>

              <!-- Overall Discount Input -->
              <div class="row items-center q-gutter-xs">
                <span class="text-caption text-grey-7">Overall Discount:</span>
                <q-input
                  v-model.number="overallDiscountInput"
                  type="number"
                  outlined
                  dense
                  min="0"
                  step="0.01"
                  placeholder="0.00"
                  style="width: 120px"
                  class="bg-white"
                  @update:model-value="applyOverallDiscountEqually"
                >
                  <template #prepend>
                    <span class="text-caption text-grey-6">৳</span>
                  </template>
                </q-input>
              </div>

              <div class="text-caption text-negative" v-if="totalDiscountAmount > 0">
                Total Discount: <strong>-৳{{ totalDiscountAmount.toFixed(2) }}</strong>
              </div>

              <div class="text-subtitle1 text-weight-bold text-primary">
                Invoice Total: ৳{{ grandTotalAmount.toFixed(2) }}
              </div>
            </div>
          </div>
        </div>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import {
  invoiceRepository,
  type InvoiceBrand,
  type SalesInvoiceStockItem,
} from '../repositories/invoiceRepository';
import type { BillingProfile } from '../repositories/billingProfileRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';

type BillingProfileWithTenant = BillingProfile & {
  tenant?: { id: number; name: string; slug: string } | null;
  parent_tenant?: { id: number; name: string; slug: string } | null;
};

export interface InvoiceLineDraftItem {
  global_stock_id: number;
  shipment_item_id: number;
  product_id: number | null;
  name: string;
  barcode: string | null;
  product_code: string | null;
  image_url: string | null;
  quantity: number;
  available_atp: number;
  unit_cost_price: number;
  sell_price_amount: number;
  line_discount_amount: number;
  shipment_id: number;
  shipment_name: string;
  holding_tenant_id: number;
  holding_tenant_name: string;
  is_allocated_to_tenant: boolean;
}

const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

const effectiveTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  if (!current) return authStore.tenantId;
  return current.id;
});

const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  return current?.parent_id ?? current?.id ?? authStore.tenantId;
});

// 1. Query Invoice Brands
const brandsQuery = useQuery({
  queryKey: computed(() => salesInvoiceQueryKeys.brands(effectiveTenantId.value)),
  queryFn: async () => {
    let query = supabase.from('invoice_brands').select('*');
    if (effectiveTenantId.value && effectiveParentTenantId.value && effectiveTenantId.value !== effectiveParentTenantId.value) {
      query = query.or(`tenant_id.eq.${effectiveTenantId.value},tenant_id.eq.${effectiveParentTenantId.value}`);
    } else if (effectiveTenantId.value) {
      query = query.eq('tenant_id', effectiveTenantId.value);
    }
    const { data, error } = await query.order('name', { ascending: true });
    if (error) {
      console.error('Error fetching invoice brands:', error);
      return [];
    }
    return (data || []) as InvoiceBrand[];
  },
  placeholderData: (prev) => prev,
});

const brands = computed(() => brandsQuery.data.value ?? []);
const brandOptions = computed(() => brands.value);
const selectedBrandId = ref<number | null>(null);

const selectedBrand = computed<InvoiceBrand | null>(
  () => brands.value.find((b) => b.id === selectedBrandId.value) || null,
);

// Auto-select if only 1 brand exists
watch(
  brands,
  (loadedBrands) => {
    if (!selectedBrandId.value && loadedBrands.length === 1 && loadedBrands[0]) {
      selectedBrandId.value = loadedBrands[0].id;
    }
  },
  { immediate: true },
);

// 2. Query Billing Profiles (Customers) with Tenant metadata
const billingProfilesQuery = useQuery({
  queryKey: computed(() =>
    salesInvoiceQueryKeys.billingProfiles(effectiveTenantId.value, {
      parentTenantId: effectiveParentTenantId.value,
    }),
  ),
  queryFn: async () => {
    let query = supabase
      .from('billing_profiles')
      .select('*, tenant:tenant_id(id, name, slug), parent_tenant:parent_tenant_id(id, name, slug)');

    if (effectiveParentTenantId.value) {
      query = query.or(
        `parent_tenant_id.eq.${effectiveParentTenantId.value},tenant_id.eq.${effectiveParentTenantId.value}`,
      );
    } else if (effectiveTenantId.value) {
      query = query.eq('tenant_id', effectiveTenantId.value);
    }

    const { data, error } = await query.order('name', { ascending: true });
    if (error) throw error;
    return (data || []) as BillingProfileWithTenant[];
  },
  enabled: computed(() => !!effectiveTenantId.value),
  placeholderData: (prev) => prev,
});

const billingProfiles = computed(() => billingProfilesQuery.data.value ?? []);
const billingProfileFilterText = ref('');
const selectedBillingProfileId = ref<number | null>(null);

const billingProfileOptions = computed(() => {
  const needle = billingProfileFilterText.value.trim().toLowerCase();
  if (!needle) return billingProfiles.value;
  return billingProfiles.value.filter(
    (p) =>
      p.name.toLowerCase().includes(needle) ||
      (p.phone && p.phone.toLowerCase().includes(needle)) ||
      (p.email && p.email.toLowerCase().includes(needle)) ||
      (p.tenant?.name && p.tenant.name.toLowerCase().includes(needle)),
  );
});

const filterBillingProfiles = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    billingProfileFilterText.value = val;
  });
};

const selectedBillingProfile = computed<BillingProfileWithTenant | null>(
  () => billingProfiles.value.find((p) => p.id === selectedBillingProfileId.value) || null,
);

const creatorTenantName = computed(() => {
  if (!selectedBillingProfile.value) return null;
  if (selectedBillingProfile.value.tenant?.name) {
    return selectedBillingProfile.value.tenant.name;
  }
  const match = tenantStore.items.find((t) => t.id === selectedBillingProfile.value?.tenant_id);
  return match?.name || (selectedBillingProfile.value.tenant_id ? `Workspace #${selectedBillingProfile.value.tenant_id}` : null);
});

// 3. Invoice Items & Live Stock Search Menu
const invoiceItems = ref<InvoiceLineDraftItem[]>([]);
const stockSearchText = ref('');
const stockMenuOpen = ref(false);
const isSearchingStock = ref(false);
const stockSearchResults = ref<SalesInvoiceStockItem[]>([]);
let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

const performStockSearch = async () => {
  const tenantId = effectiveTenantId.value;
  if (!tenantId) return;

  isSearchingStock.value = true;
  try {
    const results = await invoiceRepository.searchSalesInvoiceStock({
      tenantId,
      search: stockSearchText.value,
      limit: 30,
    });
    stockSearchResults.value = results;
    stockMenuOpen.value = true;
  } catch (err) {
    console.error('Error searching stock:', err);
    stockSearchResults.value = [];
  } finally {
    isSearchingStock.value = false;
  }
};

const onStockSearchInput = () => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(() => {
    void performStockSearch();
  }, 250);
};

const onSearchFocus = () => {
  if (!stockSearchResults.value.length) {
    void performStockSearch();
  } else {
    stockMenuOpen.value = true;
  }
};

const clearStockSearch = () => {
  stockSearchText.value = '';
  void performStockSearch();
};

const isItemAlreadyAdded = (stockId: number) => {
  return invoiceItems.value.some((item) => item.global_stock_id === stockId);
};

const addStockToInvoice = (stock: SalesInvoiceStockItem) => {
  if (isItemAlreadyAdded(stock.global_stock_id)) return;

  const cost = Number(stock.unit_cost_price) || 0;
  // Default prefill is 20% markup over unit cost price (user can edit freely)
  const defaultSellPrice = cost > 0 ? Math.round(cost * 1.2 * 100) / 100 : (Number(stock.suggested_sell_price) || 0);

  invoiceItems.value.push({
    global_stock_id: stock.global_stock_id,
    shipment_item_id: stock.shipment_item_id,
    product_id: stock.product_id,
    name: stock.name,
    barcode: stock.barcode,
    product_code: stock.product_code,
    image_url: stock.image_url,
    quantity: 1,
    available_atp: Number(stock.available_atp) || 1,
    unit_cost_price: cost,
    sell_price_amount: Number(defaultSellPrice) || 0,
    line_discount_amount: 0,
    shipment_id: stock.shipment_id,
    shipment_name: stock.shipment_name,
    holding_tenant_id: stock.holding_tenant_id,
    holding_tenant_name: stock.holding_tenant_name,
    is_allocated_to_tenant: stock.is_allocated_to_tenant,
  });
};

const removeInvoiceItem = (index: number) => {
  invoiceItems.value.splice(index, 1);
};

const calculateLineTotal = (item: InvoiceLineDraftItem): number => {
  const sub = (item.quantity || 0) * (item.sell_price_amount || 0);
  const total = sub - (item.line_discount_amount || 0);
  return Math.max(0, total);
};

const overallDiscountInput = ref<number | null>(null);

const applyOverallDiscountEqually = (val: number | null) => {
  const count = invoiceItems.value.length;
  if (!count) return;

  const totalDiscount = Number(val) || 0;
  if (totalDiscount <= 0) {
    invoiceItems.value.forEach((item) => {
      item.line_discount_amount = 0;
    });
    return;
  }

  // Distribute equally across items, with cent rounding remainder applied to the first item
  const baseLineDiscount = Math.floor((totalDiscount / count) * 100) / 100;
  const remainder = Math.round((totalDiscount - baseLineDiscount * count) * 100) / 100;

  invoiceItems.value.forEach((item, index) => {
    const extra = index === 0 ? remainder : 0;
    const allocated = baseLineDiscount + extra;
    const maxDiscount = (item.quantity || 0) * (item.sell_price_amount || 0);
    item.line_discount_amount = Math.min(maxDiscount, Math.max(0, Math.round(allocated * 100) / 100));
  });
};

const totalQuantity = computed(() =>
  invoiceItems.value.reduce((acc, item) => acc + (Number(item.quantity) || 0), 0),
);

const subtotalAmount = computed(() =>
  invoiceItems.value.reduce(
    (acc, item) => acc + (Number(item.quantity) || 0) * (Number(item.sell_price_amount) || 0),
    0,
  ),
);

const totalDiscountAmount = computed(() =>
  invoiceItems.value.reduce((acc, item) => acc + (Number(item.line_discount_amount) || 0), 0),
);

const grandTotalAmount = computed(() => Math.max(0, subtotalAmount.value - totalDiscountAmount.value));

// Save Invoice States (Default: Draft)
export type WholesaleInvoiceSaveStatus = 'draft' | 'proforma_generated' | 'issued';
const isSaving = ref(false);

const handleSaveInvoice = async (status: WholesaleInvoiceSaveStatus) => {
  if (!canSaveDraft.value || isSaving.value) return;

  const tenantId = effectiveTenantId.value;
  const parentTenantId = effectiveParentTenantId.value;
  if (!tenantId || !parentTenantId || !selectedBillingProfileId.value) return;

  isSaving.value = true;
  try {
    // Generate invoice number
    const invoiceNo = await invoiceRepository.generateInvoiceNumber(
      tenantId,
      'wholesale',
    );

    // Create the global invoice record
    const createdInvoice = await invoiceRepository.createGlobalInvoice({
      tenant_id: tenantId,
      invoice_no: invoiceNo,
      invoice_type: 'wholesale',
      invoice_date: new Date().toISOString().slice(0, 10),
      billing_profile_id: selectedBillingProfileId.value,
    });

    if (createdInvoice?.id) {
      // Add invoice line items
      for (const item of invoiceItems.value) {
        await invoiceRepository.addGlobalInvoiceItem({
          invoice_id: createdInvoice.id,
          global_stock_id: item.global_stock_id,
          quantity: item.quantity,
          sell_price_amount: item.sell_price_amount,
          line_discount_amount: item.line_discount_amount || 0,
        });
      }

      // If chosen status is issued, call postGlobalInvoice
      if (status === 'issued') {
        await invoiceRepository.postGlobalInvoice(createdInvoice.id);
      }
    }

    void router.push({
      name: 'app-global-invoices-overview',
      params: {
        tenantSlug: authStore.tenantSlug || '',
      },
    });
  } catch (err) {
    console.error('Error saving wholesale invoice:', err);
  } finally {
    isSaving.value = false;
  }
};

const validationReasons = computed(() => {
  const reasons: string[] = [];
  if (!selectedBrandId.value) reasons.push('1. Select an Invoice Brand');
  if (!selectedBillingProfileId.value) reasons.push('2. Select a Customer Billing Profile');
  if (!invoiceItems.value.length) reasons.push('3. Add at least 1 item from stock');
  return reasons;
});

const canSaveDraft = computed(() => validationReasons.value.length === 0);

const formatDate = (dateStr: string) => {
  if (!dateStr) return '';
  return dateStr.slice(0, 10);
};

const goBack = () => {
  void router.push({
    name: 'app-global-invoices-overview',
    params: {
      tenantSlug: authStore.tenantSlug || '',
    },
  });
};
</script>

<style scoped>
.create-wholesale-invoice-page {
  background-color: var(--q-page-bg, #f8fafc);
  min-height: calc(100vh - 55px);
}

.rounded-borders-12 {
  border-radius: 12px;
}

.rounded-borders-8 {
  border-radius: 8px;
}

.section-card {
  background-color: #ffffff;
  border-color: #e2e8f0;
}

.placeholder-box {
  background-color: #f8fafc;
  border: 2px dashed #cbd5e1;
}

.totals-summary-bar {
  border-top: 1px solid #e2e8f0;
}

.table-input {
  max-width: 110px;
}

.stock-menu-item {
  transition: background-color 0.15s ease;
  border-bottom: 1px solid #f1f5f9;
}

.stock-menu-item:hover {
  background-color: #f8fafc;
}

.allocated-menu-row {
  background-color: #f0fdf4;
}

.action-btn {
  border-radius: 8px;
  min-height: 38px;
  padding: 0 16px;
}
</style>

<template>
  <q-page class="create-wholesale-invoice-page q-pa-md">
    <div class="column no-wrap full-width" style="max-width: 1500px; margin: 0 auto">
      <!-- 1. Top Header Toolbar -->
      <div class="row items-center justify-between q-mb-sm">
        <div class="text-h6 text-weight-bold text-grey-9 row items-center q-gutter-xs">
          <span>{{ isExistingInvoice ? `Wholesale Invoice #${loadedInvoiceNo || existingInvoiceId}` : 'Create Wholesale Invoice' }}</span>
          <q-badge color="purple-1" text-color="purple-9" label="Wholesale B2B" class="text-weight-bold q-ml-sm" />
        </div>

        <div class="row items-center q-gutter-sm">
          <!-- Preview Proforma Button: Only shown when status is proforma_generated -->
          <q-btn
            v-if="existingInvoiceId && loadedInvoiceStatus === 'proforma_generated'"
            outline
            color="primary"
            icon="ph ph-printer"
            label="Preview Proforma"
            no-caps
            class="action-btn text-weight-bold"
            @click="openPreview"
          >
            <q-tooltip>Preview and print proforma invoice</q-tooltip>
          </q-btn>

          <!-- 1. Initial State: Save as Draft Button -->
          <q-btn
            v-if="!existingInvoiceId"
            unelevated
            color="primary"
            icon="ph ph-floppy-disk"
            label="Save as Draft"
            no-caps
            class="action-btn text-weight-bold"
            :disable="!canSaveDraft || isSaving"
            :loading="isSaving"
            @click="handleSaveInvoice('draft')"
          >
            <q-tooltip v-if="!canSaveDraft" anchor="bottom middle" self="top middle" class="bg-grey-9 text-caption shadow-4">
              <div class="text-weight-bold q-mb-xs text-amber-3">Complete required fields to save:</div>
              <div v-for="(reason, rIdx) in validationReasons" :key="rIdx" class="q-py-xxs text-white">
                • {{ reason }}
              </div>
            </q-tooltip>
          </q-btn>
        </div>
      </div>

      <!-- 2. Dedicated Status Workflow Row (Draft -> PF -> Issued) -->
      <div v-if="existingInvoiceId" class="row items-center justify-between bg-white q-pa-xs q-px-sm rounded-borders-8 border-light q-mb-sm shadow-1">
        <div class="row items-center q-gutter-xs">
          <!-- Draft Status -->
          <q-btn
            :color="loadedInvoiceStatus === 'draft' ? 'grey-8' : 'grey-4'"
            :text-color="loadedInvoiceStatus === 'draft' ? 'white' : 'grey-8'"
            :unelevated="loadedInvoiceStatus === 'draft'"
            :outline="loadedInvoiceStatus !== 'draft'"
            dense
            no-caps
            class="q-px-sm text-caption text-weight-bold"
            :loading="isSaving && selectedSaveStatus === 'draft'"
            :disable="isSaving"
            @click="handleSaveInvoice('draft')"
          >
            <q-icon
              v-if="loadedInvoiceStatus === 'draft'"
              name="ph ph-check-circle"
              size="13px"
              class="q-mr-xs"
            />
            Saved as Draft
          </q-btn>

          <q-icon name="ph ph-caret-right" color="grey-5" size="14px" />

          <!-- Proforma Status -->
          <q-btn
            :color="loadedInvoiceStatus === 'proforma_generated' ? 'primary' : 'grey-4'"
            :text-color="loadedInvoiceStatus === 'proforma_generated' ? 'white' : 'primary'"
            :unelevated="loadedInvoiceStatus === 'proforma_generated'"
            :outline="loadedInvoiceStatus !== 'proforma_generated'"
            dense
            no-caps
            class="q-px-sm text-caption text-weight-bold"
            :loading="isSaving && selectedSaveStatus === 'proforma_generated'"
            :disable="isSaving"
            @click="handleSaveInvoice('proforma_generated')"
          >
            <q-icon
              v-if="loadedInvoiceStatus === 'proforma_generated'"
              name="ph ph-check-circle"
              size="13px"
              class="q-mr-xs"
            />
            {{ loadedInvoiceStatus === 'proforma_generated' ? 'PF Generated' : 'Save as PF' }}
          </q-btn>

          <q-icon name="ph ph-caret-right" color="grey-5" size="14px" />

          <!-- Issued Status -->
          <q-btn
            :color="loadedInvoiceStatus === 'issued' ? 'positive' : 'grey-4'"
            :text-color="loadedInvoiceStatus === 'issued' ? 'white' : 'positive'"
            :unelevated="loadedInvoiceStatus === 'issued'"
            :outline="loadedInvoiceStatus !== 'issued'"
            dense
            no-caps
            class="q-px-sm text-caption text-weight-bold"
            :loading="isSaving && selectedSaveStatus === 'issued'"
            :disable="isSaving || loadedInvoiceStatus === 'issued'"
            @click="handleSaveInvoice('issued')"
          >
            <q-icon
              v-if="loadedInvoiceStatus === 'issued'"
              name="ph ph-check-circle"
              size="13px"
              class="q-mr-xs"
            />
            {{ loadedInvoiceStatus === 'issued' ? 'ISSUED' : 'Save as ISSUED' }}
          </q-btn>

          <!-- Payment Status Button-like badge when Issued -->
          <template v-if="loadedInvoiceStatus === 'issued'">
            <q-separator vertical class="q-mx-xs" />
            <q-badge
              :color="
                effectivePaymentStatus === 'paid'
                  ? 'green-1'
                  : effectivePaymentStatus === 'partial'
                    ? 'blue-1'
                    : 'red-1'
              "
              :text-color="
                effectivePaymentStatus === 'paid'
                  ? 'green-9'
                  : effectivePaymentStatus === 'partial'
                    ? 'blue-9'
                    : 'red-9'
              "
              class="text-weight-bolder text-uppercase q-px-sm q-py-xs rounded-borders"
              style="font-size: 11px; height: 28px; line-height: 20px"
            >
              <q-icon
                :name="
                  effectivePaymentStatus === 'paid'
                    ? 'ph ph-check-circle'
                    : effectivePaymentStatus === 'partial'
                      ? 'ph ph-chart-pie'
                      : 'ph ph-clock'
                "
                size="13px"
                class="q-mr-xs"
              />
              PAYMENT: {{ effectivePaymentStatus }}
            </q-badge>
          </template>
        </div>

        <!-- Right Side: Process Return Button -->
        <div class="row items-center q-gutter-xs">
          <q-btn
            v-if="canRecordPayment"
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-money"
            label="Record Payment"
            class="q-px-sm text-caption text-weight-bold"
            @click="openCollectDialog"
          />
          <q-btn
            v-if="loadedInvoiceStatus === 'issued'"
            flat
            dense
            no-caps
            color="purple"
            icon="ph ph-arrow-u-down-left"
            label="Process Return"
            class="q-px-sm text-caption text-weight-bold"
            @click="goToProcessReturn"
          >
            <q-tooltip>Record wholesale item returns & issue credit note</q-tooltip>
          </q-btn>
        </div>
      </div>

      <!-- Dense Selectors Row: Brand & Billing Profile -->
      <div class="row q-col-gutter-sm items-center q-mb-sm">
        <!-- Selector 1: Invoice Brand -->
        <div class="col-12 col-sm-6">
          <q-select
            v-model="selectedBrandId"
            :options="brandOptions"
            option-value="id"
            option-label="name"
            emit-value
            map-options
            outlined
            dense
            label="Invoice Brand *"
            class="brand-select bg-white"
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
            label="Billing Profile (Customer) *"
            class="billing-profile-select bg-white"
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

      <!-- Main Area: Invoice Items & Live Stock Search Menu -->
      <q-card flat bordered class="section-card rounded-borders-12 full-width column">
        <div class="q-pa-xs">
          <!-- Direct Stock Search Bar with Popup Menu Results -->
          <q-input
            ref="stockSearchInputRef"
            v-model="stockSearchText"
            outlined
            rounded
            dense
            placeholder="Search stock by name, barcode, product code to add items..."
            class="stock-search-input full-width"
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
                <th v-if="hasReturnedItems" class="text-center" style="width: 110px">Returned</th>
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

                <td v-if="hasReturnedItems" class="text-center">
                  <template v-if="(item.return_quantity || 0) > 0">
                    <q-chip dense square color="purple-1" text-color="purple-9" class="text-weight-bold text-caption">
                      {{ item.return_quantity }}
                    </q-chip>
                    <div class="text-caption text-grey-6 q-mt-xs">Kept {{ item.quantity - item.return_quantity }}</div>
                  </template>
                  <span v-else class="text-caption text-grey-5">—</span>
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
                  <template v-if="(item.return_quantity || 0) > 0">
                    <div class="text-caption text-grey-6 text-strike">৳{{ calculateLineGross(item).toFixed(2) }}</div>
                    <div class="text-purple-9">৳{{ calculateLineTotal(item).toFixed(2) }}</div>
                  </template>
                  <template v-else>
                    ৳{{ calculateLineTotal(item).toFixed(2) }}
                  </template>
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
              <div v-if="hasReturnedItems" class="text-caption text-purple-9">
                Returned: <strong>{{ totalReturnQuantity }}</strong>
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
                  :disable="loadedInvoiceStatus === 'issued'"
                  @update:model-value="applyOverallDiscountEqually"
                >
                  <template #prepend>
                    <span class="text-caption text-grey-6">৳</span>
                  </template>
                </q-input>
              </div>

              <div class="text-caption text-negative" v-if="totalReturnCredit > 0">
                Return credit: <strong>−৳{{ totalReturnCredit.toFixed(2) }}</strong>
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

    <WholesaleCollectPaymentDialog
      v-model="collectDialogOpen"
      :due-amount="loadedDueAmount"
      :paid-amount="loadedPaidAmount"
      :store-credit="storeCreditBalance"
      :saving="collectSaving"
      @submit="onCollectPayment"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { useQuasar } from 'quasar';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import {
  invoiceRepository,
  type InvoiceBrand,
  type SalesInvoiceStockItem,
} from '../repositories/invoiceRepository';
import type { BillingProfile } from '../repositories/billingProfileRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import WholesaleCollectPaymentDialog from '../components/WholesaleCollectPaymentDialog.vue';
import { walletRepository } from 'src/modules/wallet/repositories/walletRepository';
import WholesaleIssueConfirmDialog, {
  type WholesaleIssueDialogItem,
} from '../components/WholesaleIssueConfirmDialog.vue';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';

type BillingProfileWithTenant = BillingProfile & {
  tenant?: { id: number; name: string; slug: string } | null;
  parent_tenant?: { id: number; name: string; slug: string } | null;
};

export interface InvoiceLineDraftItem {
  id?: number;
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
  return_quantity: number;
  line_discount_amount: number;
  shipment_id: number;
  shipment_name: string;
  holding_tenant_id: number;
  holding_tenant_name: string;
  is_allocated_to_tenant: boolean;
}

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

usePageBreadcrumbs(() => {
  const tenantSlug = authStore.selectedTenant?.slug || (route.params.tenantSlug as string);
  const basePrefix = tenantSlug ? `/${tenantSlug}/app/sales/invoices` : '/app/sales/invoices';
  return [
    {
      label: authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    {
      label: 'Sales',
    },
    {
      label: 'Invoices',
      to: `${basePrefix}/list`,
    },
    {
      label: 'Invoice Details',
    },
  ];
});

const existingInvoiceId = computed(() => {
  const qId = route.query.id;
  if (typeof qId === 'string' && qId) return Number(qId);
  const pId = route.params.id;
  if (typeof pId === 'string' && pId) return Number(pId);
  return null;
});

const isExistingInvoice = computed(() => Boolean(existingInvoiceId.value));
const loadedInvoiceNo = ref('');
const loadedInvoiceStatus = ref('');
const loadedPaymentStatus = ref('due');
const loadedDueAmount = ref(0);
const loadedPaidAmount = ref(0);
const collectDialogOpen = ref(false);
const collectSaving = ref(false);
const storeCreditBalance = ref(0);
const effectivePaymentStatus = computed(() => loadedPaymentStatus.value || 'due');
const canRecordPayment = computed(() => {
  if (loadedInvoiceStatus.value !== 'issued') return false;
  if ((loadedDueAmount.value || 0) <= 0) return false;
  const ps = loadedPaymentStatus.value;
  return ps === 'due' || ps === 'partial' || ps === 'partially_paid';
});
const isLoadingInvoice = ref(false);

const loadExistingInvoice = async () => {
  const invId = existingInvoiceId.value;
  if (!invId) return;

  isLoadingInvoice.value = true;
  try {
    const [inv, invItems] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(invId),
      invoiceRepository.listGlobalInvoiceItems(invId),
    ]);

    if (inv) {
      loadedInvoiceNo.value = inv.invoice_no;
      loadedInvoiceStatus.value = inv.invoice_status;
      loadedPaymentStatus.value = inv.payment_status || 'due';
      loadedDueAmount.value = Number(inv.due_amount ?? 0);
      loadedPaidAmount.value = Number(inv.paid_amount ?? 0);
      selectedBillingProfileId.value = inv.billing_profile_id ?? null;
      overallDiscountInput.value = inv.discount_amount ?? 0;
      if (inv.invoice_status === 'issued') {
        selectedSaveStatus.value = 'issued';
      }
    }

    if (invItems && invItems.length > 0) {
      invoiceItems.value = invItems.map((item) => ({
        id: item.id,
        global_stock_id: item.global_stock_id,
        shipment_item_id: 0,
        product_id: null,
        name: item.name_snapshot,
        barcode: null,
        product_code: null,
        image_url: item.image_url ?? null,
        quantity: Number(item.quantity),
        available_atp: item.available_atp != null ? Number(item.available_atp) : Number(item.quantity),
        unit_cost_price: Number(item.unit_cost_price ?? 0),
        sell_price_amount: Number(item.sell_price_amount),
        return_quantity: Number(item.return_quantity ?? 0),
        line_discount_amount: Number(item.line_discount_amount),
        shipment_id: 0,
        shipment_name: 'Shipment',
        holding_tenant_id: effectiveTenantId.value ?? 0,
        holding_tenant_name: '',
        is_allocated_to_tenant: true,
      }));
    }
  } catch (err) {
    console.error('Error loading existing wholesale invoice:', err);
  } finally {
    isLoadingInvoice.value = false;
  }
};

watch(
  existingInvoiceId,
  (newVal) => {
    if (newVal) {
      void loadExistingInvoice();
    }
  },
  { immediate: true },
);

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

// 3. Invoice Items & Live Stock Search Menu
const invoiceItems = ref<InvoiceLineDraftItem[]>([]);
const hasReturnedItems = computed(() =>
  invoiceItems.value.some((item) => (item.return_quantity || 0) > 0),
);
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
    return_quantity: 0,
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

const overallDiscountInput = ref<number | null>(null);

const applyOverallDiscountEqually = (val: string | number | null) => {
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

const totalReturnQuantity = computed(() =>
  invoiceItems.value.reduce((acc, item) => acc + (Number(item.return_quantity) || 0), 0),
);

const totalReturnCredit = computed(() =>
  invoiceItems.value.reduce(
    (acc, item) => acc + (Number(item.return_quantity) || 0) * (Number(item.sell_price_amount) || 0),
    0,
  ),
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

const grandTotalAmount = computed(() =>
  Math.max(0, subtotalAmount.value - totalDiscountAmount.value - totalReturnCredit.value),
);

// Save Invoice States (Default: Draft)
export type WholesaleInvoiceSaveStatus = 'draft' | 'proforma_generated' | 'issued';
const selectedSaveStatus = ref<WholesaleInvoiceSaveStatus>('draft');
const isSaving = ref(false);

const openCollectDialog = async () => {
  collectDialogOpen.value = true;
  const profileId = selectedBillingProfileId.value;
  const tenantId = effectiveParentTenantId.value;
  if (!profileId || !tenantId) {
    storeCreditBalance.value = 0;
    return;
  }
  try {
    storeCreditBalance.value = await walletRepository.fetchLatestBalance({
      tenantId,
      entityType: 'customer',
      entityId: profileId,
    });
  } catch {
    storeCreditBalance.value = 0;
  }
};

const onCollectPayment = async (payload: {
  cashAmount: number;
  cashMethod: string;
  walletAmount: number;
  settlementAmount: number;
}) => {
  const invId = existingInvoiceId.value;
  if (!invId) return;
  collectSaving.value = true;
  try {
    await invoiceRepository.collectWholesaleInvoicePayment({
      invoice_id: invId,
      cash_amount: payload.cashAmount,
      cash_method: payload.cashMethod,
      wallet_amount: payload.walletAmount,
      settlement_amount: payload.settlementAmount,
    });
    collectDialogOpen.value = false;
    await loadExistingInvoice();
    showSuccessNotification('Payment recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Payment failed.');
  } finally {
    collectSaving.value = false;
  }
};

const goToProcessReturn = () => {
  const invId = existingInvoiceId.value;
  if (!invId) return;
  void router.push({
    name: 'app-global-invoice-return-page',
    params: {
      tenantSlug: authStore.tenantSlug || '',
      id: String(invId),
    },
  });
};

const openPreview = () => {
  const invId = existingInvoiceId.value;
  if (!invId) return;
  const routeData = router.resolve({
    name: 'app-global-invoice-preview',
    params: {
      tenantSlug: authStore.tenantSlug || '',

      id: String(invId),
    },
  });
  window.open(routeData.href, '_blank');
};

const handleSaveInvoice = async (status: WholesaleInvoiceSaveStatus) => {
  selectedSaveStatus.value = status;
  if (!canSaveDraft.value || isSaving.value) return;

  const tenantId = effectiveTenantId.value;
  const parentTenantId = effectiveParentTenantId.value;
  if (!tenantId || !parentTenantId || !selectedBillingProfileId.value) return;

  isSaving.value = true;
  try {
    let targetInvoiceId = existingInvoiceId.value;

    if (!targetInvoiceId) {
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
      targetInvoiceId = createdInvoice?.id ?? null;
      if (createdInvoice?.invoice_no) {
        loadedInvoiceNo.value = createdInvoice.invoice_no;
      }

      if (targetInvoiceId) {
        // Add invoice line items
        for (const item of invoiceItems.value) {
          await invoiceRepository.addGlobalInvoiceItem({
            invoice_id: targetInvoiceId,
            global_stock_id: item.global_stock_id,
            quantity: item.quantity,
            sell_price_amount: item.sell_price_amount,
            line_discount_amount: item.line_discount_amount || 0,
          });
        }
      }
    }

    if (status === 'proforma_generated') {
      loadedInvoiceStatus.value = 'proforma_generated';
      if (targetInvoiceId) {
        void router.replace({
          query: { ...route.query, id: String(targetInvoiceId) },
        });
      }
      showSuccessNotification('Proforma invoice generated. Preview is now available.');
      return;
    }

    if (status === 'issued') {
      if (!targetInvoiceId) return;

      // 1. Fetch live available quantities from global_stocks for all line items
      const stockIds = invoiceItems.value.map((i) => i.global_stock_id);
      const { data: stocksData, error: stocksError } = await supabase
        .from('global_stocks')
        .select('id, quantity')
        .in('id', stockIds);

      if (stocksError) {
        console.error('Error fetching stock availability:', stocksError);
      }

      const stockMap = new Map((stocksData || []).map((s) => [s.id, Number(s.quantity)]));

      // 2. Open WholesaleIssueConfirmDialog
      $q.dialog({
        component: WholesaleIssueConfirmDialog,
        componentProps: {
          invoiceId: targetInvoiceId,
          invoiceNo: loadedInvoiceNo.value || String(targetInvoiceId),
          items: invoiceItems.value.map((i) => ({
            id: i.id,
            global_stock_id: i.global_stock_id,
            name: i.name,
            image_url: i.image_url,
            shipment_name: i.shipment_name,
            available_stock: stockMap.has(i.global_stock_id)
              ? (stockMap.get(i.global_stock_id) ?? 0)
              : i.available_atp,
            quantity: i.quantity,
          })),
        },
      }).onOk((data: { items: WholesaleIssueDialogItem[] }) => {
        void (async () => {
          isSaving.value = true;
          try {
            // 3. Update local line item quantities
            for (const updatedItem of data.items) {
              const existing = invoiceItems.value.find(
                (i) => i.global_stock_id === updatedItem.global_stock_id,
              );
              if (existing) {
                existing.quantity = updatedItem.quantity;
              }
            }

            // 4. Single atomic RPC: updates items in batch, deducts stock, creates movements, and issues invoice
            await invoiceRepository.issueWholesaleInvoice(
              targetInvoiceId,
              data.items.map((i) => ({
                ...(i.id ? { id: i.id } : {}),
                global_stock_id: i.global_stock_id,
                quantity: i.quantity,
              })),
            );

            loadedInvoiceStatus.value = 'issued';
            loadedPaymentStatus.value = 'due';
            if (targetInvoiceId) {
              void router.replace({
                query: { ...route.query, id: String(targetInvoiceId) },
              });
            }
            showSuccessNotification('Wholesale invoice issued and stock deducted successfully.');
          } catch (err) {
            console.error('Error issuing wholesale invoice:', err);
            showWarningDialog(err instanceof Error ? err.message : 'Error issuing wholesale invoice');
          } finally {
            isSaving.value = false;
          }
        })();
      });
      return;
    }

    // Default: Save as draft
    loadedInvoiceStatus.value = 'draft';
    if (targetInvoiceId) {
      void router.replace({
        query: { ...route.query, id: String(targetInvoiceId) },
      });
    }
    showSuccessNotification('Invoice saved as draft.');
  } catch (err) {
    console.error('Error saving wholesale invoice:', err);
    showWarningDialog(err instanceof Error ? err.message : 'Error saving wholesale invoice');
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

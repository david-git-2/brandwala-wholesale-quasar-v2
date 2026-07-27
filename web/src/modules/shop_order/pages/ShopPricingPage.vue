<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="ph ph-arrow-left" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">{{ $t('navigation.shops') }}</div>
              <h1 class="text-h5 q-my-none">
                {{ $t('shop_admin.shop_pricing_title', { name: shopName }) }}
              </h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                {{ $t('shop_admin.shop_pricing_subtitle') }}
              </p>
            </div>
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            icon="ph ph-plus"
            :label="$t('shop_admin.add_product_listing')"
            unelevated
            @click="navigateToAddListings"
          />
        </div>
      </section>

      <!-- Toolbar / Search -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col-12 col-sm-5">
          <q-input
            v-model="search"
            clearable
            dense
            outlined
            :placeholder="$t('shop_admin.search_listings_placeholder')"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </div>
      </section>

      <!-- Error banner -->
      <q-banner v-if="listingsError" class="text-white bg-negative" rounded>
        {{ listingsError?.message || 'Failed to load listings' }}
      </q-banner>

      <!-- Global Pricing Strategy Card (Dropship shops) -->
      <ShopPricingRuleCard
        v-if="shopType === 'dropship'"
        :rule="pricingRule ?? null"
        :is-saving="isSavingRule"
        @save="onSavePricingRule"
      />

      <!-- Bulk Action Bar -->
      <ShopPricingBulkActionBar
        :selected-count="selectedListings.length"
        :is-applying="isBulkApplying"
        @apply-markup="onApplyBulkMarkup"
        @apply-qty-delta="onApplyBulkQtyDelta"
        @bulk-remove="confirmBulkDeleteListings"
        @clear-selection="selectedListings = []"
      />

      <!-- Listings Table -->
      <q-card flat bordered class="q-pa-none">
        <q-card-section v-if="isLoadingListings" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          {{ $t('shop_admin.loading_listings') }}
        </q-card-section>

        <q-card-section
          v-else-if="filteredListings.length === 0"
          class="text-grey-6 text-center q-pa-xl"
        >
          <q-icon name="ph ph-list-dashes" size="48px" class="q-mb-sm block" />
          {{ $t('shop_admin.no_listings') }}
        </q-card-section>

        <q-table
          v-else
          flat
          bordered
          row-key="id"
          :rows="filteredListings"
          :columns="columns"
          :pagination="{ rowsPerPage: 25 }"
          :dense="$q.screen.lt.md"
          class="shop-pricing-q-table"
        >
          <!-- Selection Header -->
          <template #header-cell-select="props">
            <q-th :props="props" class="text-center">
              <q-checkbox v-model="isAllSelected" dense />
            </q-th>
          </template>

          <!-- Selection Body Cell -->
          <template #body-cell-select="props">
            <q-td :props="props" class="text-center">
              <q-checkbox
                :model-value="isListingSelected(props.row)"
                dense
                @update:model-value="(val) => toggleSelectListing(props.row, val)"
              />
            </q-td>
          </template>

          <!-- Image cell -->
          <template #body-cell-product_image="props">
            <q-td :props="props" class="col-image text-center">
              <div class="table-image-box">
                <SmartImage
                  :src="props.row.product_image_url"
                  :alt="props.row.product_name || 'Product image'"
                  :product-id="props.row.product_id"
                  img-class="table-image-1inch"
                  fallback-class="table-image-placeholder-1inch"
                />
              </div>
            </q-td>
          </template>

          <!-- Product info cell -->
          <template #body-cell-product_name="props">
            <q-td :props="props" class="col-name">
              <div class="name-cell-content">
                <span class="name-cell-text text-weight-bold text-grey-9">{{ props.row.product_name }}</span>
                <div v-if="props.row.product_brand || props.row.product_category" class="text-caption text-grey-6 q-mt-xs">
                  {{ [props.row.product_brand, props.row.product_category].filter(Boolean).join(' | ') }}
                </div>
              </div>
            </q-td>
          </template>

          <!-- Code & Barcode combined -->
          <template #body-cell-code_barcode="props">
            <q-td :props="props" class="col-barcode">
              <div class="barcode-lines text-caption">
                <div class="row items-center no-wrap">
                  <span class="text-weight-bold">Code:</span>
                  <span class="q-ml-xs font-mono text-grey-9">{{ props.row.product_code || '—' }}</span>
                  <q-btn
                    v-if="props.row.product_code"
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-6"
                    class="q-ml-xs"
                    @click="handleCopy(props.row.product_code, 'Code')"
                  >
                    <q-tooltip>Copy Code</q-tooltip>
                  </q-btn>
                </div>
                <div v-if="props.row.product_barcode" class="row items-center no-wrap q-mt-xs">
                  <span class="text-weight-bold">Barcode:</span>
                  <span class="q-ml-xs font-mono text-grey-8">{{ props.row.product_barcode }}</span>
                  <q-btn
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-6"
                    class="q-ml-xs"
                    @click="handleCopy(props.row.product_barcode, 'Barcode')"
                  >
                    <q-tooltip>Copy Barcode</q-tooltip>
                  </q-btn>
                </div>
              </div>
            </q-td>
          </template>

          <!-- Sell Price -->
          <template #body-cell-sell_price="props">
            <q-td :props="props" class="cursor-pointer editable-cell text-right">
              <div class="text-weight-medium text-grey-9 row items-center justify-end no-wrap">
                <span>{{ formatAmount(props.row.sell_price_amount) }}</span>
                <q-icon name="ph ph-pencil-simple" size="14px" color="grey-6" class="q-ml-xs" />
              </div>
              <q-popup-edit
                v-slot="scope"
                :model-value="Number(props.row.sell_price_amount)"
                buttons
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onInlineCellEdit(props.row, 'sell_price_amount', Number(val), true)"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  step="0.01"
                  dense
                  autofocus
                  label="Sell Price Amount"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </q-td>
          </template>

          <!-- Calculated Shipment Cost -->
          <template #body-cell-unit_cost="props">
            <q-td :props="props" class="text-right">
              <div class="text-weight-medium text-primary font-mono">
                {{
                  formatMoney(
                    props.row.unit_cost_amount ?? props.row.minimum_sell_price_amount,
                    props.row.minimum_sell_price_currency_id ?? shopDefaultCurrencyId,
                  )
                }}
              </div>
            </q-td>
          </template>

          <!-- Dropship floor -->
          <template #body-cell-min_sell_price="props">
            <q-td :props="props" :class="[shopType === 'dropship' ? 'cursor-pointer editable-cell' : '', 'text-right']">
              <div v-if="shopType === 'dropship'" class="text-grey-8 row items-center justify-end no-wrap">
                <span>{{
                  formatMoney(
                    props.row.minimum_sell_price_amount,
                    props.row.minimum_sell_price_currency_id,
                  )
                }}</span>
                <q-icon name="ph ph-pencil-simple" size="14px" color="grey-6" class="q-ml-xs" />
              </div>
              <div v-else class="text-grey-4">—</div>
              <q-popup-edit
                v-if="shopType === 'dropship'"
                v-slot="scope"
                :model-value="props.row.minimum_sell_price_amount !== null ? Number(props.row.minimum_sell_price_amount) : null"
                buttons
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onInlineCellEdit(props.row, 'minimum_sell_price_amount', val !== null && val !== '' ? Number(val) : null, true)"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  step="0.01"
                  dense
                  autofocus
                  clearable
                  label="Minimum Sell Price (Floor)"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </q-td>
          </template>

          <!-- Display Qty -->
          <template #body-cell-display_quantity="props">
            <q-td :props="props" class="text-center cursor-pointer editable-cell">
              <div class="row items-center justify-center no-wrap q-gutter-x-xs">
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  :icon="props.row.is_quantity_locked ? 'ph ph-lock-key' : 'ph ph-lock-key-open'"
                  :color="props.row.is_quantity_locked ? 'warning' : 'grey-5'"
                  @click.stop="onToggleQuantityLock(props.row)"
                >
                  <q-tooltip>
                    {{ props.row.is_quantity_locked ? 'Quantity is Manually Locked (Protected from bulk updates)' : 'Quantity is Unlocked (Will update with bulk adjustments)' }}
                  </q-tooltip>
                </q-btn>
                <div
                  v-if="props.row.display_quantity_override !== null"
                  class="text-primary text-weight-bold row items-center justify-center no-wrap"
                >
                  <span>{{ props.row.display_quantity_override }}</span>
                  <q-icon name="ph ph-pencil-simple" size="14px" color="primary" class="q-ml-xs" />
                  <q-tooltip>{{
                    $t('shop_admin.marketing_override', { qty: props.row.available_to_sell })
                  }}</q-tooltip>
                </div>
                <div v-else class="text-grey-8 row items-center justify-center no-wrap">
                  <span>{{ props.row.available_to_sell }}</span>
                  <q-icon name="ph ph-pencil-simple" size="14px" color="grey-5" class="q-ml-xs" />
                </div>
              </div>
              <q-popup-edit
                v-slot="scope"
                :model-value="props.row.display_quantity_override ?? props.row.available_to_sell"
                buttons
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onInlineCellEdit(props.row, 'display_quantity_override', val !== null && val !== '' ? Number(val) : null, true)"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  dense
                  autofocus
                  clearable
                  label="Display Quantity Override"
                  placeholder="Inherits actual available qty if empty"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </q-td>
          </template>

          <!-- Actual Qty -->
          <template #body-cell-actual_quantity="props">
            <q-td :props="props" class="text-center">
              <div class="text-grey-8 font-mono">
                {{ props.row.available_to_sell }}
              </div>
            </q-td>
          </template>

          <!-- Visibility -->
          <template #body-cell-show_quantity="props">
            <q-td :props="props" class="text-center">
              <q-toggle
                :model-value="props.row.show_quantity ?? false"
                color="positive"
                dense
                @update:model-value="(val) => onToggleShowQuantity(props.row, val)"
              >
                <q-tooltip>
                  {{ props.row.show_quantity ? 'Quantity Visible to Customers' : 'Quantity Hidden from Customers' }}
                </q-tooltip>
              </q-toggle>
            </q-td>
          </template>

          <!-- Status -->
          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="props.row.is_active ? 'positive' : 'grey-5'"
                outline
                class="q-px-sm q-py-xs"
              >
                {{ props.row.is_active ? 'Active' : 'Inactive' }}
              </q-badge>
            </q-td>
          </template>

          <!-- Actions -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn
                flat
                round
                dense
                icon="ph ph-pencil-simple"
                color="primary"
                @click="openEditListing(props.row)"
              >
                <q-tooltip>{{ $t('shop_admin.edit_settings') }}</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <!-- Candidate Allocation Pick Dialog -->
    <AllocationPickDialog
      v-model="pickDialogOpen"
      :candidates="candidates"
      @pick="onAllocationPicked"
    />

    <!-- Create / Edit Listing Form Dialog -->
    <q-dialog v-model="editDialogOpen">
      <q-card style="width: 500px; max-width: 90vw">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">
            {{ form.id ? $t('shop_admin.edit_listing') : $t('shop_admin.add_listing') }}
          </div>
          <q-space />
          <q-btn icon="ph ph-x" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-gutter-y-md q-pt-md">
          <div class="bg-grey-1 q-pa-md rounded-borders row items-center no-wrap q-gutter-x-md">
            <q-avatar size="48px" rounded class="bg-grey-3 flex-shrink-0">
              <q-img v-if="selectedProductImageUrl" :src="selectedProductImageUrl" />
              <q-icon v-else name="ph ph-image" color="grey-6" size="24px" />
            </q-avatar>
            <div class="col overflow-hidden">
              <div class="text-weight-bold text-grey-9 ellipsis">{{ selectedProductName }}</div>
              <div class="text-caption text-grey-7 ellipsis">{{ selectedProductDetails }}</div>
              <div v-if="selectedProductCost !== null" class="text-caption text-primary text-weight-medium q-mt-xs">
                Cost: {{ selectedProductCost }}
              </div>
            </div>
          </div>

          <!-- Sell Price -->
          <div class="row q-col-gutter-md">
            <div class="col-7">
              <q-input
                v-model.number="form.sell_price_amount"
                type="number"
                step="0.01"
                :label="$t('shop_admin.sell_price_amount')"
                outlined
                dense
                :rules="[(val) => !!val || t('shop_admin.amount_required')]"
              />
            </div>
            <div class="col-5">
              <q-select
                v-model="form.sell_price_currency_id"
                :label="$t('shop_admin.currency')"
                outlined
                dense
                emit-value
                map-options
                option-value="id"
                option-label="code"
                :options="currencies"
                :rules="[(val) => !!val || t('shop_admin.currency_required')]"
              />
            </div>
          </div>

          <!-- Minimum Sell Price (dropship only) -->
          <div v-if="shopType === 'dropship'" class="row q-col-gutter-md">
            <div class="col-7">
              <q-input
                v-model.number="form.minimum_sell_price_amount"
                type="number"
                step="0.01"
                :label="$t('shop_admin.min_dropship_price')"
                outlined
                dense
                hint="Minimum price floor mandated by parent tenant"
                :rules="[(val) => !!val || t('shop_admin.min_dropship_required')]"
              />
            </div>
            <div class="col-5">
              <q-select
                v-model="form.minimum_sell_price_currency_id"
                :label="$t('shop_admin.currency')"
                outlined
                dense
                emit-value
                map-options
                option-value="id"
                option-label="code"
                :options="currencies"
                :rules="[(val) => !!val || t('shop_admin.currency_required')]"
              />
            </div>
          </div>

          <!-- Display Qty Override -->
          <div class="row q-col-gutter-md">
            <div class="col-12">
              <q-input
                v-model.number="form.display_quantity_override"
                type="number"
                :label="$t('shop_admin.display_qty_override')"
                outlined
                dense
                clearable
                :placeholder="$t('shop_admin.inherits_available_qty')"
                hint="Set custom display quantity for storefront (leave empty to show actual allocated stock)"
              />
            </div>
          </div>

          <!-- Show Qty Override -->
          <div class="row q-col-gutter-md">
            <div class="col-12">
              <q-select
                v-model="form.show_quantity"
                :label="$t('shop_admin.show_qty_to_customer')"
                outlined
                dense
                emit-value
                map-options
                :options="showQuantityOptions"
              />
            </div>
          </div>

          <!-- Active Switch -->
          <q-toggle v-model="form.is_active" :label="$t('shop_admin.listing_active')" color="primary" />
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md border-top bg-grey-1">
          <q-btn flat :label="$t('shop_admin.cancel')" color="grey-7" v-close-popup />
          <q-btn
            unelevated
            :label="$t('shop_admin.save_listing')"
            color="primary"
            :loading="isSavingListing"
            @click="onSaveListing"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  useShopPricingListingsQuery,
  useShopPricingCandidatesQuery,
  useShopCurrenciesQuery,
  useShopPricingRuleQuery,
} from '../composables/useShopPricingQuery';
import { useQuasar } from 'quasar';
import {
  useSaveShopListingMutation,
  useSaveShopPricingRuleMutation,
  useBulkApplyShopMarkupMutation,
  useDeleteShopListingMutation,
} from '../composables/useShopPricingMutations';
import AllocationPickDialog from '../components/AllocationPickDialog.vue';
import ShopPricingRuleCard from '../components/ShopPricingRuleCard.vue';
import ShopPricingBulkActionBar from '../components/ShopPricingBulkActionBar.vue';
import SmartImage from 'src/components/SmartImage.vue';
import type { ShopProductListing, CandidateAllocation, UpsertListingPayload } from '../types';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const { t } = useI18n();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId as number);
const shopId = computed(() => Number(route.params.shopId));
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

// Selection State
const selectedListings = ref<ShopProductListing[]>([]);

// TanStack Queries
const { data: rawListings, isLoading: isLoadingListings, error: listingsError } = useShopPricingListingsQuery(shopId);

const { data: rawCandidates } = useShopPricingCandidatesQuery(tenantId, shopId);
const { data: rawCurrencies } = useShopCurrenciesQuery();
const { data: pricingRule } = useShopPricingRuleQuery(shopId);

const listings = computed(() => rawListings.value ?? []);
const candidates = computed(() => rawCandidates.value ?? []);
const currencies = computed(() => rawCurrencies.value ?? []);

// TanStack Mutations
const { mutate: saveListing, isPending: isSavingListing } = useSaveShopListingMutation();
const { mutate: savePricingRule, isPending: isSavingRule } = useSaveShopPricingRuleMutation();
const { mutate: bulkApplyMarkup, isPending: isBulkApplying } = useBulkApplyShopMarkupMutation();
const { mutate: deleteListing } = useDeleteShopListingMutation();

const shopName = ref<string>('');
const shopType = ref<string>('');
const shopDefaultCurrencyId = ref<number | null>(null);
const search = ref<string>('');

// Form & Dialog controls
const pickDialogOpen = ref(false);
const editDialogOpen = ref(false);
const selectedProductName = ref('');
const selectedProductDetails = ref('');
const selectedProductImageUrl = ref<string | null>(null);
const selectedProductCost = ref<string | null>(null);

const form = ref<UpsertListingPayload>({
  tenant_id: 0,
  shop_id: 0,
  global_stock_allocation_id: 0,
  sell_price_amount: 0,
  sell_price_currency_id: 0,
  minimum_sell_price_amount: null,
  minimum_sell_price_currency_id: null,
  show_quantity: null,
  display_quantity_override: null,
  is_active: true,
  id: null,
});

const isListingSelected = (listing: ShopProductListing) => {
  return selectedListings.value.some((item) => item.id === listing.id);
};

const toggleSelectListing = (listing: ShopProductListing, selected: boolean) => {
  if (selected) {
    if (!isListingSelected(listing)) {
      selectedListings.value.push(listing);
    }
  } else {
    selectedListings.value = selectedListings.value.filter((item) => item.id !== listing.id);
  }
};

const isAllSelected = computed({
  get: () => {
    if (!filteredListings.value.length) return false;
    return filteredListings.value.every((l) => isListingSelected(l));
  },
  set: (val: boolean) => {
    if (val) {
      selectedListings.value = [...filteredListings.value];
    } else {
      selectedListings.value = [];
    }
  },
});

const handleCopy = (text: string, label: string) => {
  if (!text) return;
  void navigator.clipboard.writeText(text);
  $q.notify({
    type: 'positive',
    message: `${label} copied to clipboard`,
    timeout: 1500,
  });
};

const columns = computed(() => [
  {
    name: 'select',
    label: '',
    field: 'id',
    align: 'center' as const,
  },
  {
    name: 'product_image',
    label: '',
    field: 'product_image_url',
    align: 'center' as const,
  },
  {
    name: 'product_name',
    label: t('shop_admin.col_product'),
    field: 'product_name',
    align: 'left' as const,
    sortable: true,
  },
  {
    name: 'code_barcode',
    label: 'Code / Barcode',
    field: 'product_code',
    align: 'left' as const,
    sortable: true,
  },
  {
    name: 'sell_price',
    label: t('shop_admin.col_sell_price'),
    field: 'sell_price_amount',
    align: 'right' as const,
    sortable: true,
  },
  {
    name: 'unit_cost',
    label: 'Calculated Cost',
    field: 'minimum_sell_price_amount',
    align: 'right' as const,
  },
  {
    name: 'min_sell_price',
    label: t('shop_admin.dropship_floor'),
    field: 'minimum_sell_price_amount',
    align: 'right' as const,
  },
  {
    name: 'display_quantity',
    label: t('shop_admin.col_display_qty'),
    field: 'display_quantity_override',
    align: 'center' as const,
  },
  {
    name: 'actual_quantity',
    label: t('shop_admin.col_actual_qty'),
    field: 'available_to_sell',
    align: 'center' as const,
    sortable: true,
  },
  {
    name: 'show_quantity',
    label: t('shop_admin.qty_visibility'),
    field: 'show_quantity',
    align: 'center' as const,
  },
  {
    name: 'is_active',
    label: t('shop_admin.col_listing_active'),
    field: 'is_active',
    align: 'center' as const,
  },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
]);

const showQuantityOptions = computed(() => [
  { label: t('shop_admin.inherit_shop_settings'), value: null },
  { label: t('shop_admin.force_show'), value: true },
  { label: t('shop_admin.force_hide'), value: false },
]);

const formatAmount = (amount: number | null | undefined): string => {
  if (amount === null || amount === undefined) return '—';
  return Number(amount).toFixed(2);
};

const formatMoney = (amount: number | null, currencyId: number | null): string => {
  if (amount === null || currencyId === null) return '—';
  const curr = currencies.value.find((c) => c.id === currencyId);
  const code = curr ? curr.code : '';
  return `${Number(amount).toFixed(2)} ${code}`;
};

const filteredListings = computed(() => {
  const query = search.value.trim().toLowerCase();
  if (!query) return listings.value;

  return listings.value.filter((l) => {
    return (
      l.product_name.toLowerCase().includes(query) ||
      (l.product_code && l.product_code.toLowerCase().includes(query)) ||
      (l.product_barcode && l.product_barcode.toLowerCase().includes(query)) ||
      (l.product_brand && l.product_brand.toLowerCase().includes(query)) ||
      (l.product_category && l.product_category.toLowerCase().includes(query))
    );
  });
});

const loadShopDetails = async () => {
  if (!shopId.value) return;

  const { data: shopData } = await supabase
    .from('shops')
    .select('name, shop_type, default_currency_id')
    .eq('id', shopId.value)
    .single();
  if (shopData) {
    shopName.value = shopData.name;
    shopType.value = shopData.shop_type;
    shopDefaultCurrencyId.value = shopData.default_currency_id ?? null;
    form.value.sell_price_currency_id = shopData.default_currency_id || 0;
    form.value.minimum_sell_price_currency_id = shopData.default_currency_id || null;
  }
};

// Rounding helper: Nearest 5 or 0 (e.g. 5, 10, 15, 20...)
const roundNearest5or0 = (val: number): number => {
  if (!val || val <= 0) return 0;
  return Math.round(val / 5) * 5;
};

// Rounding helper: Nearest 50 or 100 (e.g. 50, 100, 150, 200...)
const roundNearest50or100 = (val: number): number => {
  if (!val || val <= 0) return 0;
  return Math.round(val / 50) * 50;
};

const onAllocationPicked = (alloc: CandidateAllocation) => {
  selectedProductName.value = alloc.product_name;
  selectedProductDetails.value = `${alloc.product_brand ?? ''} | ${alloc.product_category ?? ''} | Allocated: ${alloc.allocated_quantity}`;
  selectedProductImageUrl.value = alloc.product_image_url ?? null;
  
  const unitCost = alloc.unit_cost_amount ?? alloc.minimum_sell_price_amount ?? 0;
  selectedProductCost.value = unitCost > 0
    ? formatMoney(unitCost, alloc.minimum_sell_price_currency_id ?? form.value.minimum_sell_price_currency_id ?? null)
    : null;

  // Calculate default floor price from cost + dropship markup %, rounded to nearest 50 or 100
  const dropshipMarkupPct = Number(pricingRule.value?.dropship_markup_percentage ?? 0);
  const rawFloor = unitCost > 0 ? unitCost * (1 + dropshipMarkupPct / 100) : 0;
  const calculatedFloor = rawFloor > 0 ? roundNearest50or100(rawFloor) : null;

  // Calculate default sell price from cost + sell price markup %, rounded to nearest 5 or 0
  const sellMarkupPct = Number(pricingRule.value?.markup_percentage ?? 0);
  const rawSell = unitCost > 0 ? unitCost * (1 + sellMarkupPct / 100) : 0;
  const calculatedSell = rawSell > 0 ? roundNearest5or0(rawSell) : 0;

  form.value = {
    tenant_id: tenantId.value,
    shop_id: shopId.value,
    global_stock_allocation_id: alloc.allocation_id,
    sell_price_amount: calculatedSell,
    sell_price_currency_id: shopDefaultCurrencyId.value ?? form.value.sell_price_currency_id ?? null,
    minimum_sell_price_amount: calculatedFloor,
    minimum_sell_price_currency_id: alloc.minimum_sell_price_currency_id ?? shopDefaultCurrencyId.value ?? form.value.minimum_sell_price_currency_id ?? null,
    show_quantity: null,
    display_quantity_override: null,
    is_active: true,
    id: null,
  };
  editDialogOpen.value = true;
};

const openEditListing = (listing: ShopProductListing) => {
  selectedProductName.value = listing.product_name;
  selectedProductDetails.value = `${listing.product_brand ?? ''} | ${listing.product_category ?? ''} | Allocated: ${listing.allocated_quantity}`;
  selectedProductImageUrl.value = listing.product_image_url ?? null;
  const landedCost = listing.unit_cost_amount ?? listing.minimum_sell_price_amount;
  selectedProductCost.value = landedCost !== null && landedCost !== undefined
    ? formatMoney(landedCost, listing.minimum_sell_price_currency_id ?? shopDefaultCurrencyId.value)
    : null;

  form.value = {
    id: listing.id,
    tenant_id: tenantId.value,
    shop_id: shopId.value,
    global_stock_allocation_id: listing.global_stock_allocation_id,
    sell_price_amount: Number(listing.sell_price_amount),
    sell_price_currency_id: listing.sell_price_currency_id || shopDefaultCurrencyId.value || 0,
    minimum_sell_price_amount: listing.minimum_sell_price_amount
      ? Number(listing.minimum_sell_price_amount)
      : null,
    minimum_sell_price_currency_id: listing.minimum_sell_price_currency_id || shopDefaultCurrencyId.value,
    show_quantity: listing.show_quantity,
    display_quantity_override: listing.display_quantity_override,
    is_active: listing.is_active,
  };
  editDialogOpen.value = true;
};

const onSaveListing = () => {
  // Guard dropship currency rules
  if (shopType.value === 'dropship' && form.value.minimum_sell_price_amount) {
    if (!form.value.minimum_sell_price_currency_id) {
      form.value.minimum_sell_price_currency_id = form.value.sell_price_currency_id || shopDefaultCurrencyId.value;
    }
  } else {
    form.value.minimum_sell_price_amount = null;
    form.value.minimum_sell_price_currency_id = null;
  }

  saveListing(form.value, {
    onSuccess: () => {
      editDialogOpen.value = false;
    },
  });
};

const navigateToAddListings = () => {
  void router.push({
    name: 'app-shop-add-listings-page',
    params: { shopId: shopId.value },
  });
};

const onSavePricingRule = (payload: {
  markup_percentage: number;
  dropship_markup_percentage?: number;
  global_quantity_add?: number | null;
  is_auto_publish: boolean;
  default_show_quantity: boolean;
}) => {
  savePricingRule(
    {
      shop_id: shopId.value,
      markup_percentage: payload.markup_percentage,
      dropship_markup_percentage: payload.dropship_markup_percentage ?? 0,
      is_auto_publish: payload.is_auto_publish,
      default_show_quantity: payload.default_show_quantity,
      default_add_quantity: payload.global_quantity_add ?? 0,
    },
    {
      onSuccess: () => {
        const sellMarkupPct = payload.markup_percentage;
        const dropshipMarkupPct = payload.dropship_markup_percentage ?? 0;
        const qtyAdd = payload.global_quantity_add !== null && payload.global_quantity_add !== undefined
          ? Number(payload.global_quantity_add)
          : null;

        listings.value.forEach((item) => {
          const baseCost = item.unit_cost_amount ?? item.minimum_sell_price_amount;
          const costValue = baseCost !== null && baseCost !== undefined ? Number(baseCost) : 0;
          
          let newSellPrice = Number(item.sell_price_amount);
          let newFloorPrice = item.minimum_sell_price_amount !== null ? Number(item.minimum_sell_price_amount) : null;

          // Only auto-recalculate prices if item is NOT manually price locked
          if (costValue > 0 && !item.is_price_locked) {
            if (sellMarkupPct >= 0) {
              const rawSell = costValue * (1 + sellMarkupPct / 100);
              newSellPrice = roundNearest5or0(rawSell);
            }
            if (shopType.value === 'dropship' && dropshipMarkupPct >= 0) {
              const rawFloor = costValue * (1 + dropshipMarkupPct / 100);
              newFloorPrice = roundNearest50or100(rawFloor);
            }
          }

          const minPriceAmount = newFloorPrice !== null && newFloorPrice !== undefined ? newFloorPrice : null;
          const minPriceCurrency = minPriceAmount !== null
            ? (item.minimum_sell_price_currency_id || shopDefaultCurrencyId.value || item.sell_price_currency_id || null)
            : null;

          // If global quantity add is provided and item is NOT manually locked, update display_quantity_override
          let newDisplayQty = item.display_quantity_override;
          if (qtyAdd !== null && !item.is_quantity_locked) {
            newDisplayQty = item.available_to_sell + qtyAdd;
          }

          const listingPayload: UpsertListingPayload = {
            id: item.id,
            tenant_id: tenantId.value,
            shop_id: shopId.value,
            global_stock_allocation_id: item.global_stock_allocation_id,
            sell_price_amount: newSellPrice,
            sell_price_currency_id: item.sell_price_currency_id || shopDefaultCurrencyId.value || 0,
            minimum_sell_price_amount: minPriceAmount,
            minimum_sell_price_currency_id: minPriceCurrency,
            show_quantity: item.show_quantity,
            display_quantity_override: newDisplayQty,
            is_active: item.is_active,
            is_price_locked: Boolean(item.is_price_locked),
            is_quantity_locked: Boolean(item.is_quantity_locked),
          };
          saveListing(listingPayload);
        });
      },
    }
  );
};

const onApplyBulkMarkup = (payload: {
  markupAmount: number;
  markupType: 'percentage' | 'fixed';
  targetPrice: 'sell_price' | 'min_sell_price';
}) => {
  if (!shopId.value || selectedListings.value.length === 0) return;
  const listingIds = selectedListings.value.map((item) => item.id);

  bulkApplyMarkup(
    {
      shopId: shopId.value,
      markupAmount: payload.markupAmount,
      markupType: payload.markupType,
      targetPrice: payload.targetPrice,
      listingIds,
    },
    {
      onSuccess: () => {
        selectedListings.value = [];
      },
    }
  );
};

const onApplyBulkQtyDelta = (payload: {
  qtyDelta: number;
  qtyOperation: 'add' | 'subtract' | 'set';
}) => {
  if (!shopId.value || selectedListings.value.length === 0) return;

  // Filter only items that are NOT manually quantity locked
  const eligibleItems = selectedListings.value.filter((item) => !item.is_quantity_locked);

  if (eligibleItems.length === 0) {
    $q.notify({
      type: 'warning',
      message: 'All selected items have manually locked quantities and were skipped.',
    });
    return;
  }

  let updatedCount = 0;
  eligibleItems.forEach((listing) => {
    const currentDisplayQty = listing.display_quantity_override ?? listing.available_to_sell;
    let newDisplayQty: number;

    if (payload.qtyOperation === 'add') {
      newDisplayQty = currentDisplayQty + payload.qtyDelta;
    } else if (payload.qtyOperation === 'subtract') {
      newDisplayQty = Math.max(0, currentDisplayQty - payload.qtyDelta);
    } else {
      newDisplayQty = Math.max(0, payload.qtyDelta);
    }

    onInlineCellEdit(listing, 'display_quantity_override', newDisplayQty);
    updatedCount++;
  });

  $q.notify({
    type: 'positive',
    message: `Updated display quantity for ${updatedCount} listing(s). (${selectedListings.value.length - updatedCount} locked item(s) skipped)`,
  });

  selectedListings.value = [];
};

const onInlineCellEdit = (
  listing: ShopProductListing,
  field: 'sell_price_amount' | 'minimum_sell_price_amount' | 'display_quantity_override',
  val: number | null,
  lockOnManualEdit = false
) => {
  const currencyId = listing.sell_price_currency_id || shopDefaultCurrencyId.value || 0;
  const minPriceAmount =
    field === 'minimum_sell_price_amount'
      ? val
      : listing.minimum_sell_price_amount !== null && listing.minimum_sell_price_amount !== undefined
        ? Number(listing.minimum_sell_price_amount)
        : null;
  const minPriceCurrency = minPriceAmount !== null
    ? (listing.minimum_sell_price_currency_id || currencyId || null)
    : null;

  const isQtyField = field === 'display_quantity_override';
  const isPriceField = field === 'sell_price_amount' || field === 'minimum_sell_price_amount';

  const payload: UpsertListingPayload = {
    id: listing.id,
    tenant_id: tenantId.value,
    shop_id: shopId.value,
    global_stock_allocation_id: listing.global_stock_allocation_id,
    sell_price_amount: field === 'sell_price_amount' ? (val ?? 0) : Number(listing.sell_price_amount),
    sell_price_currency_id: currencyId,
    minimum_sell_price_amount: minPriceAmount,
    minimum_sell_price_currency_id: minPriceCurrency,
    show_quantity: listing.show_quantity,
    display_quantity_override:
      field === 'display_quantity_override' ? val : listing.display_quantity_override,
    is_active: listing.is_active,
    is_price_locked: isPriceField && lockOnManualEdit ? true : Boolean(listing.is_price_locked),
    is_quantity_locked: isQtyField && lockOnManualEdit ? true : Boolean(listing.is_quantity_locked),
  };
  saveListing(payload);
};

const onToggleQuantityLock = (listing: ShopProductListing) => {
  const newLockState = !listing.is_quantity_locked;
  const currencyId = listing.sell_price_currency_id || shopDefaultCurrencyId.value || 0;
  const minPriceAmount = listing.minimum_sell_price_amount !== null && listing.minimum_sell_price_amount !== undefined
    ? Number(listing.minimum_sell_price_amount)
    : null;

  const payload: UpsertListingPayload = {
    id: listing.id,
    tenant_id: tenantId.value,
    shop_id: shopId.value,
    global_stock_allocation_id: listing.global_stock_allocation_id,
    sell_price_amount: Number(listing.sell_price_amount),
    sell_price_currency_id: currencyId,
    minimum_sell_price_amount: minPriceAmount,
    minimum_sell_price_currency_id: minPriceAmount !== null ? (listing.minimum_sell_price_currency_id || currencyId || null) : null,
    show_quantity: listing.show_quantity,
    display_quantity_override: listing.display_quantity_override,
    is_active: listing.is_active,
    is_price_locked: Boolean(listing.is_price_locked),
    is_quantity_locked: newLockState,
  };

  saveListing(payload);
  $q.notify({
    type: newLockState ? 'warning' : 'positive',
    message: newLockState ? 'Quantity locked from bulk edits' : 'Quantity unlocked for bulk edits',
    timeout: 1500,
  });
};

const onToggleShowQuantity = (listing: ShopProductListing, showQty: boolean) => {
  const currencyId = listing.sell_price_currency_id || shopDefaultCurrencyId.value || 0;
  const minPriceAmount = listing.minimum_sell_price_amount !== null && listing.minimum_sell_price_amount !== undefined
    ? Number(listing.minimum_sell_price_amount)
    : null;
  const minPriceCurrency = minPriceAmount !== null
    ? (listing.minimum_sell_price_currency_id || currencyId || null)
    : null;

  const payload: UpsertListingPayload = {
    id: listing.id,
    tenant_id: tenantId.value,
    shop_id: shopId.value,
    global_stock_allocation_id: listing.global_stock_allocation_id,
    sell_price_amount: Number(listing.sell_price_amount),
    sell_price_currency_id: currencyId,
    minimum_sell_price_amount: minPriceAmount,
    minimum_sell_price_currency_id: minPriceCurrency,
    show_quantity: showQty,
    display_quantity_override: listing.display_quantity_override,
    is_active: listing.is_active,
  };
  saveListing(payload);
};

const confirmBulkDeleteListings = () => {
  if (!selectedListings.value.length) return;
  const count = selectedListings.value.length;

  $q.dialog({
    title: 'Remove Selected Listings',
    message: `Are you sure you want to remove ${count} selected product listing(s)?`,
    cancel: true,
    persistent: true,
    ok: {
      label: 'Remove Selected',
      color: 'negative',
      flat: true,
    },
  }).onOk(() => {
    selectedListings.value.forEach((listing) => {
      deleteListing({
        listingId: listing.id,
        tenantId: tenantId.value,
        shopId: shopId.value,
      });
    });
    selectedListings.value = [];
  });
};

const goBack = () => {
  void router.push({
    name: 'app-shop-shops-page',
    params: { tenantSlug: tenantSlug.value },
  });
};

onMounted(loadShopDetails);
</script>

<style scoped>
.shop-pricing-q-table :deep(table) {
  border-collapse: separate;
  border-spacing: 0;
}

.shop-pricing-q-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: var(--bw-theme-surface, #ffffff);
  font-weight: 700;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #555555;
  border-bottom: 2px solid #e0e0e0;
  padding: 8px 12px;
}

.shop-pricing-q-table :deep(tbody td) {
  font-size: 13px;
  padding: 8px 12px;
  border-bottom: 1px solid #f0f0f0;
}

.col-image {
  min-width: 110px;
  width: 110px;
  max-width: 110px;
}

.table-image-box {
  width: 96px;
  height: 96px;
  margin: 0 auto;
  overflow: hidden;
  border-radius: 8px;
  border: 1px solid #e0e0e0;
}

.table-image-box :deep(.table-image-1inch),
.table-image-box :deep(.table-image-placeholder-1inch) {
  width: 96px;
  height: 96px;
  display: block;
  border-radius: 8px;
}

.table-image-box :deep(.table-image-placeholder-1inch) {
  background-color: #f5f5f5;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #9e9e9e;
  font-size: 11px;
  border: 1px dashed #bdbdbd;
}

.col-name {
  min-width: 220px;
}

.name-cell-content {
  display: flex;
  flex-direction: column;
}

.name-cell-text {
  font-size: 13px;
  line-height: 1.3;
  word-break: break-word;
}

.col-barcode {
  min-width: 160px;
}

.barcode-lines {
  line-height: 1.4;
}

.font-mono {
  font-family: monospace, monospace;
}

.editable-cell {
  position: relative;
  transition: background-color 0.2s ease;
}

.editable-cell:hover {
  background-color: rgba(25, 118, 210, 0.05) !important;
}
</style>


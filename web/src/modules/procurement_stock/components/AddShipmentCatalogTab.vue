<template>
  <div class="panel-body col column no-wrap">
    <!-- Top Bar: Left Title & Section | Center Mode Buttons (Search, Bulk) | Right Filter & Close -->
    <div class="top-nav-bar row items-center justify-between q-px-md q-py-sm bg-white border-bottom">
      <div class="row items-center q-gutter-x-sm no-wrap ellipsis">
        <div class="text-subtitle1 text-weight-bold text-grey-9">
          Add Item
        </div>
        <!-- Target Section Pill / Selector -->
        <q-btn-dropdown
          v-if="selectedSectionName || sectionOptions.length > 0"
          unelevated
          dense
          no-caps
          color="primary"
          class="q-px-sm q-py-2xs text-weight-bold"
          style="border-radius: 12px; font-size: 12px"
          :dropdown-icon="sectionOptions.length > 1 ? 'ph ph-caret-down' : 'none'"
          :disable="sectionOptions.length <= 1"
        >
          <template #label>
            <div class="row items-center no-wrap">
              <q-icon name="ph ph-folder-open" size="14px" class="q-mr-2xs" />
              <span class="ellipsis" style="max-width: 170px">{{ selectedSectionName || 'Select Section' }}</span>
            </div>
          </template>
          <q-list dense style="min-width: 180px">
            <q-item
              v-for="sec in sectionOptions"
              :key="sec.value"
              clickable
              v-close-popup
              :active="selectedSectionId === sec.value"
              active-class="text-primary text-weight-bold bg-primary-subtle"
              @click="selectedSectionId = sec.value"
            >
              <q-item-section avatar style="min-width: 24px">
                <q-icon name="ph ph-folder" size="14px" />
              </q-item-section>
              <q-item-section class="text-caption">{{ sec.label }}</q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
      </div>

      <!-- Center Segmented Switch: Search | Bulk -->
      <div class="row items-center bg-grey-2 q-pa-xs rounded-borders mode-switcher">
        <q-btn
          unelevated
          dense
          no-caps
          :color="!showBulkCodes ? 'white' : 'transparent'"
          :text-color="!showBulkCodes ? 'grey-10' : 'grey-7'"
          :class="{ 'shadow-1 text-weight-bold': !showBulkCodes, 'text-weight-medium': showBulkCodes }"
          label="Search"
          icon="ph ph-magnifying-glass"
          class="q-px-md mode-btn"
          @click="showBulkCodes = false"
        />
        <q-btn
          unelevated
          dense
          no-caps
          :color="showBulkCodes ? 'white' : 'transparent'"
          :text-color="showBulkCodes ? 'grey-10' : 'grey-7'"
          :class="{ 'shadow-1 text-weight-bold': showBulkCodes, 'text-weight-medium': !showBulkCodes }"
          label="Bulk"
          icon="ph ph-list-plus"
          class="q-px-md mode-btn"
          @click="showBulkCodes = true"
        />
      </div>

      <!-- Right Action Icons: Filter & Close -->
      <div class="row items-center q-gutter-x-xs">
        <q-btn
          flat
          round
          dense
          icon="ph ph-funnel"
          color="grey-8"
          @click="openFilterSidebar"
        >
          <q-badge v-if="activeFilterCount > 0" color="dark" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
          <q-tooltip>Filter catalog</q-tooltip>
        </q-btn>
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          color="grey-8"
          @click="$emit('done')"
        >
          <q-tooltip>Close</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- Search Mode View -->
    <div v-if="!showBulkCodes" class="q-pa-md search-header-bar column q-gutter-y-sm">
      <div class="row items-center q-col-gutter-sm">
        <div class="col">
          <q-input
            v-model="browseSearch"
            :placeholder="`Search catalog by ${searchFieldLabel.toLowerCase()} (e.g. name, SKU, barcode)...`"
            outlined
            dense
            autofocus
            bg-color="white"
            class="catalog-search-input"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" color="grey-6" />
              <q-btn-dropdown
                flat
                dense
                :label="searchFieldLabel"
                class="text-caption text-weight-medium text-grey-8 search-scope-pill q-mr-xs"
                no-caps
              >
                <q-list dense>
                  <q-item clickable v-close-popup @click="browseSearchField = 'name'">
                    <q-item-section>Search by Name</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="browseSearchField = 'barcode'">
                    <q-item-section>Search by Barcode</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="browseSearchField = 'product_code'">
                    <q-item-section>Search by Product Code / SKU</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="browseSearchField = 'id'">
                    <q-item-section>Search by Product ID</q-item-section>
                  </q-item>
                </q-list>
              </q-btn-dropdown>
            </template>
            <template v-if="browseSearch" #append>
              <q-btn
                flat
                round
                dense
                size="sm"
                icon="ph ph-x"
                color="grey-6"
                @click="onClearSearch"
              />
            </template>
          </q-input>
        </div>
      </div>
    </div>

    <!-- Bulk Mode View -->
    <div v-else class="q-pa-md bulk-header-bar column q-gutter-y-sm bg-white border-bottom">
      <div class="row items-center justify-between q-px-xs">
        <span class="text-subtitle2 text-weight-bold text-grey-9">Paste SKUs / Barcodes</span>
        <q-btn-dropdown
          flat
          dense
          no-caps
          :label="bulkSearchFieldLabel"
          class="text-caption text-weight-medium text-grey-8 search-field-dropdown"
        >
          <q-list dense>
            <q-item clickable v-close-popup @click="bulkSearchField = 'auto'">
              <q-item-section>Auto (All Fields)</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="bulkSearchField = 'product_code'">
              <q-item-section>Product Code</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="bulkSearchField = 'barcode'">
              <q-item-section>Barcode</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="bulkSearchField = 'id'">
              <q-item-section>Product ID</q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
      </div>

      <q-input
        v-model="bulkCodesText"
        type="textarea"
        outlined
        dense
        bg-color="white"
        class="bulk-codes-input"
        :input-style="{
          height: '110px',
          maxHeight: '110px',
          overflowY: 'auto',
          resize: 'none',
        }"
        :placeholder="bulkPlaceholder"
      />

      <div class="row items-center q-col-gutter-sm">
        <div class="col-auto">
          <q-input
            v-model.number="bulkDefaultQty"
            type="number"
            outlined
            dense
            bg-color="white"
            label="Default Qty"
            style="width: 100px"
            min="1"
            step="1"
          />
        </div>
        <div class="col">
          <q-btn
            unelevated
            no-caps
            color="dark"
            icon="ph ph-plus"
            label="Batch Add to Shipment"
            class="full-width rounded-btn text-weight-bold"
            :loading="bulkLoading"
            :disable="!bulkCodesText.trim() || submitting"
            @click="onBulkAddCodes"
          />
        </div>
      </div>
    </div>

    <!-- Catalog List -->
    <div class="browse-section col column q-px-md q-py-sm">
      <div v-if="browseList.length" class="row items-center justify-between q-mb-xs">
        <div class="text-caption text-weight-bold text-grey-8 text-uppercase" style="letter-spacing: 0.5px">
          Search Results ({{ browseList.length }})
        </div>
      </div>

      <div class="col scroll browse-list-container relative-position rounded-borders">
        <q-inner-loading :showing="browseLoading" />
        <q-list
          v-if="browseList.length || !browseSearch.trim()"
          dense
          bordered
          separator
          class="rounded-borders browse-list bg-white"
        >
          <q-item v-for="product in browseList" :key="product.id" class="q-py-sm product-card-row">
            <q-item-section avatar>
              <q-avatar square class="bg-grey-2 browse-product-thumb rounded-borders">
                <SmartImage
                  :src="product.image_url"
                  class="browse-product-thumb__img"
                  :enable-edit="false"
                  :enable-lightbox="false"
                />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <div class="text-weight-bold text-grey-9 text-body2">{{ product.name }}</div>
              <div class="row items-center q-gutter-x-sm q-mt-xs">
                <q-badge
                  v-if="product.product_code"
                  color="grey-3"
                  text-color="grey-9"
                  class="text-weight-medium text-caption"
                >
                  {{ product.product_code }}
                </q-badge>
                <span v-if="product.barcode" class="text-caption text-grey-6 font-mono">
                  {{ product.barcode }}
                </span>
              </div>
              <div class="row items-center q-gutter-x-md q-mt-xs text-caption text-grey-7">
                <span v-if="product.list_price_amount != null" class="text-weight-bold text-grey-9">
                  £{{ product.list_price_amount.toFixed(2) }}
                </span>
                <span v-if="product.product_weight">
                  Wt: {{ product.product_weight }}kg
                </span>
                <span v-if="isAlreadyOnShipment(product)" class="text-negative text-weight-medium">
                  • Already added to section
                </span>
              </div>
            </q-item-section>

            <q-item-section side class="row no-wrap items-center q-gutter-x-sm side-actions">
              <q-input
                :model-value="browseQtyById[product.id]"
                type="number"
                outlined
                dense
                bg-color="white"
                placeholder="1"
                style="width: 70px"
                min="1"
                step="1"
                :disable="isAlreadyOnShipment(product) || submitting"
                @update:model-value="
                  (val) => setBrowseQty(product.id, val === '' ? null : Number(val))
                "
                @keyup.enter="addProductToShipment(product, browseQtyById[product.id])"
              />
              <q-btn
                unelevated
                dense
                no-caps
                color="dark"
                icon="ph ph-plus"
                class="q-px-md rounded-btn text-weight-bold"
                label="Add"
                style="min-height: 36px"
                :loading="addingProductId === product.id"
                :disable="isAlreadyOnShipment(product) || submitting"
                @click="addProductToShipment(product, browseQtyById[product.id])"
              />
            </q-item-section>
          </q-item>

          <!-- Always visible Add Product row at bottom of list when there are search results -->
          <q-item
            v-if="browseList.length > 0"
            clickable
            v-ripple
            class="q-py-md add-product-list-row text-primary"
            @click="showNewProductSidebar = true"
          >
            <q-item-section avatar>
              <q-avatar square size="40px" class="bg-grey-2 text-primary rounded-borders border">
                <q-icon name="ph ph-plus" size="20px" />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <div class="text-weight-bold text-subtitle2">Add New Product</div>
              <div class="text-caption text-grey-6">Can't find what you need? Create a new product in the catalog</div>
            </q-item-section>
            <q-item-section side>
              <q-icon name="ph ph-caret-right" size="18px" color="grey-6" />
            </q-item-section>
          </q-item>

          <!-- When a search was performed and returned no results: Show Add as New Product list item -->
          <q-item
            v-if="!browseLoading && browseList.length === 0 && browseSearch.trim()"
            clickable
            v-ripple
            class="q-py-md add-product-list-row text-primary"
            @click="openNewProductWithSearchTerm"
          >
            <q-item-section avatar>
              <q-avatar square size="40px" class="bg-grey-2 text-primary rounded-borders border">
                <q-icon name="ph ph-plus" size="20px" />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <div class="text-weight-bold text-subtitle2">
                Add "{{ browseSearch.trim() }}" as New Product
              </div>
              <div class="text-caption text-grey-6">
                Not found in catalog. Click to create and add this product
              </div>
            </q-item-section>
            <q-item-section side>
              <q-icon name="ph ph-caret-right" size="18px" color="grey-6" />
            </q-item-section>
          </q-item>

          <!-- Initial Empty State (No search term typed) -->
          <q-item v-if="!browseLoading && !browseSearch.trim() && browseList.length === 0">
            <q-item-section class="text-grey-5 text-center q-pa-xl column items-center">
              <q-icon name="ph ph-magnifying-glass" size="36px" color="grey-4" class="q-mb-sm" />
              <div class="text-body2 text-weight-medium text-grey-7">
                Type in the search bar above to find products
              </div>
              <div class="text-caption text-grey-5 q-mt-xs">
                Search across product names, SKU codes, barcodes, or IDs
              </div>
            </q-item-section>
          </q-item>
        </q-list>

        <div v-if="browseTotal > browseList.length" class="text-center q-mt-sm">
          <q-btn
            flat
            dense
            no-caps
            color="dark"
            label="Load more products..."
            class="text-weight-medium"
            :loading="browseLoading"
            @click="loadMoreBrowse"
          />
        </div>
      </div>
    </div>

    <!-- Bottom Actions Bar: Summary and Done button -->
    <div class="panel-footer q-pa-md border-top bg-white row items-center justify-between">
      <div class="text-caption text-grey-7">
        <span v-if="browseList.length">
          Found <b>{{ browseList.length }}</b> matching product<span v-if="browseList.length > 1">s</span>
        </span>
        <span v-else>
          Ready
        </span>
      </div>

      <div class="row items-center q-gutter-x-sm">
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Done"
          class="q-px-xl rounded-btn text-weight-bold"
          @click="$emit('done')"
        />
      </div>
    </div>

    <!-- Catalog Filters Sidebar -->
    <FilterSidebar v-model="filterDrawerOpen" title="Filters" :z-index="7000">
      <div class="q-gutter-y-md q-pa-sm">
        <q-select
          v-model="draftBrand"
          :options="brandOptions"
          label="Brand"
          filled
          dense
          use-input
          fill-input
          hide-selected
          clearable
          new-value-mode="add-unique"
          @filter="filterBrands"
        />

        <q-select
          v-model="draftCategory"
          :options="categoryOptions"
          label="Category"
          filled
          dense
          use-input
          fill-input
          hide-selected
          clearable
          new-value-mode="add-unique"
          @filter="filterCategories"
        />

        <div class="row justify-end q-gutter-x-sm q-mt-md">
          <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
          <q-btn unelevated no-caps label="Apply Filters" color="primary" @click="onApplyFilters" />
        </div>
      </div>
    </FilterSidebar>

    <!-- New Product Sidebar -->
    <NewShipmentProductSidebar
      v-model="showNewProductSidebar"
      :target-section-name="selectedSectionName"
      :z-index="7100"
      @add="onNewProductAdd"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { productRepository } from 'src/modules/products/repositories/productRepository';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import { productService } from 'src/modules/products/services/productService';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import SmartImage from 'src/components/SmartImage.vue';
import NewShipmentProductSidebar from './NewShipmentProductSidebar.vue';

export interface ShipmentCartItem {
  key: string;
  product_id: number | null;
  isNewProduct: boolean;
  vendor_id: number | null;
  name: string;
  ordered_quantity: number;
  purchase_price: number;
  product_weight: number;
  package_weight: number;
  barcode: string | null;
  product_code: string | null;
  image_url: string | null;
  category: string | null;
  brand: string | null;
}

export interface ProductItem {
  id: number;
  name: string;
  product_code: string | null;
  barcode: string | null;
  list_price_amount: number | null;
  product_weight: number | null;
  package_weight: number | null;
  image_url: string | null;
}

const props = defineProps<{
  shipmentId: number;
  initialSectionId?: number | null;
}>();

defineEmits<{
  done: [];
}>();

const $q = useQuasar();
const authStore = useAuthStore();
const vendorStore = useVendorStore();
const shipmentStore = useGlobalShipmentStore();

const selectedSectionId = ref<number | null>(props.initialSectionId ?? null);

watch(
  () => shipmentStore.currentShipmentSections,
  (sections) => {
    if (selectedSectionId.value == null && sections && sections.length > 0 && sections[0]) {
      selectedSectionId.value = sections[0].id;
    }
  },
  { immediate: true },
);

const selectedSectionName = computed(() => {
  if (selectedSectionId.value) {
    const sec = shipmentStore.currentShipmentSections.find((s) => s.id === selectedSectionId.value);
    if (sec) return sec.title || `Section #${sec.id}`;
  }
  return null;
});

const sectionOptions = computed(() => {
  const sections = shipmentStore.currentShipmentSections ?? [];
  return sections.map((s) => ({
    label: s.vendor?.name ? `${s.title} (${s.vendor.name})` : s.title,
    value: s.id,
  }));
});

const submitting = ref(false);
const addingProductId = ref<number | null>(null);

// Catalog browse state
const browseSearch = ref('');
const browseSearchField = ref<'name' | 'barcode' | 'product_code' | 'id'>('name');
const browseList = ref<ProductItem[]>([]);
const browseLoading = ref(false);
const browsePage = ref(1);
const browseTotal = ref(0);
const browseQtyById = ref<Record<number, number | null>>({});
const showBulkCodes = ref(false);
const bulkCodesText = ref('');
const bulkSearchField = ref<'auto' | 'product_code' | 'barcode' | 'id'>('auto');
const bulkDefaultQty = ref(1);
const bulkLoading = ref(false);

const bulkSearchFieldLabel = computed(() => {
  if (bulkSearchField.value === 'product_code') return 'Product Code';
  if (bulkSearchField.value === 'barcode') return 'Barcode';
  if (bulkSearchField.value === 'id') return 'Product ID';
  return 'Auto (All)';
});

const bulkPlaceholder = computed(() => {
  if (bulkSearchField.value === 'product_code') {
    return 'Paste one Product Code per line or comma-separated\nPRD-001\nPRD-002';
  }
  if (bulkSearchField.value === 'barcode') {
    return 'Paste one Barcode per line or comma-separated\n8711000279502\n8711000279380';
  }
  if (bulkSearchField.value === 'id') {
    return 'Paste one Product ID per line or comma-separated\n101\n102\n#103';
  }
  return 'Paste Barcodes, Product Codes, or IDs (one per line or comma-separated)\n8711000279502\nPRD-001\n#101';
});

const searchFieldLabel = computed(() => {
  if (browseSearchField.value === 'name') return 'Name';
  if (browseSearchField.value === 'barcode') return 'Barcode';
  if (browseSearchField.value === 'product_code') return 'Product Code';
  if (browseSearchField.value === 'id') return 'Product ID';
  return 'Name';
});

// Filters State
const filterDrawerOpen = ref(false);
const filterBrand = ref<string>('');
const filterCategory = ref<string>('');

const draftBrand = ref<string>('');
const draftCategory = ref<string>('');

const allBrands = ref<string[]>([]);
const allCategories = ref<string[]>([]);
const brandOptions = ref<string[]>([]);
const categoryOptions = ref<string[]>([]);

const showNewProductSidebar = ref(false);

const openNewProductWithSearchTerm = () => {
  showNewProductSidebar.value = true;
};

const shipmentVendorId = computed(() => {
  const ship = shipmentStore.currentShipment;
  if (ship && ship.id === props.shipmentId) return ship.vendor_id ?? null;
  return null;
});

const activeFilterCount = computed(() => {
  let count = 0;
  if (filterBrand.value) count++;
  if (filterCategory.value) count++;
  return count;
});

const getVendorCode = (vendorId: number | null): string | null => {
  if (!vendorId) return null;
  return vendorStore.items.find((v) => v.id === vendorId)?.code ?? null;
};

const isAlreadyOnShipment = (product: ProductItem) => {
  return shipmentStore.currentShipmentItems.some((item) => {
    // If sections exist, only check duplicates within the same section
    if (selectedSectionId.value != null && item.section_id !== selectedSectionId.value) {
      return false;
    }
    if (item.product_id != null && item.product_id === product.id) return true;
    return Boolean(
      (item.barcode && item.barcode === product.barcode) ||
      (item.product_code && item.product_code === product.product_code)
    );
  });
};

const getSectionVendorId = (): number | null => {
  if (selectedSectionId.value) {
    const sec = shipmentStore.currentShipmentSections.find((s) => s.id === selectedSectionId.value);
    if (sec?.vendor_id) return sec.vendor_id;
  }
  return shipmentVendorId.value;
};

const buildShipmentItemPayload = (product: ProductItem, qty: number) => ({
  shipment_id: props.shipmentId,
  product_id: product.id,
  section_id: selectedSectionId.value,
  vendor_id: getSectionVendorId(),
  name: product.name,
  ordered_quantity: qty,
  purchase_price: product.list_price_amount || 0,
  product_weight: product.product_weight ?? 0,
  package_weight: product.package_weight ?? 0,
  barcode: product.barcode,
  product_code: product.product_code,
  image_url: product.image_url,
  add_method: 'manual' as const,
  source_child_tenant_id: null,
  source_type: null,
  source_id: null,
});

const persistProductToShipment = async (product: ProductItem, qty: number) => {
  if (isAlreadyOnShipment(product)) {
    return { ok: false as const, skipped: true };
  }

  await shipmentStore.addShipmentItem(buildShipmentItemPayload(product, qty));
  return { ok: true as const, skipped: false };
};

const setBrowseQty = (productId: number, qty: number | null) => {
  if (qty === null || isNaN(qty) || qty < 1) {
    browseQtyById.value[productId] = null;
  } else {
    browseQtyById.value[productId] = Math.floor(qty);
  }
};

const addProductToShipment = async (product: ProductItem, qty: number | null | undefined) => {
  if (isAlreadyOnShipment(product)) {
    $q.notify({ type: 'warning', message: `"${product.name}" is already on this shipment.` });
    return;
  }

  const finalQty = !qty || isNaN(qty) || qty < 1 ? 1 : Math.floor(qty);
  addingProductId.value = product.id;
  submitting.value = true;
  try {
    await persistProductToShipment(product, finalQty);
    browseQtyById.value[product.id] = null;
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: err instanceof Error ? err.message : `Failed to add "${product.name}".`,
    });
  } finally {
    addingProductId.value = null;
    submitting.value = false;
  }
};

const parseBulkCodes = (raw: string): string[] => {
  const tokens: string[] = [];
  for (const line of raw.split(/\r?\n/)) {
    for (const part of line.split(/[,;]+/)) {
      const code = part.trim();
      if (code) tokens.push(code);
    }
  }
  return tokens;
};

const onBulkAddCodes = async () => {
  const codes = parseBulkCodes(bulkCodesText.value);
  if (codes.length === 0) {
    $q.notify({ type: 'warning', message: 'Paste at least one product code, barcode, or ID.' });
    return;
  }

  const qty = Math.floor(Number(bulkDefaultQty.value));
  if (!qty || isNaN(qty) || qty < 1) {
    $q.notify({ type: 'warning', message: 'Quantity must be at least 1.' });
    return;
  }

  if (!authStore.tenantId) {
    $q.notify({ type: 'negative', message: 'Tenant is required to look up products.' });
    return;
  }

  bulkLoading.value = true;
  try {
    const products = await productRepository.lookupProductsByCodes({
      codes,
      tenantId: authStore.tenantId,
      searchField: bulkSearchField.value,
    });

    const byBarcode = new Map<string, ProductItem>();
    const byProductCode = new Map<string, ProductItem>();
    const byId = new Map<string, ProductItem>();

    for (const p of products) {
      const item: ProductItem = {
        id: p.id,
        name: p.name ?? '',
        product_code: p.product_code,
        barcode: p.barcode,
        list_price_amount: p.list_price_amount,
        product_weight: p.product_weight,
        package_weight: p.package_weight,
        image_url: p.image_url,
      };
      if (p.barcode?.trim()) byBarcode.set(p.barcode.trim(), item);
      if (p.product_code?.trim()) byProductCode.set(p.product_code.trim(), item);
      byId.set(String(p.id), item);
    }

    const missing: string[] = [];
    const toAdd: ProductItem[] = [];
    const seen = new Set<number>();
    let skipped = 0;
    for (const rawCode of codes) {
      const code = rawCode.trim();
      const cleanId = code.replace(/^#/, '');
      let product: ProductItem | undefined;

      if (bulkSearchField.value === 'product_code') {
        product = byProductCode.get(code) ?? byProductCode.get(cleanId);
      } else if (bulkSearchField.value === 'barcode') {
        product = byBarcode.get(code) ?? byBarcode.get(cleanId);
      } else if (bulkSearchField.value === 'id') {
        product = byId.get(cleanId);
      } else {
        product =
          byBarcode.get(code) ??
          byProductCode.get(code) ??
          byBarcode.get(cleanId) ??
          byProductCode.get(cleanId) ??
          byId.get(cleanId);
      }

      if (!product) {
        missing.push(code);
        continue;
      }
      if (seen.has(product.id) || isAlreadyOnShipment(product)) {
        skipped += 1;
        continue;
      }
      seen.add(product.id);
      toAdd.push(product);
    }

    if (toAdd.length > 0) {
      await shipmentStore.addShipmentItemsBulk(
        props.shipmentId,
        toAdd.map((product) => buildShipmentItemPayload(product, qty)),
      );
      bulkCodesText.value = missing.length > 0 ? missing.join('\n') : '';
    }

    const skipNote = skipped > 0 ? ` ${skipped} already on shipment.` : '';
    if (missing.length === 0 && toAdd.length > 0) {
      $q.notify({
        type: 'positive',
        message: `Added ${toAdd.length} item${toAdd.length === 1 ? '' : 's'}.${skipNote}`,
      });
    } else if (toAdd.length > 0) {
      $q.notify({
        type: 'warning',
        message: `Added ${toAdd.length} item${toAdd.length === 1 ? '' : 's'}.${skipNote} ${missing.length} code(s) not found in catalog.`,
      });
    } else {
      $q.notify({
        type: 'warning',
        message: `No new products were added.${skipNote} ${missing.length} code(s) not found.`,
      });
    }
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: err instanceof Error ? err.message : 'Bulk add failed.',
    });
  } finally {
    bulkLoading.value = false;
  }
};

let currentQuerySeq = 0;
const demoCatalogProducts: ProductItem[] = [
  {
    id: 101,
    name: 'Oversized Cotton Tee - Black',
    product_code: 'SKU-TEE-001',
    barcode: '8711000279501',
    list_price_amount: 12.5,
    product_weight: 0.25,
    package_weight: 0.35,
    image_url: 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=100&auto=format&fit=crop&q=60',
  },
  {
    id: 102,
    name: 'Slim Fit Oxford Shirt - Sky Blue',
    product_code: 'SKU-SHT-089',
    barcode: '8711000279502',
    list_price_amount: 24.0,
    product_weight: 0.3,
    package_weight: 0.4,
    image_url: 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=100&auto=format&fit=crop&q=60',
  },
  {
    id: 103,
    name: 'Vintage Wash Denim Jacket',
    product_code: 'SKU-JK-441',
    barcode: '8711000279503',
    list_price_amount: 65.0,
    product_weight: 0.85,
    package_weight: 1.1,
    image_url: 'https://images.unsplash.com/photo-1576995853123-5a10305d93c0?w=100&auto=format&fit=crop&q=60',
  },
  {
    id: 104,
    name: 'Relaxed Fit Linen Pants',
    product_code: 'SKU-PT-112',
    barcode: '8711000279504',
    list_price_amount: 22.0,
    product_weight: 0.45,
    package_weight: 0.55,
    image_url: 'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=100&auto=format&fit=crop&q=60',
  },
  {
    id: 105,
    name: 'Canvas Utility Crossbody Bag',
    product_code: 'SKU-BG-808',
    barcode: '8711000279505',
    list_price_amount: 15.5,
    product_weight: 0.35,
    package_weight: 0.45,
    image_url: 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=100&auto=format&fit=crop&q=60',
  },
];

const loadBrowse = async (append = false) => {
  currentQuerySeq++;
  const seq = currentQuerySeq;

  const rawSearch = browseSearch.value.trim();
  const cleanSearch = browseSearchField.value === 'id' ? rawSearch.replace(/^#/, '') : rawSearch;

  // Don't search or show catalog list when there is no search query or active filter
  if (!cleanSearch && !activeFilterCount.value) {
    browseList.value = [];
    browseTotal.value = 0;
    browseLoading.value = false;
    return;
  }

  browseLoading.value = true;
  try {
    if (authStore.tenantId) {
      const vendorCode = getVendorCode(shipmentVendorId.value) ?? undefined;
      const res = await productRepository.listProducts({
        page: browsePage.value,
        pageSize: 15,
        search: cleanSearch || undefined,
        searchField: browseSearchField.value,
        vendorCode,
        brand: filterBrand.value || undefined,
        category: filterCategory.value || undefined,
        tenantId: authStore.tenantId,
      });

      if (seq !== currentQuerySeq) return;

      const items = res.data as ProductItem[];
      if (items.length > 0) {
        browseList.value = append ? [...browseList.value, ...items] : items;
        browseTotal.value = res.meta.total;
        return;
      }
    }

    // Fallback search over demo catalog
    if (seq !== currentQuerySeq) return;
    let filtered = demoCatalogProducts;
    if (cleanSearch) {
      const query = cleanSearch.toLowerCase();
      filtered = filtered.filter(
        (p) =>
          p.name.toLowerCase().includes(query) ||
          p.product_code?.toLowerCase().includes(query) ||
          p.barcode?.toLowerCase().includes(query) ||
          String(p.id).includes(query),
      );
    }
    browseList.value = append ? [...browseList.value, ...filtered] : filtered;
    browseTotal.value = filtered.length;
  } catch (err) {
    console.error('Failed to load browse products:', err);
  } finally {
    if (seq === currentQuerySeq) {
      browseLoading.value = false;
    }
  }
};

const loadMoreBrowse = () => {
  browsePage.value += 1;
  void loadBrowse(true);
};

let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;
const debouncedLoadBrowse = () => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(() => void loadBrowse(), 300);
};

watch(browseSearch, (newVal) => {
  const query = (newVal || '').trim();
  if (!query) {
    browseList.value = [];
    browseTotal.value = 0;
    browseLoading.value = false;
    if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
    return;
  }

  browsePage.value = 1;
  debouncedLoadBrowse();
});

const onClearSearch = () => {
  browseSearch.value = '';
  browseList.value = [];
  browseTotal.value = 0;
  browseLoading.value = false;
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
};

watch(browseSearchField, () => {
  browsePage.value = 1;
  void loadBrowse();
});

const onNewProductAdd = async (newProduct: Omit<ShipmentCartItem, 'key'>) => {
  if (sectionOptions.value.length > 0 && !selectedSectionId.value) {
    $q.notify({ type: 'warning', message: 'Please select a vendor section before adding items.' });
    return;
  }

  submitting.value = true;
  try {
    const item: ShipmentCartItem = {
      ...newProduct,
      vendor_id: getSectionVendorId(),
      key: 'new',
      isNewProduct: true,
    };
    const productId = (await findExistingProductId(item)) ?? (await registerProduct(item));
    const already = shipmentStore.currentShipmentItems.some(
      (row) =>
        row.product_id === productId &&
        (selectedSectionId.value == null || row.section_id === selectedSectionId.value),
    );
    if (already) {
      $q.notify({ type: 'warning', message: `"${item.name}" is already in this section.` });
      return;
    }
    await shipmentStore.addShipmentItem({
      shipment_id: props.shipmentId,
      product_id: productId,
      section_id: selectedSectionId.value,
      vendor_id: getSectionVendorId(),
      name: item.name,
      ordered_quantity: item.ordered_quantity || 1,
      purchase_price: item.purchase_price || 0,
      product_weight: item.product_weight ?? 0,
      package_weight: item.package_weight ?? 0,
      barcode: item.barcode,
      product_code: item.product_code,
      image_url: item.image_url,
      add_method: 'manual',
      source_child_tenant_id: null,
      source_type: null,
      source_id: null,
    });
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: err instanceof Error ? err.message : 'Failed to add new product.',
    });
  } finally {
    submitting.value = false;
  }
};

const loadBrandCategoryOptions = async (vendorId: number | null) => {
  allBrands.value = [];
  allCategories.value = [];

  if (!vendorId) return;

  const vendorCode = getVendorCode(vendorId);
  const tenantId = authStore.tenantId;

  const [brandsRes, catsRes] = await Promise.all([
    productService.listBrands({ vendorCode, tenantId }),
    productService.listCategories({ vendorCode, tenantId }),
  ]);

  if (brandsRes.success && brandsRes.data) {
    allBrands.value = brandsRes.data;
  }
  if (catsRes.success && catsRes.data) {
    allCategories.value = catsRes.data;
  }
};

const openFilterSidebar = () => {
  draftBrand.value = filterBrand.value;
  draftCategory.value = filterCategory.value;
  void loadBrandCategoryOptions(shipmentVendorId.value);
  filterDrawerOpen.value = true;
};

const filterBrands = (val: string, update: (callback: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    brandOptions.value = needle
      ? allBrands.value.filter((v) => v.toLowerCase().includes(needle))
      : allBrands.value;
  });
};

const filterCategories = (val: string, update: (callback: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    categoryOptions.value = needle
      ? allCategories.value.filter((v) => v.toLowerCase().includes(needle))
      : allCategories.value;
  });
};

const onApplyFilters = () => {
  filterBrand.value = draftBrand.value;
  filterCategory.value = draftCategory.value;
  filterDrawerOpen.value = false;
  browsePage.value = 1;
  void loadBrowse();
};

const onResetFilters = () => {
  draftBrand.value = '';
  draftCategory.value = '';
  filterBrand.value = '';
  filterCategory.value = '';
  filterDrawerOpen.value = false;
  browsePage.value = 1;
  void loadBrowse();
};

const findExistingProductId = async (item: ShipmentCartItem): Promise<number | null> => {
  if (!authStore.tenantId) return null;
  const barcode = item.barcode?.trim();
  if (barcode) {
    const res = await productRepository.listProducts({
      page: 1,
      pageSize: 1,
      search: barcode,
      searchField: 'barcode',
      tenantId: authStore.tenantId,
    });
    const [first] = res.data;
    if (first) return first.id;
  }
  const productCode = item.product_code?.trim();
  if (productCode) {
    const res = await productRepository.listProducts({
      page: 1,
      pageSize: 1,
      search: productCode,
      searchField: 'product_code',
      tenantId: authStore.tenantId,
    });
    const [first] = res.data;
    if (first) return first.id;
  }
  return null;
};

const gbpCurrencyId = ref<number | null>(null);

const registerProduct = async (item: ShipmentCartItem): Promise<number> => {
  const existingId = await findExistingProductId(item);
  if (existingId) return existingId;

  const created = await productRepository.createProduct({
    inserted_by_tenant_id: authStore.tenantId ?? null,
    name: item.name,
    product_code: item.product_code,
    barcode: item.barcode,
    list_price_amount: item.purchase_price,
    list_price_currency_id: gbpCurrencyId.value,
    product_weight: item.product_weight,
    package_weight: item.package_weight,
    image_url: item.image_url,
    category: item.category,
    brand: item.brand,
    vendor_code: getVendorCode(shipmentVendorId.value),
    country_of_origin: null,
    available_units: null,
    languages: null,
    batch_code_manufacture_date: null,
    expire_date: null,
    minimum_order_quantity: null,
    market_code: null,
    is_available: true,
  });
  return created.id;
};

onMounted(async () => {
  if (
    !shipmentStore.currentShipment ||
    shipmentStore.currentShipment.id !== props.shipmentId
  ) {
    void shipmentStore.fetchShipmentDetails(props.shipmentId);
  }
  if (authStore.tenantId && vendorStore.items.length === 0) {
    void vendorStore.fetchVendors(authStore.tenantId);
  }
  void loadBrowse();
  try {
    const currencyData = await globalReferenceRepository.listCurrencies();
    gbpCurrencyId.value = currencyData.find((c) => c.code === 'GBP')?.id ?? null;
  } catch (e) {
    console.error('Error fetching currencies:', e);
  }
});
</script>

<style scoped>
.panel-body {
  min-height: 0;
  background: #f8fafc;
}

.top-nav-bar {
  border-bottom: 1px solid #e2e8f0;
}

.mode-switcher {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #f1f5f9;
}

.mode-btn {
  border-radius: 6px !important;
  font-size: 12.5px;
  transition: all 0.15s ease;
}

.search-header-bar {
  background: #ffffff;
  border-bottom: 1px solid #e2e8f0;
}

.search-scope-pill {
  border-right: 1px solid #e2e8f0;
  border-radius: 0;
}

.rounded-btn {
  border-radius: 8px !important;
}

.bulk-codes-box {
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
}

.browse-section {
  min-height: 0;
}

.browse-list-container {
  overflow-y: auto;
  min-height: 200px;
}

.browse-list {
  border: 1px solid #e2e8f0;
}

.product-card-row {
  transition: background-color 0.15s ease;
}

.product-card-row:hover {
  background-color: #f8fafc;
}

.add-product-list-row {
  background-color: #f8fafc;
  border-top: 1px dashed #cbd5e1;
  transition: background-color 0.15s ease;
}

.add-product-list-row:hover {
  background-color: #f1f5f9;
}

.side-actions {
  flex-shrink: 0 !important;
  display: flex !important;
  flex-direction: row !important;
  align-items: center !important;
}

.browse-product-thumb {
  width: 52px;
  height: 52px;
  border: 1px solid #e2e8f0;
}

.browse-product-thumb__img {
  width: 52px;
  height: 52px;
  object-fit: contain;
}

.panel-footer {
  border-top: 1px solid #e2e8f0;
  background: #ffffff;
}

:deep(input[type='number']::-webkit-outer-spin-button),
:deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(input[type='number']) {
  -moz-appearance: textfield;
}
</style>

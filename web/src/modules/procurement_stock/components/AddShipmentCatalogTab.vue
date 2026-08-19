<template>
  <div class="panel-body col column no-wrap">
    <div class="q-pa-md toolbar-section column q-gutter-y-sm">
      <!-- Target Vendor Section Selector -->
      <div class="row items-center q-col-gutter-sm">
        <div class="col-12">
          <q-select
            v-model="selectedSectionId"
            :options="sectionOptions"
            label="Target Vendor Section *"
            outlined
            dense
            bg-color="white"
            emit-value
            map-options
            :error="!selectedSectionId && sectionOptions.length > 0"
            error-message="A vendor section is required to add items"
            hide-bottom-space
          >
            <template #prepend>
              <q-icon name="ph ph-folder" size="18px" color="primary" />
            </template>
          </q-select>
        </div>
      </div>

      <div class="row items-center q-col-gutter-sm">
        <div class="col-auto">
          <q-btn-dropdown
            flat
            dense
            :label="searchFieldLabel"
            class="text-caption text-weight-medium text-grey-8 search-field-dropdown"
            no-caps
          >
            <q-list dense>
              <q-item clickable v-close-popup @click="browseSearchField = 'name'">
                <q-item-section>Name</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="browseSearchField = 'barcode'">
                <q-item-section>Barcode</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="browseSearchField = 'product_code'">
                <q-item-section>Product Code</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="browseSearchField = 'id'">
                <q-item-section>Product ID</q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
        </div>
        <div class="col">
          <q-input
            v-model="browseSearch"
            :placeholder="`Search catalog by ${searchFieldLabel.toLowerCase()}...`"
            outlined
            dense
            clearable
            autofocus
            class="full-width"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </div>
        <div class="col-auto">
          <q-btn
            flat
            dense
            no-caps
            color="grey-8"
            icon="ph ph-list-plus"
            label="Bulk codes"
            @click="showBulkCodes = !showBulkCodes"
          />
          <q-btn flat round dense icon="ph ph-funnel" color="grey-8" @click="openFilterSidebar">
            <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
              {{ activeFilterCount }}
            </q-badge>
          </q-btn>
        </div>
      </div>

      <q-btn
        unelevated
        no-caps
        color="primary"
        icon="ph ph-plus"
        label="New Product"
        class="new-product-btn full-width"
        @click="showNewProductSidebar = true"
      />

      <div
        v-if="showBulkCodes"
        class="column q-gutter-y-sm bulk-codes-box q-pa-sm rounded-borders"
      >
        <div class="row items-center justify-between q-px-xs">
          <span class="text-caption text-weight-medium text-grey-8">Paste Mode:</span>
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
          class="bulk-codes-input"
          :input-style="{
            height: '100px',
            maxHeight: '100px',
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
              label="Qty"
              style="width: 90px"
              min="1"
              step="1"
            />
          </div>
          <div class="col">
            <q-btn
              unelevated
              no-caps
              color="primary"
              icon="ph ph-plus"
              label="Add to shipment"
              class="full-width"
              :loading="bulkLoading"
              :disable="!bulkCodesText.trim() || submitting"
              @click="onBulkAddCodes"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Catalog List -->
    <div class="browse-section col column q-px-md q-pb-sm">
      <div class="text-subtitle2 text-weight-bold q-mb-xs">Catalog</div>
      <div class="col scroll browse-list-container relative-position">
        <q-inner-loading :showing="browseLoading" />
        <q-list
          v-if="browseList.length || !browseSearch.trim()"
          dense
          bordered
          separator
          class="rounded-borders browse-list"
        >
          <q-item v-for="product in browseList" :key="product.id">
            <q-item-section avatar>
              <q-avatar square class="bg-grey-2 browse-product-thumb">
                <SmartImage
                  :src="product.image_url"
                  class="browse-product-thumb__img"
                  :enable-edit="false"
                  :enable-lightbox="false"
                />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ product.name }}</q-item-label>
              <q-item-label caption>
                {{
                  [product.product_code, product.barcode].filter(Boolean).join(' · ') ||
                  'No code'
                }}
              </q-item-label>
              <q-item-label
                v-if="product.list_price_amount != null"
                caption
                class="text-secondary"
              >
                £{{ product.list_price_amount.toFixed(2) }}
              </q-item-label>
              <q-item-label v-if="isAlreadyOnShipment(product)" caption class="text-negative">
                Already in this section
              </q-item-label>
            </q-item-section>
            <q-item-section side class="row no-wrap items-center q-gutter-x-xs">
              <q-input
                :model-value="browseQtyById[product.id]"
                type="number"
                outlined
                dense
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
                color="primary"
                icon="ph ph-plus"
                class="q-px-sm"
                label="Add"
                :loading="addingProductId === product.id"
                :disable="isAlreadyOnShipment(product) || submitting"
                @click="addProductToShipment(product, browseQtyById[product.id])"
              />
            </q-item-section>
          </q-item>
          <q-item v-if="!browseLoading && browseList.length === 0">
            <q-item-section class="text-grey-6 text-center q-pa-md">
              {{
                browseSearch.trim() || activeFilterCount
                  ? 'No products found'
                  : 'Search the catalog to add items'
              }}
            </q-item-section>
          </q-item>
        </q-list>
        <div v-if="browseTotal > browseList.length" class="text-center q-mt-sm">
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            label="Load more"
            :loading="browseLoading"
            @click="loadMoreBrowse"
          />
        </div>
      </div>
    </div>

    <div class="panel-footer q-pa-md">
      <q-btn
        unelevated
        no-caps
        color="primary"
        label="Done"
        class="full-width"
        @click="$emit('done')"
      />
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
    if (selectedSectionId.value == null && sections && sections.length > 0) {
      selectedSectionId.value = sections[0].id;
    }
  },
  { immediate: true },
);

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
  if (sectionOptions.value.length > 0 && !selectedSectionId.value) {
    $q.notify({ type: 'warning', message: 'Please select a vendor section before adding items.' });
    return { ok: false as const, skipped: true };
  }

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
const loadBrowse = async (append = false) => {
  if (!authStore.tenantId) return;

  currentQuerySeq++;
  const seq = currentQuerySeq;
  browseLoading.value = true;
  try {
    const vendorCode = getVendorCode(shipmentVendorId.value) ?? undefined;

    const rawSearch = browseSearch.value.trim();
    const cleanSearch = browseSearchField.value === 'id' ? rawSearch.replace(/^#/, '') : rawSearch;

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
    browseList.value = append ? [...browseList.value, ...items] : items;
    browseTotal.value = res.meta.total;
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
  if (query) {
    let detectedField: 'name' | 'barcode' | 'product_code' | 'id' | null = null;
    if (/^#\d+$/.test(query)) {
      detectedField = 'id';
    } else if (/^\d{6,}$/.test(query)) {
      detectedField = 'barcode';
    } else if (/^[A-Za-z0-9\-_]{3,}$/.test(query) && /\d/.test(query) && /[A-Za-z]/.test(query)) {
      detectedField = 'product_code';
    }

    if (detectedField && browseSearchField.value !== detectedField) {
      browseSearchField.value = detectedField;
      browsePage.value = 1;
      return;
    }
  }

  browsePage.value = 1;
  debouncedLoadBrowse();
});

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
}

.toolbar-section {
  background: rgba(248, 250, 252, 0.5);
  border-bottom: 1px solid rgba(226, 232, 240, 0.8);
}

.new-product-btn {
  height: 40px;
}

.bulk-codes-box {
  background: rgba(241, 245, 249, 0.9);
  border: 1px solid rgba(226, 232, 240, 0.9);
}

.browse-section {
  min-height: 0;
}

.browse-list-container {
  overflow-y: auto;
  min-height: 150px;
}

.browse-list {
  border: 1px solid #e2e8f0;
}

.browse-product-thumb {
  width: 48px;
  height: 48px;
}

.browse-product-thumb__img {
  width: 48px;
  height: 48px;
  object-fit: contain;
}

.panel-footer {
  border-top: 1px solid rgba(226, 232, 240, 0.8);
  background: rgba(248, 250, 252, 0.5);
}

.search-field-dropdown {
  border-right: 1px solid rgba(0, 0, 0, 0.12);
  border-radius: 0;
  margin-right: 8px;
  padding-right: 8px;
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

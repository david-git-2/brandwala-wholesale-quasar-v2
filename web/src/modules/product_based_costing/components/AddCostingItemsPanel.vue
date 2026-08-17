<template>
  <div
    class="add-items-panel column no-wrap"
    :class="{ 'add-items-panel--drawer': layout === 'drawer' }"
  >
    <div class="panel-body col column no-wrap">
      <div class="q-pa-md toolbar-section column q-gutter-y-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col">
            <q-input
              v-model="browseSearch"
              placeholder="Search name, barcode, or code"
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

        <div
          v-if="showBulkCodes"
          class="column q-gutter-y-sm bulk-codes-box q-pa-sm rounded-borders"
        >
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
            placeholder="Paste barcodes or product codes, one per line"
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
                label="Add to file"
                class="full-width"
                :loading="bulkLoading"
                :disable="!bulkCodesText.trim() || submitting"
                @click="onBulkAddCodes"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="browse-section col column q-px-md q-pb-sm">
        <div class="text-subtitle2 text-weight-bold q-mb-xs">Catalog</div>
        <div class="col scroll browse-list-container relative-position">
          <q-inner-loading :showing="browseLoading" />
          <q-list dense bordered separator class="rounded-borders browse-list">
            <q-item
              v-if="browseSearch.trim()"
              clickable
              @click="onCreateMissingProduct"
            >
              <q-item-section avatar>
                <q-avatar square color="primary" text-color="white" icon="ph ph-plus" size="48px" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ createMissingProductLabel }}</q-item-label>
                <q-item-label caption>Not in the catalog? Add it as a new product.</q-item-label>
              </q-item-section>
            </q-item>
            <q-item v-for="product in browseList" :key="product.id">
              <q-item-section avatar>
                <q-avatar square class="bg-grey-2" size="48px">
                  <SmartImage
                    :src="product.image_url"
                    style="width: 48px; height: 48px; object-fit: contain"
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
                <q-item-label v-if="isAlreadyOnFile(product)" caption class="text-negative">
                  Already on file
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-btn
                  unelevated
                  dense
                  no-caps
                  color="primary"
                  icon="ph ph-plus"
                  label="Add"
                  :loading="addingProductId === product.id"
                  :disable="isAlreadyOnFile(product) || submitting"
                  @click="addProductToFile(product)"
                />
              </q-item-section>
            </q-item>
            <q-item v-if="!browseLoading && browseList.length === 0 && !browseSearch.trim()">
              <q-item-section class="text-center q-pa-md">
                <div class="text-grey-6">
                  {{ activeFilterCount ? 'No products found' : 'Search the catalog' }}
                </div>
              </q-item-section>
            </q-item>
            <q-item
              v-else-if="!browseLoading && browseList.length === 0 && browseSearch.trim()"
            >
              <q-item-section class="text-center q-pa-md text-grey-6">
                No products found
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
          @click="onDone"
        />
      </div>
    </div>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters" :z-index="7000">
      <div class="q-gutter-y-md q-pa-sm">
        <q-select
          v-model="draftVendorId"
          :options="vendorOptions"
          label="Vendor"
          filled
          dense
          emit-value
          map-options
          clearable
          @update:model-value="onDraftVendorChange"
        />

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
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import { describePbcItemMutationError } from '../composables/useProductBasedCostingItemMutations';
import { productRepository } from 'src/modules/products/repositories/productRepository';
import { productService } from 'src/modules/products/services/productService';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import SmartImage from 'src/components/SmartImage.vue';

interface ProductItem {
  id: number;
  name: string;
  product_code: string | null;
  barcode: string | null;
  list_price_amount: number | null;
  product_weight: number | null;
  package_weight: number | null;
  image_url: string | null;
  brand?: string | null;
  vendor_code?: string | null;
  market_code?: string | null;
  minimum_order_quantity?: number | null;
}

const props = withDefaults(
  defineProps<{
    fileId: number;
    layout?: 'drawer' | 'page';
  }>(),
  {
    layout: 'drawer',
  },
);

const emit = defineEmits<{
  saved: [];
  createNewProduct: [name: string];
}>();

const $q = useQuasar();
const authStore = useAuthStore();
const vendorStore = useVendorStore();
const costingStore = useProductBasedCostingStore();

const submitting = ref(false);
const addingProductId = ref<number | null>(null);

const browseSearch = ref('');
const browseSearchField = ref<'name' | 'barcode' | 'product_code'>('name');
const browseList = ref<ProductItem[]>([]);
const browseLoading = ref(false);
const browsePage = ref(1);
const browseTotal = ref(0);
const showBulkCodes = ref(false);
const bulkCodesText = ref('');
const bulkDefaultQty = ref(1);
const bulkLoading = ref(false);

const filterDrawerOpen = ref(false);
const filterVendorId = ref<number | null>(null);
const filterBrand = ref<string>('');
const filterCategory = ref<string>('');

const draftVendorId = ref<number | null>(null);
const draftBrand = ref<string>('');
const draftCategory = ref<string>('');

const allBrands = ref<string[]>([]);
const allCategories = ref<string[]>([]);
const brandOptions = ref<string[]>([]);
const categoryOptions = ref<string[]>([]);

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({ label: v.name, value: v.id })),
);

const activeFilterCount = computed(() => {
  let count = 0;
  if (filterVendorId.value) count++;
  if (filterBrand.value) count++;
  if (filterCategory.value) count++;
  return count;
});

const getVendorCode = (vendorId: number | null): string | null => {
  if (!vendorId) return null;
  return vendorStore.items.find((v) => v.id === vendorId)?.code ?? null;
};

const isAlreadyOnFile = (product: ProductItem) => {
  return costingStore.costingItems.some((item) => {
    if (item.product_id != null && item.product_id === product.id) return true;
    return item.barcode === product.barcode && item.product_code === product.product_code;
  });
};

const toProductItem = (p: {
  id: number;
  name: string | null;
  product_code: string | null;
  barcode: string | null;
  list_price_amount: number | null;
  product_weight: number | null;
  package_weight: number | null;
  image_url: string | null;
  brand?: string | null;
  vendor_code?: string | null;
  market_code?: string | null;
  minimum_order_quantity?: number | null;
}): ProductItem => ({
  id: p.id,
  name: p.name ?? '',
  product_code: p.product_code,
  barcode: p.barcode,
  list_price_amount: p.list_price_amount,
  product_weight: p.product_weight,
  package_weight: p.package_weight,
  image_url: p.image_url,
  brand: p.brand ?? null,
  vendor_code: p.vendor_code ?? null,
  market_code: p.market_code ?? null,
  minimum_order_quantity: p.minimum_order_quantity ?? null,
});

const defaultQtyForProduct = (product: ProductItem) => {
  const moq = product.minimum_order_quantity;
  if (moq != null && !isNaN(moq) && moq >= 1) return Math.floor(moq);
  return 1;
};

const persistProductToFile = async (product: ProductItem, qty: number) => {
  if (isAlreadyOnFile(product)) {
    return { ok: false as const, skipped: true };
  }

  const result = await costingStore.createProductBasedCostingItem({
    name: product.name || '',
    brand: product.brand || null,
    image_url: product.image_url || '',
    quantity: qty,
    barcode: product.barcode || '',
    product_code: product.product_code || '',
    vendor_code: product.vendor_code || null,
    market_code: product.market_code || null,
    price_gbp: product.list_price_amount || 0,
    product_weight: product.product_weight || 0,
    web_link: '',
    package_weight: product.package_weight || 0,
    product_based_costing_file_id: props.fileId,
    product_id: product.id,
    input_type: 'product_list',
  });

  if (!result.success) {
    const described = describePbcItemMutationError(
      result.error ?? `Failed to add "${product.name}".`,
      `Failed to add "${product.name}".`,
      'add',
    );
    $q.notify({ type: 'negative', message: described.message });
    return { ok: false as const, skipped: false };
  }
  return { ok: true as const, skipped: false };
};

const addProductToFile = async (product: ProductItem) => {
  if (isAlreadyOnFile(product)) {
    $q.notify({
      type: 'warning',
      message: `"${product.name}" is already on this costing file.`,
    });
    return;
  }

  addingProductId.value = product.id;
  submitting.value = true;
  try {
    await persistProductToFile(product, defaultQtyForProduct(product));
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
    $q.notify({ type: 'warning', message: 'Paste at least one barcode or product code.' });
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
    });

    const byBarcode = new Map<string, ProductItem>();
    const byProductCode = new Map<string, ProductItem>();
    for (const p of products) {
      const item = toProductItem(p);
      if (p.barcode?.trim()) byBarcode.set(p.barcode.trim(), item);
      if (p.product_code?.trim()) byProductCode.set(p.product_code.trim(), item);
    }

    const missing: string[] = [];
    let added = 0;
    let skipped = 0;
    submitting.value = true;
    for (const code of codes) {
      const product = byBarcode.get(code) ?? byProductCode.get(code);
      if (!product) {
        missing.push(code);
        continue;
      }
      const result = await persistProductToFile(product, qty);
      if (result.ok) added += 1;
      else if (result.skipped) skipped += 1;
    }

    if (missing.length > 0) {
      bulkCodesText.value = missing.join('\n');
    } else if (added > 0) {
      bulkCodesText.value = '';
    }

    const skipNote = skipped > 0 ? ` ${skipped} already on file.` : '';
    if (missing.length === 0 && added > 0) {
      $q.notify({
        type: 'positive',
        message: `Added ${added} item${added === 1 ? '' : 's'} to the file.${skipNote}`,
      });
    } else if (missing.length === 0 && skipped > 0) {
      $q.notify({
        type: 'warning',
        message: `${skipped} already on this file.`,
      });
    } else if (missing.length > 0 && added > 0) {
      $q.notify({
        type: 'warning',
        message: `Added ${added}.${skipNote} Not found: ${missing.join(', ')}`,
        timeout: 6000,
      });
    } else if (missing.length > 0) {
      $q.notify({
        type: 'negative',
        message: `Not found: ${missing.join(', ')}${skipNote}`,
        timeout: 6000,
      });
    }
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: err instanceof Error ? err.message : 'Failed to look up products.',
    });
  } finally {
    submitting.value = false;
    bulkLoading.value = false;
  }
};

let currentQuerySeq = 0;

const loadBrowse = async (append = false) => {
  if (
    !browseSearch.value.trim() &&
    !filterBrand.value &&
    !filterCategory.value &&
    !filterVendorId.value
  ) {
    browseList.value = [];
    browseTotal.value = 0;
    return;
  }

  currentQuerySeq++;
  const seq = currentQuerySeq;
  browseLoading.value = true;
  try {
    const vendorCode = filterVendorId.value
      ? vendorStore.items.find((v) => v.id === filterVendorId.value)?.code
      : undefined;

    const res = await productRepository.listProducts({
      page: browsePage.value,
      pageSize: 15,
      search: browseSearch.value.trim() || undefined,
      searchField: browseSearchField.value,
      vendorCode,
      brand: filterBrand.value || undefined,
      category: filterCategory.value || undefined,
      tenantId: authStore.tenantId,
    });

    if (seq !== currentQuerySeq) return;

    const items = (res.data as ProductItem[]).map((p) => toProductItem(p));
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
    let detectedField: 'name' | 'barcode' | 'product_code' | null = null;
    if (/^\d{6,}$/.test(query)) {
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

const openFilterSidebar = () => {
  draftVendorId.value = filterVendorId.value;
  draftBrand.value = filterBrand.value;
  draftCategory.value = filterCategory.value;
  void onDraftVendorChange(filterVendorId.value);
  filterDrawerOpen.value = true;
};

const onDraftVendorChange = async (vendorId: number | null) => {
  draftBrand.value = '';
  draftCategory.value = '';
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
  filterVendorId.value = draftVendorId.value;
  filterBrand.value = draftBrand.value;
  filterCategory.value = draftCategory.value;
  filterDrawerOpen.value = false;
  browsePage.value = 1;
  void loadBrowse();
};

const onResetFilters = () => {
  draftVendorId.value = null;
  draftBrand.value = '';
  draftCategory.value = '';
  filterVendorId.value = null;
  filterBrand.value = '';
  filterCategory.value = '';
  filterDrawerOpen.value = false;
  browsePage.value = 1;
  void loadBrowse();
};

const onDone = () => {
  emit('saved');
};

const createMissingProductLabel = computed(() => {
  const q = browseSearch.value.trim();
  return q ? `Create "${q}" as a new product` : 'Create new product';
});

const onCreateMissingProduct = () => {
  emit('createNewProduct', browseSearch.value.trim());
};

onMounted(async () => {
  if (costingStore.costingItems.length === 0) {
    await costingStore.fetchProductBasedCostingItems(props.fileId);
  }
  if (authStore.tenantId && vendorStore.items.length === 0) {
    void vendorStore.fetchVendors(authStore.tenantId);
  }
});
</script>

<style scoped>
.add-items-panel {
  flex: 1;
  min-height: 0;
  background: transparent;
}

.add-items-panel--drawer {
  width: 100%;
}

.add-items-panel:not(.add-items-panel--drawer) {
  min-height: 70vh;
}

.panel-body {
  min-height: 0;
}

.toolbar-section {
  background: rgba(248, 250, 252, 0.5);
  border-bottom: 1px solid rgba(226, 232, 240, 0.8);
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

.panel-footer {
  border-top: 1px solid rgba(226, 232, 240, 0.8);
  background: rgba(248, 250, 252, 0.5);
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

<template>
  <div
    class="add-items-panel column no-wrap"
    :class="{ 'add-items-panel--drawer': layout === 'drawer' }"
  >
    <div class="panel-body col">
      <div class="search-col column no-wrap">
        <div class="q-pa-md toolbar-section column q-gutter-y-sm">
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
                class="full-width"
              />
            </div>
            <div class="col-auto">
              <q-btn flat round dense icon="filter_alt" color="grey-8" @click="openFilterSidebar">
                <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                  {{ activeFilterCount }}
                </q-badge>
              </q-btn>
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col">
              <q-btn
                outline
                no-caps
                icon="playlist_add"
                label="Bulk codes"
                class="full-width"
                :color="showBulkCodes ? 'secondary' : 'primary'"
                @click="showBulkCodes = !showBulkCodes"
              />
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
                height: '120px',
                maxHeight: '120px',
                overflowY: 'auto',
                resize: 'none',
              }"
              placeholder="Paste one barcode or product code per line&#10;8711000279502&#10;8711000279380"
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
                  color="secondary"
                  icon="add_shopping_cart"
                  label="Add to cart"
                  class="full-width"
                  :loading="bulkLoading"
                  :disable="!bulkCodesText.trim()"
                  @click="onBulkAddCodes"
                />
              </div>
            </div>
          </div>
        </div>

        <div class="browse-section col column q-px-md q-pb-sm">
          <div class="text-subtitle2 text-weight-bold q-mb-xs">Catalog Products</div>
          <div class="col scroll browse-list-container relative-position">
            <q-inner-loading :showing="browseLoading" />
            <q-list dense bordered separator class="rounded-borders browse-list">
              <q-item v-for="product in browseList" :key="product.id">
                <q-item-section avatar>
                  <q-avatar square class="bg-grey-2" style="width: 1in; height: 1in">
                    <SmartImage
                      :src="product.image_url"
                      style="width: 1in; height: 1in; object-fit: contain"
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
                  <q-item-label caption class="text-grey-7">
                    MOQ: {{ product.minimum_order_quantity ?? '—' }}
                  </q-item-label>
                  <q-item-label v-if="isAlreadyOnFile(product)" caption class="text-negative">
                    Already on file
                  </q-item-label>
                </q-item-section>
                <q-item-section side class="row no-wrap items-center q-gutter-x-xs">
                  <q-input
                    :model-value="browseQtyById[product.id]"
                    type="number"
                    outlined
                    dense
                    placeholder="Qty"
                    style="width: 70px"
                    min="1"
                    step="1"
                    :disable="isAlreadyOnFile(product)"
                    @update:model-value="
                      (val) => setBrowseQty(product.id, val === '' ? null : Number(val))
                    "
                  />
                  <q-input
                    :model-value="browsePalletById[product.id]"
                    type="number"
                    outlined
                    dense
                    placeholder="Case"
                    style="width: 70px"
                    min="1"
                    step="1"
                    :disable="isAlreadyOnFile(product)"
                    @update:model-value="
                      (val) => setBrowsePallet(product.id, val === '' ? null : Number(val))
                    "
                  />
                  <q-btn
                    unelevated
                    dense
                    no-caps
                    color="secondary"
                    icon="add"
                    class="q-px-sm"
                    label="Add"
                    :disable="isAlreadyOnFile(product)"
                    @click="addProductToCart(product)"
                  />
                </q-item-section>
              </q-item>
              <q-item v-if="!browseLoading && browseList.length === 0">
                <q-item-section class="text-grey-6 text-center q-pa-md"
                  >No products found</q-item-section
                >
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
      </div>

      <div class="cart-col column no-wrap">
        <div class="cart-section col q-pa-md">
          <div class="row items-center justify-between q-mb-sm">
            <div class="text-subtitle1 text-weight-bold">
              Cart
              <q-badge v-if="cart.length" color="primary" :label="cart.length" class="q-ml-xs" />
            </div>
            <q-btn
              v-if="cart.length"
              flat
              dense
              no-caps
              color="negative"
              label="Clear"
              @click="confirmClearCart"
            />
          </div>

          <div v-if="cart.length === 0" class="text-center text-grey-6 q-py-lg">
            <q-icon name="shopping_cart" size="36px" color="grey-4" />
            <div class="q-mt-sm">Search catalog and add products</div>
          </div>

          <div v-else class="cart-scroll">
            <div
              v-for="item in cart"
              :key="item.key"
              class="cart-line q-mb-sm q-pa-sm rounded-borders"
            >
              <div class="row items-start no-wrap q-col-gutter-sm">
                <div class="col-auto">
                  <q-avatar square class="bg-grey-2" style="width: 1in; height: 1in">
                    <SmartImage
                      :src="item.image_url"
                      style="width: 1in; height: 1in; object-fit: contain"
                      :enable-edit="false"
                      :enable-lightbox="false"
                    />
                  </q-avatar>
                </div>
                <div class="col" style="min-width: 0">
                  <div class="text-weight-medium ellipsis-2-lines">{{ item.name }}</div>
                  <div class="text-caption text-grey-7">
                    <span v-if="item.product_code || item.barcode">
                      {{ [item.product_code, item.barcode].filter(Boolean).join(' · ') }}
                    </span>
                    <span class="q-ml-sm text-weight-bold text-grey-6">
                      (Wt: {{ item.product_weight }}g / Pkg: {{ item.package_weight }}g)
                    </span>
                  </div>
                  <div class="text-caption text-secondary">
                    £{{ formatMoney(item.price_gbp) }}
                  </div>
                </div>
                <div class="col-auto">
                  <q-btn
                    flat
                    round
                    dense
                    size="sm"
                    color="negative"
                    icon="close"
                    @click="removeFromCart(item)"
                  />
                </div>
              </div>
              <div class="row q-col-gutter-xs q-mt-xs">
                <div class="col-4">
                  <q-input
                    v-model.number="item.quantity"
                    type="number"
                    label="Qty"
                    outlined
                    dense
                    min="1"
                    step="1"
                  />
                </div>
                <div class="col-4">
                  <q-input
                    type="number"
                    label="Case"
                    outlined
                    dense
                    min="1"
                    step="1"
                    :model-value="cartPalletByKey[item.key] ?? null"
                    @update:model-value="(v) => onCartPalletUpdated(item, v === '' ? null : Number(v))"
                  />
                </div>
                <div class="col-4">
                  <q-input
                    v-model.number="item.price_gbp"
                    type="number"
                    step="0.01"
                    label="Price £"
                    outlined
                    dense
                    min="0"
                  />
                </div>
              </div>
              <div class="text-caption text-grey-7 text-right q-mt-xs">
                £{{ formatMoney(lineSubtotal(item)) }}
              </div>
            </div>
          </div>
        </div>

        <div class="panel-footer q-pa-md">
          <div v-if="cart.length" class="row justify-between text-body2 q-mb-xs">
            <span class="text-grey-7"
              >{{ totalCartUnits }} units · {{ totalCartWeightKg.toFixed(2) }} kg</span
            >
            <span class="text-weight-bold text-primary">£{{ formatMoney(totalCartPriceGbp) }}</span>
          </div>
          <div class="row q-gutter-sm">
            <q-btn
              v-if="showCancel"
              flat
              no-caps
              color="grey-8"
              label="Cancel"
              class="col"
              @click="onCancel"
            />
            <q-btn
              unelevated
              no-caps
              color="primary"
              icon="save"
              :label="
                cart.length ? `Save ${cart.length} item${cart.length === 1 ? '' : 's'}` : 'Save'
              "
              class="col"
              :loading="submitting"
              :disable="cart.length === 0"
              @click="onCommitCart"
            />
          </div>
        </div>
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
import { productRepository } from 'src/modules/products/repositories/productRepository';
import { productService } from 'src/modules/products/services/productService';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import SmartImage from 'src/components/SmartImage.vue';

export interface CostingCartItem {
  key: string;
  product_id: number;
  name: string;
  quantity: number;
  price_gbp: number;
  product_weight: number;
  package_weight: number;
  barcode: string | null;
  product_code: string | null;
  brand: string | null;
  vendor_code: string | null;
  market_code: string | null;
  image_url: string | null;
  minimum_order_quantity: number | null;
}

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
    showCancel?: boolean;
  }>(),
  {
    layout: 'drawer',
    showCancel: true,
  },
);

const emit = defineEmits<{
  saved: [];
  cancel: [];
}>();

const $q = useQuasar();
const authStore = useAuthStore();
const vendorStore = useVendorStore();
const costingStore = useProductBasedCostingStore();

const submitting = ref(false);

const browseSearch = ref('');
const browseSearchField = ref<'name' | 'barcode' | 'product_code'>('name');
const browseList = ref<ProductItem[]>([]);
const browseLoading = ref(false);
const browsePage = ref(1);
const browseTotal = ref(0);
const browseQtyById = ref<Record<number, number | null>>({});
const browsePalletById = ref<Record<number, number | null>>({});
const cartPalletByKey = ref<Record<string, number | null>>({});
const showBulkCodes = ref(false);
const bulkCodesText = ref('');
const bulkDefaultQty = ref(1);
const bulkLoading = ref(false);

const searchFieldLabel = computed(() => {
  if (browseSearchField.value === 'name') return 'Name';
  if (browseSearchField.value === 'barcode') return 'Barcode';
  if (browseSearchField.value === 'product_code') return 'Product Code';
  return 'Name';
});

const cart = ref<CostingCartItem[]>([]);
const cartStorageKey = computed(() => `costing_cart_${props.fileId}`);

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

const totalCartUnits = computed(() =>
  cart.value.reduce((sum, item) => sum + (item.quantity || 0), 0),
);

const totalCartWeightKg = computed(() => {
  let sum = 0;
  for (const item of cart.value) {
    sum += ((item.product_weight || 0) + (item.package_weight || 0)) * item.quantity;
  }
  return sum / 1000;
});

const totalCartPriceGbp = computed(() =>
  cart.value.reduce((sum, item) => sum + (item.price_gbp || 0) * item.quantity, 0),
);

const formatMoney = (val: number) => val.toFixed(2);
const lineSubtotal = (item: CostingCartItem) => (item.price_gbp || 0) * item.quantity;

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

const saveCartToStorage = () => {
  const key = cartStorageKey.value;
  if (cart.value.length === 0) {
    sessionStorage.removeItem(key);
  } else {
    sessionStorage.setItem(key, JSON.stringify(cart.value));
  }
};

const loadCartFromStorage = () => {
  try {
    const raw = sessionStorage.getItem(cartStorageKey.value);
    if (!raw) return;
    const parsed = JSON.parse(raw) as CostingCartItem[];
    if (Array.isArray(parsed)) {
      cart.value = parsed.map((item) => ({
        ...item,
        minimum_order_quantity: item.minimum_order_quantity ?? null,
      }));
    }
  } catch {
    sessionStorage.removeItem(cartStorageKey.value);
  }
};

let saveCartTimer: ReturnType<typeof setTimeout> | null = null;
const debouncedSaveCart = () => {
  if (saveCartTimer) clearTimeout(saveCartTimer);
  saveCartTimer = setTimeout(saveCartToStorage, 500);
};

watch(cart, debouncedSaveCart, { deep: true });

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

const buildCatalogCartItem = (product: ProductItem, qty: number): CostingCartItem => ({
  key: `catalog_${product.id}`,
  product_id: product.id,
  name: product.name,
  quantity: qty,
  price_gbp: product.list_price_amount || 0,
  product_weight: product.product_weight ?? 0,
  package_weight: product.package_weight ?? 0,
  barcode: product.barcode,
  product_code: product.product_code,
  brand: product.brand ?? null,
  vendor_code: product.vendor_code ?? null,
  market_code: product.market_code ?? null,
  image_url: product.image_url,
  minimum_order_quantity: product.minimum_order_quantity ?? null,
});

const mergeProductIntoCart = (product: ProductItem, cleanQty: number) => {
  if (isAlreadyOnFile(product)) {
    $q.notify({
      type: 'warning',
      message: `"${product.name}" is already on this costing file.`,
    });
    return;
  }

  const key = `catalog_${product.id}`;
  const existing = cart.value.find((c) => c.key === key);
  if (existing) {
    existing.quantity += cleanQty;
    existing.product_weight = product.product_weight ?? 0;
    existing.package_weight = product.package_weight ?? 0;
    existing.minimum_order_quantity = product.minimum_order_quantity ?? null;

    const idx = cart.value.indexOf(existing);
    if (idx > -1) {
      cart.value.splice(idx, 1);
      cart.value.unshift(existing);
    }
  } else {
    cart.value.unshift(buildCatalogCartItem(product, cleanQty));
  }
};

const setBrowseQty = (productId: number, qty: number | null) => {
  if (qty === null || isNaN(qty) || qty < 1) {
    browseQtyById.value[productId] = null;
  } else {
    browseQtyById.value[productId] = Math.floor(qty);
  }
};

const setBrowsePallet = (productId: number, pallet: number | null) => {
  if (pallet === null || isNaN(pallet) || pallet < 1) {
    browsePalletById.value[productId] = null;
  } else {
    browsePalletById.value[productId] = Math.floor(pallet);
  }
};

/** Qty wins; else pallet × MOQ. Returns null if neither usable. */
const resolveAddQty = (
  qty: number | null | undefined,
  pallet: number | null | undefined,
  moq: number | null | undefined,
): { qty: number } | { error: 'missing_moq' | 'missing_input' } => {
  if (qty != null && !isNaN(qty) && qty >= 1) {
    return { qty: Math.floor(qty) };
  }
  if (pallet != null && !isNaN(pallet) && pallet >= 1) {
    if (moq == null || isNaN(moq) || moq < 1) {
      return { error: 'missing_moq' };
    }
    return { qty: Math.floor(pallet) * Math.floor(moq) };
  }
  return { error: 'missing_input' };
};

const addProductToCart = (product: ProductItem) => {
  const resolved = resolveAddQty(
    browseQtyById.value[product.id],
    browsePalletById.value[product.id],
    product.minimum_order_quantity,
  );
  if ('error' in resolved) {
    $q.notify({
      type: 'warning',
      message:
        resolved.error === 'missing_moq'
          ? 'Case needs a minimum order quantity on the product.'
          : 'Enter Qty, or Case (× MOQ).',
    });
    return;
  }

  mergeProductIntoCart(product, resolved.qty);
  browseQtyById.value[product.id] = null;
  browsePalletById.value[product.id] = null;
  browseSearch.value = '';
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
    for (const code of codes) {
      const product = byBarcode.get(code) ?? byProductCode.get(code);
      if (!product) {
        missing.push(code);
        continue;
      }
      if (isAlreadyOnFile(product)) continue;
      mergeProductIntoCart(product, qty);
      added += 1;
    }

    if (added > 0) {
      bulkCodesText.value = '';
    }

    if (missing.length === 0) {
      $q.notify({
        type: 'positive',
        message: `Added ${added} item${added === 1 ? '' : 's'} to cart.`,
      });
    } else if (added > 0) {
      $q.notify({
        type: 'warning',
        message: `Added ${added}. Not found: ${missing.join(', ')}`,
        timeout: 6000,
      });
    } else {
      $q.notify({
        type: 'negative',
        message: `Not found: ${missing.join(', ')}`,
        timeout: 6000,
      });
    }
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: err instanceof Error ? err.message : 'Failed to look up products.',
    });
  } finally {
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

const onCartPalletUpdated = (item: CostingCartItem, pallet: number | null) => {
  if (pallet === null || isNaN(pallet) || pallet < 1) {
    cartPalletByKey.value[item.key] = null;
    return;
  }
  const moq = item.minimum_order_quantity;
  if (moq == null || isNaN(moq) || moq < 1) {
    $q.notify({
      type: 'warning',
      message: 'Case needs a minimum order quantity on the product.',
    });
    cartPalletByKey.value[item.key] = null;
    return;
  }
  cartPalletByKey.value[item.key] = Math.floor(pallet);
  item.quantity = Math.floor(pallet) * Math.floor(moq);
};

const removeFromCart = (item: CostingCartItem) => {
  cart.value = cart.value.filter((c) => c.key !== item.key);
  delete cartPalletByKey.value[item.key];
};

const confirmClearCart = () => {
  $q.dialog({ title: 'Clear cart?', message: 'Remove all items?', cancel: true }).onOk(() => {
    cart.value = [];
    cartPalletByKey.value = {};
  });
};

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

const onCancel = () => {
  emit('cancel');
};

const onCommitCart = async () => {
  if (cart.value.length === 0) return;

  const invalid = cart.value.find(
    (item) => !item.quantity || isNaN(Number(item.quantity)) || Number(item.quantity) < 1,
  );
  if (invalid) {
    $q.notify({
      type: 'warning',
      message: `"${invalid.name}" needs a quantity of at least 1.`,
    });
    return;
  }

  submitting.value = true;
  try {
    let saved = 0;
    for (const item of [...cart.value].reverse()) {
      const result = await costingStore.createProductBasedCostingItem({
        name: item.name || '',
        brand: item.brand || null,
        image_url: item.image_url || '',
        quantity: item.quantity,
        barcode: item.barcode || '',
        product_code: item.product_code || '',
        vendor_code: item.vendor_code || null,
        market_code: item.market_code || null,
        price_gbp: item.price_gbp || 0,
        product_weight: item.product_weight || 0,
        web_link: '',
        package_weight: item.package_weight || 0,
        status: 'pending',
        product_based_costing_file_id: props.fileId,
        product_id: item.product_id,
        input_type: 'product_list',
      });

      if (!result.success) {
        $q.notify({
          type: 'negative',
          message: result.error ?? `Failed to add "${item.name}".`,
        });
        return;
      }
      saved += 1;
    }

    cart.value = [];
    cartPalletByKey.value = {};
    sessionStorage.removeItem(cartStorageKey.value);
    $q.notify({
      type: 'positive',
      message: `Saved ${saved} item${saved === 1 ? '' : 's'}.`,
    });
    emit('saved');
  } finally {
    submitting.value = false;
  }
};

onMounted(async () => {
  loadCartFromStorage();
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
  display: flex;
  flex-direction: row;
  flex-wrap: nowrap;
}

.search-col {
  flex: 1 1 58%;
  min-width: 0;
  min-height: 0;
  border-right: 1px solid rgba(226, 232, 240, 0.8);
}

.cart-col {
  flex: 1 1 42%;
  min-width: 0;
  min-height: 0;
}

@media (max-width: 900px) {
  .panel-body {
    flex-direction: column;
  }
  .search-col,
  .cart-col {
    flex: 1 1 auto;
  }
  .search-col {
    border-right: none;
    border-bottom: 1px solid rgba(226, 232, 240, 0.8);
  }
  .browse-list-container {
    max-height: 45vh;
  }
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

.cart-section {
  min-height: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.cart-scroll {
  overflow-y: auto;
  flex: 1;
}

.cart-line {
  background: rgba(248, 250, 252, 0.6);
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.panel-footer {
  border-top: 1px solid rgba(226, 232, 240, 0.8);
  background: rgba(248, 250, 252, 0.5);
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
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

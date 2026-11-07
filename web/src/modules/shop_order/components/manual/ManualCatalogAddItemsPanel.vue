<template>
  <div class="panel-body col column no-wrap" :class="{ 'panel-body--drawer': layout === 'drawer' }">
    <div class="top-nav-bar row items-center justify-between q-px-md q-py-sm bg-white border-bottom">
      <div class="text-subtitle1 text-weight-bold text-grey-9">
        {{ $t('shop_admin.manual_catalog_add_item_title', 'Add Item') }}
      </div>

      <div class="row items-center bg-grey-2 q-pa-xs rounded-borders mode-switcher">
        <q-btn
          unelevated
          dense
          no-caps
          :color="!showBulkCodes ? 'white' : 'transparent'"
          :text-color="!showBulkCodes ? 'grey-10' : 'grey-7'"
          :class="{ 'shadow-1 text-weight-bold': !showBulkCodes, 'text-weight-medium': showBulkCodes }"
          :label="$t('common.search', 'Search')"
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
          :label="$t('shop_admin.manual_catalog_add_item_bulk', 'Bulk')"
          icon="ph ph-list-plus"
          class="q-px-md mode-btn"
          @click="showBulkCodes = true"
        />
      </div>

      <q-btn flat round dense icon="ph ph-x" color="grey-8" @click="emit('done')">
        <q-tooltip>{{ $t('common.close', 'Close') }}</q-tooltip>
      </q-btn>
    </div>

    <div v-if="!showBulkCodes" class="q-pa-md search-header-bar column q-gutter-y-sm">
      <div class="row items-center q-col-gutter-sm">
        <div class="col">
          <q-input
            v-model="browseSearch"
            :placeholder="searchPlaceholder"
            outlined
            dense
            autofocus
            bg-color="white"
            class="catalog-search-input"
            data-test="manual-catalog-add-items-search"
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
                    <q-item-section>{{ $t('shop_admin.manual_catalog_search_by_name', 'Search by Name') }}</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="browseSearchField = 'barcode'">
                    <q-item-section>{{ $t('shop_admin.manual_catalog_search_by_barcode', 'Search by Barcode') }}</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="browseSearchField = 'product_code'">
                    <q-item-section>{{ $t('shop_admin.manual_catalog_search_by_code', 'Search by Product Code / SKU') }}</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="browseSearchField = 'id'">
                    <q-item-section>{{ $t('shop_admin.manual_catalog_search_by_id', 'Search by Product ID') }}</q-item-section>
                  </q-item>
                </q-list>
              </q-btn-dropdown>
            </template>
            <template v-if="browseSearch" #append>
              <q-btn flat round dense size="sm" icon="ph ph-x" color="grey-6" @click="onClearSearch" />
            </template>
          </q-input>
        </div>
      </div>
    </div>

    <div v-else class="q-pa-md bulk-header-bar column q-gutter-y-sm bg-white border-bottom">
      <div class="row items-center justify-between q-px-xs">
        <span class="text-subtitle2 text-weight-bold text-grey-9">
          {{ $t('shop_admin.manual_catalog_paste_skus', 'Paste SKUs / Barcodes') }}
        </span>
        <q-btn-dropdown
          flat
          dense
          no-caps
          :label="bulkSearchFieldLabel"
          class="text-caption text-weight-medium text-grey-8 search-field-dropdown"
        >
          <q-list dense>
            <q-item clickable v-close-popup @click="bulkSearchField = 'auto'">
              <q-item-section>{{ $t('shop_admin.manual_catalog_bulk_field_auto', 'Auto (All Fields)') }}</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="bulkSearchField = 'product_code'">
              <q-item-section>{{ $t('shop_admin.manual_catalog_bulk_field_code', 'Product Code') }}</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="bulkSearchField = 'barcode'">
              <q-item-section>{{ $t('shop_admin.manual_catalog_bulk_field_barcode', 'Barcode') }}</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="bulkSearchField = 'id'">
              <q-item-section>{{ $t('shop_admin.manual_catalog_bulk_field_id', 'Product ID') }}</q-item-section>
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
            :label="$t('shop_admin.manual_catalog_default_qty', 'Default Qty')"
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
            :label="$t('shop_admin.manual_catalog_batch_add_lines', 'Batch add to order')"
            class="full-width rounded-btn text-weight-bold"
            :loading="bulkLoading"
            :disable="!bulkCodesText.trim() || bulkLoading"
            data-test="manual-catalog-batch-add"
            @click="onBulkAddCodes"
          />
        </div>
      </div>
      <div v-if="oldOrderMode" class="text-caption text-grey-7">
        {{ $t('shop_admin.manual_catalog_bulk_add_codes_old_hint', 'Set GBP unit price and sell on each line in the table after adding.') }}
      </div>
    </div>

    <div v-if="!showBulkCodes" class="browse-section col column q-px-md q-py-sm">
      <div v-if="browseList.length" class="row items-center justify-between q-mb-xs">
        <div class="text-caption text-weight-bold text-grey-8 text-uppercase" style="letter-spacing: 0.5px">
          {{ $t('shop_admin.manual_catalog_search_results', 'Search results') }} ({{ browseList.length }})
        </div>
      </div>

      <div class="col scroll browse-list-container relative-position rounded-borders">
        <q-inner-loading :showing="browseLoading" />
        <q-list dense bordered separator class="rounded-borders browse-list bg-white">
          <q-item v-for="row in browseList" :key="row.product_id" class="q-py-sm product-card-row">
            <q-item-section avatar>
              <q-avatar square class="bg-grey-2 browse-product-thumb rounded-borders">
                <q-img
                  v-if="row.product_image_url"
                  :src="row.product_image_url"
                  fit="contain"
                  class="browse-product-thumb__img"
                />
                <q-icon v-else name="ph ph-image-square" color="grey-5" />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <div class="text-weight-bold text-grey-9 text-body2">{{ row.product_name }}</div>
              <div class="row items-center q-gutter-x-sm q-mt-xs">
                <q-badge
                  v-if="row.product_code"
                  color="grey-3"
                  text-color="grey-9"
                  class="text-weight-medium text-caption"
                >
                  {{ row.product_code }}
                </q-badge>
                <span v-if="row.product_barcode" class="text-caption text-grey-6 font-mono">
                  {{ row.product_barcode }}
                </span>
              </div>
              <div v-if="row.unit_price_amount != null" class="q-mt-xs text-caption text-weight-bold text-grey-9">
                £{{ formatPrice(row.unit_price_amount) }}
              </div>
            </q-item-section>
            <q-item-section side class="row no-wrap items-center q-gutter-x-sm side-actions">
              <q-input
                :model-value="browseQtyById[row.product_id]"
                type="number"
                outlined
                dense
                bg-color="white"
                placeholder="1"
                style="width: 70px"
                min="1"
                step="1"
                :disable="addingProductId === row.product_id"
                @update:model-value="
                  (val) => setBrowseQty(row.product_id, val === '' ? null : Number(val))
                "
                @keyup.enter="addRow(row, browseQtyById[row.product_id])"
              />
              <q-btn
                unelevated
                dense
                no-caps
                color="dark"
                icon="ph ph-plus"
                class="q-px-md rounded-btn text-weight-bold"
                :label="$t('common.add', 'Add')"
                style="min-height: 36px"
                :loading="addingProductId === row.product_id"
                @click="addRow(row, browseQtyById[row.product_id])"
              />
            </q-item-section>
          </q-item>

          <q-item v-if="!browseLoading && !browseSearch.trim() && browseList.length === 0">
            <q-item-section class="text-grey-5 text-center q-pa-xl column items-center">
              <q-icon name="ph ph-magnifying-glass" size="36px" color="grey-4" class="q-mb-sm" />
              <div class="text-body2 text-weight-medium text-grey-7">
                {{ $t('shop_admin.manual_catalog_add_search_empty', 'Type in the search bar to find products') }}
              </div>
            </q-item-section>
          </q-item>

          <q-item v-if="!browseLoading && browseSearch.trim() && browseList.length === 0">
            <q-item-section class="text-grey-6 text-center q-pa-lg">
              {{ $t('shop_admin.manual_order_no_products', 'No products match your search') }}
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>

    <div class="panel-footer q-pa-md border-top bg-white row items-center justify-end">
      <q-btn
        unelevated
        no-caps
        color="primary"
        :label="$t('common.done', 'Done')"
        class="q-px-xl rounded-btn text-weight-bold"
        data-test="manual-catalog-add-items-done"
        @click="emit('done')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useQuasar } from 'quasar';
import { productRepository } from 'src/modules/products/repositories/productRepository';
import {
  browseManualCatalogProducts,
  productRowToCatalogItem,
} from '../../composables/useManualCatalogOrder';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { ShopCatalogItem } from '../../types';

const props = withDefaults(
  defineProps<{
    tenantId: number;
    browseShopIds: number[];
    oldOrderMode?: boolean;
    layout?: 'drawer' | 'page';
  }>(),
  { oldOrderMode: false, layout: 'drawer' },
);

const emit = defineEmits<{
  done: [];
  'add-product': [row: ShopCatalogItem, qty: number];
}>();

const { t } = useI18n();
const $q = useQuasar();

const browseSearch = ref('');
const browseSearchField = ref<'name' | 'barcode' | 'product_code' | 'id'>('name');
const browseList = ref<ShopCatalogItem[]>([]);
const browseLoading = ref(false);
const browseQtyById = ref<Record<number, number | null>>({});
const showBulkCodes = ref(false);
const bulkCodesText = ref('');
const bulkSearchField = ref<'auto' | 'product_code' | 'barcode' | 'id'>('auto');
const bulkDefaultQty = ref(1);
const bulkLoading = ref(false);
const addingProductId = ref<number | null>(null);

const searchFieldLabel = computed(() => {
  if (browseSearchField.value === 'barcode') return t('shop_admin.manual_catalog_bulk_field_barcode', 'Barcode');
  if (browseSearchField.value === 'product_code') {
    return t('shop_admin.manual_catalog_bulk_field_code', 'Product Code');
  }
  if (browseSearchField.value === 'id') return t('shop_admin.manual_catalog_bulk_field_id', 'Product ID');
  return t('shop_admin.manual_catalog_search_by_name', 'Name');
});

const searchPlaceholder = computed(
  () =>
    `${t('shop_admin.manual_catalog_search_catalog_by', 'Search catalog by')} ${searchFieldLabel.value.toLowerCase()}…`,
);

const bulkSearchFieldLabel = computed(() => {
  if (bulkSearchField.value === 'product_code') {
    return t('shop_admin.manual_catalog_bulk_field_code', 'Product Code');
  }
  if (bulkSearchField.value === 'barcode') {
    return t('shop_admin.manual_catalog_bulk_field_barcode', 'Barcode');
  }
  if (bulkSearchField.value === 'id') {
    return t('shop_admin.manual_catalog_bulk_field_id', 'Product ID');
  }
  return t('shop_admin.manual_catalog_bulk_field_auto', 'Auto (All Fields)');
});

const bulkPlaceholder = computed(() => {
  if (bulkSearchField.value === 'product_code') {
    return 'PRD-001\nPRD-002';
  }
  if (bulkSearchField.value === 'barcode') {
    return '8711000279502\n8711000279380';
  }
  if (bulkSearchField.value === 'id') {
    return '101\n#102';
  }
  return '8711000279502\nPRD-001\n#101';
});

const formatPrice = (amount: number | string) => {
  const n = Number(amount);
  return Number.isFinite(n) ? n.toFixed(2) : String(amount);
};

const setBrowseQty = (productId: number, qty: number | null) => {
  browseQtyById.value[productId] = qty;
};

const onClearSearch = () => {
  browseSearch.value = '';
};

let browseSeq = 0;
const loadBrowse = async () => {
  browseSeq += 1;
  const seq = browseSeq;
  const raw = browseSearch.value.trim();
  const cleanSearch = browseSearchField.value === 'id' ? raw.replace(/^#/, '') : raw;
  if (cleanSearch.length < 2) {
    browseList.value = [];
    browseLoading.value = false;
    return;
  }

  browseLoading.value = true;
  try {
    let items: ShopCatalogItem[];
    if (browseSearchField.value === 'name' || props.browseShopIds.length > 0) {
      items = await browseManualCatalogProducts(props.tenantId, props.browseShopIds, cleanSearch);
    } else {
      const res = await productRepository.listProducts({
        tenantId: props.tenantId,
        search: cleanSearch,
        searchField: browseSearchField.value,
        pageSize: 24,
      });
      items = (res.data ?? []).map(productRowToCatalogItem);
    }
    if (seq !== browseSeq) return;
    browseList.value = items;
  } catch (err) {
    if (seq === browseSeq) {
      showErrorNotification(
        err instanceof Error ? err.message : t('common.error_generic', 'Something went wrong'),
      );
    }
  } finally {
    if (seq === browseSeq) {
      browseLoading.value = false;
    }
  }
};

let searchDebounceTimer: ReturnType<typeof setTimeout> | undefined;
watch(browseSearch, () => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  const query = browseSearch.value.trim();
  if (query.length < 2) {
    browseList.value = [];
    browseLoading.value = false;
    return;
  }
  searchDebounceTimer = setTimeout(() => void loadBrowse(), 300);
});

watch(browseSearchField, () => {
  if (browseSearch.value.trim().length >= 2) void loadBrowse();
});

onBeforeUnmount(() => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
});

const addRow = async (row: ShopCatalogItem, qty: number | null | undefined) => {
  const finalQty = !qty || Number.isNaN(qty) || qty < 1 ? 1 : Math.floor(qty);
  addingProductId.value = row.product_id;
  try {
    emit('add-product', row, finalQty);
    browseQtyById.value[row.product_id] = null;
  } finally {
    addingProductId.value = null;
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

const resolveProductFromMaps = (
  code: string,
  byBarcode: Map<string, ShopCatalogItem>,
  byProductCode: Map<string, ShopCatalogItem>,
  byId: Map<string, ShopCatalogItem>,
): ShopCatalogItem | undefined => {
  const cleanId = code.replace(/^#/, '');
  if (bulkSearchField.value === 'product_code') {
    return byProductCode.get(code) ?? byProductCode.get(cleanId);
  }
  if (bulkSearchField.value === 'barcode') {
    return byBarcode.get(code) ?? byBarcode.get(cleanId);
  }
  if (bulkSearchField.value === 'id') {
    return byId.get(cleanId);
  }
  return (
    byBarcode.get(code) ??
    byProductCode.get(code) ??
    byBarcode.get(cleanId) ??
    byProductCode.get(cleanId) ??
    byId.get(cleanId)
  );
};

const onBulkAddCodes = async () => {
  const codes = parseBulkCodes(bulkCodesText.value);
  if (codes.length === 0) {
    $q.notify({ type: 'warning', message: t('shop_admin.manual_catalog_bulk_codes_required', 'Paste at least one code.') });
    return;
  }
  const qty = Math.floor(Number(bulkDefaultQty.value));
  if (!qty || Number.isNaN(qty) || qty < 1) {
    $q.notify({ type: 'warning', message: t('shop_admin.manual_catalog_qty_min', 'Quantity must be at least 1.') });
    return;
  }

  bulkLoading.value = true;
  try {
    const products = await productRepository.lookupProductsByCodes({
      codes,
      tenantId: props.tenantId,
      searchField: bulkSearchField.value,
    });
    const byBarcode = new Map<string, ShopCatalogItem>();
    const byProductCode = new Map<string, ShopCatalogItem>();
    const byId = new Map<string, ShopCatalogItem>();
    for (const p of products) {
      const item = productRowToCatalogItem(p);
      if (p.barcode?.trim()) byBarcode.set(p.barcode.trim(), item);
      if (p.product_code?.trim()) byProductCode.set(p.product_code.trim(), item);
      byId.set(String(p.id), item);
    }

    const missing: string[] = [];
    const seen = new Set<number>();
    let added = 0;
    for (const rawCode of codes) {
      const product = resolveProductFromMaps(rawCode, byBarcode, byProductCode, byId);
      if (!product) {
        missing.push(rawCode);
        continue;
      }
      if (seen.has(product.product_id)) continue;
      seen.add(product.product_id);
      emit('add-product', product, qty);
      added += 1;
    }

    if (added > 0) {
      showSuccessNotification(
        t('shop_admin.manual_catalog_bulk_add_success', '{n} item(s) added', { n: added }),
      );
      bulkCodesText.value = missing.length > 0 ? missing.join('\n') : '';
    }
    if (missing.length) {
      showErrorNotification(
        t('shop_admin.manual_catalog_bulk_add_missing', 'No match: {codes}', {
          codes: missing.slice(0, 8).join(', '),
        }),
      );
    }
  } catch (err) {
    showErrorNotification(
      err instanceof Error ? err.message : t('common.error_generic', 'Something went wrong'),
    );
  } finally {
    bulkLoading.value = false;
  }
};
</script>

<style scoped>
.panel-body {
  min-height: 0;
  background: #f8fafc;
}

.panel-body--drawer {
  width: 100%;
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

.product-card-row:hover {
  background-color: var(--tf-hover-bg);
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

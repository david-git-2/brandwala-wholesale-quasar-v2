<template>
  <q-page class="q-pa-md" :class="{ 'preview-canvas': mode === 'pdf' }">
    <section
      class="preview-page__shell"
      :class="{
        'preview-page--screenshot': mode === 'screenshot',
        'preview-page--pdf': mode === 'pdf',
      }"
      :style="{ maxWidth: shellMaxWidth }"
    >
      <div class="preview-page__actions q-mb-md no-print row items-center justify-between">
        <div class="row items-center q-gutter-x-sm">
          <q-btn
            size="sm"
            dense
            flat
            color="primary"
            icon="ph ph-arrow-left"
            :label="$t('product_based_costing.go_back')"
            class="preview-page__action-btn"
            @click="goBack"
          />
          <q-btn-group unelevated class="preview-page__mode-group">
            <q-btn
              size="sm"
              :color="mode === 'screenshot' ? 'primary' : 'grey-4'"
              :text-color="mode === 'screenshot' ? 'white' : 'dark'"
              icon="ph ph-camera"
              :label="$t('product_based_costing.preview_screenshot')"
              @click="mode = 'screenshot'"
            />
            <q-btn
              size="sm"
              :color="mode === 'pdf' ? 'primary' : 'grey-4'"
              :text-color="mode === 'pdf' ? 'white' : 'dark'"
              icon="ph ph-file-pdf"
              :label="$t('product_based_costing.preview_pdf_mode')"
              @click="mode = 'pdf'"
            />
          </q-btn-group>
        </div>

        <q-btn
          size="sm"
          color="primary"
          icon="ph ph-printer"
          :label="$t('product_based_costing.preview_print')"
          class="preview-page__action-btn preview-page__print-btn"
          @click="printPage"
        />
      </div>

      <q-card flat bordered class="preview-page__meta-card q-mb-md">
        <q-card-section class="preview-page__meta-section">
          <div class="preview-page__meta-line">
            <div class="preview-page__meta-value">{{ fileLabel }}</div>
            <div class="preview-page__meta-value preview-page__meta-value--compact">
              {{ fileName }}
            </div>
          </div>

          <template v-if="mode === 'screenshot'">
            <div class="preview-page__meta-label q-mt-sm">{{ $t('product_based_costing.col_created_for') }}</div>
            <div class="preview-page__meta-value preview-page__meta-value--compact">
              {{ createdFor }}
            </div>
          </template>
        </q-card-section>
      </q-card>

      <q-banner
        v-if="mode === 'pdf' && columns.length > 7"
        dense
        class="no-print q-mb-md bg-amber-1 text-amber-10 rounded-borders"
      >
        <template #avatar>
          <q-icon name="ph ph-warning" color="warning" size="18px" />
        </template>
        <div class="text-caption">
          <strong>{{ $t('product_based_costing.preview_a4_notice_title') }}</strong>
          {{
            $t('product_based_costing.preview_a4_notice_body', {
              count: columns.length,
            })
          }}
        </div>
      </q-banner>

      <q-card flat bordered class="preview-page__table-card">
        <q-table
          flat
          bordered
          :rows="tableRows"
          :columns="columns"
          row-key="id"
          :loading="loading"
          hide-pagination
          :pagination="{ rowsPerPage: 0 }"
          class="preview-page__table"
        >
          <template #header="props">
            <q-tr :props="props" class="preview-page__header-row">
              <q-th
                v-for="(col, colIdx) in props.cols"
                :key="col.name"
                :props="props"
                :class="[
                  'preview-page__header-cell',
                  col.align ? `text-${col.align}` : '',
                  col.name === 'sl' ? 'preview-page__header-cell--sl preview-page__sl-cell' : '',
                  col.name === 'image' ? 'preview-page__header-cell--image' : '',
                  col.name === 'name' ? 'preview-page__header-cell--name' : '',
                  col.name === 'offerPriceBdt' ? 'preview-page__header-cell--offer' : '',
                  showCutoffMarking && props.cols.length > 7 && Number(colIdx) === 6
                    ? 'a4-cutoff-cell'
                    : '',
                  showCutoffMarking && props.cols.length > 7 && Number(colIdx) > 6
                    ? 'a4-overflow-header'
                    : '',
                ]"
              >
                <span>{{ col.label }}</span>
                <q-badge
                  v-if="showCutoffMarking && props.cols.length > 7 && Number(colIdx) === 6"
                  color="warning"
                  text-color="dark"
                  dense
                  class="q-ml-xs no-print text-weight-bold"
                  style="font-size: 9px; padding: 2px 4px"
                >
                  A4 Cutoff
                </q-badge>
              </q-th>
            </q-tr>
          </template>

          <template #body="slotProps">
            <q-tr :props="slotProps">
              <q-td
                v-for="(col, colIdx) in slotProps.cols"
                :key="col.name"
                :props="slotProps"
                :class="[
                  col.align ? `text-${col.align}` : '',
                  col.name === 'sl' ? 'preview-page__sl-cell' : '',
                  col.name === 'name' ? 'preview-page__name-cell' : '',
                  col.name === 'qty' ? 'preview-page__compact-cell' : '',
                  col.name === 'offerPriceBdt' ? 'preview-page__offer-cell' : '',
                  showCutoffMarking && slotProps.cols.length > 7 && Number(colIdx) === 6
                    ? 'a4-cutoff-cell'
                    : '',
                  showCutoffMarking && slotProps.cols.length > 7 && Number(colIdx) > 6
                    ? 'a4-overflow-body'
                    : '',
                ]"
              >
                <!-- SL -->
                <template v-if="col.name === 'sl'">
                  {{ slotProps.row.sl }}
                </template>

                <!-- Image -->
                <template v-else-if="col.name === 'image'">
                  <SmartImage
                    :src="resolvePreviewImageUrl(slotProps.row.imageUrl)"
                    :alt="slotProps.row.name || 'Product image'"
                    img-class="preview-page__image"
                    fallback-class="preview-page__image preview-page__image--placeholder"
                    :enable-edit="false"
                    fit="contain"
                  />
                </template>

                <!-- Name -->
                <template v-else-if="col.name === 'name'">
                  <div class="preview-page__name-text">
                    {{ slotProps.row.name }}
                  </div>
                </template>

                <!-- Qty -->
                <template v-else-if="col.name === 'qty'">
                  <span class="text-weight-bold">{{ slotProps.row.qty ?? slotProps.row.quantity ?? '-' }}</span>
                </template>

                <!-- Website -->
                <template v-else-if="col.name === 'website'">
                  <a
                    v-if="slotProps.row.website"
                    :href="slotProps.row.website"
                    target="_blank"
                    rel="noopener"
                    class="text-primary text-caption"
                  >
                    {{ $t('product_based_costing.preview_link') }}
                  </a>
                  <span v-else>-</span>
                </template>

                <!-- Numeric GBP fields -->
                <template
                  v-else-if="
                    [
                      'priceGbp',
                      'totalPurchasePriceGbp',
                      'cargoCostGbp',
                      'totalCostGbp',
                    ].includes(col.name)
                  "
                >
                  £{{ formatNumber(slotProps.row[col.name]) }}
                </template>

                <!-- Numeric BDT fields -->
                <template
                  v-else-if="
                    [
                      'costBdt',
                      'offerPriceBdt',
                      'totalBdt',
                      'profitPerUnitBdt',
                    ].includes(col.name)
                  "
                >
                  <span
                    :class="{
                      'preview-page__offer-value':
                        col.name === 'offerPriceBdt' || col.name === 'totalBdt',
                    }"
                  >
                    ৳{{ formatNumber(slotProps.row[col.name]) }}
                  </span>
                </template>

                <!-- Weight fields -->
                <template
                  v-else-if="
                    ['productWeight', 'packageWeight', 'totalWeight'].includes(
                      col.name,
                    )
                  "
                >
                  {{ slotProps.row[col.name] ? `${slotProps.row[col.name]} kg` : '-' }}
                </template>

                <!-- Profit rate -->
                <template v-else-if="col.name === 'profitRate'">
                  {{ slotProps.row.profitRate != null ? `${slotProps.row.profitRate}%` : '-' }}
                </template>

                <!-- Default fallback -->
                <template v-else>
                  {{ slotProps.row[col.name] ?? '-' }}
                </template>
              </q-td>
            </q-tr>
          </template>

          <template #loading>
            <q-inner-loading showing color="primary" />
          </template>

          <template #no-data>
            <div class="full-width row flex-center q-pa-lg text-grey-7">
              {{ $t('product_based_costing.preview_no_data') }}
            </div>
          </template>
        </q-table>
      </q-card>

      <!-- Dynamic Export Summary Card -->
      <q-card
        v-if="summaryMetrics.length && mode !== 'screenshot'"
        flat
        bordered
        class="preview-page__summary-card q-mt-md"
      >
        <q-card-section class="q-pa-md">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm row items-center">
            <q-icon name="ph ph-file-text" size="18px" class="q-mr-xs text-primary" />
            {{ $t('product_based_costing.preview_costing_summary') }}
          </div>
          <div class="row q-col-gutter-sm">
            <div
              v-for="metric in summaryMetrics"
              :key="metric.label"
              class="col-6 col-sm-4 col-md-3"
            >
              <div class="preview-page__summary-item">
                <div class="preview-page__summary-label">{{ metric.label }}</div>
                <div
                  class="preview-page__summary-value"
                  :class="{ 'text-positive text-weight-bolder': metric.highlight }"
                >
                  {{ metric.value }}
                </div>
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <div v-if="mode === 'screenshot'" class="preview-page__pager q-mt-sm no-print">
        <q-btn
          size="sm"
          dense
          round
          flat
          color="primary"
          icon="ph ph-caret-left"
          class="preview-page__pager-nav"
          :disable="currentPage <= 1 || !rows.length"
          @click="goPrevPage"
        />
        <div class="preview-page__pager-center">
          <div class="preview-page__pager-label">
            {{ $t('product_based_costing.preview_page_of', { current: currentPage, total: totalPages }) }}
          </div>
          <div class="preview-page__pager-sub">
            {{
              $t('product_based_costing.preview_showing_range', {
                start: pageStartIndex,
                end: pageEndIndex,
                total: rows.length,
              })
            }}
          </div>
        </div>
        <q-btn
          size="sm"
          dense
          round
          flat
          color="primary"
          icon="ph ph-caret-right"
          class="preview-page__pager-nav"
          :disable="currentPage >= totalPages || !rows.length"
          @click="goNextPage"
        />
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import type { QTableColumn } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

import SmartImage from 'src/components/SmartImage.vue';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import type { ProductBasedCostingFile, ProductBasedCostingItem } from '../types';
import {
  calculateOfferPriceBdt,
  getUnitCostBdt,
  getUnitTotalCostGbp,
  normalizeOfferPriceBdt,
  toNumberSafe,
} from '../utils/pricing';

const props = defineProps<{
  id: string;
  pageSize?: number;
}>();

const mode = ref<'screenshot' | 'pdf'>('screenshot');
const isPrinting = ref(false);
const showCutoffMarking = computed(() => !isPrinting.value && mode.value === 'pdf');

const handleBeforePrint = () => {
  isPrinting.value = true;
};

const handleAfterPrint = () => {
  isPrinting.value = false;
};

onMounted(() => {
  window.addEventListener('beforeprint', handleBeforePrint);
  window.addEventListener('afterprint', handleAfterPrint);
});

onUnmounted(() => {
  window.removeEventListener('beforeprint', handleBeforePrint);
  window.removeEventListener('afterprint', handleAfterPrint);
});

const route = useRoute();
const router = useRouter();
const store = useProductBasedCostingStore();
const { t } = useI18n();

const costingFileId = computed(() => Number(props.id));
const loading = ref(false);
const costingFile = ref<ProductBasedCostingFile | null>(null);
const rawItems = ref<ProductBasedCostingItem[]>([]);

interface PreviewColumnDef {
  key: string;
  label: string;
  align: 'left' | 'center' | 'right';
  field: string | ((row: any) => any);
}

const ALL_PREVIEW_COLUMN_DEFS: Record<string, PreviewColumnDef> = {
  sl: { key: 'sl', label: 'SL', align: 'center', field: 'sl' },
  image: { key: 'image', label: t('product_based_costing.table_image'), align: 'center', field: 'imageUrl' },
  name: { key: 'name', label: t('product_based_costing.col_name'), align: 'center', field: 'name' },
  brand: { key: 'brand', label: t('product_based_costing.table_col_brand'), align: 'center', field: 'brand' },
  note: { key: 'note', label: t('product_based_costing.note'), align: 'center', field: 'note' },
  qty: { key: 'qty', label: t('product_based_costing.table_col_qty'), align: 'center', field: 'quantity' },
  deliveredQty: {
    key: 'deliveredQty',
    label: t('product_based_costing.table_col_deliveredQty'),
    align: 'center',
    field: 'delivered_quantity',
  },
  barcodeText: {
    key: 'barcodeText',
    label: t('product_based_costing.preview_barcode_code'),
    align: 'center',
    field: 'barcodeText',
  },
  website: { key: 'website', label: t('product_based_costing.table_col_website'), align: 'center', field: 'website' },
  priceGbp: { key: 'priceGbp', label: t('product_based_costing.preview_price_gbp'), align: 'center', field: 'priceGbp' },
  totalPurchasePriceGbp: {
    key: 'totalPurchasePriceGbp',
    label: t('product_based_costing.preview_total_purchase_gbp'),
    align: 'center',
    field: 'totalPurchasePriceGbp',
  },
  productWeight: {
    key: 'productWeight',
    label: t('product_based_costing.preview_product_wt_kg'),
    align: 'center',
    field: 'productWeight',
  },
  packageWeight: {
    key: 'packageWeight',
    label: t('product_based_costing.preview_package_wt_kg'),
    align: 'center',
    field: 'packageWeight',
  },
  totalWeight: {
    key: 'totalWeight',
    label: t('product_based_costing.preview_total_wt_kg'),
    align: 'center',
    field: 'totalWeight',
  },
  cargoRate: { key: 'cargoRate', label: t('product_based_costing.table_col_cargoRate'), align: 'center', field: 'cargoRate' },
  cargoCostGbp: {
    key: 'cargoCostGbp',
    label: t('product_based_costing.preview_cargo_cost_gbp'),
    align: 'center',
    field: 'cargoCostGbp',
  },
  totalCostGbp: {
    key: 'totalCostGbp',
    label: t('product_based_costing.preview_total_cost_gbp'),
    align: 'center',
    field: 'totalCostGbp',
  },
  costBdt: { key: 'costBdt', label: t('product_based_costing.preview_cost_bdt'), align: 'center', field: 'costBdt' },
  offerPriceBdt: {
    key: 'offerPriceBdt',
    label: t('product_based_costing.preview_offer_price_bdt'),
    align: 'center',
    field: 'offerPriceBdt',
  },
  totalBdt: { key: 'totalBdt', label: t('product_based_costing.preview_total_offer_bdt'), align: 'center', field: 'totalBdt' },
  profitPerUnitBdt: {
    key: 'profitPerUnitBdt',
    label: t('product_based_costing.preview_profit_bdt'),
    align: 'center',
    field: 'profitPerUnitBdt',
  },
  profitRate: { key: 'profitRate', label: t('product_based_costing.table_col_profitRate'), align: 'center', field: 'profitRate' },
  status: { key: 'status', label: t('product_based_costing.col_status'), align: 'center', field: 'status' },
};

const requestedColumnKeys = computed<string[]>(() => {
  const queryCols = route.query.cols;
  if (typeof queryCols === 'string' && queryCols.trim()) {
    const parsed = queryCols
      .split(',')
      .map((c) => c.trim())
      .filter(Boolean);
    if (parsed.length) {
      return parsed;
    }
  }
  return [
    'sl',
    'image',
    'name',
    'brand',
    'qty',
    'priceGbp',
    'productWeight',
    'offerPriceBdt',
    'totalBdt',
  ];
});

const columns = computed<QTableColumn[]>(() => {
  return requestedColumnKeys.value
    .map((key) => ALL_PREVIEW_COLUMN_DEFS[key])
    .filter((def): def is PreviewColumnDef => Boolean(def))
    .map((def) => ({
      name: def.key,
      label: def.label,
      field: def.field,
      align: def.align,
    }));
});

watch(
  costingFileId,
  async (newId) => {
    if (!newId) return;
    loading.value = true;
    try {
      const [fileResult, itemsResult] = await Promise.all([
        store.fetchProductBasedCostingFileById(newId),
        store.fetchProductBasedCostingItems(newId),
      ]);
      costingFile.value = fileResult.success ? fileResult.data ?? null : null;
      rawItems.value = itemsResult.success ? itemsResult.data ?? [] : [];
    } finally {
      loading.value = false;
    }
  },
  { immediate: true },
);

const shellMaxWidth = computed(() => {
  if (mode.value === 'pdf') {
    const count = requestedColumnKeys.value.length;
    if (count <= 4) return '580px';
    if (count <= 6) return '720px';
    if (count <= 8) return '840px';
    return '920px';
  }
  return '414px';
});

const fileLabel = computed(() => `#${costingFile.value?.id ?? costingFileId.value ?? '-'}`);
const fileName = computed(() => costingFile.value?.name?.trim() || '-');
const createdFor = computed(() => costingFile.value?.order_for?.trim() || '-');

const rows = computed<ProductBasedCostingItem[]>(() => rawItems.value);

const computedPageSize = computed(() => {
  if (typeof props.pageSize === 'number' && props.pageSize > 0) {
    return Math.floor(props.pageSize);
  }
  return 6;
});

const currentPage = ref(1);

const totalPages = computed(() => {
  if (!rows.value.length) return 1;
  return Math.ceil(rows.value.length / computedPageSize.value);
});

watch(
  () => rows.value.length,
  () => {
    if (currentPage.value > totalPages.value) {
      currentPage.value = totalPages.value;
    }
  },
);

const pageStartIndex = computed(() => {
  if (!rows.value.length) return 0;
  return (currentPage.value - 1) * computedPageSize.value + 1;
});

const pageEndIndex = computed(() => {
  if (!rows.value.length) return 0;
  return Math.min(currentPage.value * computedPageSize.value, rows.value.length);
});

const tableRows = computed(() => {
  const cargoRate = costingFile.value?.cargo_rate_kg_gbp ?? 0;
  const conversionRate = costingFile.value?.conversion_rate ?? 140;
  const profitRate = costingFile.value?.profit_rate ?? 0;

  const mapItem = (item: ProductBasedCostingItem, slNum: number) => {
    const qty = toNumberSafe(item.quantity);
    const priceGbp = toNumberSafe(item.price_gbp);
    const totalPurchasePriceGbp = priceGbp * qty;
    const productWeight = toNumberSafe(item.product_weight);
    const packageWeight = toNumberSafe(item.package_weight);
    const totalWeightUnit = productWeight + packageWeight;

    const unitCargoCostGbp = (totalWeightUnit / 1000) * cargoRate;

    const unitTotalCostGbp = getUnitTotalCostGbp({
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate,
    });

    const costBdt = getUnitCostBdt({
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate,
      conversionRate,
    });

    const calculatedOfferPriceBdt = calculateOfferPriceBdt({
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate,
      conversionRate,
      profitRate,
    });

    const isManual =
      item.is_offer_price_manual === true ||
      (item.is_offer_price_manual == null &&
        item.offer_price != null &&
        normalizeOfferPriceBdt(item.offer_price) !== calculatedOfferPriceBdt);

    const offerPriceBdt =
      isManual && item.offer_price != null
        ? normalizeOfferPriceBdt(item.offer_price)
        : calculatedOfferPriceBdt;

    const totalBdt = offerPriceBdt * qty;
    const profitPerUnitBdt = offerPriceBdt - costBdt;

    return {
      ...item,
      sl: slNum,
      imageUrl: item.image_url || '',
      qty,
      quantity: qty,
      delivered_quantity: item.delivered_quantity ?? '-',
      barcodeText: item.barcode || item.product_code || '-',
      website: item.web_link || '',
      priceGbp,
      totalPurchasePriceGbp,
      productWeight,
      packageWeight,
      totalWeight: totalWeightUnit / 1000,
      cargoRate,
      cargoCostGbp: unitCargoCostGbp,
      totalCostGbp: unitTotalCostGbp,
      costBdt,
      offerPriceBdt,
      totalBdt,
      profitPerUnitBdt,
      profitRate,
    };
  };

  if (mode.value === 'pdf') {
    return rows.value.map((item, index) => mapItem(item, index + 1));
  }

  if (!rows.value.length) return [];
  const start = (currentPage.value - 1) * computedPageSize.value;
  const pageSlice = rows.value.slice(start, start + computedPageSize.value);

  return pageSlice.map((item, index) => mapItem(item, start + index + 1));
});

interface SummaryMetric {
  label: string;
  value: string;
  highlight?: boolean;
}

const summaryMetrics = computed<SummaryMetric[]>(() => {
  if (!rawItems.value.length) return [];

  const visible = new Set(requestedColumnKeys.value);
  const metrics: SummaryMetric[] = [];
  const cargoRate = costingFile.value?.cargo_rate_kg_gbp ?? 0;
  const conversionRate = costingFile.value?.conversion_rate ?? 140;
  const profitRate = costingFile.value?.profit_rate ?? 0;

  metrics.push({
    label: t('product_based_costing.preview_total_items'),
    value: t('product_based_costing.preview_items_count', { count: rawItems.value.length }),
  });

  if (visible.has('qty') || visible.has('deliveredQty')) {
    const totalQty = rawItems.value.reduce((acc, item) => acc + (item.quantity ?? 0), 0);
    metrics.push({
      label: t('product_based_costing.total_quantity'),
      value: `${formatNumber(totalQty)} ${t('product_based_costing.pcs')}`,
    });
  }

  if (visible.has('priceGbp') || visible.has('totalPurchasePriceGbp')) {
    const totalGbp = rawItems.value.reduce(
      (acc, item) => acc + (item.price_gbp ?? 0) * (item.quantity ?? 0),
      0,
    );
    metrics.push({
      label: t('product_based_costing.preview_total_purchase_gbp'),
      value: `£${formatNumber(Math.round(totalGbp * 100) / 100)}`,
    });
  }

  if (
    visible.has('productWeight') ||
    visible.has('packageWeight') ||
    visible.has('totalWeight')
  ) {
    const totalKg = rawItems.value.reduce(
      (acc, item) =>
        acc +
        (((item.product_weight ?? 0) + (item.package_weight ?? 0)) / 1000) *
          (item.quantity ?? 0),
      0,
    );
    metrics.push({
      label: t('product_based_costing.preview_total_weight'),
      value: `${(Math.round(totalKg * 100) / 100).toLocaleString('en-US')} kg`,
    });
  }

  if (
    visible.has('costBdt') ||
    visible.has('totalCostGbp') ||
    visible.has('cargoCostGbp')
  ) {
    const totalCostBdt = rawItems.value.reduce((acc, item) => {
      const priceGbp = item.price_gbp ?? 0;
      const productWeight = item.product_weight ?? 0;
      const packageWeight = item.package_weight ?? 0;
      const costBdt = getUnitCostBdt({
        priceGbp,
        productWeight,
        packageWeight,
        cargoRate,
        conversionRate,
      });
      return acc + costBdt * (item.quantity ?? 0);
    }, 0);

    metrics.push({
      label: t('product_based_costing.preview_landed_cost_bdt'),
      value: `৳${formatNumber(Math.round(totalCostBdt))}`,
    });
  }

  if (visible.has('offerPriceBdt') || visible.has('totalBdt')) {
    const totalOfferBdt = rawItems.value.reduce((acc, item) => {
      const priceGbp = item.price_gbp ?? 0;
      const productWeight = item.product_weight ?? 0;
      const packageWeight = item.package_weight ?? 0;
      const calculatedOfferPriceBdt = calculateOfferPriceBdt({
        priceGbp,
        productWeight,
        packageWeight,
        cargoRate,
        conversionRate,
        profitRate,
      });
      const isManual =
        item.is_offer_price_manual === true ||
        (item.is_offer_price_manual == null &&
          item.offer_price != null &&
          normalizeOfferPriceBdt(item.offer_price) !== calculatedOfferPriceBdt);
      const offerPriceBdt =
        isManual && item.offer_price != null
          ? normalizeOfferPriceBdt(item.offer_price)
          : calculatedOfferPriceBdt;
      return acc + offerPriceBdt * (item.quantity ?? 0);
    }, 0);

    metrics.push({
      label: t('product_based_costing.preview_total_offer_bdt'),
      value: `৳${formatNumber(Math.round(totalOfferBdt))}`,
      highlight: true,
    });
  }

  if (visible.has('profitPerUnitBdt') || visible.has('profitRate')) {
    const totalProfitBdt = rawItems.value.reduce((acc, item) => {
      const priceGbp = item.price_gbp ?? 0;
      const productWeight = item.product_weight ?? 0;
      const packageWeight = item.package_weight ?? 0;
      const costBdt = getUnitCostBdt({
        priceGbp,
        productWeight,
        packageWeight,
        cargoRate,
        conversionRate,
      });
      const calculatedOfferPriceBdt = calculateOfferPriceBdt({
        priceGbp,
        productWeight,
        packageWeight,
        cargoRate,
        conversionRate,
        profitRate,
      });
      const isManual =
        item.is_offer_price_manual === true ||
        (item.is_offer_price_manual == null &&
          item.offer_price != null &&
          normalizeOfferPriceBdt(item.offer_price) !== calculatedOfferPriceBdt);
      const offerPriceBdt =
        isManual && item.offer_price != null
          ? normalizeOfferPriceBdt(item.offer_price)
          : calculatedOfferPriceBdt;
      const profitPerUnit = offerPriceBdt - costBdt;
      return acc + profitPerUnit * (item.quantity ?? 0);
    }, 0);

    metrics.push({
      label: t('product_based_costing.preview_est_profit_bdt'),
      value: `৳${formatNumber(Math.round(totalProfitBdt))}`,
      highlight: true,
    });
  }

  return metrics;
});

function goBack() {
  window.close();
  setTimeout(() => {
    if (!window.closed) {
      if (window.history.length > 1) {
        void router.back();
      }
    }
  }, 100);
}

async function printPage() {
  isPrinting.value = true;
  await nextTick();
  window.print();
  setTimeout(() => {
    isPrinting.value = false;
  }, 500);
}

function goPrevPage() {
  if (currentPage.value > 1) {
    currentPage.value -= 1;
  }
}

function goNextPage() {
  if (currentPage.value < totalPages.value) {
    currentPage.value += 1;
  }
}

function resolvePreviewImageUrl(rawUrl?: string | null): string {
  if (!rawUrl) return '';
  const trimmed = rawUrl.trim();
  if (!trimmed) return '';
  return trimmed;
}

function formatNumber(val?: number | null): string {
  if (val === null || val === undefined || Number.isNaN(val)) return '-';
  return val.toLocaleString('en-US');
}
</script>

<style scoped lang="scss">
.preview-page__shell {
  max-width: 600px;
  margin: 0 auto;
  transition: max-width 0.3s ease;
}

.preview-canvas {
  background-color: #f4f6f8;
  min-height: 100vh;
}

.preview-page__actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.preview-page__action-btn {
  font-size: 11px;
}

.preview-page__meta-card {
  border-radius: 8px;
  background: #ffffff;
}

.preview-page__meta-section {
  padding: 10px 12px;
}

.preview-page__meta-line {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: 700;
  color: #1f2937;
}

.preview-page__meta-value {
  font-size: 14px;
}

.preview-page__meta-value--compact {
  font-size: 12px;
  font-weight: 600;
  color: #4b5563;
}

.preview-page__meta-label {
  font-size: 11px;
  text-transform: uppercase;
  color: #6b7280;
  letter-spacing: 0.5px;
}

.preview-page__table-card {
  border-radius: 8px;
  overflow: hidden;
  background: #ffffff;
}

.preview-page__table {
  :deep(.q-table__card) {
    box-shadow: none;
  }

  :deep(thead tr) {
    height: 36px;
  }

  :deep(th) {
    font-size: 11px;
    font-weight: 700;
    color: #374151;
    background: #f9fafb;
    padding: 6px 10px;
    white-space: nowrap;
    text-align: center;
    vertical-align: middle;
  }

  :deep(td) {
    font-size: 12px;
    padding: 8px 10px;
    white-space: nowrap;
    text-align: center;
    vertical-align: middle;
  }

  :deep(.preview-page__name-cell) {
    white-space: normal !important;
    word-break: break-word !important;
    text-align: center;
    min-width: 120px;
    max-width: 200px;
    width: 180px;
  }

  :deep(.a4-cutoff-cell) {
    border-right: 2px dashed #f59e0b !important;
  }

  :deep(.a4-overflow-header) {
    background-color: #fef3c7 !important;
    color: #92400e !important;
  }

  :deep(.a4-overflow-body) {
    background-color: #fffbe6 !important;
  }
}

.preview-page__sl-cell {
  width: 44px;
  font-weight: 600;
}

.preview-page__header-cell--image {
  width: calc(1in + 16px);
}

.preview-page__header-cell--name {
  min-width: 120px;
  max-width: 200px;
  width: 180px;
}

.preview-page__header-cell--offer {
  min-width: 110px;
  background-color: #ede9fe !important;
  color: #5b21b6 !important;
}

.preview-page__image {
  width: 1in;
  height: 1in;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  background-color: #ffffff;
  border-radius: 6px;
  border: 1px solid #e5e7eb;
  overflow: hidden;
  margin: 0 auto;

  :deep(img) {
    max-width: 100% !important;
    max-height: 100% !important;
    width: auto !important;
    height: auto !important;
    object-fit: contain !important;
    margin: auto !important;
  }
}

.preview-page__name-text {
  font-size: 13px;
  font-weight: 700;
  color: #111827;
  line-height: 1.35;
  white-space: normal !important;
  word-break: break-word !important;
  text-align: center;
  max-width: 200px;
  margin: 0 auto;
}

.preview-page__offer-cell {
  background-color: #f3e8ff !important;
  color: #6b21a8 !important;
  font-weight: 700;
}

.preview-page--screenshot {
  .preview-page__summary-card {
    display: none !important;
  }

  .preview-page__name-text {
    font-weight: 400;
  }

  .preview-page__table {
    :deep(th) {
      padding: 6px 8px;
      font-size: 10.5px;
    }

    :deep(td) {
      padding: 6px 8px;
      font-size: 11.5px;
    }

    :deep(.preview-page__name-cell) {
      min-width: 100px;
    }
  }

  .preview-page__header-cell--name {
    min-width: 100px;
  }
}

.preview-page__pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

.preview-page__pager-center {
  text-align: center;
}

.preview-page__pager-label {
  font-size: 12px;
  font-weight: 700;
  color: #374151;
}

.preview-page__pager-sub {
  font-size: 10px;
  color: #6b7280;
}

.preview-page__summary-card {
  border-radius: 8px;
  background: #ffffff;
  break-inside: avoid;
  page-break-inside: avoid;
}

.preview-page__summary-item {
  background: #f9fafb;
  border: 1px solid #f3f4f6;
  border-radius: 6px;
  padding: 8px 10px;
}

.preview-page__summary-label {
  font-size: 11px;
  color: #6b7280;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.preview-page__summary-value {
  font-size: 14px;
  font-weight: 700;
  color: #111827;
  margin-top: 2px;
}

@media print {
  @page {
    size: A4 portrait;
    margin: 8mm;
  }

  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  html,
  body,
  #q-app,
  .q-page-container,
  .q-page,
  .preview-canvas {
    min-height: 0 !important;
    height: auto !important;
    padding: 0 !important;
    margin: 0 !important;
    background: transparent !important;
    overflow: visible !important;
  }

  .q-header,
  .q-footer,
  .q-drawer,
  .q-drawer-container,
  .no-print,
  .preview-page__actions,
  .preview-page__pager {
    display: none !important;
  }

  .preview-page__shell {
    width: 100% !important;
    margin: 0 auto !important;
    padding: 0 !important;
    box-shadow: none !important;
  }

  .preview-page__meta-card {
    margin-top: 0 !important;
    margin-bottom: 6px !important;
    break-inside: avoid !important;
    page-break-inside: avoid !important;
  }

  .preview-page__table-card {
    margin-top: 0 !important;
    margin-bottom: 6px !important;
    border: 1px solid #e5e7eb !important;
    box-shadow: none !important;
    break-inside: auto !important;
    page-break-inside: auto !important;
  }

  .preview-page__table {
    :deep(tr) {
      break-inside: avoid !important;
      page-break-inside: avoid !important;
    }
  }

  .preview-page__summary-card {
    margin-top: 6px !important;
    margin-bottom: 0 !important;
    border: 1px solid #e5e7eb !important;
    box-shadow: none !important;
    break-inside: avoid !important;
    page-break-inside: avoid !important;
  }

  .a4-cutoff-cell {
    border-right: none !important;
  }

  .a4-overflow-header {
    background-color: #f9fafb !important;
    color: #374151 !important;
  }

  .a4-overflow-body {
    background-color: transparent !important;
  }
}
</style>

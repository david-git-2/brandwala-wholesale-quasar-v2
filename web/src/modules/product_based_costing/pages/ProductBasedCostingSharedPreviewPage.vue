<template>
  <q-layout view="hHh LpR lFf" class="preview-page-layout theme-app">
    <q-drawer
      v-model="customizerDrawerOpen"
      show-if-above
      bordered
      side="left"
      :width="300"
      :breakpoint="960"
      class="preview-page__customizer-drawer no-print"
    >
      <div v-if="loading" class="column full-height preview-page__skeleton-drawer q-px-md q-py-sm">
        <q-skeleton type="text" width="75%" height="18px" class="q-mb-xs" />
        <q-skeleton type="text" width="55%" height="14px" class="q-mb-md" />
        <q-skeleton type="rect" height="34px" class="rounded-borders q-mb-sm" />
        <q-skeleton type="rect" height="34px" class="rounded-borders q-mb-md" />
        <q-skeleton type="text" width="45%" height="14px" class="q-mb-sm" />
        <q-skeleton type="rect" height="40px" class="rounded-borders q-mb-md" />
        <q-skeleton type="text" width="50%" height="14px" class="q-mb-sm" />
        <div class="column col q-gutter-y-xs preview-page__skeleton-drawer-list">
          <q-skeleton
            v-for="n in 9"
            :key="n"
            type="rect"
            height="34px"
            class="rounded-borders"
          />
        </div>
        <q-skeleton type="QBtn" height="40px" class="full-width q-mt-sm" />
      </div>
      <div v-else class="column full-height preview-page__customizer-inner">
        <div class="preview-page__customizer-top q-px-md q-pt-sm q-pb-xs">
          <div class="row items-center no-wrap q-gutter-x-xs q-mb-xs">
            <q-btn
              size="sm"
              dense
              flat
              round
              color="primary"
              icon="ph ph-arrow-left"
              :aria-label="$t('product_based_costing.go_back')"
              @click="goBack"
            />
            <div class="col min-width-0">
              <div class="text-caption text-weight-bold text-grey-9 ellipsis">
                {{ $t('product_based_costing.preview_customizer_title') }}
                · {{ fileLabel }}
              </div>
              <div class="text-caption text-grey-7 ellipsis" style="font-size: 11px; line-height: 1.2">
                {{ fileName }}
              </div>
            </div>
            <q-btn
              flat
              round
              dense
              size="sm"
              icon="ph ph-x"
              class="lt-md"
              @click="customizerDrawerOpen = false"
            />
          </div>
          <q-btn-toggle
            v-model="mode"
            spread
            no-caps
            unelevated
            dense
            toggle-color="primary"
            color="grey-3"
            text-color="grey-9"
            :options="previewModeOptions"
            class="preview-page__mode-toggle full-width"
          />
          <template v-if="mode === 'screenshot'">
            <div class="row items-center justify-between q-mt-xs preview-page__ss-controls">
              <q-btn
                size="xs"
                dense
                round
                flat
                color="primary"
                icon="ph ph-caret-left"
                :disable="currentPage <= 1 || !rows.length"
                @click="goPrevPage"
              />
              <div class="text-center col">
                <div class="text-caption text-weight-bold" style="font-size: 11px; line-height: 1.2">
                  {{ $t('product_based_costing.preview_page_of', { current: currentPage, total: totalPages }) }}
                  ·
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
                size="xs"
                dense
                round
                flat
                color="primary"
                icon="ph ph-caret-right"
                :disable="currentPage >= totalPages || !rows.length"
                @click="goNextPage"
              />
            </div>
            <q-option-group
              v-model="screenshotExportScope"
              dense
              inline
              :options="screenshotExportScopeOptions"
              type="radio"
              class="text-caption preview-page__export-scope q-mt-xs"
            />
          </template>
          <div class="q-mt-xs">
            <div class="text-caption text-grey-8 q-mb-xs">
              {{ $t('product_based_costing.preview_image_size_inches') }}
            </div>
            <q-btn-toggle
              v-model="previewImageSizeInches"
              spread
              no-caps
              unelevated
              dense
              toggle-color="primary"
              color="grey-3"
              text-color="grey-9"
              :options="previewImageSizeOptions"
              class="preview-page__image-size-toggle full-width"
            />
          </div>
        </div>

        <q-separator />

        <div class="q-px-md q-py-xs column col min-height-0">
            <div class="text-caption text-weight-bold text-grey-9 q-mb-xs">
              {{ $t('product_based_costing.show_columns') }}
              ({{ selectedColumnKeys.length }})
            </div>
            <q-input
              v-model="columnSearchQuery"
              outlined
              dense
              hide-bottom-space
              :placeholder="$t('product_based_costing.search_columns')"
              clearable
              class="preview-page__column-search q-mb-sm"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" />
              </template>
            </q-input>
            <div v-if="mode === 'pdf'" class="q-mb-sm">
              <div
                v-if="hasA4ColumnOverflow"
                class="text-caption bg-negative-1 text-negative-10 q-pa-sm rounded-borders"
              >
                <div class="text-weight-bold q-mb-xs">
                  {{ $t('product_based_costing.preview_a4_notice_title') }}
                </div>
                {{
                  $t('product_based_costing.preview_a4_notice_body', {
                    count: a4EffectiveColumnCount,
                    max: a4MaxFittingColumnCount,
                  })
                }}
              </div>
              <div v-else class="text-caption text-grey-8 q-pa-xs rounded-borders preview-page__a4-hint">
                {{
                  $t('product_based_costing.preview_a4_hint', {
                    count: a4EffectiveColumnCount,
                    max: a4MaxFittingColumnCount,
                  })
                }}
              </div>
            </div>
            <q-scroll-area class="preview-page__column-scroll col">
              <div
                v-if="!unifiedColumnPickerRows.length"
                class="text-body2 text-grey-6 q-pa-sm"
              >
                {{ $t('product_based_costing.no_matching_columns') }}
              </div>
              <div v-else class="column q-gutter-y-xs q-pr-sm">
                <div
                  v-for="row in unifiedColumnPickerRows"
                  :key="row.value"
                  class="preview-page__column-picker-row"
                  :class="{ 'preview-page__column-picker-row--selected': row.selected }"
                >
                  <span
                    class="preview-page__column-seq text-caption text-weight-medium"
                    :class="row.selected ? 'text-primary' : 'text-grey-5'"
                  >
                    {{ row.sequence ?? '' }}
                  </span>
                  <q-checkbox
                    :model-value="row.selected"
                    dense
                    size="sm"
                    class="preview-page__column-check"
                    :disable="
                      (row.value === 'priceGbpWithVat' && !isVatThenGbpOfferMode)
                      || (!row.selected && mode === 'pdf' && !canAddPdfColumn(row.value))
                    "
                    @update:model-value="(checked) => onPreviewColumnCheck(row.value, checked)"
                  />
                  <span class="preview-page__column-picker-label text-caption ellipsis">{{ row.label }}</span>
                  <div class="preview-page__column-picker-actions">
                    <template v-if="row.selected">
                      <q-btn
                        dense
                        flat
                        round
                        size="xs"
                        color="grey-7"
                        icon="ph ph-caret-up"
                        :aria-label="$t('product_based_costing.preview_move_column_up')"
                        :disable="row.selectedOrderIndex <= 0"
                        @click="moveSelectedColumn(row.value, -1)"
                      />
                      <q-btn
                        dense
                        flat
                        round
                        size="xs"
                        color="grey-7"
                        icon="ph ph-caret-down"
                        :aria-label="$t('product_based_costing.preview_move_column_down')"
                        :disable="row.selectedOrderIndex < 0 || row.selectedOrderIndex >= orderedSelectedColumnItems.length - 1"
                        @click="moveSelectedColumn(row.value, 1)"
                      />
                    </template>
                  </div>
                </div>
              </div>
            </q-scroll-area>
        </div>

        <q-separator />

        <div class="q-px-md q-py-sm">
            <q-btn
              color="primary"
              unelevated
              no-caps
              :icon="primaryActionIcon"
              :label="primaryActionLabel"
              :loading="exporting"
              :disable="!rows.length || exporting"
              class="full-width preview-page__print-btn"
              @click="printPage"
            />
        </div>
      </div>
    </q-drawer>

    <q-page-container>
      <q-page class="q-pa-md preview-canvas theme-app">
        <div
          v-if="loading"
          class="preview-page__skeleton-preview"
          :class="{ 'preview-page--screenshot': mode === 'screenshot' }"
          :style="shellStyle"
        >
          <q-card flat bordered class="preview-page__table-card preview-page__skeleton-card">
            <div class="preview-page__skeleton-head row no-wrap q-pa-sm q-gutter-x-sm">
              <q-skeleton
                v-for="col in 5"
                :key="col"
                type="text"
                class="col"
                height="16px"
              />
            </div>
            <q-separator />
            <div
              v-for="row in skeletonPreviewRowCount"
              :key="row"
              class="preview-page__skeleton-row row items-center no-wrap q-px-sm q-py-sm q-gutter-x-sm"
            >
              <q-skeleton type="text" width="16px" height="14px" />
              <q-skeleton type="rect" width="52px" height="52px" class="rounded-borders" />
              <div class="col column q-gutter-y-xs">
                <q-skeleton type="text" width="92%" height="12px" />
                <q-skeleton type="text" width="68%" height="12px" />
              </div>
              <q-skeleton type="text" width="44px" height="14px" />
            </div>
          </q-card>
        </div>
        <div v-else class="preview-page__preview">
        <section
          class="preview-page__shell"
          :class="{
            'preview-page--screenshot': mode === 'screenshot',
            'preview-page--pdf': mode === 'pdf',
          }"
          :style="shellStyle"
        >
      <div
        ref="screenshotCaptureRef"
        class="preview-page__capture"
        :class="{ 'preview-page__capture--exporting': exporting }"
      >
      <q-card flat bordered class="preview-page__table-card" :style="previewTableCardStyle">
        <div
          v-if="showA4CutoffGuide"
          class="a4-cutoff-guide no-print"
          aria-hidden="true"
        />
        <q-table
          flat
          bordered
          :rows="tableRows"
          :columns="columns"
          row-key="id"
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
                  isGbpPriceColumn(col.name) ? 'preview-page__header-cell--gbp' : '',
                  isPdfCompactColumn(col.name) ? 'preview-page__compact-cell' : '',
                  showCutoffMarking && a4CutoffColumnIndex >= 0 && Number(colIdx) === a4CutoffColumnIndex
                    ? 'a4-cutoff-cell'
                    : '',
                  showCutoffMarking && a4FirstOverflowColumnIndex >= 0 && Number(colIdx) >= a4FirstOverflowColumnIndex
                    ? 'a4-overflow-header'
                    : '',
                ]"
              >
                <span class="preview-page__header-label">{{ col.label }}</span>
                <q-badge
                  v-if="showCutoffMarking && a4CutoffColumnIndex >= 0 && Number(colIdx) === a4CutoffColumnIndex"
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
                  isPdfCompactColumn(col.name) ? 'preview-page__compact-cell' : '',
                  col.name === 'offerPriceBdt' ? 'preview-page__offer-cell' : '',
                  isGbpPriceColumn(col.name) ? 'preview-page__gbp-cell' : '',
                  showCutoffMarking && a4CutoffColumnIndex >= 0 && Number(colIdx) === a4CutoffColumnIndex
                    ? 'a4-cutoff-cell'
                    : '',
                  showCutoffMarking && a4FirstOverflowColumnIndex >= 0 && Number(colIdx) >= a4FirstOverflowColumnIndex
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
                    :enable-lightbox="false"
                    img-loading="eager"
                    :use-cors="mode === 'screenshot' || mode === 'pdf'"
                    single-source
                    :hide-loading-ui="exporting"
                    fit="contain"
                  />
                </template>

                <!-- Name -->
                <template v-else-if="col.name === 'name'">
                  <div class="preview-page__name-text">
                    {{ slotProps.row.name }}
                  </div>
                </template>

                <!-- Qty & Confirmed Qty -->
                <template v-else-if="col.name === 'qty' || col.name === 'confirmedQty'">
                  <span class="text-weight-bold">{{ slotProps.row[col.name] ?? slotProps.row.quantity ?? '-' }}</span>
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

                <!-- Cargo Rate -->
                <template v-else-if="col.name === 'cargoRate'">
                  {{ buyMark }}{{ formatNumber(slotProps.row.cargoRate) }}
                </template>

                <!-- Status -->
                <template v-else-if="col.name === 'status'">
                  <span class="text-caption text-capitalize">{{ slotProps.row.status }}</span>
                </template>

                <!-- Numeric GBP fields -->
                <template
                  v-else-if="
                    [
                      'priceGbp',
                      'priceGbpWithVat',
                      'totalPurchasePriceGbp',
                      'cargoCostGbp',
                      'totalCostGbp',
                      'rowTotalCostGbp',
                    ].includes(col.name)
                  "
                >
                  {{ buyMark }}{{ formatNumber(slotProps.row[col.name]) }}
                </template>

                <!-- Numeric BDT fields -->
                <template
                  v-else-if="
                    [
                      'costBdt',
                      'totalCostBdt',
                      'offerPriceBdt',
                      'totalBdt',
                      'profitPerUnitBdt',
                      'profitBdt',
                    ].includes(col.name)
                  "
                >
                  <span
                    :class="{
                      'preview-page__offer-value':
                        col.name === 'offerPriceBdt' || col.name === 'totalBdt',
                    }"
                  >
                    {{ sellMark }}{{ formatNumber(slotProps.row[col.name]) }}
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
                  {{ slotProps.row.profitRate != null ? `${Number(slotProps.row.profitRate).toFixed(2)}%` : '-' }}
                </template>

                <!-- Default fallback -->
                <template v-else>
                  {{ slotProps.row[col.name] ?? '-' }}
                </template>
              </q-td>
            </q-tr>
          </template>

          <template #no-data>
            <div class="full-width row flex-center q-pa-lg text-grey-7">
              {{ $t('product_based_costing.preview_no_data') }}
            </div>
          </template>
        </q-table>
      </q-card>
      </div>

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

        </section>
        </div>
      </q-page>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { toBlob } from 'html-to-image';
import JSZip from 'jszip';
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import type { QTableColumn } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

import SmartImage from 'src/components/SmartImage.vue';
import { showErrorNotification } from 'src/utils/appFeedback';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import type { ProductBasedCostingFile, ProductBasedCostingItem } from '../types';
import {
  computeProfitRatePercentOnCost,
  getPriceGbpWithVat,
  getUnitCostBdt,
  getUnitTotalCostGbp,
  normalizeOfferPricingMode,
  resolveEffectiveOfferPriceBdt,
  toNumberSafe,
} from '../utils/pricing';
import {
  pbcCurrencyMark,
  pbcFileBuyCurrencyCode,
  pbcFileSellCurrencyCode,
} from '../utils/pbcFileCurrencies';
import {
  SCREENSHOT_FRAME_WIDTH_PX,
  SCREENSHOT_ROWS_PER_PAGE,
  SCREENSHOT_SL_COLUMN_WIDTH_PX,
  fileSafeForExport,
  computeFixedBudgetColumnWidthsPx,
  computeScreenshotColumnWidthsPx,
  sumPreviewColumnWidthsPx,
  DEFAULT_PBC_PREVIEW_SCREENSHOT_COLUMNS,
  PBC_SCREENSHOT_SELECTABLE_COLUMN_KEYS,
  fitScreenshotColumnKeys,
  normalizePreviewImageSizeInches,
  PREVIEW_IMAGE_SIZE_INCHES_OPTIONS,
  screenshotHeaderLabel,
  screenshotImageColumnWidthPx,
  prepareScreenshotCaptureDom,
  type PreviewImageSizeInches,
} from '../utils/pbcPreviewScreenshot';

const props = defineProps<{
  id: string;
  pageSize?: number;
}>();

/** Printable width for A4 portrait with 8mm @page margins (210mm − 16mm). */
const A4_PRINTABLE_WIDTH_MM = 194;

const PBC_PREVIEW_COLUMN_MIN_WIDTH_PX: Record<string, number> = {
  sl: SCREENSHOT_SL_COLUMN_WIDTH_PX,
  image: 52,
  priceGbp: 48,
  name: 96,
  priceGbpWithVat: 52,
  offerPriceBdt: 58,
  qty: 28,
  cargoRate: 44,
  cargoCostGbp: 48,
};

const DEFAULT_PREVIEW_COLUMN_MIN_WIDTH_PX = 48;

function mmToPx(mm: number): number {
  return (mm * 96) / 25.4;
}

function a4ColumnMinWidthPx(columnKey: string, imageSizeInches: number): number {
  if (columnKey === 'image') {
    return screenshotImageColumnWidthPx(imageSizeInches);
  }
  return PBC_PREVIEW_COLUMN_MIN_WIDTH_PX[columnKey] ?? DEFAULT_PREVIEW_COLUMN_MIN_WIDTH_PX;
}

function a4ColumnShrinkFloorPx(columnKey: string, imageSizeInches: number): number {
  if (columnKey === 'sl') {
    return SCREENSHOT_SL_COLUMN_WIDTH_PX;
  }
  if (columnKey === 'image') {
    return Math.max(56, Math.floor(screenshotImageColumnWidthPx(imageSizeInches) * 0.72));
  }
  const min = a4ColumnMinWidthPx(columnKey, imageSizeInches);
  return Math.max(18, Math.floor(min * 0.55));
}

const a4PrintableWidthPx = computed(() => Math.floor(mmToPx(A4_PRINTABLE_WIDTH_MM)));

function computeA4FirstOverflowColumnIndex(
  columnKeys: string[],
  imageSizeInches: number,
): number {
  const limitPx = mmToPx(A4_PRINTABLE_WIDTH_MM);
  let acc = 0;
  for (let i = 0; i < columnKeys.length; i++) {
    acc += a4ColumnMinWidthPx(columnKeys[i], imageSizeInches);
    if (acc > limitPx) {
      return i;
    }
  }
  return -1;
}

const customizerDrawerOpen = ref(true);
const isPrinting = ref(false);
const exporting = ref(false);
const exportWithoutImages = ref(false);
const screenshotCaptureRef = ref<HTMLElement | null>(null);
const screenshotExportScope = ref<'all' | 'current'>('all');
const lastPdfColumnKeys = ref<string[] | null>(null);

const screenshotExportScopeOptions = computed(() => [
  {
    label: t('product_based_costing.preview_screenshot_export_all'),
    value: 'all' as const,
  },
  {
    label: t('product_based_costing.preview_screenshot_export_current'),
    value: 'current' as const,
  },
]);
const showCutoffMarking = computed(() => !isPrinting.value && mode.value === 'pdf');

let savedDocumentTitleForPrint: string | null = null;

function applyPdfPrintDocumentTitle() {
  if (mode.value !== 'pdf') return;
  if (savedDocumentTitleForPrint === null) {
    savedDocumentTitleForPrint = document.title;
  }
  document.title = buildPdfDownloadTitle();
}

function restoreDocumentTitleAfterPrint() {
  if (savedDocumentTitleForPrint !== null) {
    document.title = savedDocumentTitleForPrint;
    savedDocumentTitleForPrint = null;
  }
}

const handleBeforePrint = () => {
  isPrinting.value = true;
  applyPdfPrintDocumentTitle();
};

const handleAfterPrint = () => {
  isPrinting.value = false;
  restoreDocumentTitleAfterPrint();
};

onMounted(() => {
  window.addEventListener('beforeprint', handleBeforePrint);
  window.addEventListener('afterprint', handleAfterPrint);
  if (!route.query.view) {
    syncViewModeToQuery();
  }
});

onUnmounted(() => {
  window.removeEventListener('beforeprint', handleBeforePrint);
  window.removeEventListener('afterprint', handleAfterPrint);
  restoreDocumentTitleAfterPrint();
});

const route = useRoute();
const router = useRouter();

function parsePreviewViewMode(query: unknown): 'screenshot' | 'pdf' {
  const value = typeof query === 'string' ? query.trim().toLowerCase() : '';
  if (value === 'pdf') return 'pdf';
  if (value === 'screenshot') return 'screenshot';
  return 'screenshot';
}

const mode = ref<'screenshot' | 'pdf'>(parsePreviewViewMode(route.query.view));

const previewImageSizeInches = ref<PreviewImageSizeInches>(
  normalizePreviewImageSizeInches(route.query.imgSize),
);

const previewImageSizeOptions = PREVIEW_IMAGE_SIZE_INCHES_OPTIONS.map((size) => ({
  label: `${size}"`,
  value: size,
}));
const store = useProductBasedCostingStore();
const { t } = useI18n();

const costingFileId = computed(() => Number(props.id));
const loading = ref(false);
const costingFile = ref<ProductBasedCostingFile | null>(null);
const rawItems = ref<ProductBasedCostingItem[]>([]);

const currencyI18n = computed(() => ({
  buy: pbcFileBuyCurrencyCode(costingFile.value),
  sell: pbcFileSellCurrencyCode(costingFile.value),
}));
const buyMark = computed(() => pbcCurrencyMark(currencyI18n.value.buy));
const sellMark = computed(() => pbcCurrencyMark(currencyI18n.value.sell));

interface PreviewColumnDef {
  key: string;
  label: string;
  align: 'left' | 'center' | 'right';
  field: string | ((row: any) => any);
}

const ALL_PREVIEW_COLUMN_DEFS = computed<Record<string, PreviewColumnDef>>(() => {
  const c = currencyI18n.value;
  return {
  sl: { key: 'sl', label: 'SL', align: 'center', field: 'sl' },
  image: { key: 'image', label: t('product_based_costing.table_image'), align: 'center', field: 'imageUrl' },
  name: { key: 'name', label: t('product_based_costing.col_name'), align: 'center', field: 'name' },
  brand: { key: 'brand', label: t('product_based_costing.table_col_brand'), align: 'center', field: 'brand' },
  note: { key: 'note', label: t('product_based_costing.note'), align: 'center', field: 'note' },
  qty: { key: 'qty', label: t('product_based_costing.table_col_qty'), align: 'center', field: 'quantity' },
  confirmedQty: {
    key: 'confirmedQty',
    label: t('product_based_costing.table_col_confirmedQty'),
    align: 'center',
    field: 'confirmedQty',
  },
  barcodeText: {
    key: 'barcodeText',
    label: t('product_based_costing.preview_barcode_code'),
    align: 'center',
    field: 'barcodeText',
  },
  website: { key: 'website', label: t('product_based_costing.table_col_website'), align: 'center', field: 'website' },
  priceGbp: { key: 'priceGbp', label: t('product_based_costing.preview_price_gbp', c), align: 'center', field: 'priceGbp' },
  priceGbpWithVat: {
    key: 'priceGbpWithVat',
    label: t('product_based_costing.preview_price_gbp_with_vat', c),
    align: 'center',
    field: 'priceGbpWithVat',
  },
  totalPurchasePriceGbp: {
    key: 'totalPurchasePriceGbp',
    label: t('product_based_costing.preview_total_purchase_gbp', c),
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
    label: t('product_based_costing.preview_cargo_cost_gbp', c),
    align: 'center',
    field: 'cargoCostGbp',
  },
  totalCostGbp: {
    key: 'totalCostGbp',
    label: t('product_based_costing.preview_total_cost_gbp', c),
    align: 'center',
    field: 'totalCostGbp',
  },
  rowTotalCostGbp: {
    key: 'rowTotalCostGbp',
    label: t('product_based_costing.table_col_rowTotalCostGbp', c),
    align: 'center',
    field: 'rowTotalCostGbp',
  },
  costBdt: { key: 'costBdt', label: t('product_based_costing.preview_cost_bdt', c), align: 'center', field: 'costBdt' },
  totalCostBdt: {
    key: 'totalCostBdt',
    label: t('product_based_costing.preview_total_cost_bdt', c),
    align: 'center',
    field: 'totalCostBdt',
  },
  offerPriceBdt: {
    key: 'offerPriceBdt',
    label: t('product_based_costing.preview_offer_price_bdt', c),
    align: 'center',
    field: 'offerPriceBdt',
  },
  totalBdt: { key: 'totalBdt', label: t('product_based_costing.preview_total_offer_bdt', c), align: 'center', field: 'totalBdt' },
  profitPerUnitBdt: {
    key: 'profitPerUnitBdt',
    label: t('product_based_costing.preview_profit_bdt', c),
    align: 'center',
    field: 'profitPerUnitBdt',
  },
  profitBdt: {
    key: 'profitBdt',
    label: t('product_based_costing.preview_total_profit_bdt', c),
    align: 'center',
    field: 'profitBdt',
  },
  profitRate: { key: 'profitRate', label: t('product_based_costing.table_col_profitRate'), align: 'center', field: 'profitRate' },
  status: { key: 'status', label: t('product_based_costing.col_status'), align: 'center', field: 'status' },
};
});

const defaultPreviewColumns = [...DEFAULT_PBC_PREVIEW_SCREENSHOT_COLUMNS];

const parseQueryCols = (query: unknown): string[] | null => {
  if (typeof query === 'string' && query.trim()) {
    const parsed = query
      .split(',')
      .map((c) => c.trim())
      .filter((c) => Boolean(ALL_PREVIEW_COLUMN_DEFS.value[c]));
    if (parsed.length) {
      return parsed;
    }
  }
  return null;
};

const selectedColumnKeys = ref<string[]>(
  parseQueryCols(route.query.cols) ?? defaultPreviewColumns,
);

watch(
  () => route.query.cols,
  (newCols) => {
    const parsed = parseQueryCols(newCols);
    if (parsed) {
      selectedColumnKeys.value = parsed;
    }
  },
);

const previewModeOptions = computed(() => [
  {
    label: t('product_based_costing.preview_screenshot'),
    value: 'screenshot' as const,
    icon: 'ph ph-camera',
  },
  {
    label: t('product_based_costing.preview_pdf_mode'),
    value: 'pdf' as const,
    icon: 'ph ph-file-pdf',
  },
]);

const onColumnToggle = (val: string[]) => {
  applySelectedColumnKeys(val);
};

function syncPreviewQuery(patch: Record<string, string>) {
  void router.replace({
    query: {
      ...route.query,
      ...patch,
    },
  });
}

function syncColumnKeysToQuery() {
  syncPreviewQuery({
    cols: selectedColumnKeys.value.join(','),
    view: mode.value,
  });
}

function syncViewModeToQuery() {
  syncPreviewQuery({ view: mode.value });
}

const previewColumnOptions = computed(() => {
  const defs = ALL_PREVIEW_COLUMN_DEFS.value;
  const keys =
    mode.value === 'screenshot'
      ? [...PBC_SCREENSHOT_SELECTABLE_COLUMN_KEYS]
      : Object.keys(defs);
  return keys
    .map((key) => defs[key])
    .filter((def): def is PreviewColumnDef => Boolean(def))
    .map((def) => ({
      label: def.label,
      value: def.key,
    }));
});

const columnSearchQuery = ref('');

const filteredPreviewColumnOptions = computed(() => {
  const q = columnSearchQuery.value.trim().toLowerCase();
  if (!q) return previewColumnOptions.value;
  return previewColumnOptions.value.filter((opt) => opt.label.toLowerCase().includes(q));
});

interface UnifiedColumnPickerRow {
  value: string;
  label: string;
  selected: boolean;
  sequence: number | null;
  selectedOrderIndex: number;
}

const orderedSelectedColumnItems = computed(() => {
  const defs = ALL_PREVIEW_COLUMN_DEFS.value;
  const allowedScreenshot = new Set<string>(PBC_SCREENSHOT_SELECTABLE_COLUMN_KEYS);
  return selectedColumnKeys.value
    .filter((key) => {
      if (mode.value === 'screenshot') {
        return allowedScreenshot.has(key);
      }
      return Boolean(defs[key]);
    })
    .map((key) => ({
      key,
      label: defs[key]?.label ?? key,
    }));
});

const unifiedColumnPickerRows = computed<UnifiedColumnPickerRow[]>(() => {
  const selectedSet = new Set(selectedColumnKeys.value);
  const selectedRows: UnifiedColumnPickerRow[] = orderedSelectedColumnItems.value.map(
    (item, idx) => ({
      value: item.key,
      label: item.label,
      selected: true,
      sequence: idx + 1,
      selectedOrderIndex: idx,
    }),
  );

  const unselectedRows: UnifiedColumnPickerRow[] = filteredPreviewColumnOptions.value
    .filter((opt) => !selectedSet.has(opt.value))
    .map((opt) => ({
      value: opt.value,
      label: opt.label,
      selected: false,
      sequence: null,
      selectedOrderIndex: -1,
    }));

  return [...selectedRows, ...unselectedRows];
});

function applySelectedColumnKeys(keys: string[]) {
  if (mode.value === 'screenshot') {
    selectedColumnKeys.value = fitScreenshotColumnKeys(
      keys,
      SCREENSHOT_FRAME_WIDTH_PX,
      isVatThenGbpOfferMode.value,
      previewImageSizeInches.value,
    );
  } else {
    selectedColumnKeys.value = keys;
  }
  syncColumnKeysToQuery();
}

function moveSelectedColumn(columnKey: string, direction: -1 | 1) {
  const keys = [...selectedColumnKeys.value];
  const idx = keys.indexOf(columnKey);
  if (idx < 0) return;
  const targetIdx = idx + direction;
  if (targetIdx < 0 || targetIdx >= keys.length) return;
  keys.splice(idx, 1);
  keys.splice(targetIdx, 0, columnKey);
  applySelectedColumnKeys(keys);
}

const requestedColumnKeys = computed<string[]>(() => selectedColumnKeys.value);

const isVatThenGbpOfferMode = computed(
  () => normalizeOfferPricingMode(costingFile.value?.offer_pricing_mode) === 'gbp_vat_then_profit',
);

watch(
  () => route.query.view,
  (view) => {
    const parsed = parsePreviewViewMode(view);
    if (parsed !== mode.value) {
      mode.value = parsed;
    }
  },
);

watch(mode, (nextMode, prevMode) => {
  syncViewModeToQuery();

  if (nextMode === 'screenshot' && prevMode === 'pdf') {
    lastPdfColumnKeys.value = [...selectedColumnKeys.value];
    selectedColumnKeys.value = fitScreenshotColumnKeys(
      selectedColumnKeys.value,
      SCREENSHOT_FRAME_WIDTH_PX,
      isVatThenGbpOfferMode.value,
      previewImageSizeInches.value,
    );
    syncColumnKeysToQuery();
  } else if (nextMode === 'pdf' && prevMode === 'screenshot') {
    if (lastPdfColumnKeys.value?.length) {
      selectedColumnKeys.value = [...lastPdfColumnKeys.value];
    }
    if (!selectedColumnKeys.value.includes('image')) {
      const keys = [...selectedColumnKeys.value];
      const slIdx = keys.indexOf('sl');
      if (slIdx >= 0) {
        keys.splice(slIdx + 1, 0, 'image');
      } else {
        keys.unshift('sl', 'image');
      }
      selectedColumnKeys.value = keys;
    }
    syncColumnKeysToQuery();
  }
});

function resolveEffectivePdfColumnKeys(keys: string[]): string[] {
  if (!isVatThenGbpOfferMode.value) {
    return keys.filter((key) => key !== 'priceGbpWithVat');
  }
  return keys;
}

function pdfPreviewColumnKeysFit(keys: string[], imageSizeInches: number): boolean {
  return (
    computeA4FirstOverflowColumnIndex(resolveEffectivePdfColumnKeys(keys), imageSizeInches) < 0
  );
}

function canAddPdfColumn(columnKey: string): boolean {
  if (mode.value !== 'pdf') return true;
  if (selectedColumnKeys.value.includes(columnKey)) return true;
  const nextKeys = [...selectedColumnKeys.value, columnKey];
  return pdfPreviewColumnKeysFit(nextKeys, previewImageSizeInches.value);
}

function onPreviewColumnCheck(columnKey: string, checked: boolean) {
  if (checked && mode.value === 'pdf' && !canAddPdfColumn(columnKey)) {
    showErrorNotification(t('product_based_costing.preview_a4_remove_column_first'));
    return;
  }
  const next = checked
    ? [...selectedColumnKeys.value, columnKey]
    : selectedColumnKeys.value.filter((k) => k !== columnKey);
  onColumnToggle(next);
}

const effectivePreviewColumnKeys = computed(() => {
  if (mode.value === 'screenshot') {
    return fitScreenshotColumnKeys(
      requestedColumnKeys.value,
      SCREENSHOT_FRAME_WIDTH_PX,
      isVatThenGbpOfferMode.value,
      previewImageSizeInches.value,
    );
  }
  return resolveEffectivePdfColumnKeys(requestedColumnKeys.value);
});

const a4EffectiveColumnCount = computed(() => effectivePreviewColumnKeys.value.length);

const a4MaxFittingColumnCount = computed(() => {
  if (mode.value !== 'pdf') return 0;
  const order = previewColumnOptions.value.map((opt) => opt.value);
  let fitted: string[] = [];
  for (const key of order) {
    const next = fitted.includes(key) ? fitted : [...fitted, key];
    const ordered = order.filter((k) => next.includes(k));
    if (pdfPreviewColumnKeysFit(ordered, previewImageSizeInches.value)) {
      fitted = ordered;
    }
  }
  return resolveEffectivePdfColumnKeys(fitted).length;
});

const a4FirstOverflowColumnIndex = computed(() => {
  if (mode.value !== 'pdf') return -1;
  return computeA4FirstOverflowColumnIndex(
    effectivePreviewColumnKeys.value,
    previewImageSizeInches.value,
  );
});

const a4CutoffColumnIndex = computed(() => {
  const overflowIdx = a4FirstOverflowColumnIndex.value;
  if (overflowIdx <= 0) return -1;
  return overflowIdx - 1;
});

const showA4CutoffGuide = computed(() => false);

const hasA4ColumnOverflow = computed(
  () => mode.value === 'pdf' && a4FirstOverflowColumnIndex.value >= 0,
);

const screenshotColumnWidthsPx = computed(() => {
  if (mode.value !== 'screenshot') return {} as Record<string, number>;
  return computeScreenshotColumnWidthsPx(
    effectivePreviewColumnKeys.value,
    SCREENSHOT_FRAME_WIDTH_PX,
    previewImageSizeInches.value,
  );
});

const pdfColumnWidthsPx = computed(() => {
  if (mode.value !== 'pdf') return {} as Record<string, number>;
  const imageSize = previewImageSizeInches.value;
  return computeFixedBudgetColumnWidthsPx(
    effectivePreviewColumnKeys.value,
    a4PrintableWidthPx.value,
    (key) => a4ColumnMinWidthPx(key, imageSize),
    (key) => a4ColumnShrinkFloorPx(key, imageSize),
    SCREENSHOT_SL_COLUMN_WIDTH_PX,
    false,
  );
});

const pdfTableWidthPx = computed(() => {
  if (mode.value !== 'pdf') return 0;
  return sumPreviewColumnWidthsPx(
    effectivePreviewColumnKeys.value,
    pdfColumnWidthsPx.value,
  );
});

const previewTableCardStyle = computed(() => {
  if (mode.value !== 'pdf' || pdfTableWidthPx.value <= 0) {
    return undefined;
  }
  return {
    width: `${pdfTableWidthPx.value}px`,
    maxWidth: '100%',
  };
});

const columns = computed<QTableColumn[]>(() => {
  const isScreenshot = mode.value === 'screenshot';
  const isPdf = mode.value === 'pdf';
  const widths = isScreenshot ? screenshotColumnWidthsPx.value : isPdf ? pdfColumnWidthsPx.value : {};

  return effectivePreviewColumnKeys.value
    .map((key) => ALL_PREVIEW_COLUMN_DEFS.value[key])
    .filter((def): def is PreviewColumnDef => Boolean(def))
    .map((def) => {
      const w = widths[def.key];
      const widthStyle =
        w != null
          ? `width: ${w}px; min-width: ${w}px; max-width: ${w}px;`
          : undefined;

      return {
        name: def.key,
        label:
          isScreenshot || isPdf ? screenshotHeaderLabel(def.key, def.label) : def.label,
        field: def.field,
        align: def.align,
        headerStyle: widthStyle,
        style: widthStyle,
      };
    });
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

watch(loading, (isLoading) => {
  if (isLoading || mode.value !== 'screenshot') return;
  const ordered = fitScreenshotColumnKeys(
    selectedColumnKeys.value,
    SCREENSHOT_FRAME_WIDTH_PX,
    isVatThenGbpOfferMode.value,
    previewImageSizeInches.value,
  );
  if (ordered.join(',') !== selectedColumnKeys.value.join(',')) {
    selectedColumnKeys.value = ordered;
    syncColumnKeysToQuery();
  }
});

watch(previewImageSizeInches, (size) => {
  syncPreviewQuery({
    imgSize: String(size),
    view: mode.value,
  });
});

const shellStyle = computed(() => {
  const imageSizeVar = {
    '--pbc-preview-image-size': `${previewImageSizeInches.value}in`,
    '--pbc-screenshot-sl-width': `${SCREENSHOT_SL_COLUMN_WIDTH_PX}px`,
  } as Record<string, string>;
  if (mode.value === 'pdf') {
    return { maxWidth: `${A4_PRINTABLE_WIDTH_MM}mm`, ...imageSizeVar };
  }
  return {
    width: `${SCREENSHOT_FRAME_WIDTH_PX}px`,
    maxWidth: `${SCREENSHOT_FRAME_WIDTH_PX}px`,
    ...imageSizeVar,
  };
});

const fileLabel = computed(() => `#${costingFile.value?.id ?? costingFileId.value ?? '-'}`);
const fileName = computed(() => costingFile.value?.name?.trim() || '-');

const rows = computed<ProductBasedCostingItem[]>(() => rawItems.value);

const computedPageSize = computed(() => {
  if (mode.value === 'screenshot') {
    return SCREENSHOT_ROWS_PER_PAGE;
  }
  if (typeof props.pageSize === 'number' && props.pageSize > 0) {
    return Math.floor(props.pageSize);
  }
  return SCREENSHOT_ROWS_PER_PAGE;
});

const skeletonPreviewRowCount = computed(() =>
  mode.value === 'screenshot' ? SCREENSHOT_ROWS_PER_PAGE : 8,
);

const currentPage = ref(1);

const totalPages = computed(() => {
  if (!rows.value.length) return 1;
  return Math.ceil(rows.value.length / computedPageSize.value);
});

const primaryActionIcon = computed(() =>
  mode.value === 'screenshot' ? 'ph ph-download-simple' : 'ph ph-printer',
);

const primaryActionLabel = computed(() => {
  if (mode.value === 'pdf') {
    return t('product_based_costing.preview_print');
  }
  if (screenshotExportScope.value === 'all' && totalPages.value > 1) {
    return t('product_based_costing.preview_download_screenshot_zip');
  }
  return t('product_based_costing.preview_download_screenshot');
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
  const vatRate = costingFile.value?.vat_rate ?? 0;
  const offerPricingMode = normalizeOfferPricingMode(costingFile.value?.offer_pricing_mode);

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

    const offerPriceBdt = resolveEffectiveOfferPriceBdt(item, {
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate,
      conversionRate,
      profitRate,
      vatRate,
      offerPricingMode,
    });

    const totalBdt = offerPriceBdt * qty;
    const profitPerUnitBdt = offerPriceBdt - costBdt;

    const confirmedQty = toNumberSafe(item.confirmed_qty ?? item.quantity);
    const rowTotalCostGbp = unitTotalCostGbp * qty;
    const totalCostBdt = costBdt * qty;
    const profitBdt = profitPerUnitBdt * qty;

    return {
      ...item,
      sl: slNum,
      imageUrl: item.image_url || '',
      qty,
      quantity: qty,
      confirmedQty,
      barcodeText: item.barcode || item.product_code || '-',
      website: item.web_link || '',
      priceGbp,
      priceGbpWithVat: getPriceGbpWithVat(priceGbp, vatRate),
      totalPurchasePriceGbp,
      productWeight,
      packageWeight,
      totalWeight: totalWeightUnit / 1000,
      cargoRate,
      cargoCostGbp: unitCargoCostGbp,
      totalCostGbp: unitTotalCostGbp,
      rowTotalCostGbp,
      costBdt,
      totalCostBdt,
      offerPriceBdt,
      totalBdt,
      profitPerUnitBdt,
      profitBdt,
      profitRate: computeProfitRatePercentOnCost(costBdt, profitPerUnitBdt),
      status: item.status || 'pending',
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
  const vatRate = costingFile.value?.vat_rate ?? 0;
  const offerPricingMode = normalizeOfferPricingMode(costingFile.value?.offer_pricing_mode);

  metrics.push({
    label: t('product_based_costing.preview_total_items'),
    value: t('product_based_costing.preview_items_count', { count: rawItems.value.length }),
  });

  if (visible.has('qty')) {
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
      const offerPriceBdt = resolveEffectiveOfferPriceBdt(item, {
        priceGbp,
        productWeight,
        packageWeight,
        cargoRate,
        conversionRate,
        profitRate,
        vatRate,
        offerPricingMode,
      });
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
      const offerPriceBdt = resolveEffectiveOfferPriceBdt(item, {
        priceGbp,
        productWeight,
        packageWeight,
        cargoRate,
        conversionRate,
        profitRate,
        vatRate,
        offerPricingMode,
      });
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

const PDF_COMPACT_COLUMN_NAMES = new Set([
  'sl',
  'qty',
  'confirmedQty',
  'priceGbp',
  'priceGbpWithVat',
  'totalPurchasePriceGbp',
  'productWeight',
  'packageWeight',
  'totalWeight',
  'cargoRate',
  'cargoCostGbp',
  'totalCostGbp',
  'rowTotalCostGbp',
  'costBdt',
  'totalCostBdt',
  'offerPriceBdt',
  'totalBdt',
  'profitPerUnitBdt',
  'profitBdt',
  'profitRate',
]);

function isPdfCompactColumn(name: string): boolean {
  return mode.value === 'pdf' && PDF_COMPACT_COLUMN_NAMES.has(name);
}

function isGbpPriceColumn(name: string): boolean {
  return name === 'priceGbp' || name === 'priceGbpWithVat';
}

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

function downloadBlob(blob: Blob, filename: string) {
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function buildExportBaseName() {
  const id = costingFile.value?.id ?? costingFileId.value ?? 'file';
  const name = costingFile.value?.name ?? 'costing';
  return `${fileSafeForExport(name)}-${fileSafeForExport(String(id))}`;
}

/** Default name when saving print output as PDF (browser uses document.title). */
function buildPdfDownloadTitle(): string {
  const name = costingFile.value?.name?.trim();
  if (name) {
    return fileSafeForExport(name);
  }
  return buildExportBaseName();
}

function toExternalUrl(value: string) {
  return /^https?:\/\//i.test(value) ? value : `https://${value}`;
}

function buildExportProxyUrl(value: string) {
  const baseUrl = (import.meta.env.VITE_SUPABASE_URL ?? '').replace(/\/+$/, '');
  const targetUrl = toExternalUrl(value);
  if (!baseUrl) return targetUrl;
  return `${baseUrl}/functions/v1/image-proxy?url=${encodeURIComponent(targetUrl)}`;
}

async function captureScreenshotBlob(): Promise<Blob> {
  if (!screenshotCaptureRef.value) {
    throw new Error('capture-missing');
  }
  await prepareScreenshotCaptureDom(screenshotCaptureRef.value);
  await nextTick();
  const blob = await toBlob(screenshotCaptureRef.value, {
    cacheBust: false,
    pixelRatio: 2,
    backgroundColor: '#ffffff',
    useCORS: true,
  });
  if (!blob) {
    throw new Error('capture-failed');
  }
  return blob;
}

async function downloadScreenshot() {
  if (!rows.value.length || exporting.value) return;

  exporting.value = true;
  const savedPage = currentPage.value;
  const base = buildExportBaseName();

  try {
    const captureOnce = async () => {
      try {
        exportWithoutImages.value = false;
        await nextTick();
        return await captureScreenshotBlob();
      } catch {
        exportWithoutImages.value = true;
        await nextTick();
        return await captureScreenshotBlob();
      } finally {
        exportWithoutImages.value = false;
      }
    };

    const pagesToExport =
      screenshotExportScope.value === 'current'
        ? [currentPage.value]
        : Array.from({ length: totalPages.value }, (_, i) => i + 1);

    if (pagesToExport.length === 1) {
      currentPage.value = pagesToExport[0];
      await nextTick();
      const blob = await captureOnce();
      const pageNum = String(pagesToExport[0]).padStart(2, '0');
      downloadBlob(blob, `${base}-page-${pageNum}.png`);
      return;
    }

    const zip = new JSZip();
    for (const page of pagesToExport) {
      currentPage.value = page;
      await nextTick();
      await nextTick();
      const blob = await captureOnce();
      const pageNum = String(page).padStart(2, '0');
      zip.file(`${base}-page-${pageNum}.png`, blob);
    }
    const zipBlob = await zip.generateAsync({
      type: 'blob',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 },
    });
    downloadBlob(zipBlob, `${base}-screenshots.zip`);
  } catch {
    showErrorNotification(t('product_based_costing.preview_screenshot_export_failed'));
  } finally {
    exportWithoutImages.value = false;
    currentPage.value = savedPage;
    exporting.value = false;
  }
}

async function printPage() {
  if (mode.value === 'screenshot') {
    await downloadScreenshot();
    return;
  }
  isPrinting.value = true;
  applyPdfPrintDocumentTitle();
  await nextTick();
  window.print();
  setTimeout(() => {
    isPrinting.value = false;
    restoreDocumentTitleAfterPrint();
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
  if (!rawUrl || exportWithoutImages.value) return '';
  const trimmed = rawUrl.trim();
  if (!trimmed) return '';
  if (mode.value === 'screenshot' || mode.value === 'pdf' || exporting.value) {
    return buildExportProxyUrl(trimmed);
  }
  return trimmed;
}

function formatNumber(val?: number | null): string {
  if (val === null || val === undefined || Number.isNaN(val)) return '-';
  return val.toLocaleString('en-US');
}
</script>

<style scoped lang="scss">
.preview-page-layout {
  min-height: 100vh;
  background-color: var(--tf-neutral-canvas);
  overflow-x: hidden;
}

.preview-page__customizer-drawer {
  background: var(--tf-neutral-surface);
}

.preview-page__customizer-inner {
  min-height: 100%;
}

.preview-page__customizer-top {
  flex-shrink: 0;
}

.preview-page__mode-toggle {
  :deep(.q-btn) {
    min-height: 32px;
    padding: 0 6px;
    font-size: 11px;
  }

  :deep(.q-btn .q-icon) {
    font-size: 14px;
  }
}

.preview-page__export-scope {
  :deep(.q-radio) {
    margin-right: 8px;
  }

  :deep(.q-radio__label) {
    font-size: 11px;
    line-height: 1.2;
  }
}

.preview-page__ss-controls {
  min-height: 28px;
}

.preview-page__column-picker-row {
  display: grid;
  grid-template-columns: 22px 28px minmax(0, 1fr) 44px;
  align-items: center;
  column-gap: 6px;
  min-height: 34px;
  padding: 2px 4px;
  border-radius: 6px;

  &--selected {
    background: color-mix(in srgb, var(--q-primary) 10%, transparent);
  }
}

.preview-page__column-seq {
  justify-self: center;
  line-height: 1.2;
  font-variant-numeric: tabular-nums;
}

.preview-page__column-picker-label {
  line-height: 1.25;
  padding: 2px 0;
}

.preview-page__column-picker-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0;
  min-height: 28px;
}

.preview-page__a4-hint {
  background: color-mix(in srgb, var(--q-primary) 6%, var(--tf-neutral-surface));
  border: 1px solid var(--tf-neutral-border);
}

.preview-page__column-scroll {
  flex: 1 1 auto;
  min-height: 120px;
  max-height: calc(100vh - 300px);
}

.preview-page__column-picker-row .preview-page__column-check {
  justify-self: center;
  margin: 0;
  padding: 0;

  :deep(.q-checkbox__inner) {
    font-size: 24px;
  }

  :deep(.q-checkbox__bg) {
    top: 12%;
    left: 12%;
    width: 76%;
    height: 76%;
  }
}

.preview-page__column-search {
  :deep(.q-field__control) {
    min-height: 40px;
  }

  :deep(input) {
    font-size: 14px;
  }
}

.preview-page__skeleton-drawer-list {
  min-height: 0;
  overflow: hidden;
}

.preview-page__skeleton-preview {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
}

.preview-page__skeleton-preview.preview-page--screenshot {
  max-width: none;
}

.preview-page__skeleton-card {
  overflow: hidden;
}

.preview-page__skeleton-head {
  background: color-mix(in srgb, var(--q-primary) 6%, var(--tf-neutral-surface));
}

.preview-page__skeleton-row {
  border-bottom: 1px solid var(--tf-neutral-border);

  &:last-child {
    border-bottom: none;
  }
}

.preview-page__preview {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  overflow-x: hidden;
}

.preview-page__capture {
  background: #ffffff;
}

.preview-page__capture--exporting {
  :deep(.smart-image-loading-overlay) {
    display: none !important;
  }

  :deep(.smart-image__img--loading) {
    filter: none !important;
    opacity: 1 !important;
  }
}

.preview-page__shell {
  margin: 0 auto;
  transition: max-width 0.3s ease;
}

.preview-canvas {
  background-color: var(--tf-neutral-canvas);
  min-height: 100vh;
  overflow-x: hidden;
}

.preview-page__action-btn {
  font-size: 11px;
}

.preview-page__table-card {
  position: relative;
  border-radius: 8px;
  overflow: hidden;
  background: var(--tf-neutral-surface);
}

.preview-page--pdf .preview-page__table-card {
  max-width: 100%;
  overflow: visible;
  margin-left: auto;
  margin-right: auto;
}

.a4-cutoff-guide {
  position: absolute;
  top: 0;
  bottom: 0;
  left: 100%;
  width: 0;
  border-left: 2px dashed #f59e0b;
  z-index: 3;
  pointer-events: none;
}

.preview-page__table {
  :deep(.q-table__card) {
    box-shadow: none;
  }

  :deep(thead tr) {
    height: auto;
  }

  :deep(th) {
    font-size: 11px;
    font-weight: 700;
    color: var(--tf-neutral-ink);
    background: color-mix(in srgb, var(--q-primary) 6%, var(--tf-neutral-surface));
    padding: 6px 10px;
    white-space: normal;
    word-break: normal;
    overflow-wrap: anywhere;
    line-height: 1.25;
    text-align: center;
    vertical-align: middle;
  }

  :deep(th.preview-page__header-cell--sl) {
    white-space: nowrap;
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

  :deep(.a4-overflow-header) {
    background-color: #fef3c7 !important;
    color: #92400e !important;
  }

  :deep(.a4-overflow-body) {
    background-color: #fffbe6 !important;
  }
}

.preview-page__header-label {
  display: inline-block;
  max-width: 100%;
}

.preview-page__sl-cell {
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

.preview-page__header-cell--gbp {
  background-color: color-mix(in srgb, var(--tf-ops-hue-price) 88%, #fff) !important;
  color: #166534 !important;
}

.preview-page__image {
  width: 1in;
  height: 1in;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  background-color: var(--tf-neutral-surface);
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

.preview-page__offer-value {
  color: #6b21a8;
}

.preview-page__gbp-cell {
  background-color: color-mix(in srgb, var(--tf-ops-hue-price) 72%, #fff) !important;
  color: #15803d !important;
  font-weight: 600;
}

.preview-page--pdf {
  overflow-x: hidden;
  max-width: 100%;

  .preview-page__capture {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 100%;
  }

  .preview-page__table-card {
    overflow: hidden;
  }

  .preview-page__table {
    :deep(.q-table__middle) {
      overflow-x: hidden !important;
    }

    :deep(.q-table__container) {
      overflow-x: hidden !important;
    }

    :deep(table) {
      width: 100%;
      max-width: 100%;
      table-layout: fixed;
    }

    :deep(thead tr) {
      height: auto;
    }

    :deep(th) {
      padding: 3px 4px;
      font-size: 9px;
      line-height: 1.2;
      white-space: normal;
      word-break: normal;
      overflow-wrap: anywhere;
      overflow: visible;
      text-overflow: clip;
      vertical-align: middle;
    }

    :deep(td) {
      padding: 3px 4px;
      font-size: 9px;
      line-height: 1.2;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    :deep(.preview-page__name-cell) {
      min-width: 0;
      max-width: none;
      width: auto;
      white-space: normal !important;
      text-align: center;
      vertical-align: middle;
      word-break: normal;
      overflow-wrap: anywhere;
    }

    :deep(td.preview-page__compact-cell) {
      white-space: nowrap;
    }

    :deep(th.preview-page__compact-cell) {
      white-space: normal;
      overflow-wrap: anywhere;
    }
  }

  .preview-page__sl-cell {
    width: 28px;
    max-width: 28px;
  }

  .preview-page__header-cell--image {
    width: calc(var(--pbc-preview-image-size, 1in) + 8px);
    min-width: calc(var(--pbc-preview-image-size, 1in) + 8px);
  }

  .preview-page__header-cell--name {
    min-width: 0;
    max-width: none;
    width: auto;
  }

  .preview-page__header-cell--offer {
    min-width: 72px;
  }

  .preview-page__image {
    width: var(--pbc-preview-image-size, 1in);
    height: var(--pbc-preview-image-size, 1in);
    max-width: var(--pbc-preview-image-size, 1in);
    max-height: var(--pbc-preview-image-size, 1in);
    border-radius: 4px;
  }

  .preview-page__name-text {
    font-size: 9px;
    font-weight: 600;
    line-height: 1.2;
    max-width: none;
    text-align: center;
  }
}

.preview-page--screenshot {
  overflow-x: hidden;
  max-width: 100%;

  .preview-page__summary-card {
    display: none !important;
  }

  .preview-page__table-card {
    overflow: hidden;
  }

  .preview-page__table {
    :deep(.q-table__middle) {
      overflow-x: hidden !important;
    }

    :deep(.q-table__container) {
      overflow-x: hidden !important;
    }

    :deep(table) {
      width: 100%;
      max-width: 100%;
      table-layout: fixed;
    }

    :deep(th) {
      padding: 5px 4px;
      font-size: 10px;
      line-height: 1.25;
      white-space: normal;
      word-break: normal;
      overflow-wrap: normal;
      hyphens: none;
      text-align: center;
      vertical-align: middle;
    }

    :deep(td) {
      padding: 4px 2px;
      font-size: 10px;
      line-height: 1.2;
      word-break: normal;
      overflow-wrap: anywhere;
    }

    :deep(.preview-page__name-cell) {
      min-width: 0;
      max-width: none;
      width: auto;
      white-space: normal !important;
      text-align: left;
      vertical-align: top;
    }
  }

  .preview-page__sl-cell {
    box-sizing: border-box;
    width: var(--pbc-screenshot-sl-width, 22px) !important;
    min-width: var(--pbc-screenshot-sl-width, 22px) !important;
    max-width: var(--pbc-screenshot-sl-width, 22px) !important;
    padding-left: 2px !important;
    padding-right: 2px !important;
    font-size: 10px;
    font-weight: 500;
    text-align: center !important;
    white-space: nowrap;
  }

  :deep(.preview-page__header-cell--sl) {
    box-sizing: border-box;
    width: var(--pbc-screenshot-sl-width, 22px) !important;
    min-width: var(--pbc-screenshot-sl-width, 22px) !important;
    max-width: var(--pbc-screenshot-sl-width, 22px) !important;
    padding-left: 2px !important;
    padding-right: 2px !important;
    font-size: 9px;
    line-height: 1.1;
  }

  .preview-page__header-cell--image {
    width: calc(var(--pbc-preview-image-size, 1in) + 8px) !important;
    max-width: calc(var(--pbc-preview-image-size, 1in) + 8px) !important;
    min-width: calc(var(--pbc-preview-image-size, 1in) + 8px) !important;
  }

  .preview-page__header-cell--name {
    min-width: 0 !important;
    max-width: none !important;
    width: auto !important;
  }

  .preview-page__header-cell--offer {
    min-width: 56px !important;
  }

  .preview-page__image {
    width: var(--pbc-preview-image-size, 1in) !important;
    height: var(--pbc-preview-image-size, 1in) !important;
    max-width: var(--pbc-preview-image-size, 1in) !important;
    max-height: var(--pbc-preview-image-size, 1in) !important;
    border-radius: 4px;
  }

  .preview-page__name-text {
    font-size: 11px;
    font-weight: 400;
    line-height: 1.25;
    max-width: none;
    text-align: left;
    word-break: normal;
    overflow-wrap: anywhere;
  }

  .preview-page__offer-cell {
    white-space: nowrap;
    font-size: 11px;
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
  background: var(--tf-neutral-surface);
  break-inside: avoid;
  page-break-inside: avoid;
}

.preview-page__summary-item {
  background: color-mix(in srgb, var(--q-primary) 5%, var(--tf-neutral-surface));
  border: 1px solid var(--tf-neutral-border);
  border-radius: 6px;
  padding: 8px 10px;
}

.preview-page__summary-label {
  font-size: 11px;
  color: var(--tf-neutral-muted);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.preview-page__summary-value {
  font-size: 14px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
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
  .preview-page__customizer-drawer,
  .preview-page-layout .q-drawer-container {
    display: none !important;
  }

  .preview-page__preview {
    max-width: 100% !important;
  }

  .preview-page__shell {
    width: 100% !important;
    margin: 0 auto !important;
    padding: 0 !important;
    box-shadow: none !important;
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

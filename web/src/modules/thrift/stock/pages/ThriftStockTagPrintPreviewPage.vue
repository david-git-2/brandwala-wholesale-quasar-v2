<template>
  <q-page class="q-pa-md preview-canvas">
    <div class="preview-page__shell a4-sheet">
      <div
        class="preview-page__actions q-mb-md no-print row justify-between items-center q-col-gutter-sm"
      >
        <div class="col-auto">
          <q-btn
            flat
            dense
            no-caps
            icon="arrow_back"
            label="Back to Picker"
            color="primary"
            @click="goBack"
          />
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            outline
            color="primary"
            icon="settings"
            label="Configure Tags"
            class="pill-btn"
            no-caps
            :disable="!shipment"
            @click="openConfigDialog"
          />
          <q-btn
            color="primary"
            icon="print"
            label="Print Marketing Tags"
            class="preview-page__print-btn pill-btn"
            :loading="loading"
            :disabled="stickers.length === 0"
            @click="printPage"
          />
        </div>
      </div>

      <div v-if="loading" class="text-center q-pa-xl no-print">
        <q-spinner size="50px" color="primary" />
        <div class="q-mt-md text-grey-7">Loading marketing tags...</div>
      </div>

      <template v-else>
        <div
          v-for="(pageStickers, pageIdx) in tagPages"
          v-show="pageStickers.length > 0"
          :key="pageIdx"
          class="tag-sheet"
          :class="{ 'tag-sheet--break': pageIdx < tagPages.length - 1 }"
        >
          <div class="tag-cut-guides" aria-hidden="true">
            <span class="tag-cut-line tag-cut-line--v tag-cut-line--v-1" />
            <span class="tag-cut-line tag-cut-line--v tag-cut-line--v-2" />
            <span
              v-for="row in horizontalCutRowsForPage(pageStickers.length)"
              :key="`cut-h-${pageIdx}-${row}`"
              class="tag-cut-line tag-cut-line--h"
              :style="{ top: `calc(${row} * (${TAG_HEIGHT} + ${TAG_GAP}) - calc(${TAG_GAP} / 2))` }"
            />
          </div>
          <div class="tag-grid">
            <div v-for="(sticker, idx) in pageStickers" :key="`${pageIdx}-${idx}`" class="tag-cell">
              <StockMarketingTag
                :stock="sticker.stock"
                :tag-config="sticker.tagConfig"
                :listed-sell-formatted="sticker.listedSellFormatted"
              />
            </div>
          </div>
        </div>

        <div v-if="stickers.length === 0" class="text-center q-pa-xl text-grey-6 no-print">
          No available stock items with barcodes found in this shipment.
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftSettingsStore } from '../../settings/stores/thriftSettingsStore';
import { useThriftCurrencyStore } from '../../currency/stores/thriftCurrencyStore';
import { thriftShipmentRepository } from '../../shipment/repositories/thriftShipmentRepository';
import { thriftStockRepository } from '../repositories/thriftStockRepository';
import { expandStocksForTagPrint } from '../utils/expandStocksForTagPrint';
import { formatThriftAmount } from '../../currency/utils/formatMoney';
import { buildThriftCostBreakdownByStockId } from '../../shared/utils/computeThriftUnitCosts';
import { resolveListedSellPrice } from '../../shared/utils/resolveListedSellPrice';
import { resolveMarketingTagConfig } from '../../shipment/utils/defaultMarketingTagConfig';
import StockMarketingTag from '../components/StockMarketingTag.vue';
import ShipmentMarketingTagConfigDialog from '../../shipment/components/ShipmentMarketingTagConfigDialog.vue';
import type { ThriftShipment } from '../../shipment/types';
import type { ThriftStock } from '../types';
import type { StockTagPrintSticker } from '../types/marketingTag';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();
const settingsStore = useThriftSettingsStore();
const currencyStore = useThriftCurrencyStore();

const loading = ref(false);
const shipment = ref<ThriftShipment | null>(null);
const stocks = ref<ThriftStock[]>([]);

const shipmentId = computed(() => Number(route.params.shipmentId));

const costCurrency = computed(() => {
  if (!shipment.value?.cost_currency_id) return undefined;
  return currencyStore.currencyById(shipment.value.cost_currency_id);
});

const tagConfig = computed(() => resolveMarketingTagConfig(shipment.value?.marketing_tag_config));

const breakdownByStockId = computed(() => {
  const sh = shipment.value;
  const settings = settingsStore.settings;
  if (!sh || !settings) return {};

  const shipmentMap = new Map([[sh.id, sh]]);
  const stocksInput = stocks.value.map((stock) => ({
    id: stock.id,
    shipment_id: stock.shipment_id,
    quantity: stock.quantity || 0,
    product_weight: stock.product_weight ?? null,
    extra_weight: stock.extra_weight ?? null,
    origin_unit_price: stock.origin_unit_price ?? null,
    extra_origin_unit_price: stock.extra_origin_unit_price ?? null,
    additional_charges_cost: stock.additional_charges_cost ?? null,
    pricing: stock.pricing
      ? {
          listed_unit_price: stock.pricing.listed_unit_price,
          is_listed_price_manual: stock.pricing.is_listed_price_manual,
          markup_rate_override: stock.pricing.markup_rate_override ?? null,
        }
      : null,
  }));

  return buildThriftCostBreakdownByStockId(stocksInput, shipmentMap, settings);
});

function formatPrice(amount: number): string {
  return formatThriftAmount(amount, costCurrency.value);
}

const TAG_COLS = 3;
const TAG_HEIGHT = '42mm';
const TAG_GAP = '3mm';
// A4 printable height ~267mm (297 − 15mm top/bottom @page margins)
const TAG_ROWS_PER_PAGE = 6;
const TAGS_PER_PAGE = TAG_COLS * TAG_ROWS_PER_PAGE;

const stickers = computed<StockTagPrintSticker[]>(() => {
  const expanded = expandStocksForTagPrint(stocks.value);
  const config = tagConfig.value;
  return expanded.map((stock) => {
    const breakdown = breakdownByStockId.value[stock.id];
    const amount = resolveListedSellPrice(stock.pricing, breakdown);
    return {
      stock,
      tagConfig: config,
      listedSellFormatted: formatPrice(amount),
    };
  });
});

const tagPages = computed(() => {
  const pages: StockTagPrintSticker[][] = [];
  const all = stickers.value;
  for (let i = 0; i < all.length; i += TAGS_PER_PAGE) {
    pages.push(all.slice(i, i + TAGS_PER_PAGE));
  }
  return pages;
});

function horizontalCutRowsForPage(stickerCount: number): number[] {
  const rows = Math.ceil(stickerCount / TAG_COLS);
  return Array.from({ length: Math.max(0, rows - 1) }, (_, i) => i + 1);
}

function goBack() {
  void router.push({ name: 'thrift-stock-tags-picker' });
}

function printPage() {
  window.print();
}

function openConfigDialog() {
  const sh = shipment.value;
  if (!sh) return;
  $q.dialog({
    component: ShipmentMarketingTagConfigDialog,
    componentProps: {
      shipmentId: sh.id,
      shipmentName: sh.name,
      initialConfig: sh.marketing_tag_config,
    },
  }).onOk((updated: ThriftShipment) => {
    shipment.value = updated;
  });
}

async function loadData() {
  const shId = shipmentId.value;
  if (!authStore.tenantId || !Number.isFinite(shId)) return;

  loading.value = true;
  try {
    const [shipmentData, stocksData] = await Promise.all([
      thriftShipmentRepository.fetchShipmentById(authStore.tenantId, shId),
      thriftStockRepository.fetchStocksByShipment(authStore.tenantId, shId),
      settingsStore.loadSettings(authStore.tenantId),
      currencyStore.loadCurrencies(),
    ]);
    shipment.value = shipmentData;
    stocks.value = stocksData;
  } catch (err) {
    console.error('Failed to load print preview data:', err);
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  void loadData();
});
</script>

<style scoped>
.preview-canvas {
  background: #eef1f6;
  min-height: 100vh;
  overflow: visible;
}

.a4-sheet {
  max-width: 210mm;
  margin: 0 auto;
  background: #fff;
  padding: 15mm;
  box-shadow: 0 8px 24px rgba(17, 24, 39, 0.12);
  border: 1px solid #d9dce3;
  border-radius: 8px;
  overflow: visible;
}

.preview-page__actions {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
  padding-bottom: 12px;
}

.pill-btn {
  border-radius: 999px;
}

.tag-sheet {
  position: relative;
  --tag-height: 42mm;
  --tag-gap: 3mm;
}

.tag-sheet--break {
  page-break-after: always;
  break-after: page;
}

.tag-cut-guides {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 1;
  overflow: visible;
}

.tag-cut-line--v {
  position: absolute;
  top: -15mm;
  bottom: -15mm;
  height: auto;
  width: 0;
  border-left: 1px dotted #999;
  transform: translateX(-50%);
}

.tag-cut-line--v-1 {
  left: calc((100% - (2 * var(--tag-gap))) / 3 + calc(var(--tag-gap) / 2));
}

.tag-cut-line--v-2 {
  left: calc((100% - (2 * var(--tag-gap))) / 3 * 2 + calc(var(--tag-gap) * 1.5));
}

.tag-cut-line--h {
  position: absolute;
  left: -15mm;
  width: calc(100% + 30mm);
  height: 0;
  border-top: 1px dotted #999;
  transform: translateY(-50%);
}

.tag-grid {
  position: relative;
  z-index: 0;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-auto-rows: var(--tag-height);
  gap: var(--tag-gap);
}

.tag-cell {
  display: flex;
  justify-content: center;
  align-items: stretch;
  height: var(--tag-height);
  min-height: 0;
  overflow: hidden;
  page-break-inside: avoid;
  break-inside: avoid;
}

@media print {
  @page {
    size: A4;
    margin: 15mm 10mm 15mm 10mm;
  }

  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  body {
    background: #fff !important;
  }

  .preview-canvas {
    background: transparent !important;
    padding: 0 !important;
    min-height: 0 !important;
    overflow: visible !important;
  }

  .a4-sheet {
    box-shadow: none !important;
    border: none !important;
    padding: 0 !important;
    width: auto !important;
    max-width: none !important;
    overflow: visible !important;
  }

  .no-print {
    display: none !important;
  }

  .tag-sheet {
    page-break-inside: avoid;
    break-inside: avoid;
  }

  .tag-grid {
    gap: var(--tag-gap);
  }

  .tag-cut-line--v {
    top: -15mm;
    bottom: -15mm;
    height: auto;
    border-left-color: #000;
  }

  .tag-cut-line--h {
    left: -10mm;
    width: calc(100% + 20mm);
    border-top-color: #000;
  }

  :deep(.marketing-tag-card) {
    height: 42mm !important;
    max-height: 42mm !important;
    border: 1.5px solid #000 !important;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
}
</style>

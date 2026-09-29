<template>
  <q-card flat bordered class="pbc-item-card">
    <div class="pbc-item-card__media">
      <q-checkbox
        v-if="selectable"
        class="pbc-item-card__check"
        :model-value="selected"
        dense
        size="xs"
        @update:model-value="(checked) => emit('toggle-select', checked)"
      />
      <div v-if="row.imageUrl" class="pbc-item-card__image">
        <SmartImage
          :src="row.imageUrl"
          :alt="row.name || 'Product'"
          :enable-edit="false"
          :enable-lightbox="true"
        />
      </div>
      <div v-else class="pbc-item-card__image-empty column items-center justify-center">
        <q-icon name="ph ph-image-square" size="22px" color="grey-5" />
      </div>
    </div>

    <div class="pbc-item-card__body">
      <div class="pbc-item-card__title-row">
        <span class="pbc-item-card__sl">{{ row.sl }}</span>
        <div class="min-width-0 col">
          <div v-if="row.brand" class="pbc-item-card__brand">{{ row.brand }}</div>
          <div class="pbc-item-card__name" :title="row.name">{{ row.name || '—' }}</div>
        </div>
        <q-badge
          dense
          outline
          class="pbc-item-card__status q-ma-none text-capitalize"
        >
          {{ statusLabel }}
        </q-badge>
      </div>

      <div class="pbc-item-card__chips">
        <span v-if="originLabel" class="pbc-item-card__chip">{{ originLabel }}</span>
        <span v-if="languageLabel" class="pbc-item-card__chip">{{ languageLabel }}</span>
        <span class="pbc-item-card__chip" :class="qtyClass">{{ availableQtyLabel }}</span>
      </div>

      <dl class="pbc-item-card__meta">
        <div class="pbc-item-card__row">
          <dt>{{ $t('product_based_costing.barcode') }}</dt>
          <dd>
            <span class="font-mono">{{ displayValue(row.barcode) }}</span>
            <q-btn
              v-if="row.barcode"
              flat
              round
              dense
              size="xs"
              icon="ph ph-copy"
              color="grey-6"
              class="pbc-item-card__copy"
              :aria-label="$t('product_based_costing.copy_barcode')"
              @click.stop="copyText(row.barcode, $t('product_based_costing.barcode'))"
            >
              <q-tooltip>{{ $t('product_based_costing.copy_barcode') }}</q-tooltip>
            </q-btn>
          </dd>
        </div>
        <div class="pbc-item-card__row">
          <dt>{{ $t('product_based_costing.product_code') }}</dt>
          <dd>
            <span class="font-mono">{{ displayValue(row.product_code) }}</span>
            <q-btn
              v-if="row.product_code"
              flat
              round
              dense
              size="xs"
              icon="ph ph-copy"
              color="grey-6"
              class="pbc-item-card__copy"
              :aria-label="$t('product_based_costing.copy_code')"
              @click.stop="copyText(row.product_code, $t('product_based_costing.code'))"
            >
              <q-tooltip>{{ $t('product_based_costing.copy_code') }}</q-tooltip>
            </q-btn>
          </dd>
        </div>
        <div class="pbc-item-card__row">
          <dt>{{ $t('product_based_costing.vendor') }}</dt>
          <dd>
            <span class="font-mono">{{ displayValue(row.raw.vendor_code) }}</span>
            <q-btn
              v-if="row.raw.vendor_code"
              flat
              round
              dense
              size="xs"
              icon="ph ph-copy"
              color="grey-6"
              class="pbc-item-card__copy"
              :aria-label="$t('product_based_costing.copy_code')"
              @click.stop="copyText(row.raw.vendor_code, $t('product_based_costing.vendor'))"
            >
              <q-tooltip>{{ $t('product_based_costing.copy_code') }}</q-tooltip>
            </q-btn>
          </dd>
        </div>
        <div v-if="batchItems.length" class="pbc-item-card__batches">
          <div class="pbc-item-card__batches-label">{{ $t('product_based_costing.card_batch') }}</div>
          <div class="pbc-item-card__batch-list">
            <span v-for="(batch, idx) in batchItems" :key="`${batch.code}-${idx}`" class="pbc-item-card__batch-chip">
              <span class="font-mono">{{ batch.code }}</span>
              <span v-if="batch.date" class="pbc-item-card__batch-date">{{ batch.date }}</span>
            </span>
          </div>
        </div>
        <div v-if="expireLabel" class="pbc-item-card__row">
          <dt>{{ $t('product_based_costing.card_expire') }}</dt>
          <dd>{{ expireLabel }}</dd>
        </div>
      </dl>

      <div class="pbc-item-card__stats">
        <div class="pbc-item-card__stat bw-ops-col-tint--qty">
          <span class="pbc-item-card__stat-label">{{ $t('product_based_costing.table_col_qty') }}</span>
          <span class="pbc-item-card__stat-value bw-tabular">{{ row.quantity }}</span>
          <span class="pbc-item-card__stat-sub bw-tabular">{{ row.confirmed_quantity }} conf</span>
        </div>
        <div class="pbc-item-card__stat bw-ops-col-tint--price">
          <span class="pbc-item-card__stat-label">{{ $t('product_based_costing.table_col_priceGbp', currencyI18n) }}</span>
          <span class="pbc-item-card__stat-value bw-tabular">{{ buyMark }}{{ formatMoney(row.price_gbp) }}</span>
        </div>
        <div class="pbc-item-card__stat bw-ops-col-tint--cost">
          <span class="pbc-item-card__stat-label">{{ $t('product_based_costing.table_col_costBdt', currencyI18n) }}</span>
          <span class="pbc-item-card__stat-value bw-tabular">{{ sellMark }}{{ formatMoney(row.costBdt) }}</span>
        </div>
        <div class="pbc-item-card__stat bw-ops-col-tint--price">
          <span class="pbc-item-card__stat-label">{{ $t('product_based_costing.table_col_offerPriceBdt', currencyI18n) }}</span>
          <span class="pbc-item-card__stat-value bw-tabular">{{ sellMark }}{{ formatMoney(row.offer_price) }}</span>
        </div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useQuasar, copyToClipboard } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import type { PbcItemProductCatalog, ProductBasedCostingItem } from '../types';
import { formatMoney, formatStatusLabel } from '../composables/useProductBasedCostingFileDetailsState';

export type PbcDetailsTableRow = {
  id: number;
  sl: number;
  name: string;
  product_code: string;
  barcode: string;
  brand: string;
  imageUrl: string;
  quantity: number;
  confirmed_quantity: number;
  price_gbp: number;
  costBdt: number;
  offer_price: number;
  status: string;
  raw: ProductBasedCostingItem;
};

const props = withDefaults(
  defineProps<{
    row: PbcDetailsTableRow;
    catalog?: PbcItemProductCatalog | null;
    buyMark: string;
    sellMark: string;
    currencyI18n?: Record<string, string>;
    selected?: boolean;
    selectable?: boolean;
  }>(),
  {
    catalog: null,
    currencyI18n: () => ({}),
    selected: false,
    selectable: true,
  },
);

const emit = defineEmits<{
  (event: 'toggle-select', checked: boolean): void;
}>();

const { t } = useI18n();
const $q = useQuasar();

const displayValue = (value: string | null | undefined) => {
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : '—';
};

const copyText = (text: string | null | undefined, label: string) => {
  const value = text?.trim();
  if (!value) return;
  void copyToClipboard(value)
    .then(() => {
      $q.notify({
        type: 'positive',
        message: t('product_based_costing.copied_to_clipboard', { label }),
        timeout: 1000,
      });
    })
    .catch(() => {
      $q.notify({
        type: 'negative',
        message: t('product_based_costing.failed_to_copy', { label }),
        timeout: 1000,
      });
    });
};

const formatCatalogDate = (value: string | null | undefined) => {
  const trimmed = value?.trim();
  if (!trimmed) return '';
  return trimmed.replace(/[ T]00:00:00(?:\.0+)?(?:Z|[+-]\d{2}:?\d{2})?/g, '').trim();
};

const formatShortDate = (raw: string) => {
  const match = raw.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (!match) return raw;
  const month = Number(match[1]);
  const day = Number(match[2]);
  const year = Number(match[3]);
  const date = new Date(year, month - 1, day);
  if (Number.isNaN(date.getTime())) return raw;
  return date.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
};

type BatchChip = { code: string; date: string };

const batchItems = computed<BatchChip[]>(() => {
  const raw = props.catalog?.batch_code_manufacture_date?.trim();
  if (!raw) return [];

  return raw
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => {
      const cleaned = formatCatalogDate(part);
      const withDate = cleaned.match(/^(.+?)\s*-\s*(\d{1,2}\/\d{1,2}\/\d{4})$/);
      if (withDate) {
        return { code: withDate[1].trim().replace(/-$/, '').trim(), date: formatShortDate(withDate[2]) };
      }
      return { code: cleaned, date: '' };
    });
});

const originLabel = computed(() => props.catalog?.country_of_origin?.trim() || '');
const languageLabel = computed(() => props.catalog?.languages?.trim() || '');
const expireLabel = computed(() => {
  const formatted = formatCatalogDate(props.catalog?.expire_date);
  const dateOnly = formatted.match(/^(\d{1,2}\/\d{1,2}\/\d{4})$/);
  return dateOnly ? formatShortDate(dateOnly[1]) : formatted;
});

const availableQtyLabel = computed(() => {
  const units = props.catalog?.available_units;
  if (units == null) return '—';
  return t('product_based_costing.available_units', { count: units });
});

const qtyClass = computed(() => {
  const units = props.catalog?.available_units;
  if (units == null) return '';
  if (units <= 0) return 'pbc-item-card__chip--out';
  if (units <= 5) return 'pbc-item-card__chip--low';
  return 'pbc-item-card__chip--ok';
});

const statusLabel = computed(() => formatStatusLabel(props.row.status));
</script>

<style scoped>
.pbc-item-card {
  display: grid;
  grid-template-columns: 108px minmax(0, 1fr);
  min-height: 0;
  border-radius: var(--bw-radius-md, 12px);
  background: var(--bw-neutral-surface, #fff);
  border-color: var(--bw-neutral-border, #e7e1d8);
  overflow: hidden;
}

.pbc-item-card__media {
  position: relative;
  background: var(--bw-neutral-canvas, #fbfaf7);
  border-right: 1px solid var(--bw-neutral-border, #e7e1d8);
  min-height: 132px;
}

.pbc-item-card__check {
  position: absolute;
  top: 4px;
  left: 4px;
  z-index: 2;
}

.pbc-item-card__sl {
  flex-shrink: 0;
  min-width: 26px;
  height: 22px;
  padding: 0 6px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 800;
  font-family: var(--bw-font-mono, ui-monospace, monospace);
  line-height: 1;
  color: var(--bw-neutral-ink, #171412);
  background: var(--bw-neutral-canvas, #fbfaf7);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: 6px;
}

.pbc-item-card__image,
.pbc-item-card__image-empty {
  position: absolute;
  inset: 10px;
}

.pbc-item-card__image :deep(.smart-image-wrapper) {
  display: block !important;
  width: 100%;
  height: 100%;
}

.pbc-item-card__image :deep(.smart-image__img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  object-position: center;
}

.pbc-item-card__body {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
  padding: 10px 12px 12px;
}

.pbc-item-card__title-row {
  display: flex;
  align-items: flex-start;
  gap: 8px;
}

.pbc-item-card__brand {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--bw-neutral-muted, #736a61);
}

.pbc-item-card__name {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.3;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.pbc-item-card__status {
  flex-shrink: 0;
  margin-top: 1px;
}

.pbc-item-card__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.pbc-item-card__chip {
  font-size: 10px;
  font-weight: 600;
  line-height: 1.2;
  padding: 2px 6px;
  border-radius: 4px;
  background: var(--bw-neutral-canvas, #fbfaf7);
  color: var(--bw-neutral-ink, #171412);
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pbc-item-card__chip--out {
  color: var(--bw-error, #b83a3a);
  background: color-mix(in srgb, var(--bw-error, #b83a3a) 12%, #fff);
}

.pbc-item-card__chip--low {
  color: var(--bw-warning, #b45309);
  background: color-mix(in srgb, var(--bw-warning, #b45309) 12%, #fff);
}

.pbc-item-card__chip--ok {
  color: var(--bw-success, #1a7f4b);
  background: color-mix(in srgb, var(--bw-success, #1a7f4b) 12%, #fff);
}

.pbc-item-card__meta {
  margin: 0;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2px 10px;
}

.pbc-item-card__batches {
  grid-column: 1 / -1;
  min-width: 0;
  margin-top: 4px;
}

.pbc-item-card__batches-label {
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: var(--bw-neutral-muted, #736a61);
  margin-bottom: 4px;
}

.pbc-item-card__batch-list {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.pbc-item-card__batch-chip {
  display: inline-flex;
  align-items: baseline;
  gap: 6px;
  max-width: 100%;
  padding: 3px 7px;
  border-radius: 6px;
  background: var(--bw-neutral-canvas, #fbfaf7);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  font-size: 11px;
  font-weight: 700;
  line-height: 1.3;
}

.pbc-item-card__batch-date {
  font-weight: 600;
  color: var(--bw-neutral-muted, #736a61);
}

.pbc-item-card__row {
  display: grid;
  min-width: 0;
}

.pbc-item-card__row dt {
  margin: 0;
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: var(--bw-neutral-muted, #736a61);
}

.pbc-item-card__row dd {
  margin: 0;
  font-size: 11px;
  font-weight: 600;
  color: var(--bw-neutral-ink, #171412);
  display: flex;
  align-items: center;
  gap: 2px;
  min-width: 0;
}

.pbc-item-card__row dd span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pbc-item-card__copy {
  flex-shrink: 0;
}

.pbc-item-card__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 6px;
  margin-top: auto;
  padding-top: 8px;
  border-top: 1px solid var(--bw-neutral-border, #e7e1d8);
}

.pbc-item-card__stat {
  display: flex;
  flex-direction: column;
  min-width: 0;
  gap: 1px;
  padding: 6px 7px;
  border-radius: 6px;
}

.pbc-item-card__stat.bw-ops-col-tint--qty {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

.pbc-item-card__stat.bw-ops-col-tint--price {
  background-color: #daf3e4 !important;
  box-shadow: inset 2px 0 0 #059669;
}

.pbc-item-card__stat.bw-ops-col-tint--cost {
  background-color: #ffe8d1 !important;
  box-shadow: inset 2px 0 0 #ea580c;
}

.pbc-item-card__stat-label {
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: var(--bw-neutral-muted, #736a61);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pbc-item-card__stat-value {
  font-size: 12px;
  font-weight: 700;
  line-height: 1.2;
}

.pbc-item-card__stat-sub {
  font-size: 10px;
  color: var(--bw-neutral-muted, #736a61);
}

@media (max-width: 599px) {
  .pbc-item-card {
    grid-template-columns: 84px minmax(0, 1fr);
  }

  .pbc-item-card__stats {
    grid-template-columns: 1fr 1fr;
  }
}
</style>

<template>
  <q-card flat bordered class="catalog-storefront-card">
    <div class="catalog-storefront-card__image">
      <div v-if="item.product_image_url && !imageBroken" class="catalog-storefront-card__image-frame">
        <img
          :src="item.product_image_url"
          :alt="item.product_name"
          class="catalog-storefront-card__image-el"
          loading="lazy"
          @error="imageBroken = true"
        />
      </div>
      <div v-else class="catalog-storefront-card__image-fallback column items-center justify-center">
        <q-icon name="ph ph-image-square" size="32px" color="grey-5" />
        <span class="text-caption text-grey-6 q-mt-xs">
          {{ $t('shop_admin.storefront_product_no_image') }}
        </span>
      </div>
    </div>

    <q-card-section class="catalog-storefront-card__body">
      <div v-if="item.product_brand" class="catalog-storefront-card__brand">
        {{ item.product_brand }}
      </div>

      <div class="catalog-storefront-card__name" :title="item.product_name">
        {{ item.product_name }}
      </div>

      <dl class="catalog-storefront-card__meta">
        <div class="catalog-storefront-card__row">
          <dt>{{ $t('shop_admin.storefront_product_barcode') }}</dt>
          <dd>{{ displayValue(item.product_barcode) }}</dd>
        </div>
        <div class="catalog-storefront-card__row">
          <dt>{{ $t('shop_admin.storefront_product_vendor') }}</dt>
          <dd>{{ displayValue(item.vendor_code) }}</dd>
        </div>
        <div class="catalog-storefront-card__row">
          <dt>{{ $t('shop_admin.storefront_product_country_of_origin') }}</dt>
          <dd>{{ displayValue(item.country_of_origin) }}</dd>
        </div>
        <div class="catalog-storefront-card__row">
          <dt>{{ $t('shop_admin.storefront_product_batch_code') }}</dt>
          <dd>{{ displayValue(item.batch_code_manufacture_date) }}</dd>
        </div>
        <div class="catalog-storefront-card__row">
          <dt>{{ $t('shop_admin.storefront_product_expire_date') }}</dt>
          <dd>{{ displayValue(item.expire_date) }}</dd>
        </div>
        <div class="catalog-storefront-card__row">
          <dt>{{ $t('shop_admin.storefront_product_language') }}</dt>
          <dd>{{ displayValue(item.languages) }}</dd>
        </div>
        <div class="catalog-storefront-card__row">
          <dt>{{ $t('shop_admin.storefront_product_available_qty') }}</dt>
          <dd :class="qtyClass">{{ availableQtyLabel }}</dd>
        </div>
      </dl>

      <div v-if="priceText" class="catalog-storefront-card__price bw-tabular">
        <span class="catalog-storefront-card__price-label">
          {{ $t('shop_admin.storefront_product_list_price') }}
        </span>
        <span class="catalog-storefront-card__price-value">{{ priceText }}</span>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import type { ShopCatalogStorefrontProduct } from '../types';
import { formatStorefrontCardPrice } from '../utils/catalogPriceUtils';

const props = defineProps<{
  item: ShopCatalogStorefrontProduct;
  formatMoney: (amount: unknown, symbol?: string | null) => string;
}>();

const { t } = useI18n();
const imageBroken = ref(false);

const displayValue = (value: string | null | undefined) => {
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : '—';
};

const availableQtyLabel = computed(() => {
  const units = props.item.available_units;
  if (units == null) return '—';
  return t('shop_admin.storefront_qty_available', { qty: units });
});

const qtyClass = computed(() => {
  const units = props.item.available_units;
  if (units == null) return '';
  if (units <= 0) return 'catalog-storefront-card__qty--out';
  if (units <= 5) return 'catalog-storefront-card__qty--low';
  return 'catalog-storefront-card__qty--ok';
});

const priceText = computed(() => {
  const catalogItem = {
    unit_price: null,
    unit_price_amount: props.item.unit_price_amount,
    unit_price_currency_id: props.item.unit_price_currency_id,
    unit_price_currency_code: props.item.unit_price_currency_code ?? null,
    unit_price_currency_symbol: props.item.unit_price_currency_symbol ?? null,
    sell_price: null,
  };
  return formatStorefrontCardPrice(catalogItem, props.formatMoney);
});
</script>

<style scoped>
.catalog-storefront-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  border-radius: 16px;
  background: color-mix(in srgb, #ffffff 90%, var(--bw-shop-mauve, #996888) 10%);
  border-color: var(--bw-theme-border, rgb(42 43 42 / 0.1));
  color: var(--bw-theme-ink, #2a2b2a);
  overflow: hidden;
  transition:
    transform 0.2s ease,
    box-shadow 0.2s ease;
}

.catalog-storefront-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--bw-theme-shadow, 0 8px 20px rgb(42 43 42 / 0.08));
}

.catalog-storefront-card__image {
  position: relative;
  height: 200px;
  flex: 0 0 200px;
  background: #ffffff;
  border-bottom: 1px solid var(--bw-theme-border, rgb(42 43 42 / 0.06));
  overflow: hidden;
}

.catalog-storefront-card__image-frame {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 12px;
}

.catalog-storefront-card__image-el {
  display: block;
  max-width: 100%;
  max-height: 100%;
  width: auto;
  height: auto;
  object-fit: contain;
  object-position: center;
}

.catalog-storefront-card__image-fallback {
  position: absolute;
  inset: 0;
}

.catalog-storefront-card__body {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px 16px 16px;
  flex: 1;
}

.catalog-storefront-card__brand {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, #64748b);
}

.catalog-storefront-card__name {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.35;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.catalog-storefront-card__meta {
  margin: 0;
  display: grid;
  gap: 6px;
}

.catalog-storefront-card__row {
  display: grid;
  grid-template-columns: minmax(0, 42%) minmax(0, 1fr);
  gap: 8px;
  align-items: baseline;
  font-size: 12px;
  line-height: 1.35;
}

.catalog-storefront-card__row dt {
  margin: 0;
  color: var(--bw-theme-muted, #64748b);
  font-weight: 500;
}

.catalog-storefront-card__row dd {
  margin: 0;
  color: var(--bw-theme-ink, #2a2b2a);
  font-weight: 600;
  word-break: break-word;
}

.catalog-storefront-card__qty--out {
  color: #dc2626;
}

.catalog-storefront-card__qty--low {
  color: #d97706;
}

.catalog-storefront-card__qty--ok {
  color: #15803d;
}

.catalog-storefront-card__price {
  margin-top: auto;
  padding-top: 10px;
  border-top: 1px solid var(--bw-theme-border, rgb(42 43 42 / 0.08));
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.catalog-storefront-card__price-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--bw-theme-muted, #64748b);
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.catalog-storefront-card__price-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--bw-theme-primary, #996888);
}
</style>

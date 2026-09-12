<template>
  <q-card
    flat
    bordered
    class="product-card"
    :class="{
      'product-card--listing-inactive': showListingStatusToggle && !isListingActive,
      'product-card--dropship': shopType === 'dropship',
    }"
  >
    <div class="product-image-wrapper cursor-pointer" @click="$emit('open-detail', item)">
      <q-chip
        v-if="showGradeChip && gradeChipLabel"
        dense
        size="sm"
        class="product-overlay-chip product-grade-chip text-weight-bold"
        text-color="white"
        :style="gradeChipStyle"
      >
        {{ gradeChipLabel }}
      </q-chip>
      <img
        v-if="item.product_image_url && !isImageBroken"
        :src="item.product_image_url"
        :alt="item.product_name || 'Product'"
        class="product-image"
        loading="lazy"
        @error="$emit('image-error')"
      />
      <div v-else class="product-image-fallback">
        <q-icon name="ph ph-image-square" size="28px" color="grey-5" />
      </div>
    </div>

    <div class="product-main">
    <q-card-section class="product-body">
      <div class="product-meta">
        {{ item.product_brand || 'Generic' }}
      </div>
      <div
        class="storefront-product-card__name cursor-pointer"
        :title="item.product_name || undefined"
        @click="$emit('open-detail', item)"
      >
        {{ item.product_name }}
      </div>

      <div
        v-if="resolvedPriceText || resolvedMinPriceText"
        class="product-pricing"
      >
        <div
          v-if="resolvedPriceText"
          class="storefront-product-card__price bw-tabular"
        >
          <span
            v-if="showPriceLabel && resolvedPriceLabel"
            class="storefront-product-card__price-label"
          >
            {{ resolvedPriceLabel }}
          </span>
          {{ resolvedPriceText }}
        </div>

        <div
          v-if="resolvedMinPriceText"
          class="storefront-product-card__min-price"
        >
          {{ $t('shop.min_sell_price') }}
          <span>{{ resolvedMinPriceText }}</span>
        </div>
      </div>

      <div
        v-if="
          showQuantityBreakdown &&
          permissions?.can_view_quantity
        "
        class="storefront-qty-breakdown column q-gutter-y-xs"
      >
        <div class="product-stock row items-center no-wrap q-gutter-x-xs">
          <span>{{ $t('shop_admin.col_actual_qty') }}:</span>
          <span class="text-weight-medium" :class="actualQtyClass">{{ actualAvailableQty }}</span>
        </div>
        <div class="product-stock row items-center no-wrap q-gutter-x-xs">
          <span>{{ $t('shop_admin.col_display_qty') }}:</span>
          <span class="text-weight-medium" :class="displayQtyClass">{{ displayQtyValue }}</span>
          <span v-if="!hasDisplayOverride">({{ $t('shop_admin.storefront_qty_auto') }})</span>
        </div>
      </div>

      <div
        v-else-if="
          shopType === 'dropship' &&
          item.available_units !== null &&
          item.available_units !== undefined
        "
        class="product-stock"
        :class="stockToneClass"
      >
        {{ item.available_units }} {{ $t('shop.avail') }}
      </div>

      <div
        v-else-if="
          permissions?.can_view_quantity &&
          item.available_units !== null &&
          item.available_units !== undefined
        "
        class="product-stock"
        :class="stockToneClass"
      >
        {{ customerStockLabel }}
      </div>

      <div v-if="showCalculateSellPrice" class="q-mt-sm">
        <q-btn
          outline
          dense
          no-caps
          color="primary"
          icon="ph ph-calculator"
          :label="$t('shop_admin.storefront_calculate_sell_price')"
          class="full-width square-btn"
          @click="$emit('calculate-sell-price', item)"
        />
      </div>

      <div
        v-if="showAdminCardActions"
        class="q-mt-sm row items-center no-wrap admin-card-actions"
        :class="showListingStatusToggle ? 'justify-between' : 'justify-end'"
      >
        <div v-if="showListingStatusToggle" class="row items-center no-wrap q-gutter-x-sm col min-width-0">
          <span class="product-stock">{{ listingStatusLabel }}</span>
          <q-toggle
            :model-value="isListingActive"
            color="positive"
            dense
            @update:model-value="onListingActiveChange"
          >
            <q-tooltip>
              {{
                isListingActive
                  ? $t('shop_admin.listing_on_shop')
                  : $t('shop_admin.listing_off_shop')
              }}
            </q-tooltip>
          </q-toggle>
        </div>

        <div class="row items-center no-wrap q-gutter-x-xs col-auto">
          <q-btn
            v-if="showCopyGradeVariant && availableGradeVariants.length > 0"
            flat
            round
            dense
            color="secondary"
            icon="ph ph-copy"
            :aria-label="$t('shop_admin.storefront_copy_grade_variant')"
          >
            <q-tooltip>{{ $t('shop_admin.storefront_copy_grade_variant') }}</q-tooltip>
            <q-menu anchor="bottom middle" self="top middle">
              <q-list dense style="min-width: 200px">
                <q-item-label header class="text-weight-bold">
                  {{ $t('shop_admin.storefront_pick_grade') }}
                </q-item-label>
                <q-item
                  v-for="grade in availableGradeVariants"
                  :key="grade.slug"
                  v-close-popup
                  clickable
                  @click="$emit('copy-grade-variant', item, grade)"
                >
                  <q-item-section avatar>
                    <q-avatar size="24px" :style="{ backgroundColor: grade.color ?? '#6b7280' }" />
                  </q-item-section>
                  <q-item-section>{{ grade.label }}</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>

          <q-btn
            v-if="showRemoveProduct"
            flat
            round
            dense
            color="negative"
            icon="ph ph-trash"
            :aria-label="$t('shop_admin.storefront_remove_product')"
            @click="$emit('remove-product', item)"
          >
            <q-tooltip>{{ $t('shop_admin.storefront_remove_product') }}</q-tooltip>
          </q-btn>
        </div>
      </div>
    </q-card-section>

    <q-card-actions v-if="shouldShowCartActions" class="product-actions q-pa-sm q-pt-none">
      <div class="product-actions__inner row items-center no-wrap justify-between q-gutter-x-xs full-width">
        <div
          v-if="!inCart"
          class="row items-center no-wrap quantity-controls col-auto"
        >
          <q-btn
            flat
            round
            dense
            size="xs"
            icon="ph ph-minus"
            @click="$emit('decrement', item)"
          />
          <div class="quantity-value text-weight-bold text-center">
            {{ selectedQty || minQty }}
          </div>
          <q-btn
            flat
            round
            dense
            size="xs"
            icon="ph ph-plus"
            @click="$emit('increment', item)"
          />
        </div>
        <div v-else class="col-auto"></div>

        <q-btn
          v-if="!inCart"
          color="primary"
          unelevated
          no-caps
          dense
          icon="ph ph-shopping-cart"
          :label="addCartLabel"
          class="col square-btn"
          :loading="loading"
          :disabled="
            !permissions?.can_add_to_cart ||
            (item.available_units !== null && item.available_units <= 0)
          "
          @click="$emit('add-to-cart', item)"
        />
        <q-btn
          v-else
          color="negative"
          unelevated
          no-caps
          dense
          icon="ph ph-shopping-cart"
          :label="removeCartLabel"
          class="col square-btn"
          :loading="loading"
          :disabled="!permissions?.can_add_to_cart"
          @click="$emit('remove-from-cart', item)"
        />
      </div>
    </q-card-actions>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import type { CustomerShopPermissions } from '../composables/useCustomerShopPermissionsQuery';
import type {
  ShopCatalogItem,
  ShopCatalogStockGrade,
  ShopType,
} from '../types';
import {
  customerCanSeeCatalogPrice,
  formatStorefrontCardMinPrice,
  formatStorefrontCardPrice,
  storefrontCardPriceLabelKey,
} from '../utils/catalogPriceUtils';
import { resolveShopCartItemMoq } from '../utils/cartQuantityUtils';

const props = defineProps<{
  item: ShopCatalogItem;
  permissions?: CustomerShopPermissions | null;
  shopType?: ShopType | null;
  selectedQty?: number | undefined;
  inCart?: boolean | undefined;
  loading?: boolean | undefined;
  isImageBroken?: boolean | undefined;
  showActions?: boolean | undefined;
  showUnitPrice?: boolean | undefined;
  showQuantityBreakdown?: boolean | undefined;
  showCalculateSellPrice?: boolean | undefined;
  showAvgCost?: boolean | undefined;
  showGradeChip?: boolean | undefined;
  showCopyGradeVariant?: boolean | undefined;
  showListingStatusToggle?: boolean | undefined;
  showRemoveProduct?: boolean | undefined;
  availableGradeVariants?: ShopCatalogStockGrade[] | undefined;
  formatMoney: (amount: unknown, symbol?: string | null) => string;
  priceText?: string | null;
  priceLabel?: string | null;
  minPriceText?: string | null;
}>();

const showActions = computed(() => props.showActions !== false);
const shouldShowCartActions = showActions;
const showUnitPrice = computed(() => props.showUnitPrice !== false);
const showQuantityBreakdown = computed(() => props.showQuantityBreakdown === true);
const showCalculateSellPrice = computed(() => props.showCalculateSellPrice === true);
const showAvgCost = computed(() => props.showAvgCost === true);
const showGradeChip = computed(() => props.showGradeChip === true);
const showCopyGradeVariant = computed(() => props.showCopyGradeVariant === true);
const showListingStatusToggle = computed(() => props.showListingStatusToggle === true);
const showRemoveProduct = computed(() => props.showRemoveProduct === true);
const availableGradeVariants = computed(() => props.availableGradeVariants ?? []);
const showAdminCardActions = computed(
  () =>
    showListingStatusToggle.value ||
    showRemoveProduct.value ||
    (showCopyGradeVariant.value && availableGradeVariants.value.length > 0),
);

const showPriceLabel = computed(
  () =>
    showQuantityBreakdown.value ||
    showCalculateSellPrice.value ||
    showAdminCardActions.value,
);

const emit = defineEmits<{
  (e: 'open-detail', item: ShopCatalogItem): void;
  (e: 'image-error'): void;
  (e: 'increment', item: ShopCatalogItem): void;
  (e: 'decrement', item: ShopCatalogItem): void;
  (e: 'add-to-cart', item: ShopCatalogItem): void;
  (e: 'remove-from-cart', item: ShopCatalogItem): void;
  (e: 'calculate-sell-price', item: ShopCatalogItem): void;
  (e: 'copy-grade-variant', item: ShopCatalogItem, grade: ShopCatalogStockGrade): void;
  (e: 'toggle-listing-status', item: ShopCatalogItem, isActive: boolean): void;
  (e: 'remove-product', item: ShopCatalogItem): void;
}>();

const { t } = useI18n();

const addCartLabel = computed(() => t('shop.add'));
const removeCartLabel = computed(() => t('shop.remove'));

const isListingActive = computed(
  () => props.item.listing_status !== 'inactive',
);

const listingStatusLabel = computed(() =>
  isListingActive.value ? t('shop_admin.active') : t('shop_admin.inactive'),
);

const onListingActiveChange = (value: boolean) => {
  emit('toggle-listing-status', props.item, value);
};

const minQty = computed(() => resolveShopCartItemMoq(props.item, props.shopType));

const actualAvailableQty = computed(() => {
  const raw = props.item.real_available_units ?? props.item.available_units;
  return raw ?? 0;
});

const hasDisplayOverride = computed(
  () =>
    props.item.display_quantity_override !== null &&
    props.item.display_quantity_override !== undefined,
);

const displayQtyValue = computed(() => {
  if (hasDisplayOverride.value) return props.item.display_quantity_override as number;
  return actualAvailableQty.value;
});

const actualQtyClass = computed(() =>
  actualAvailableQty.value > 0 ? 'product-stock--ok' : 'product-stock--out',
);

const displayQtyClass = computed(() => {
  if (!hasDisplayOverride.value) return '';
  return displayQtyValue.value > 0 ? 'product-stock--ok' : 'product-stock--out';
});

const stockToneClass = computed(() => {
  const units = props.item.available_units;
  if (units == null) return '';
  if (units <= 0) return 'product-stock--out';
  if (units <= 5) return 'product-stock--low';
  return 'product-stock--ok';
});

const customerStockLabel = computed(() => {
  const units = props.item.available_units;
  if (units == null) return '';
  if (units <= 0) return t('shop.out_of_stock');
  if (units <= 5) return t('shop.low_stock');
  return t('shop.in_stock');
});

const canSeeCatalogPrice = computed(() =>
  customerCanSeeCatalogPrice(props.shopType, props.permissions),
);

const resolvedPriceText = computed(() => {
  if (!canSeeCatalogPrice.value) return null;
  return props.priceText || formatStorefrontCardPrice(props.item, props.formatMoney);
});
const resolvedPriceLabel = computed(() => {
  if (props.priceLabel) return props.priceLabel;
  const key = storefrontCardPriceLabelKey(props.item);
  return key ? t(key) : null;
});
const resolvedMinPriceText = computed(() => {
  if (!canSeeCatalogPrice.value) return null;
  return props.minPriceText || formatStorefrontCardMinPrice(props.item, props.formatMoney);
});

const gradeChipLabel = computed(() => {
  if (!showGradeChip.value || !props.item.stock_grade?.label) return null;
  return props.item.stock_grade.label;
});

const gradeChipStyle = computed(() => {
  const color = props.item.stock_grade?.color?.trim();
  if (!color) return undefined;
  return { backgroundColor: color };
});
</script>

<style scoped>
.product-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  border-radius: var(--bw-radius-md);
  background: color-mix(in srgb, var(--bw-theme-surface) 90%, var(--bw-shop-mauve, #996888) 10%);
  border-color: var(--bw-theme-border);
  color: var(--bw-theme-ink);
  overflow: hidden;
  transition:
    transform 0.25s ease,
    box-shadow 0.25s ease;
}
.product-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--bw-theme-shadow, 0 10px 24px rgb(42 43 42 / 0.08));
}
.product-card--listing-inactive {
  opacity: 0.72;
}
.product-card--listing-inactive .product-image-wrapper::after {
  content: '';
  position: absolute;
  inset: 0;
  background: rgb(255 255 255 / 0.35);
  pointer-events: none;
}
.admin-card-actions {
  padding-top: 6px;
  margin-top: 8px;
  border-top: 1px solid var(--bw-theme-border, rgb(42 43 42 / 0.08));
}
.product-image-wrapper {
  position: relative;
  height: 200px;
  flex: 0 0 200px;
  background: #ffffff;
  border-bottom: 1px solid var(--bw-theme-border, rgb(42 43 42 / 0.06));
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  overflow: hidden;
}
.product-overlay-chip {
  position: absolute;
  top: 10px;
  z-index: 1;
  font-size: 11px;
  min-height: 22px;
  box-shadow: 0 2px 8px rgb(42 43 42 / 0.16);
}
.product-grade-chip {
  left: 10px;
  max-width: calc(100% - 20px);
}
.product-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}
.product-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
}
.product-main {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  min-width: 0;
}
.product-body {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  min-width: 0;
  overflow: visible;
  padding: 12px 12px 8px;
  gap: 0.25rem;
}
.product-meta {
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, #5e4955);
}
.storefront-product-card__name {
  font-size: 0.9375rem;
  font-weight: 600;
  line-height: 1.35;
  min-height: calc(1.35em * 2);
  max-height: calc(1.35em * 2);
  color: var(--bw-theme-ink, #2a2b2a);
  word-break: break-word;
  overflow-wrap: anywhere;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.storefront-product-card__price {
  font-size: 1.5rem;
  font-weight: 700;
  line-height: 1.15;
  letter-spacing: -0.03em;
  color: var(--bw-theme-ink, #2a2b2a);
}
.storefront-product-card__price-label {
  display: block;
  margin-bottom: 0.1rem;
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, #5e4955);
}
.storefront-product-card__min-price {
  margin-top: 0.15rem;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--bw-theme-muted, #5e4955);
}
.storefront-product-card__min-price span {
  font-weight: 700;
  color: var(--bw-shop-plum, #5e4955);
}
.product-stock {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--bw-theme-muted, #5e4955);
}
.product-stock--ok {
  color: var(--bw-success, #1a7f4b);
}
.product-stock--low {
  color: var(--q-warning, #f2c037);
}
.product-stock--out {
  color: var(--bw-error, #b42318);
}
.product-actions {
  flex-shrink: 0;
  margin-top: auto;
  display: flex !important;
  width: 100%;
  min-height: 44px;
  opacity: 1 !important;
  visibility: visible !important;
  padding: 0 12px 12px;
}
.product-actions__inner {
  width: 100%;
}
.quantity-controls {
  border: 1px solid var(--bw-theme-border);
  border-radius: var(--bw-radius-sm);
  padding: 2px;
  background: var(--bw-theme-surface);
}
.quantity-value {
  width: 28px;
  font-size: 13px;
  user-select: none;
  color: var(--bw-theme-ink, #2a2b2a);
}
.product-pricing {
  flex-shrink: 0;
  min-width: 0;
  margin-top: 0.15rem;
}

.product-card--dropship .storefront-product-card__price-label {
  color: var(--bw-shop-mauve, #996888);
}

@media (prefers-reduced-motion: reduce) {
  .product-card,
  .product-card:hover {
    transition: none;
    transform: none;
  }
}

@media (max-width: 599px) {
  .product-card {
    display: grid;
    grid-template-columns: 96px minmax(0, 1fr);
    grid-template-areas:
      'image body'
      'actions actions';
    column-gap: 10px;
    row-gap: 8px;
    align-items: start;
    height: auto;
    margin: 0 0 10px;
    padding: 10px;
    border-radius: var(--bw-radius-md);
    border: none !important;
    overflow: hidden;
  }
  .product-card:hover {
    transform: none;
    box-shadow: none;
  }
  .product-image-wrapper {
    grid-area: image;
    width: 96px;
    height: 96px;
    flex: none;
    align-self: start;
    margin: 0;
    padding: 0;
    border-bottom: none;
    border-radius: var(--bw-radius-md);
    overflow: hidden;
  }
  .product-main {
    display: contents;
  }
  .product-body {
    grid-area: body;
    padding: 0;
    gap: 0.15rem;
  }
  .storefront-product-card__name {
    font-size: 0.8125rem;
    min-height: 0;
    max-height: calc(1.35em * 2);
  }
  .storefront-product-card__price {
    font-size: 1.3125rem;
  }
  .product-actions {
    grid-area: actions;
    min-height: 0;
    padding: 0;
    width: 100%;
  }
  .product-actions__inner {
    gap: 8px;
  }
  .quantity-controls {
    flex: 0 0 auto;
  }
}
</style>

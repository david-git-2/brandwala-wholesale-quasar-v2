<template>
  <q-card
    flat
    bordered
    class="product-card"
    :class="{ 'product-card--listing-inactive': showListingStatusToggle && !isListingActive }"
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

    <div class="product-body">
      <div class="product-meta text-caption text-uppercase tracking-wider">
        {{ item.product_brand || 'Generic' }}
      </div>
      <div
        class="product-name text-subtitle2 text-weight-bold cursor-pointer"
        @click="$emit('open-detail', item)"
      >
        {{ item.product_name }}
      </div>

      <div
        v-if="
          showQuantityBreakdown &&
          permissions?.can_view_quantity
        "
        class="storefront-qty-breakdown q-mt-xs column q-gutter-y-xs"
      >
        <div class="text-caption row items-center no-wrap q-gutter-x-xs">
          <span class="text-grey-7">{{ $t('shop_admin.col_actual_qty') }}:</span>
          <span class="text-weight-medium" :class="actualQtyClass">{{ actualAvailableQty }}</span>
        </div>
        <div class="text-caption row items-center no-wrap q-gutter-x-xs">
          <span class="text-grey-7">{{ $t('shop_admin.col_display_qty') }}:</span>
          <span class="text-weight-medium" :class="displayQtyClass">{{ displayQtyValue }}</span>
          <span v-if="!hasDisplayOverride" class="text-grey-6">({{ $t('shop_admin.storefront_qty_auto') }})</span>
        </div>
      </div>

      <div
        v-else-if="
          permissions?.can_view_quantity &&
          item.available_units !== null &&
          item.available_units !== undefined
        "
        class="text-caption q-mt-xs"
        :class="
          item.available_units > 0
            ? 'text-positive'
            : item.available_units === 0
              ? 'text-negative'
              : 'text-grey-6'
        "
      >
        {{ item.available_units }} {{ $t('shop.avail') }}
      </div>

      <div class="product-pricing q-mt-sm">
        <div
          v-if="avgCostText"
          class="text-body2 text-grey-9 text-weight-medium"
        >
          <span class="text-caption text-grey-6 block text-weight-medium">
            {{ $t('shop_admin.storefront_avg_cost') }}
          </span>
          {{ avgCostText }}
        </div>

        <div
          v-if="unitPriceText"
          class="text-subtitle1 text-weight-bold text-primary"
          :class="{ 'q-mt-xs': avgCostText }"
        >
          <span
            v-if="unitPriceLabel"
            class="text-caption text-grey-6 block text-weight-medium"
          >
            {{ unitPriceLabel }}
          </span>
          {{ unitPriceText }}
        </div>

        <div
          v-if="sellPriceText"
          class="text-subtitle1 text-weight-bold text-primary"
          :class="{ 'q-mt-xs': unitPriceText }"
        >
          <span
            v-if="sellPriceLabel"
            class="text-caption text-grey-6 block text-weight-medium"
          >
            {{ sellPriceLabel }}
          </span>
          {{ sellPriceText }}
        </div>

        <div
          v-if="resellMinimumText"
          class="text-body2 text-grey-9 text-weight-medium q-mt-xs"
        >
          {{ $t('shop.min_sell_price') }}
          <span class="text-secondary text-weight-bold">{{ resellMinimumText }}</span>
        </div>
      </div>

      <div v-if="showCalculateSellPrice" class="q-mt-sm">
        <q-btn
          outline
          dense
          no-caps
          color="primary"
          icon="ph ph-calculator"
          :label="$t('shop_admin.storefront_calculate_sell_price')"
          class="full-width"
          style="border-radius: 8px"
          @click="$emit('calculate-sell-price', item)"
        />
      </div>

      <div
        v-if="showAdminCardActions"
        class="q-mt-sm row items-center no-wrap admin-card-actions"
        :class="showListingStatusToggle ? 'justify-between' : 'justify-end'"
      >
        <div v-if="showListingStatusToggle" class="row items-center no-wrap q-gutter-x-sm col min-width-0">
          <span class="text-caption text-grey-7">{{ listingStatusLabel }}</span>
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

      <div v-if="showActions" class="product-actions q-mt-auto q-pt-sm">
        <div class="row items-center no-wrap justify-between q-gutter-x-xs">
          <div
            v-if="!inCart"
            class="row items-center no-wrap quantity-controls col-auto"
            style="
              border: 1.5px solid var(--bw-theme-border, rgba(34, 56, 101, 0.15));
              border-radius: 8px;
              padding: 2px;
              background: rgba(0, 0, 0, 0.02);
            "
          >
            <q-btn
              flat
              round
              dense
              size="xs"
              icon="ph ph-minus"
              color="grey-8"
              style="min-width: 28px; min-height: 28px"
              @click="$emit('decrement', item)"
            />
            <div
              class="text-weight-bold text-center text-grey-9"
              style="width: 28px; font-size: 13px; user-select: none"
            >
              {{ selectedQty || minQty }}
            </div>
            <q-btn
              flat
              round
              dense
              size="xs"
              icon="ph ph-plus"
              color="grey-8"
              style="min-width: 28px; min-height: 28px"
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
            :label="$q.screen.lt.sm ? undefined : $t('shop.add')"
            class="add-cart-btn"
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
            :label="$q.screen.lt.sm ? undefined : $t('shop.remove')"
            class="add-cart-btn"
            :loading="loading"
            :disabled="!permissions?.can_add_to_cart"
            @click="$emit('remove-from-cart', item)"
          />
        </div>
      </div>
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
import { formatCatalogPrice, hasCatalogPrice } from '../utils/catalogPriceUtils';

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
}>();

const showActions = computed(() => props.showActions !== false);
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

const isListingActive = computed(
  () => props.item.listing_status !== 'inactive',
);

const listingStatusLabel = computed(() =>
  isListingActive.value ? t('shop_admin.active') : t('shop_admin.inactive'),
);

const onListingActiveChange = (value: boolean) => {
  emit('toggle-listing-status', props.item, value);
};

const minQty = computed(() => {
  if (props.shopType === 'dropship') return 1;
  return props.item.minimum_order_quantity || 1;
});

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
  actualAvailableQty.value > 0 ? 'text-positive' : 'text-negative',
);

const displayQtyClass = computed(() => {
  if (!hasDisplayOverride.value) return 'text-grey-8';
  return displayQtyValue.value > 0 ? 'text-primary' : 'text-negative';
});

const formatItemPrice = (price: ShopCatalogItem['unit_price']) =>
  formatCatalogPrice(price, props.formatMoney);

const avgCostText = computed(() => {
  if (!showAvgCost.value) return null;
  return formatItemPrice(props.item.avg_cost ?? null);
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

const unitPriceLabel = computed(() => {
  if (!hasCatalogPrice(props.item.unit_price)) return null;
  if (props.shopType === 'dropship') return t('shop.wholesale_price');
  if (props.shopType === 'vendor_catalog') return t('shop.unit_price');
  return null;
});

const unitPriceText = computed(() => {
  if (!showUnitPrice.value || props.shopType === 'fixed_price') return null;
  return formatItemPrice(props.item.unit_price);
});

const sellPriceLabel = computed(() => {
  if (!hasCatalogPrice(props.item.sell_price)) return null;
  if (props.shopType === 'dropship') return t('shop.sell_price');
  return null;
});

const sellPriceText = computed(() => formatItemPrice(props.item.sell_price));

const resellMinimumText = computed(() => {
  if (props.shopType !== 'dropship') return null;
  return formatItemPrice(props.item.resell_minimum_price);
});
</script>

<style scoped>
.product-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  border-radius: 16px;
  background: var(--bw-theme-surface, #ffffff);
  border-color: var(--bw-theme-border, rgba(34, 56, 101, 0.12));
  color: var(--bw-theme-ink, #1f2937);
  overflow: hidden;
  transition:
    transform 0.25s ease,
    box-shadow 0.25s ease;
}
.product-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--bw-theme-shadow, 0 10px 20px rgba(34, 56, 101, 0.06));
}
.product-card--listing-inactive {
  opacity: 0.72;
}
.product-card--listing-inactive .product-image-wrapper::after {
  content: '';
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.35);
  pointer-events: none;
}
.admin-card-actions {
  padding-top: 4px;
  border-top: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08));
}
.product-image-wrapper {
  position: relative;
  height: 160px;
  flex: 0 0 160px;
  background: var(--bw-theme-surface, #ffffff);
  border-bottom: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.05));
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px;
}
.product-overlay-chip {
  position: absolute;
  top: 8px;
  z-index: 1;
  font-size: 11px;
  min-height: 22px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.18);
}
.product-grade-chip {
  left: 8px;
  max-width: calc(100% - 16px);
}
.product-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
  border-radius: 8px;
}
.product-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bw-theme-surface, #ffffff);
  border-radius: 8px;
}
.product-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 10px 12px 12px;
}
.product-meta {
  letter-spacing: 0.05em;
  margin-bottom: 2px;
  color: var(--bw-theme-muted, #6b7280);
}
.product-name {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.35;
  min-height: 4.05em;
  margin-bottom: 4px;
  color: var(--bw-theme-ink, #1f2937);
}
.product-actions {
  margin-top: auto;
  padding-top: 8px;
  border-top: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.06));
}
.product-pricing {
  min-width: 0;
}
.add-cart-btn {
  flex: 1 1 auto;
  border-radius: 8px;
}

@media (max-width: 599px) {
  .product-card {
    flex-direction: row;
    align-items: stretch;
    height: auto;
    border-radius: 0;
    border: none !important;
    border-bottom: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08)) !important;
    box-shadow: none;
  }
  .product-card:hover {
    transform: none;
    box-shadow: none;
  }
  .product-image-wrapper {
    width: 96px;
    height: 96px;
    flex: 0 0 96px;
    align-self: center;
    margin: 10px 0 10px 10px;
    padding: 4px;
    border-bottom: none;
    border-radius: 8px;
    overflow: hidden;
  }
  .product-image,
  .product-image-fallback {
    border-radius: 6px;
  }
  .product-body {
    padding: 10px 12px 10px 10px;
  }
  .product-name {
    min-height: unset;
    -webkit-line-clamp: 3;
    line-clamp: 3;
    font-size: 14px;
  }
  .product-actions {
    border-top: none;
    padding-top: 4px;
  }
  .add-cart-btn {
    min-width: 36px;
    padding-left: 4px;
    padding-right: 4px;
  }
}
</style>

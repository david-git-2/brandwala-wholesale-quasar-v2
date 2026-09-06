<template>
  <q-card
    flat
    bordered
    class="product-group-card"
    :class="{ 'product-group-card--inactive': showListingStatusToggle && selectedListing && !isListingActive }"
  >
    <div class="product-image-wrapper">
      <img
        v-if="group.product_image_url"
        :src="group.product_image_url"
        :alt="group.product_name || 'Product'"
        class="product-image"
        loading="lazy"
      />
      <div v-else class="product-image-fallback">
        <q-icon name="ph ph-image-square" size="28px" color="grey-5" />
      </div>
    </div>

    <div class="product-main">
      <q-card-section class="product-body">
        <div class="product-header">
          <div class="product-meta text-caption text-uppercase tracking-wider">
            {{ group.product_brand || 'Generic' }}
          </div>
          <div class="product-name text-subtitle2 text-weight-bold">
            {{ group.product_name }}
          </div>
        </div>

        <StorefrontGradeToggleRow
          v-model="selectedGradeSlug"
          class="q-mt-xs"
          :listings-by-grade="group.listingsByGrade"
        />

        <div v-if="!selectedListing" class="grade-empty q-mt-md">
          <div class="text-caption text-grey-7">
            {{ $t('shop_admin.storefront_grade_not_listed') }}
          </div>
          <q-btn
            outline
            dense
            no-caps
            color="primary"
            class="q-mt-sm full-width"
            style="border-radius: 8px"
            :loading="isSettingUpGrade"
            :label="$t('shop_admin.storefront_setup_grade')"
            @click="$emit('setup-grade', group, selectedGradeSlug)"
          />
        </div>

        <template v-else>
          <div class="product-details-grid q-mt-sm">
            <div
              v-if="showQuantityBreakdown && permissions?.can_view_quantity"
              class="detail-field"
            >
              <span class="detail-label">{{ $t('shop_admin.col_actual_qty') }}</span>
              <span class="detail-value text-weight-medium" :class="actualQtyClass">
                {{ actualAvailableQty }}
              </span>
            </div>

            <div
              v-if="showQuantityBreakdown && permissions?.can_view_quantity"
              class="detail-field"
            >
              <span class="detail-label">{{ $t('shop_admin.col_display_qty') }}</span>
              <span class="detail-value text-weight-medium" :class="displayQtyClass">
                {{ displayQtyValue }}
                <span v-if="!hasDisplayOverride" class="text-grey-6 text-caption">
                  ({{ $t('shop_admin.storefront_qty_auto') }})
                </span>
              </span>
            </div>

            <div v-if="avgCostText" class="detail-field">
              <span class="detail-label">{{ $t('shop_admin.storefront_avg_cost') }}</span>
              <span class="detail-value text-weight-medium">{{ avgCostText }}</span>
            </div>

            <div v-if="sellPriceText" class="detail-field">
              <span v-if="sellPriceLabel" class="detail-label">{{ sellPriceLabel }}</span>
              <span v-else class="detail-label">{{ $t('shop.sell_price') }}</span>
              <span class="detail-value text-weight-bold text-primary">{{ sellPriceText }}</span>
            </div>

            <div v-if="resellMinimumText" class="detail-field">
              <span class="detail-label">{{ $t('shop.min_sell_price') }}</span>
              <span class="detail-value text-weight-bold text-secondary">{{ resellMinimumText }}</span>
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
              @click="$emit('calculate-sell-price', selectedListing)"
            />
          </div>

          <div
            v-if="showAdminCardActions"
            class="q-mt-sm row items-center no-wrap admin-card-actions justify-between"
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

            <q-btn
              v-if="showRemoveProduct"
              flat
              round
              dense
              color="negative"
              icon="ph ph-trash"
              :aria-label="$t('shop_admin.storefront_remove_grade')"
              @click="$emit('remove-grade', selectedListing)"
            >
              <q-tooltip>{{ $t('shop_admin.storefront_remove_grade') }}</q-tooltip>
            </q-btn>
          </div>
        </template>
      </q-card-section>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import StorefrontGradeToggleRow from './StorefrontGradeToggleRow.vue';
import type { CustomerShopPermissions } from '../composables/useCustomerShopPermissionsQuery';
import type { ShopStorefrontAdminListing, ShopType } from '../types';
import {
  pickDefaultGradeSlug,
  type StorefrontProductGroup,
} from '../utils/storefrontProductGroups';
import { normalizeStorefrontGradeSlug } from '../constants/storefrontWarehouseGrades';
import { formatCatalogPrice, hasCatalogPrice } from '../utils/catalogPriceUtils';

const props = defineProps<{
  group: StorefrontProductGroup;
  permissions?: CustomerShopPermissions | null;
  shopType?: ShopType | null;
  showQuantityBreakdown?: boolean | undefined;
  showCalculateSellPrice?: boolean | undefined;
  showAvgCost?: boolean | undefined;
  showListingStatusToggle?: boolean | undefined;
  showRemoveProduct?: boolean | undefined;
  isSettingUpGrade?: boolean | undefined;
  formatMoney: (amount: unknown, symbol?: string | null) => string;
}>();

const emit = defineEmits<{
  (e: 'setup-grade', group: StorefrontProductGroup, gradeSlug: string): void;
  (e: 'calculate-sell-price', listing: ShopStorefrontAdminListing): void;
  (e: 'toggle-listing-status', listing: ShopStorefrontAdminListing, isActive: boolean): void;
  (e: 'remove-grade', listing: ShopStorefrontAdminListing): void;
}>();

const { t } = useI18n();

const selectedGradeSlug = ref(pickDefaultGradeSlug(props.group));

watch(
  () => props.group,
  (group) => {
    if (!group?.listingsByGrade) return;
    selectedGradeSlug.value = pickDefaultGradeSlug(group);
  },
  { deep: true },
);

const selectedListing = computed(() => {
  const byGrade = props.group?.listingsByGrade;
  if (!byGrade) return null;
  return byGrade[normalizeStorefrontGradeSlug(selectedGradeSlug.value)] ?? null;
});

const showQuantityBreakdown = computed(() => props.showQuantityBreakdown === true);
const showCalculateSellPrice = computed(() => props.showCalculateSellPrice === true);
const showAvgCost = computed(() => props.showAvgCost === true);
const showListingStatusToggle = computed(() => props.showListingStatusToggle === true);
const showRemoveProduct = computed(() => props.showRemoveProduct === true);
const showAdminCardActions = computed(
  () => showListingStatusToggle.value || showRemoveProduct.value,
);

const isListingActive = computed(() => selectedListing.value?.listing_status !== 'inactive');

const listingStatusLabel = computed(() =>
  isListingActive.value ? t('shop_admin.active') : t('shop_admin.inactive'),
);

const onListingActiveChange = (value: boolean) => {
  if (selectedListing.value) {
    emit('toggle-listing-status', selectedListing.value, value);
  }
};

const actualAvailableQty = computed(() => {
  const raw = selectedListing.value?.real_available_units ?? selectedListing.value?.available_units;
  return raw ?? 0;
});

const hasDisplayOverride = computed(
  () =>
    selectedListing.value?.display_quantity_override !== null &&
    selectedListing.value?.display_quantity_override !== undefined,
);

const displayQtyValue = computed(() => {
  if (!selectedListing.value) return 0;
  if (hasDisplayOverride.value) return selectedListing.value.display_quantity_override as number;
  return actualAvailableQty.value;
});

const actualQtyClass = computed(() =>
  actualAvailableQty.value > 0 ? 'text-positive' : 'text-negative',
);

const displayQtyClass = computed(() => {
  if (!hasDisplayOverride.value) return 'text-grey-8';
  return displayQtyValue.value > 0 ? 'text-primary' : 'text-negative';
});

const formatItemPrice = (price: ShopStorefrontAdminListing['unit_price']) =>
  formatCatalogPrice(price, props.formatMoney);

const avgCostText = computed(() => {
  if (!showAvgCost.value || !selectedListing.value) return null;
  return formatItemPrice(selectedListing.value.avg_cost ?? null);
});

const sellPriceLabel = computed(() => {
  if (!selectedListing.value || !hasCatalogPrice(selectedListing.value.sell_price)) return null;
  if (props.shopType === 'dropship') return t('shop.sell_price');
  return null;
});

const sellPriceText = computed(() =>
  selectedListing.value ? formatItemPrice(selectedListing.value.sell_price) : null,
);

const resellMinimumText = computed(() => {
  if (props.shopType !== 'dropship' || !selectedListing.value) return null;
  return formatItemPrice(selectedListing.value.resell_minimum_price);
});
</script>

<style scoped>
.product-group-card {
  display: flex;
  flex-direction: row;
  align-items: stretch;
  border-radius: 16px;
  background: var(--bw-theme-surface, #ffffff);
  border-color: var(--bw-theme-border, rgba(34, 56, 101, 0.12));
  overflow: visible;
  transition:
    transform 0.25s ease,
    box-shadow 0.25s ease;
}
.product-group-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--bw-theme-shadow, 0 10px 20px rgba(34, 56, 101, 0.06));
}
.product-group-card--inactive {
  opacity: 0.78;
}
.product-image-wrapper {
  width: 112px;
  flex: 0 0 112px;
  min-height: 112px;
  border-right: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.05));
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px;
  border-radius: 16px 0 0 16px;
}
.product-image {
  width: 100%;
  max-height: 120px;
  object-fit: contain;
  border-radius: 8px;
}
.product-image-fallback {
  width: 100%;
  min-height: 96px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.product-main {
  flex: 1 1 auto;
  min-width: 0;
}
.product-body {
  padding: 10px 12px 10px;
}
.product-meta {
  color: var(--bw-theme-muted, #6b7280);
}
.product-name {
  line-height: 1.35;
}
.grade-empty {
  padding: 8px;
  border-radius: 8px;
  background: rgba(0, 0, 0, 0.02);
  border: 1px dashed var(--bw-theme-border, rgba(34, 56, 101, 0.12));
}
.product-details-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px 12px;
}
.detail-field {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.detail-label {
  font-size: 11px;
  color: var(--bw-theme-muted, #6b7280);
  font-weight: 500;
}
.detail-value {
  font-size: 13px;
  word-break: break-word;
}
.admin-card-actions {
  padding-top: 4px;
  border-top: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08));
}
.min-width-0 {
  min-width: 0;
}

@media (max-width: 599px) {
  .product-image-wrapper {
    width: 88px;
    flex: 0 0 88px;
    border-radius: 0;
  }
}

@media (max-width: 359px) {
  .product-details-grid {
    grid-template-columns: 1fr;
  }
}
</style>

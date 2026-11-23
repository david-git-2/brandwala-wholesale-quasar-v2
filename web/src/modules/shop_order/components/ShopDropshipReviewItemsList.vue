<template>
  <q-card flat bordered class="dropship-review-list">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle2 text-weight-bold text-grey-9">
        {{ $t('shop.items') }} ({{ itemCount }})
      </div>
    </q-card-section>

    <!-- xs: stacked item cards -->
    <div class="dropship-review-list__mobile lt-md q-pa-sm column q-gutter-y-sm">
      <ShopDropshipReviewItemRow
        v-for="item in items"
        :key="item.id"
        :item="item"
        :shop-id="shopId"
        :currency-symbol="currencySymbol"
        :disable-resell="disableResell"
        @update:resell-price="(id, val) => onResellInput(id, val)"
        @resell-price-blur="(id) => $emit('resell-price-blur', id)"
      />
    </div>

    <!-- sm+: aligned grid -->
    <div class="dropship-review-list__desktop gt-sm">
      <div
        class="dropship-review-list__head dropship-review-list__row-grid text-caption text-grey-6 text-weight-medium"
      >
        <div>{{ $t('shop.dropship_col_product') }}</div>
        <div class="text-center">{{ $t('shop.qty') }}</div>
        <div class="text-right">{{ $t('shop.dropship_col_purchase') }}</div>
        <div class="text-right">{{ $t('shop.dropship_col_resell') }}</div>
        <div class="text-right">{{ $t('shop.dropship_col_purchase_total') }}</div>
        <div class="text-right">{{ $t('shop.dropship_col_resell_total') }}</div>
      </div>

      <div class="dropship-review-list__rows">
        <ShopDropshipReviewItemRow
          v-for="item in items"
          :key="item.id"
          :item="item"
          :shop-id="shopId"
          :currency-symbol="currencySymbol"
          :disable-resell="disableResell"
          @update:resell-price="(id, val) => onResellInput(id, val)"
          @resell-price-blur="(id) => $emit('resell-price-blur', id)"
        />
      </div>
    </div>

    <!-- xs footer -->
    <div class="dropship-review-list__footer dropship-review-list__footer--mobile lt-md q-px-md q-py-md">
      <div class="dropship-review-list__footer-grid">
        <div>
          <div class="dropship-review-list__footer-label">{{ $t('shop.dropship_col_purchase_total') }}</div>
          <div class="text-body2 text-weight-bold text-grey-9">{{ formatMoney(totals.purchaseTotal) }}</div>
        </div>
        <div class="text-right">
          <div class="dropship-review-list__footer-label">{{ $t('shop.dropship_col_resell_total') }}</div>
          <div
            class="text-body2 text-weight-bold"
            :class="hasPendingDiscountInList ? 'dropship-review-list__resell-total--pending' : 'text-primary'"
          >
            {{ formatMoney(totals.resellTotal) }}
          </div>
          <div v-if="hasPendingDiscountInList" class="dropship-review-list__footer-hint">
            {{ $t('shop.dropship_totals_pending_discount_note') }}
          </div>
        </div>
      </div>
    </div>

    <!-- sm+ footer -->
    <div
      class="dropship-review-list__footer dropship-review-list__footer--desktop gt-sm dropship-review-list__row-grid"
    >
      <div class="text-body2 text-weight-bold text-grey-9 min-width-0">
        {{ $t('shop.dropship_column_totals') }}
      </div>
      <div />
      <div />
      <div />
      <div class="text-right">
        <div class="dropship-review-list__footer-label">{{ $t('shop.dropship_col_purchase_total') }}</div>
        <div class="text-body2 text-weight-bold text-grey-9">{{ formatMoney(totals.purchaseTotal) }}</div>
      </div>
      <div class="text-right">
        <div class="dropship-review-list__footer-label">{{ $t('shop.dropship_col_resell_total') }}</div>
        <div
          class="text-body2 text-weight-bold"
          :class="hasPendingDiscountInList ? 'dropship-review-list__resell-total--pending' : 'text-primary'"
        >
          {{ formatMoney(totals.resellTotal) }}
        </div>
        <div v-if="hasPendingDiscountInList" class="dropship-review-list__footer-hint">
          {{ $t('shop.dropship_totals_pending_discount_note') }}
        </div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatCartMoney } from '../utils/cartPriceUtils';
import { hasPendingResellDiscount } from '../utils/dropshipReviewPricingUtils';
import ShopDropshipReviewItemRow from './ShopDropshipReviewItemRow.vue';

export interface DropshipReviewListItem {
  id: number;
  name: string;
  imageUrl?: string | null;
  quantity: number;
  purchasePrice: number;
  resellPrice: number;
  minResellPrice: number;
  isSaving?: boolean;
  requestedResellDiscountPrice?: number | null;
  resellDiscountRequestReason?: string | null;
}

const props = withDefaults(
  defineProps<{
    items: DropshipReviewListItem[];
    itemCount: number;
    totals: {
      purchaseTotal: number;
      resellTotal: number;
    };
    currencySymbol?: string;
    disableResell?: boolean;
    savingItemId?: number | null;
    shopId?: number | null;
  }>(),
  {
    currencySymbol: '৳',
    disableResell: false,
    savingItemId: null,
    shopId: null,
  },
);

const emit = defineEmits<{
  (e: 'update:resellPrice', itemId: number, value: number): void;
  (e: 'resell-price-blur', itemId: number): void;
}>();

const formatMoney = (amount: number) =>
  formatCartMoney(amount, props.currencySymbol ?? '৳');

const hasPendingDiscountInList = computed(() =>
  props.items.some((item) => hasPendingResellDiscount(item.requestedResellDiscountPrice)),
);

const onResellInput = (itemId: number, val: number) => {
  emit('update:resellPrice', itemId, val);
};
</script>

<style scoped>
.dropship-review-list {
  border-radius: var(--tf-radius-md, 12px);
  overflow: hidden;
}

.border-bottom {
  border-bottom: 1px solid var(--tf-neutral-border, rgba(34, 56, 101, 0.08));
}

.dropship-review-list__row-grid,
:deep(.dropship-review-list__row-grid) {
  display: grid;
  grid-template-columns: minmax(0, 1.5fr) 44px 84px minmax(120px, 1.05fr) 92px 92px;
  gap: 8px 12px;
  padding: 12px 16px;
  align-items: start;
}

@media (min-width: 1280px) {
  .dropship-review-list__row-grid,
  :deep(.dropship-review-list__row-grid) {
    grid-template-columns: minmax(0, 1.6fr) 48px 88px minmax(128px, 1.1fr) 96px 96px;
  }
}

.dropship-review-list__head {
  border-bottom: 1px solid rgba(34, 56, 101, 0.06);
  align-items: end;
}

.dropship-review-list__rows :deep(.dropship-review-item-wrap + .dropship-review-item-wrap .dropship-review-item--grid) {
  border-top: 1px solid rgba(34, 56, 101, 0.06);
}

.dropship-review-list__footer {
  border-top: 1px solid var(--tf-neutral-border, rgba(34, 56, 101, 0.08));
  background: rgba(34, 56, 101, 0.03);
}

.dropship-review-list__footer-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.dropship-review-list__footer-label {
  font-size: 11px;
  line-height: 1.2;
  font-weight: 600;
  color: rgba(34, 56, 101, 0.55);
  margin-bottom: 4px;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

:deep(.dropship-review-item__cell) {
  min-width: 0;
}

.dropship-review-list__resell-total--pending {
  color: color-mix(in srgb, var(--tf-warning) 75%, var(--tf-neutral-ink));
}

.dropship-review-list__footer-hint {
  margin-top: 6px;
  max-width: 220px;
  margin-left: auto;
  font-size: 10px;
  line-height: 1.35;
  font-weight: 500;
  color: rgba(34, 56, 101, 0.58);
  text-align: right;
}
</style>
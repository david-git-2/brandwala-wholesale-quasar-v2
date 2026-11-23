<template>
  <div class="column q-gutter-y-md">
    <ShopDropshipReviewItemsList
      :items="uiItems"
      :shop-id="shopId"
      :item-count="reviewSummary.totalUnits"
      :totals="columnTotals"
      :currency-symbol="currencySymbol"
      :disable-resell="isUpdatingPrice"
      :saving-item-id="savingItemId"
      @update:resell-price="updateResellPriceLocal"
      @resell-price-blur="saveResellPrice"
    />
    <q-card flat bordered>
      <q-card-section class="q-pa-md">
        <div class="row items-center justify-between">
          <div class="text-subtitle2 text-weight-bold">{{ $t('shop.recipient_pay') }}</div>
          <div class="text-h6 text-weight-bold text-primary tf-num">
            {{ formatMoney(reviewSummary.itemsTotal) }}
          </div>
        </div>
        <div class="text-caption text-grey-6 q-mt-xs">
          {{ $t('shop.dropship_courier_added_later') }}
        </div>
        <div
          v-if="reviewSummary.hasFloorViolation"
          class="text-caption text-negative q-mt-sm text-center"
        >
          {{ $t('shop.cart_price_below_floor') }}
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import ShopDropshipReviewItemsList, {
  type DropshipReviewListItem,
} from '../ShopDropshipReviewItemsList.vue';

const props = defineProps<{
  shopId: number | null;
  uiItems: DropshipReviewListItem[];
  columnTotals: { purchaseTotal: number; resellTotal: number };
  reviewSummary: { itemsTotal: number; totalUnits: number; hasFloorViolation: boolean };
  currencySymbol: string;
  isUpdatingPrice: boolean;
  savingItemId: number | null;
  updateResellPriceLocal: (itemId: number, value: number) => void;
  saveResellPrice: (itemId: number) => Promise<void>;
}>();

const formatMoney = (amount: number) => {
  const sym = props.currencySymbol?.trim() || '৳';
  return `${sym} ${amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
};
</script>
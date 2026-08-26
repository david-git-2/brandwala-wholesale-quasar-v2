<template>
  <q-page class="q-pa-md shop-commerce-page">
    <div class="q-gutter-y-md">
      <section class="dropship-review-header">
        <div class="text-subtitle1 text-weight-bold text-grey-9 q-my-none">
          {{ $t('shop.dropship_review_title') }}
        </div>
        <div class="text-caption text-grey-6 q-mt-xs">
          {{ $t('shop.dropship_review_subtitle') }}
          <span v-if="totalUnits > 0"> · {{ totalUnits }} {{ $t('shop.items').toLowerCase() }}</span>
        </div>
      </section>

      <div class="row q-col-gutter-lg">
        <div class="col-xs-12 col-lg-8">
          <ShopDropshipReviewItemsList
            :items="uiItems"
            :item-count="totalUnits"
            :totals="columnTotals"
            :currency-symbol="currencySymbol"
            @update:resell-price="updateResellPrice"
          />
        </div>

        <div class="col-xs-12 col-lg-4">
          <ShopDropshipReviewSummaryCard
            :summary="summary"
            :currency-symbol="currencySymbol"
            @continue="goToDelivery"
          />
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  DROPSHIP_CART_UI_MOCK_SHOP,
  DROPSHIP_REVIEW_UI_MOCK_ITEMS,
  DROPSHIP_UI_MOCK_CHARGES,
  type DropshipReviewUiItem,
} from '../mocks/dropshipCartUiMocks';
import { shopDropshipDeliveryPath } from '../utils/catalogShop';
import ShopDropshipReviewItemsList from '../components/ShopDropshipReviewItemsList.vue';
import ShopDropshipReviewSummaryCard from '../components/ShopDropshipReviewSummaryCard.vue';

const route = useRoute();
const router = useRouter();

const currencySymbol = DROPSHIP_CART_UI_MOCK_SHOP.currency_symbol;

const uiItems = ref<DropshipReviewUiItem[]>(
  DROPSHIP_REVIEW_UI_MOCK_ITEMS.map((item) => ({ ...item })),
);

const totalUnits = computed(() =>
  uiItems.value.reduce((sum, item) => sum + item.quantity, 0),
);

const columnTotals = computed(() => ({
  purchaseTotal: uiItems.value.reduce(
    (sum, item) => sum + item.purchasePrice * item.quantity,
    0,
  ),
  resellTotal: uiItems.value.reduce(
    (sum, item) => sum + item.resellPrice * item.quantity,
    0,
  ),
}));

const hasFloorViolation = computed(() =>
  uiItems.value.some((item) => item.resellPrice < item.minResellPrice),
);

const summary = computed(() => {
  const resellTotal = columnTotals.value.resellTotal;
  const deliveryMid =
    (DROPSHIP_UI_MOCK_CHARGES.deliveryChargeMin +
      DROPSHIP_UI_MOCK_CHARGES.deliveryChargeMax) /
    2;
  const codCharge = (resellTotal * DROPSHIP_UI_MOCK_CHARGES.codPercent) / 100;
  const recipientGrandTotal = resellTotal + deliveryMid + codCharge;

  return {
    recipientGrandTotal,
    totalUnits: totalUnits.value,
    hasFloorViolation: hasFloorViolation.value,
  };
});

const updateResellPrice = (itemId: number, value: number) => {
  const item = uiItems.value.find((row) => row.id === itemId);
  if (item) item.resellPrice = value;
};

const goToDelivery = () => {
  if (summary.value.hasFloorViolation) return;
  void router.push(
    shopDropshipDeliveryPath(
      route.params.tenantSlug ? String(route.params.tenantSlug) : null,
      DROPSHIP_CART_UI_MOCK_SHOP.shop_id,
    ),
  );
};
</script>

<script lang="ts">
export default {
  name: 'ShopDropshipReviewPage',
};
</script>

<style scoped>
.dropship-review-header {
  min-height: 40px;
}
</style>

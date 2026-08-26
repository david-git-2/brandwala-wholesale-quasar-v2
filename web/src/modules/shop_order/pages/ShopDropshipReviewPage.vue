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

      <ShopCartSkeleton v-if="isLoading" />

      <q-card v-else-if="isError" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-warning-circle" size="64px" color="negative" class="q-mb-md" />
          <div class="text-h6 text-grey-8 text-weight-bold q-mb-xs">
            {{ $t('shop.cart_load_error') }}
          </div>
          <div class="text-grey-6 q-mb-md">
            {{ $t('shop.cart_load_error_desc') }}
          </div>
          <q-btn
            color="primary"
            no-caps
            unelevated
            icon="ph ph-arrow-clockwise"
            :label="$t('shop.cart_retry')"
            @click="() => refetch()"
          />
        </q-card-section>
      </q-card>

      <q-card v-else-if="!shopId || items.length === 0" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-shopping-cart" size="64px" color="grey-4" class="q-mb-md" />
          <div class="text-h6 text-grey-7 text-weight-bold">{{ $t('shop.cart_empty') }}</div>
          <p class="text-body2 text-grey-6 q-mt-sm q-mb-md">
            {{ $t('shop.cart_empty_desc') }}
          </p>
          <q-btn
            color="primary"
            no-caps
            unelevated
            :label="$t('shop.continue_shopping')"
            @click="goBackToCart"
          />
        </q-card-section>
      </q-card>

      <div v-else class="row q-col-gutter-lg">
        <div class="col-xs-12 col-lg-8">
          <ShopDropshipReviewItemsList
            :items="uiItems"
            :item-count="totalUnits"
            :totals="columnTotals"
            :currency-symbol="currencySymbol"
            :disable-resell="isUpdatingPrice"
            :saving-item-id="savingItemId"
            @update:resell-price="updateResellPriceLocal"
            @save-resell-price="saveResellPrice"
          />
        </div>

        <div class="col-xs-12 col-lg-4">
          <ShopDropshipReviewSummaryCard
            :summary="summary"
            :currency-symbol="currencySymbol"
            :disable-continue="isUpdatingPrice || hasUnsavedEdits"
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
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useDropshipReviewCartQuery } from '../composables/useDropshipReviewCartQuery';
import { useShopCartMutations } from '../composables/useShopCartMutations';
import {
  resolveCartShopId,
  shopCartPath,
  shopDropshipDeliveryPath,
} from '../utils/catalogShop';
import ShopCartSkeleton from '../components/ShopCartSkeleton.vue';
import ShopDropshipReviewItemsList, {
  type DropshipReviewListItem,
} from '../components/ShopDropshipReviewItemsList.vue';
import ShopDropshipReviewSummaryCard from '../components/ShopDropshipReviewSummaryCard.vue';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const shopId = computed(() =>
  resolveCartShopId(authStore.tenantId, [], route.query.shopId),
);

const {
  items,
  currencySymbol,
  totalUnits,
  resellSubtotal,
  hasFloorViolation,
  recipientGrandTotal,
  getPurchaseUnitAmount,
  getResellUnitAmount,
  getMinResellAmount,
  isLoading,
  isError,
  refetch,
} = useDropshipReviewCartQuery(shopId);

const { updatePriceMutation } = useShopCartMutations();
const isUpdatingPrice = computed(() => updatePriceMutation.isPending.value);
const savingItemId = ref<number | null>(null);
const editedResellPrices = ref<Record<number, number>>({});

const getItemResellPrice = (itemId: number, savedPrice: number) =>
  editedResellPrices.value[itemId] !== undefined
    ? editedResellPrices.value[itemId]
    : savedPrice;

const hasUnsavedResell = (itemId: number, savedPrice: number) =>
  editedResellPrices.value[itemId] !== undefined &&
  editedResellPrices.value[itemId] !== savedPrice;

const hasUnsavedEdits = computed(() =>
  items.value.some((item) =>
    hasUnsavedResell(item.id, getResellUnitAmount(item)),
  ),
);

const uiItems = computed<DropshipReviewListItem[]>(() =>
  items.value.map((item) => {
    const savedResell = getResellUnitAmount(item);
    const resellPrice = getItemResellPrice(item.id, savedResell);
    return {
      id: item.id,
      name: item.name,
      imageUrl: item.image_url,
      quantity: item.quantity,
      purchasePrice: getPurchaseUnitAmount(item),
      resellPrice,
      minResellPrice: getMinResellAmount(item),
      showSaveResell: hasUnsavedResell(item.id, savedResell),
      isSaving: savingItemId.value === item.id && isUpdatingPrice.value,
    };
  }),
);

const columnTotals = computed(() => {
  const purchaseTotal = items.value.reduce(
    (sum, item) => sum + getPurchaseUnitAmount(item) * item.quantity,
    0,
  );
  const resellTotal = items.value.reduce((sum, item) => {
    const resell = getItemResellPrice(item.id, getResellUnitAmount(item));
    return sum + resell * item.quantity;
  }, 0);
  return { purchaseTotal, resellTotal };
});

const summary = computed(() => ({
  recipientGrandTotal: hasUnsavedEdits.value
    ? columnTotals.value.resellTotal +
      (recipientGrandTotal.value - resellSubtotal.value)
    : recipientGrandTotal.value,
  totalUnits: totalUnits.value,
  hasFloorViolation: hasUnsavedEdits.value
    ? uiItems.value.some((item) => item.resellPrice < item.minResellPrice)
    : hasFloorViolation.value,
}));

const updateResellPriceLocal = (itemId: number, value: number) => {
  const item = items.value.find((row) => row.id === itemId);
  if (!item) return;
  const savedPrice = getResellUnitAmount(item);
  if (value === savedPrice) {
    delete editedResellPrices.value[itemId];
    return;
  }
  editedResellPrices.value[itemId] = value;
};

const saveResellPrice = async (itemId: number) => {
  const targetPrice = editedResellPrices.value[itemId];
  if (targetPrice === undefined || !shopId.value) return;

  savingItemId.value = itemId;
  try {
    await updatePriceMutation.mutateAsync({
      cartItemId: itemId,
      price: targetPrice,
      shopId: shopId.value,
    });
    delete editedResellPrices.value[itemId];
  } finally {
    savingItemId.value = null;
  }
};

const tenantSlugParam = () =>
  route.params.tenantSlug ? String(route.params.tenantSlug) : null;

const goBackToCart = () => {
  void router.push(shopCartPath(tenantSlugParam(), shopId.value));
};

const goToDelivery = () => {
  if (!shopId.value || summary.value.hasFloorViolation || hasUnsavedEdits.value || isUpdatingPrice.value) {
    return;
  }
  void router.push(shopDropshipDeliveryPath(tenantSlugParam(), shopId.value));
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

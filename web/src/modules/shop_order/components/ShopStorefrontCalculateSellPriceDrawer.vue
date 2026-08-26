<template>
  <q-drawer
    v-model="isOpen"
    side="right"
    overlay
    elevated
    :width="520"
    class="shop-storefront-calc-price-drawer bg-white"
  >
    <div class="column full-height">
      <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
        <div class="text-subtitle1 text-weight-bold row items-center min-width-0">
          <q-icon name="ph ph-calculator" class="q-mr-xs text-primary" size="20px" />
          <span class="ellipsis">{{ $t('shop_admin.storefront_calculate_sell_price') }}</span>
        </div>
        <q-btn icon="ph ph-x" flat round dense @click="isOpen = false" />
      </div>

      <q-separator />

      <div v-if="listingId" class="col scroll q-pa-md column q-gutter-y-md relative-position">
        <q-inner-loading :showing="isLoading" color="primary" />

        <div
          v-if="isError"
          class="column items-center justify-center q-pa-lg text-center text-grey-7"
        >
          {{ error?.message || $t('shop_admin.storefront_calc_load_failed') }}
        </div>

        <template v-else-if="calcData">
          <div class="row items-start q-col-gutter-md product-hero">
            <div class="col-auto">
              <q-avatar square size="72px" class="bg-grey-2 rounded-borders">
                <img
                  v-if="calcData.listing.product_image_url"
                  :src="calcData.listing.product_image_url"
                  :alt="calcData.listing.product_name"
                />
                <q-icon v-else name="ph ph-package" color="grey-6" size="28px" />
              </q-avatar>
            </div>
            <div class="col min-width-0">
              <div class="row items-start no-wrap q-gutter-x-sm">
                <div class="col min-width-0">
                  <div class="text-subtitle2 text-weight-bold">{{ calcData.listing.product_name }}</div>
                  <div v-if="calcData.listing.product_code" class="text-caption text-grey-7 q-mt-xs">
                    {{ $t('shop_admin.storefront_product_code') }}: {{ calcData.listing.product_code }}
                  </div>
                </div>
                <q-chip
                  v-if="gradeChipLabel"
                  dense
                  size="sm"
                  class="grade-chip text-weight-bold"
                  text-color="white"
                  :style="gradeChipStyle"
                >
                  {{ gradeChipLabel }}
                </q-chip>
              </div>
            </div>
          </div>

          <div>
            <div class="text-subtitle2 text-weight-bold q-mb-sm">
              {{ $t('shop_admin.storefront_calc_shipment_costs') }}
            </div>
            <q-markup-table flat bordered dense class="rounded-borders">
              <thead>
                <tr>
                  <th class="text-left">{{ $t('shop_admin.storefront_calc_shipment_no') }}</th>
                  <th class="text-left">{{ $t('shop_admin.storefront_calc_shipment_name') }}</th>
                  <th class="text-right">{{ $t('shop_admin.storefront_calc_quantity') }}</th>
                  <th class="text-right">{{ $t('shop_admin.storefront_calc_unit_cost') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="shipmentRows.length === 0">
                  <td colspan="4" class="text-center text-grey-6 q-pa-md">
                    {{ $t('shop_admin.storefront_calc_no_shipments') }}
                  </td>
                </tr>
                <tr v-for="row in shipmentRows" :key="row.shipment_id">
                  <td class="text-weight-medium">{{ row.shipment_no }}</td>
                  <td>{{ row.shipment_name }}</td>
                  <td class="text-right">{{ row.quantity }}</td>
                  <td class="text-right text-weight-medium">{{ formatMoney(row.unit_cost_amount) }}</td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="bg-grey-2">
                  <td colspan="2" class="text-weight-bold">
                    {{ $t('shop_admin.storefront_calc_total_quantity') }}
                  </td>
                  <td class="text-right text-weight-bold">{{ totalQuantity }}</td>
                  <td />
                </tr>
              </tfoot>
            </q-markup-table>
          </div>

          <q-input
            v-model.number="displayQuantity"
            type="number"
            min="0"
            step="1"
            outlined
            dense
            :label="$t('shop_admin.col_display_qty')"
            :hint="$t('shop_admin.storefront_calc_display_qty_hint')"
          >
            <template #prepend>
              <q-icon name="ph ph-stack" />
            </template>
          </q-input>

          <q-banner dense rounded class="bg-blue-1 text-blue-10">
            <div class="row items-center justify-between">
              <span class="text-weight-medium">{{ $t('shop_admin.storefront_avg_cost') }}</span>
              <span class="text-subtitle2 text-weight-bold">{{ formatMoney(weightedAvgCost) }}</span>
            </div>
          </q-banner>

          <div class="column q-gutter-y-md">
            <q-input
              v-model.number="sellPrice"
              type="number"
              step="0.01"
              outlined
              dense
              :label="$t('shop_admin.storefront_calc_sell_price')"
            >
              <template #prepend>
                <q-icon name="ph ph-tag" />
              </template>
              <template v-if="suggestedSellPrice != null" #hint>
                {{ $t('shop_admin.storefront_calc_suggested_sell_price') }}:
                {{ formatMoney(suggestedSellPrice) }}
              </template>
            </q-input>

            <q-input
              v-if="showMinResellPrice"
              v-model.number="minResellPrice"
              type="number"
              step="0.01"
              outlined
              dense
              :label="$t('shop_admin.col_min_sell_price')"
            >
              <template #prepend>
                <q-icon name="ph ph-currency-circle-dollar" />
              </template>
            </q-input>
          </div>
        </template>
      </div>

      <q-separator />

      <div class="q-pa-md bg-grey-1 row items-center justify-end q-gutter-sm">
        <q-btn
          flat
          no-caps
          color="grey-8"
          :label="$t('shop_admin.cancel')"
          @click="isOpen = false"
        />
        <q-btn
          color="primary"
          unelevated
          no-caps
          :label="$t('shop_admin.save')"
          :loading="isSaving"
          :disable="!calcData || isLoading"
          @click="onSave"
        />
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ShopType } from '../types';
import { useShopStorefrontListingPriceCalcQuery } from '../composables/useShopStorefrontListingPriceCalcQuery';
import { useSaveShopStorefrontListingPricingMutation } from '../composables/useShopStorefrontAdminMutations';

const props = defineProps<{
  modelValue: boolean;
  shopId: number | null;
  tenantId: number | null;
  listingId: number | null;
  shopType?: ShopType | null;
}>();

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void;
  (event: 'saved'): void;
}>();

const sellPrice = ref<number | null>(null);
const minResellPrice = ref<number | null>(null);
const displayQuantity = ref<number | null>(null);

const isOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const shopIdRef = computed(() => props.shopId);
const listingIdRef = computed(() => props.listingId);
const queryEnabled = computed(() => isOpen.value && !!props.listingId);

const { data: calcData, isLoading, isError, error } = useShopStorefrontListingPriceCalcQuery(
  shopIdRef,
  listingIdRef,
  queryEnabled,
);

const { mutate: savePricing, isPending: isSaving } = useSaveShopStorefrontListingPricingMutation();

const showMinResellPrice = computed(() => props.shopType === 'dropship');

const shipmentRows = computed(() => calcData.value?.shipment_costs ?? []);

const totalQuantity = computed(() => calcData.value?.totals.total_quantity ?? 0);

const weightedAvgCost = computed(() => calcData.value?.totals.weighted_avg_cost?.amount ?? 0);

const suggestedSellPrice = computed(
  () => calcData.value?.pricing.suggested_sell_price?.amount ?? null,
);

const currencySymbol = computed(
  () =>
    calcData.value?.pricing.sell_price?.symbol ??
    calcData.value?.totals.weighted_avg_cost?.symbol ??
    '৳',
);

const gradeChipLabel = computed(() => calcData.value?.listing.stock_grade?.label ?? null);

const gradeChipStyle = computed(() => {
  const color = calcData.value?.listing.stock_grade?.color?.trim();
  if (!color) return undefined;
  return { backgroundColor: color };
});

const formatMoney = (amount: number | null | undefined) => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '—';
  const sym = currencySymbol.value?.trim() || '৳';
  const formatted = n.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${sym} ${formatted}`;
};

const applyPricingForm = () => {
  if (!calcData.value) return;
  const pricing = calcData.value.pricing;
  sellPrice.value = pricing.sell_price?.amount ?? suggestedSellPrice.value ?? null;
  minResellPrice.value = pricing.resell_minimum_price?.amount ?? null;
  displayQuantity.value =
    pricing.display_quantity_override ?? pricing.suggested_display_quantity ?? null;
};

watch(calcData, (data) => {
  if (data) {
    applyPricingForm();
  }
});

watch(isOpen, (open) => {
  if (!open) {
    sellPrice.value = null;
    minResellPrice.value = null;
    displayQuantity.value = null;
  }
});

const onSave = () => {
  if (!calcData.value || !props.shopId || !props.tenantId) return;

  const listing = calcData.value.listing;
  const sellAmount = Number(sellPrice.value);
  const sellCurrencyId = calcData.value.pricing.sell_price?.currency_id;
  if (!Number.isFinite(sellAmount) || !sellCurrencyId) return;

  const minAmount =
    minResellPrice.value !== null && minResellPrice.value !== undefined
      ? Number(minResellPrice.value)
      : null;
  const minCurrencyId =
    minAmount !== null
      ? (calcData.value.pricing.resell_minimum_price?.currency_id ?? sellCurrencyId)
      : null;

  savePricing(
    {
      id: listing.listing_id,
      tenant_id: props.tenantId,
      shop_id: props.shopId,
      global_stock_id: listing.global_stock_id,
      sell_price_amount: sellAmount,
      sell_price_currency_id: sellCurrencyId,
      minimum_sell_price_amount: minAmount,
      minimum_sell_price_currency_id: minCurrencyId,
      show_quantity: true,
      display_quantity_override: displayQuantity.value ?? null,
      is_active: listing.is_active,
      is_price_locked: true,
    },
    {
      onSuccess: () => {
        isOpen.value = false;
        emit('saved');
      },
    },
  );
};
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.product-hero {
  padding: 12px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 12px;
  background: rgba(248, 250, 252, 0.8);
}

.grade-chip {
  flex-shrink: 0;
  font-size: 11px;
  min-height: 22px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.18);
}
</style>

<template>
  <q-dialog
    v-model="isOpen"
    position="right"
    maximized-on-small-screen
    class="shop-storefront-calc-price-dialog"
  >
    <q-card class="calc-price-panel column no-wrap bg-white">
      <q-card-section class="row items-center justify-between q-py-md bg-grey-1 border-bottom">
        <div class="text-subtitle1 text-weight-bold row items-center min-width-0">
          <q-icon name="ph ph-calculator" class="q-mr-xs text-primary" size="20px" />
          <span class="ellipsis">{{ $t('shop_admin.storefront_calculate_sell_price') }}</span>
        </div>
        <q-btn icon="ph ph-x" flat round dense @click="isOpen = false" />
      </q-card-section>

      <q-separator />

      <q-card-section
        v-if="productGroup || listingId"
        class="col scroll q-pa-md relative-position calc-price-body"
      >
        <q-inner-loading :showing="isLoading && hasListedGrade" color="primary" />

        <div
          v-if="isError && hasListedGrade"
          class="column items-center justify-center q-pa-lg text-center text-grey-7"
        >
          {{ error?.message || $t('shop_admin.storefront_calc_load_failed') }}
        </div>

        <div v-else class="calc-drawer-stack">
          <div class="row items-start q-col-gutter-md product-hero">
            <div class="col-auto">
              <q-avatar square size="72px" class="bg-grey-2 rounded-borders">
                <img
                  v-if="productHeroImage"
                  :src="productHeroImage"
                  :alt="productHeroName"
                />
                <q-icon v-else name="ph ph-package" color="grey-6" size="28px" />
              </q-avatar>
            </div>
            <div class="col min-width-0">
              <div class="text-subtitle2 text-weight-bold">{{ productHeroName }}</div>
              <div v-if="productHeroCode" class="text-caption text-grey-7 q-mt-xs">
                {{ $t('shop_admin.storefront_product_code') }}: {{ productHeroCode }}
              </div>
              <StorefrontGradeToggleRow
                v-if="productGroup"
                v-model="selectedGradeSlug"
                class="q-mt-sm"
                :listings-by-grade="productGroup.listingsByGrade"
              />
            </div>
          </div>

          <div v-if="!hasListedGrade" class="grade-empty">
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
              :loading="isEnsuringGrade"
              :label="$t('shop_admin.storefront_setup_grade')"
              @click="setupSelectedGrade"
            />
          </div>

          <template v-else-if="calcData">
            <section class="calc-section">
              <div class="text-subtitle2 text-weight-bold q-mb-sm">
                {{ $t('shop_admin.storefront_calc_shipment_costs') }}
              </div>
              <div class="shipment-table-wrap">
              <q-markup-table flat bordered dense class="rounded-borders shipment-cost-table">
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
                    <td class="text-weight-medium cell-ellipsis">{{ row.shipment_no }}</td>
                    <td class="cell-ellipsis" :title="row.shipment_name">{{ row.shipment_name }}</td>
                    <td class="text-right">{{ row.quantity }}</td>
                    <td class="text-right text-weight-medium cell-nowrap">
                      {{ formatMoney(row.unit_cost_amount) }}
                    </td>
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
          </section>

          <section class="calc-section">
            <q-input
              v-model.number="displayQuantity"
              type="number"
              min="0"
              step="1"
              outlined
              dense
              class="full-width-field"
              :label="$t('shop_admin.col_display_qty')"
              :hint="$t('shop_admin.storefront_calc_display_qty_hint')"
            >
              <template #prepend>
                <q-icon name="ph ph-stack" />
              </template>
            </q-input>
          </section>

          <section class="calc-section">
            <q-banner dense rounded class="bg-blue-1 text-blue-10">
              <div class="row items-center justify-between no-wrap">
                <span class="text-weight-medium">{{ $t('shop_admin.storefront_avg_cost') }}</span>
                <span class="text-subtitle2 text-weight-bold">{{ formatMoney(weightedAvgCost) }}</span>
              </div>
            </q-banner>
          </section>

          <section class="calc-section">
            <div class="text-caption text-weight-medium text-grey-8 q-mb-sm">
              {{ $t('shop_admin.storefront_calc_sell_price') }}
            </div>
            <div class="column q-gutter-y-sm">
              <q-input
                :model-value="sellPrice"
                type="number"
                step="0.01"
                outlined
                dense
                class="full-width-field"
                :label="$t('shop_admin.sell_price_amount')"
                @update:model-value="updateSellPrice"
                @blur="roundSellPriceField"
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
                :model-value="sellMarkupPctOnCost"
                type="number"
                step="0.1"
                outlined
                dense
                suffix="%"
                class="full-width-field"
                :label="$t('shop_admin.storefront_calc_sell_markup_on_cost')"
                :disable="!hasUnitCost"
                :hint="!hasUnitCost ? $t('shop_admin.storefront_calc_markup_disabled_hint') : undefined"
                @update:model-value="updateSellMarkupPct"
              >
                <template #prepend>
                  <q-icon name="ph ph-percent" />
                </template>
              </q-input>
            </div>
          </section>

          <section v-if="showMinResellPrice" class="calc-section">
            <div class="text-caption text-weight-medium text-grey-8 q-mb-sm">
              {{ $t('shop_admin.col_min_sell_price') }}
            </div>
            <div class="column q-gutter-y-sm">
              <q-input
                :model-value="resellPrice"
                type="number"
                step="0.01"
                outlined
                dense
                class="full-width-field"
                :label="$t('shop_admin.min_dropship_price')"
                @update:model-value="updateResellPrice"
                @blur="roundResellPriceField"
              >
                <template #prepend>
                  <q-icon name="ph ph-currency-circle-dollar" />
                </template>
              </q-input>
              <q-input
                :model-value="resellMarkupPctOnCost"
                type="number"
                step="0.1"
                outlined
                dense
                suffix="%"
                class="full-width-field"
                :label="$t('shop_admin.storefront_calc_resell_markup_on_cost')"
                :disable="!hasUnitCost"
                @update:model-value="updateResellMarkupPctOnCost"
              />
              <q-input
                :model-value="resellMarkupPctOnSell"
                type="number"
                step="0.1"
                outlined
                dense
                suffix="%"
                class="full-width-field"
                :label="$t('shop_admin.storefront_calc_resell_markup_on_sell')"
                :disable="!hasSellPrice"
                @update:model-value="updateResellMarkupPctOnSell"
              />
            </div>
          </section>
          </template>
        </div>
      </q-card-section>

      <q-separator />

      <q-card-actions align="right" class="q-pa-md bg-grey-1 q-gutter-sm">
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
          :disable="!calcData || isLoading || !hasListedGrade"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ShopType } from '../types';
import StorefrontGradeToggleRow from './StorefrontGradeToggleRow.vue';
import { normalizeStorefrontGradeSlug } from '../constants/storefrontWarehouseGrades';
import { useShopStorefrontListingPriceCalcQuery } from '../composables/useShopStorefrontListingPriceCalcQuery';
import {
  useEnsureShopStorefrontGradeListingMutation,
  useSaveShopStorefrontListingPricingMutation,
} from '../composables/useShopStorefrontAdminMutations';
import { useLinkedListingPriceFields } from '../composables/useLinkedListingPriceFields';
import { roundUpToNearest50or100 } from '../utils/shopPricingRound';
import {
  findSiblingListingForPricing,
  pickDefaultGradeSlug,
  type StorefrontProductGroup,
} from '../utils/storefrontProductGroups';

const props = defineProps<{
  modelValue: boolean;
  shopId: number | null;
  tenantId: number | null;
  listingId: number | null;
  productGroup: StorefrontProductGroup | null;
  sellCurrencyId: number | null;
  shopType?: ShopType | null;
}>();

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void;
  (event: 'saved'): void;
  (event: 'grade-setup'): void;
}>();

const displayQuantity = ref<number | null>(null);
const selectedGradeSlug = ref('standard');
const activeListingId = ref<number | null>(null);
const isEnsuringGrade = ref(false);

const isOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const shopIdRef = computed(() => props.shopId);
const listingIdRef = computed(() => activeListingId.value);
const queryEnabled = computed(() => isOpen.value && !!activeListingId.value);

const selectedListing = computed(() => {
  if (!props.productGroup) return null;
  return (
    props.productGroup.listingsByGrade[normalizeStorefrontGradeSlug(selectedGradeSlug.value)] ??
    null
  );
});

const hasListedGrade = computed(() => selectedListing.value != null);

const { data: calcData, isLoading, isError, error } = useShopStorefrontListingPriceCalcQuery(
  shopIdRef,
  listingIdRef,
  queryEnabled,
);

const { mutate: savePricing, isPending: isSaving } = useSaveShopStorefrontListingPricingMutation();
const { mutate: ensureGradeMutation } = useEnsureShopStorefrontGradeListingMutation();

const syncDrawerStateFromProps = () => {
  activeListingId.value = props.listingId;
  if (!props.productGroup) {
    selectedGradeSlug.value = 'standard';
    return;
  }

  let matchedSlug = pickDefaultGradeSlug(props.productGroup);
  for (const [slug, listing] of Object.entries(props.productGroup.listingsByGrade)) {
    if (listing?.listing_id === props.listingId) {
      matchedSlug = slug;
      break;
    }
  }
  selectedGradeSlug.value = matchedSlug;
};

watch(
  () => [isOpen.value, props.listingId, props.productGroup?.product_id] as const,
  ([open]) => {
    if (open) {
      syncDrawerStateFromProps();
    }
  },
);

watch(selectedGradeSlug, (slug) => {
  if (!props.productGroup) return;
  const listing =
    props.productGroup.listingsByGrade[normalizeStorefrontGradeSlug(slug)] ?? null;
  activeListingId.value = listing?.listing_id ?? null;
});

watch(
  () => props.productGroup?.listingsByGrade,
  (byGrade) => {
    if (!byGrade || !isOpen.value) return;
    const listing = byGrade[normalizeStorefrontGradeSlug(selectedGradeSlug.value)];
    if (listing?.listing_id) {
      activeListingId.value = listing.listing_id;
    }
  },
  { deep: true },
);

const productHeroName = computed(
  () => calcData.value?.listing.product_name ?? props.productGroup?.product_name ?? '—',
);

const productHeroImage = computed(
  () => calcData.value?.listing.product_image_url ?? props.productGroup?.product_image_url ?? null,
);

const productHeroCode = computed(() => calcData.value?.listing.product_code ?? null);

const setupSelectedGrade = () => {
  if (!props.productGroup || !props.shopId || !props.tenantId || !props.sellCurrencyId) return;

  isEnsuringGrade.value = true;
  ensureGradeMutation(
    {
      shopId: props.shopId,
      tenantId: props.tenantId,
      productId: props.productGroup.product_id,
      gradeSlug: selectedGradeSlug.value,
      sourceListing: findSiblingListingForPricing(props.productGroup),
      sellCurrencyId: props.sellCurrencyId,
    },
    {
      onSettled: () => {
        isEnsuringGrade.value = false;
      },
      onSuccess: (listing) => {
        emit('grade-setup');
        if (listing?.id) {
          activeListingId.value = listing.id;
        }
      },
    },
  );
};

const showMinResellPrice = computed(() => props.shopType === 'dropship');

const shipmentRows = computed(() => calcData.value?.shipment_costs ?? []);

const totalQuantity = computed(() => calcData.value?.totals.total_quantity ?? 0);

const weightedAvgCost = computed(() => calcData.value?.totals.weighted_avg_cost?.amount ?? 0);

const {
  sellPrice,
  sellMarkupPctOnCost,
  resellPrice,
  resellMarkupPctOnCost,
  resellMarkupPctOnSell,
  initialize: initializePricingFields,
  updateSellPrice,
  updateSellMarkupPct,
  updateResellPrice,
  updateResellMarkupPctOnCost,
  updateResellMarkupPctOnSell,
  roundSellPriceField,
  roundResellPriceField,
} = useLinkedListingPriceFields(weightedAvgCost);

const hasUnitCost = computed(() => weightedAvgCost.value > 0);
const hasSellPrice = computed(() => {
  const sell = Number(sellPrice.value);
  return Number.isFinite(sell) && sell > 0;
});

const suggestedSellPrice = computed(
  () => calcData.value?.pricing.suggested_sell_price?.amount ?? null,
);

const currencySymbol = computed(
  () =>
    calcData.value?.pricing.sell_price?.symbol ??
    calcData.value?.totals.weighted_avg_cost?.symbol ??
    '৳',
);

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
  initializePricingFields(
    pricing.sell_price?.amount ?? suggestedSellPrice.value ?? null,
    pricing.resell_minimum_price?.amount ?? null,
  );
  displayQuantity.value =
    pricing.display_quantity_override ?? pricing.suggested_display_quantity ?? null;
};

watch(activeListingId, () => {
  initializePricingFields(null, null);
  displayQuantity.value = null;
});

watch(calcData, (data) => {
  if (data) {
    applyPricingForm();
  }
});

watch(isOpen, (open) => {
  if (!open) {
    initializePricingFields(null, null);
    displayQuantity.value = null;
  }
});

const onSave = () => {
  if (!calcData.value || !props.shopId || !props.tenantId) return;

  const listing = calcData.value.listing;
  const sellAmount = roundUpToNearest50or100(Number(sellPrice.value));
  const sellCurrencyId = calcData.value.pricing.sell_price?.currency_id;
  if (!Number.isFinite(sellAmount) || sellAmount <= 0 || !sellCurrencyId) return;

  const minAmount =
    resellPrice.value !== null && resellPrice.value !== undefined
      ? roundUpToNearest50or100(Number(resellPrice.value))
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
      global_stock_id: listing.global_stock_id ?? null,
      product_id: listing.global_stock_id == null ? listing.product_id : undefined,
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
.calc-price-panel {
  width: min(640px, 100vw);
  max-width: 100vw;
  height: 100vh;
  border-radius: 0;
}

.calc-price-body {
  min-width: 0;
  overflow-x: hidden;
}

.calc-drawer-stack {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 16px;
  width: 100%;
  max-width: 100%;
}

.calc-section {
  width: 100%;
  max-width: 100%;
  min-width: 0;
}

.full-width-field {
  width: 100%;
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.product-hero {
  padding: 12px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 12px;
  background: rgba(248, 250, 252, 0.8);
}

.grade-empty {
  padding: 16px;
  border: 1px dashed rgba(0, 0, 0, 0.12);
  border-radius: 12px;
  text-align: center;
}

.min-width-0 {
  min-width: 0;
}

.shipment-table-wrap {
  width: 100%;
  max-width: 100%;
  overflow-x: auto;
}

.shipment-cost-table {
  table-layout: fixed;
  width: 100%;
  min-width: 0;
}

.shipment-cost-table th,
.shipment-cost-table td {
  overflow: hidden;
  text-overflow: ellipsis;
}

.shipment-cost-table th:nth-child(1),
.shipment-cost-table td:nth-child(1) {
  width: 22%;
}

.shipment-cost-table th:nth-child(2),
.shipment-cost-table td:nth-child(2) {
  width: 38%;
}

.shipment-cost-table th:nth-child(3),
.shipment-cost-table td:nth-child(3) {
  width: 14%;
}

.shipment-cost-table th:nth-child(4),
.shipment-cost-table td:nth-child(4) {
  width: 26%;
}

.cell-nowrap {
  white-space: nowrap;
}
</style>

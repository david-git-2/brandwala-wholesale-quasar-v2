<template>
  <q-dialog :model-value="modelValue" @update:model-value="(val) => $emit('update:modelValue', val)">
    <q-card style="width: 520px; max-width: 95vw" class="rounded-borders shadow-4">
      <!-- Header -->
      <q-card-section class="row items-center justify-between bg-primary text-white q-py-sm">
        <div class="row items-center q-gutter-x-sm">
          <q-icon name="ph ph-pencil-simple" size="22px" />
          <div class="text-subtitle1 text-weight-bold">Edit Item Costing & Prices</div>
        </div>
        <q-btn icon="ph ph-x" flat round dense v-close-popup color="white" />
      </q-card-section>

      <!-- Item Preview Section -->
      <q-card-section v-if="form" class="bg-grey-1 border-bottom q-pa-md">
        <div class="row q-col-gutter-md items-center">
          <div class="col-auto">
            <div class="inch-image-wrapper">
              <SmartImage
                :src="form.image_url"
                :alt="form.name"
                img-class="inch-image"
                fallback-class="inch-image-placeholder"
              />
            </div>
          </div>
          <div class="col">
            <div class="text-subtitle2 text-weight-bold text-grey-9 line-clamp-2">{{ form.name }}</div>
            <div class="row items-center q-gutter-x-xs text-caption text-grey-7 q-mt-xs">
              <q-badge outline color="blue-grey-8" class="font-mono">{{ form.brand || 'No Brand' }}</q-badge>
              <span v-if="form.sku" class="font-mono">SKU: {{ form.sku }}</span>
              <span v-if="form.barcode" class="font-mono">Barcode: {{ form.barcode }}</span>
            </div>
          </div>
        </div>
      </q-card-section>

      <!-- Edit Form Fields -->
      <q-card-section v-if="form" class="q-pa-md">
        <div class="q-gutter-y-md">
          <!-- Quantities Row -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-input
                :model-value="form.quantity"
                label="Customer Qty"
                dense
                outlined
                readonly
                class="bg-grey-2"
              />
            </div>
            <div class="col-12 col-sm-4">
              <q-input
                v-model.number="form.ordered_quantity"
                label="Ordered Qty"
                dense
                outlined
                type="number"
                min="0"
                :readonly="!isOrderedQtyEditable"
                :class="{ 'bg-grey-2': !isOrderedQtyEditable }"
              />
            </div>
            <div class="col-12 col-sm-4">
              <q-input
                v-model.number="form.delivered_quantity"
                label="Delivered Qty"
                dense
                outlined
                type="number"
                min="0"
                :readonly="!isDeliveredQtyEditable"
                :class="{ 'bg-grey-2': !isDeliveredQtyEditable }"
              />
            </div>
          </div>

          <!-- Weight & Cargo Row -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-input
                v-model.number="form.product_weight_gm"
                label="Product Weight (gm)"
                dense
                outlined
                type="number"
                step="1"
                min="0"
                :readonly="isFulfillmentQtyOnly"
                :class="{ 'bg-grey-2': isFulfillmentQtyOnly }"
                @update:model-value="recalculateOffer"
              >
                <template #append>
                  <span class="text-caption">g</span>
                </template>
              </q-input>
            </div>
            <div class="col-12 col-sm-4">
              <q-input
                v-model.number="form.package_weight_gm"
                label="Package Weight (gm)"
                dense
                outlined
                type="number"
                step="1"
                min="0"
                :readonly="isFulfillmentQtyOnly"
                :class="{ 'bg-grey-2': isFulfillmentQtyOnly }"
                @update:model-value="recalculateOffer"
              >
                <template #append>
                  <span class="text-caption">g</span>
                </template>
              </q-input>
            </div>
            <div class="col-12 col-sm-4">
              <q-input
                :model-value="calculatedTotalWeightGm"
                label="Total Weight (gm)"
                dense
                outlined
                readonly
                class="bg-grey-2 font-mono text-weight-bold"
              >
                <template #append>
                  <span class="text-caption">g</span>
                </template>
              </q-input>
            </div>
          </div>

          <!-- Purchase Cost Price -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.cost_price_amount"
                :label="`Cost Price (${buyCurrencySymbol || 'Purchase Currency'})`"
                dense
                outlined
                type="number"
                step="0.01"
                min="0"
                class="text-weight-bold"
                :readonly="isFirstOfferLocked || isFulfillmentQtyOnly"
                :class="{ 'bg-grey-2': isFirstOfferLocked || isFulfillmentQtyOnly }"
                @update:model-value="recalculateOffer"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="calculatedLandedCostSell"
                :label="`Landed Cost (${currencySymbol || 'Selling Currency'})`"
                dense
                outlined
                readonly
                class="bg-grey-2 font-mono text-weight-bold text-teal-9"
              />
            </div>
          </div>

          <!-- Staff First Offer & Margin -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-7">
              <q-input
                v-model.number="form.staff_offer_amount"
                :label="`1st Offer Unit Price (${currencySymbol || 'Selling Currency'})`"
                dense
                outlined
                type="number"
                step="1"
                min="0"
                class="text-weight-bold text-deep-purple-9"
                :readonly="isFirstOfferLocked || isFulfillmentQtyOnly"
                :class="{ 'bg-grey-2': isFirstOfferLocked || isFulfillmentQtyOnly }"
              />
            </div>
            <div class="col-12 col-sm-5">
              <div class="column justify-center fill-height bg-purple-1 q-px-sm q-py-xs rounded-borders border-purple">
                <div class="text-caption text-grey-8">Profit Margin</div>
                <div class="text-subtitle2 font-mono text-weight-bold" :class="marginColorClass">
                  {{ calculatedFirstOfferMargin.toFixed(1) }}%
                </div>
              </div>
            </div>
          </div>

          <!-- Customer Counter & Final Offer -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="form.customer_offer_amount != null ? form.customer_offer_amount : '—'"
                label="Customer Counter Offer"
                dense
                outlined
                readonly
                class="bg-grey-2 text-orange-9 font-mono"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.final_price_amount"
                :label="`Final Agreed Offer Unit (${currencySymbol || 'Selling Currency'})`"
                dense
                outlined
                type="number"
                step="1"
                min="0"
                class="text-weight-bold text-green-10"
                :readonly="!isFinalOfferEditable || isFulfillmentQtyOnly"
                :class="{ 'bg-grey-2': !isFinalOfferEditable || isFulfillmentQtyOnly }"
              />
            </div>
          </div>
        </div>
      </q-card-section>

      <!-- Footer Actions -->
      <q-card-actions align="right" class="q-pa-md bg-grey-1 border-top">
        <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          icon="ph ph-check"
          label="Save Changes"
          no-caps
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import SmartImage from 'src/components/SmartImage.vue';
import type { ShopOrder, ShopOrderItem } from '../types';
import { isCatalogFirstOfferLocked, isCatalogFinalOfferEditable, isCatalogOrderedQtyEditable, isCatalogDeliveredQtyEditable } from '../utils/catalogOrderStatus';

const props = defineProps<{
  modelValue: boolean;
  item: ShopOrderItem | null;
  order: ShopOrder | null;
  currencySymbol?: string | undefined;
  buyCurrencySymbol?: string | undefined;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'save-item', updatedItem: ShopOrderItem): void;
}>();

const form = ref<ShopOrderItem | null>(null);

const FX = computed(() => props.order?.conversion_rate ?? 140);
const cargoRate = computed(() => props.order?.cargo_rate ?? 0);
const profitRate = computed(() => props.order?.profit_rate ?? 25);
const profitBasis = computed(() => props.order?.profit_basis || 'total_cost');
const isFirstOfferLocked = computed(() => isCatalogFirstOfferLocked(props.order?.status));
const isFinalOfferEditable = computed(() => isCatalogFinalOfferEditable(props.order?.status));
const isOrderedQtyEditable = computed(() => isCatalogOrderedQtyEditable(props.order?.status));
const isDeliveredQtyEditable = computed(() => isCatalogDeliveredQtyEditable(props.order?.status));
const isFulfillmentQtyOnly = computed(() => isOrderedQtyEditable.value || isDeliveredQtyEditable.value);

watch(
  () => props.item,
  (newItem) => {
    if (newItem) {
      const cloned = JSON.parse(JSON.stringify(newItem));
      if (cloned.final_price_amount == null) {
        cloned.final_price_amount = getFinalOfferUnitAmount(
          cloned,
          {
            conversion_rate: FX.value,
            cargo_rate: cargoRate.value,
            first_offer_rate: profitRate.value,
            profit_basis: profitBasis.value,
          },
          props.order?.package_weight_kg,
        );
      }
      form.value = cloned;
    } else {
      form.value = null;
    }
  },
  { immediate: true },
);

const calculatedTotalWeightGm = computed(() => {
  if (!form.value) return 0;
  const prod = form.value.product_weight_gm ?? (form.value.weight_kg ? form.value.weight_kg * 1000 : 0);
  const pkg = form.value.package_weight_gm ?? (props.order?.package_weight_kg ? props.order.package_weight_kg * 1000 : 0);
  return Math.round(prod + pkg);
});

const calculatedLandedCostSell = computed(() => {
  if (!form.value) return '0.00';
  const purchasePrice = Number(form.value.cost_price_amount || 0);
  const weightKg = calculatedTotalWeightGm.value / 1000;
  const cargoCostPurchase = weightKg * cargoRate.value;
  const totalPurchaseLanded = purchasePrice + cargoCostPurchase;
  const sellLanded = totalPurchaseLanded * FX.value;
  return sellLanded.toFixed(2);
});

const calculatedFirstOfferMargin = computed(() => {
  if (!form.value) return 0;
  const offer = Number(form.value.staff_offer_amount || 0);
  const cost = Number(calculatedLandedCostSell.value);
  if (cost <= 0) return 0;
  return ((offer - cost) / cost) * 100;
});

const marginColorClass = computed(() => {
  const m = calculatedFirstOfferMargin.value;
  if (m >= 20) return 'text-positive';
  if (m >= 10) return 'text-warning';
  return 'text-negative';
});

function recalculateOffer() {
  if (!form.value || isFirstOfferLocked.value) return;
  const purchasePrice = Number(form.value.cost_price_amount || 0);
  const weightKg = calculatedTotalWeightGm.value / 1000;
  const cargoCostBuy = weightKg * cargoRate.value;
  const fx = FX.value;
  const pRate = profitRate.value || 0;
  const pBasis = profitBasis.value || 'total_cost';
  const markup = pRate / 100;

  if (pBasis === 'purchase') {
    const purchaseCostSell = purchasePrice * fx;
    const cargoCostSell = cargoCostBuy * fx;
    const rawPrice = purchaseCostSell * (1 + markup) + cargoCostSell;
    form.value.staff_offer_amount = rawPrice > 0 ? Math.ceil(rawPrice / 5) * 5 : 0;
  } else {
    const landedCostSell = (purchasePrice + cargoCostBuy) * fx;
    const rawPrice = landedCostSell * (1 + markup);
    form.value.staff_offer_amount = rawPrice > 0 ? Math.ceil(rawPrice / 5) * 5 : 0;
  }
}

function onSave() {
  if (form.value) {
    form.value.weight_kg = calculatedTotalWeightGm.value / 1000;
    emit('save-item', form.value);
    emit('update:modelValue', false);
  }
}
</script>

<style scoped>
.inch-image-wrapper {
  width: 72px;
  height: 72px;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background: #ffffff;
}

.inch-image {
  width: 72px;
  height: 72px;
  object-fit: contain;
}

.inch-image-placeholder {
  width: 72px;
  height: 72px;
  background: #f1f5f9;
  color: #94a3b8;
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>

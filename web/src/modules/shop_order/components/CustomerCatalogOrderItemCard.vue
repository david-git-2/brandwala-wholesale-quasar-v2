<template>
  <q-card
    flat
    bordered
    class="item-card q-mb-md"
    :class="[`item-card--${decisionTone}`]"
  >
    <q-card-section class="q-pa-md item-card__section column q-gutter-y-md">
      <div class="row items-start q-gutter-x-md">
        <div class="item-thumb col-auto">
          <q-img
            v-if="item.image_url"
            :src="item.image_url"
            fit="cover"
            class="item-thumb__img"
            spinner-color="primary"
          />
          <div v-else class="item-thumb__placeholder column flex-center">
            <q-icon name="ph ph-image" size="32px" color="grey-5" />
          </div>
        </div>

        <div class="col item-card__header">
          <div class="text-subtitle1 text-weight-bold text-grey-9 leading-snug item-card__title">
            {{ item.name }}
          </div>

          <div class="row items-center q-gutter-x-sm q-mt-xs">
            <q-chip dense color="grey-2" text-color="grey-8" class="q-ma-none text-caption text-weight-medium">
              Qty: <span class="text-weight-bolder q-ml-xs">{{ item.quantity }}</span>
            </q-chip>

            <q-chip
              v-if="item.unit_list_price_amount"
              dense
              outline
              color="grey-6"
              class="q-ma-none text-caption"
            >
              List: {{ buyCurrencySymbol }}{{ Number(item.unit_list_price_amount).toFixed(2) }}
            </q-chip>
          </div>
        </div>
      </div>

      <!-- Pricing Summary (table-style colored cells) -->
      <div v-if="status === 'priced' || status === 'countered' || status === 'final_offered' || isConfirmedOrBeyond" class="price-cells-row row no-wrap q-col-gutter-xs item-card__full-width">
        <div class="col price-cell price-cell--first-offer">
          <span class="price-cell__label">1st Offer / Unit</span>
          <span class="price-cell__value">{{ currencySymbol }}{{ staffOfferAmount.toFixed(2) }}</span>
        </div>

        <div v-if="hasCustomerCounter" class="col price-cell price-cell--counter">
          <span class="price-cell__label">Your Counter</span>
          <span class="price-cell__value">{{ currencySymbol }}{{ Number(item.customer_offer_amount).toFixed(2) }}</span>
        </div>

        <div v-if="status === 'final_offered' || isConfirmedOrBeyond" class="col price-cell price-cell--final">
          <span class="price-cell__label">Final Offer</span>
          <span class="price-cell__value">{{ currencySymbol }}{{ Number(item.final_offer_amount || item.staff_offer_amount || 0).toFixed(2) }}</span>
        </div>
      </div>

      <!-- Decision Buttons Box for 'priced' state -->
      <div v-if="status === 'priced' && isNegotiable" class="decision-box q-pa-sm bg-blue-1-soft rounded-borders item-card__full-width">
        <div class="row items-center justify-between q-mb-xs">
          <span class="text-caption text-weight-bold text-grey-8">Decision for this item:</span>
          <q-badge v-if="!hasCustomerCounter" color="grey-7" dense class="text-caption text-weight-bold">
            Pending
          </q-badge>
          <q-badge v-else-if="isOfferAccepted" color="green-7" dense class="text-caption text-weight-bold">
            Accepted
          </q-badge>
          <q-badge v-else color="amber-9" dense class="text-caption text-weight-bold">
            Countered
          </q-badge>
        </div>

        <!-- Action Buttons when not inline editing -->
        <div v-if="!isEditingCounter" class="decision-actions column q-gutter-y-sm">
          <!-- Shown when customer_offer_amount is null/0 -->
          <template v-if="!hasCustomerCounter">
            <q-btn
              unelevated
              color="positive"
              text-color="white"
              no-caps
              class="full-width text-caption text-weight-bold decision-btn border-grey shadow-1"
              @click="selectAcceptOffer"
            >
              <q-icon name="ph ph-check-circle" size="16px" class="q-mr-xs" />
              Accept 1st Offer
            </q-btn>

            <q-btn
              unelevated
              color="white"
              text-color="grey-8"
              no-caps
              class="full-width text-caption text-weight-bold decision-btn border-grey"
              @click="enableCounterEditing"
            >
              <q-icon name="ph ph-pencil-simple" size="16px" class="q-mr-xs" />
              Counter Offer
            </q-btn>
          </template>

          <!-- Shown when customer_offer_amount is already set -->
          <template v-else>
            <q-btn
              unelevated
              color="amber-9"
              text-color="white"
              no-caps
              class="full-width text-caption text-weight-bold decision-btn border-grey shadow-1"
              @click="enableCounterEditing"
            >
              <q-icon name="ph ph-pencil-simple" size="16px" class="q-mr-xs" />
              Edit Counter Offer
            </q-btn>
          </template>
        </div>

        <!-- Inline Counter Edit Input -->
        <div v-else class="counter-input-container q-pa-sm bg-white rounded-borders border-amber shadow-1 column q-gutter-y-sm item-card__full-width">
          <span class="text-caption text-weight-bold text-amber-9">Enter counter price</span>
          <q-input
            :model-value="item.customer_offer_amount"
            type="number"
            outlined
            dense
            bg-color="white"
            class="counter-field full-width"
            :prefix="currencySymbol"
            placeholder="0.00"
            @update:model-value="onOfferInput"
          />
          <div class="row q-gutter-x-sm">
            <q-btn
              unelevated
              color="amber-9"
              no-caps
              class="col text-caption text-weight-bold decision-btn"
              label="Save"
              @click="saveItemCounter"
            />
            <q-btn
              flat
              no-caps
              color="grey-7"
              class="col text-caption"
              label="Cancel"
              @click="cancelCounterEditing"
            />
          </div>
        </div>
      </div>

      <!-- Quantity Stepper for status == 'final_offered' -->
      <div v-if="status === 'final_offered'" class="qty-stepper-box q-pa-sm bg-green-1 rounded-borders border-green item-card__full-width">
        <div class="row items-center justify-between q-col-gutter-xs">
          <div class="column col-xs-12 col-sm-auto q-mb-xs q-mb-sm-none">
            <span class="text-caption text-weight-bold text-green-9">Update Final Quantity:</span>
            <span class="text-caption text-grey-7" style="font-size: 11px;">
              Step size: {{ minQtyStep }}
            </span>
          </div>
          <div class="row items-center q-gutter-x-xs col-xs-12 col-sm-auto justify-end">
            <q-btn
              unelevated
              dense
              color="white"
              text-color="green-9"
              icon="ph ph-minus"
              size="md"
              class="touch-stepper-btn border-green"
              :disable="quantity <= 0"
              @click="updateQuantity(quantity - minQtyStep)"
            />
            <q-input
              v-model.number="quantity"
              type="number"
              outlined
              dense
              bg-color="white"
              input-class="text-center text-weight-bolder"
              style="width: 70px"
              :min="0"
              @update:model-value="onQtyInput"
            />
            <q-btn
              unelevated
              dense
              color="white"
              text-color="green-9"
              icon="ph ph-plus"
              size="md"
              class="touch-stepper-btn border-green"
              @click="updateQuantity(quantity + minQtyStep)"
            />
            <q-btn
              v-if="isQtyChanged"
              unelevated
              color="positive"
              dense
              no-caps
              class="q-px-sm text-caption text-weight-bold q-ml-xs"
              style="height: 38px; border-radius: 8px;"
              label="Save"
              @click="saveQuantity"
            />
          </div>
        </div>
      </div>

      <!-- Line Total Summary -->
      <div class="line-total-row row items-center justify-between q-pt-sm border-top item-card__full-width">
        <span class="text-caption text-weight-medium text-grey-7">Line Total</span>
        <span class="text-subtitle1 text-weight-bolder text-grey-9">
          {{ currencySymbol }}{{ calculatedLineTotal.toFixed(2) }}
        </span>
      </div>

      <!-- Progress Tracking Post-Confirmed (procuring, ordered, delivered) -->
      <div v-if="isConfirmedOrBeyond && status !== 'confirmed'" class="progress-section q-pa-xs bg-grey-2 rounded-borders text-caption text-grey-8 item-card__full-width">
        <div class="row items-center justify-around text-center">
          <div>
            <div class="text-weight-bold">{{ item.quantity }}</div>
            <div style="font-size: 10px;" class="text-grey-6">Quantity</div>
          </div>
          <q-separator vertical />
          <div>
            <div class="text-weight-bold text-indigo-8">{{ item.ordered_quantity ?? 0 }}</div>
            <div style="font-size: 10px;" class="text-grey-6">Ordered</div>
          </div>
          <q-separator vertical />
          <div>
            <div class="text-weight-bold text-positive">{{ item.delivered_quantity ?? 0 }}</div>
            <div style="font-size: 10px;" class="text-grey-6">Delivered</div>
          </div>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { ShopOrderItem, ShopOrder, CustomerOrderDetailOrder } from '../types';
import { calculateItemFirstOfferPrice } from '../utils/catalogPricingUtils';

const props = defineProps<{
  item: ShopOrderItem;
  order?: ShopOrder | CustomerOrderDetailOrder | null;
  status: string;
  isNegotiable: boolean;
  currencySymbol: string;
  buyCurrencySymbol?: string;
}>();

const emit = defineEmits<{
  (e: 'update:quantity', payload: { itemId: number; quantity: number }): void;
  (e: 'save-quantity', payload: { itemId: number; quantity: number }): void;
  (e: 'update:customerOffer', payload: { itemId: number; amount: number }): void;
  (e: 'save-item-counter', payload: { itemId: number; amount: number }): void;
}>();

const initialQty = ref<number>(props.item.quantity);
const quantity = ref<number>(props.item.quantity);

const isCountering = ref<boolean>(
  props.item.customer_offer_amount != null &&
    Number(props.item.customer_offer_amount) > 0 &&
    Number(props.item.customer_offer_amount) !== Number(props.item.staff_offer_amount),
);

const isQtyChanged = computed(() => {
  return quantity.value !== initialQty.value;
});

watch(
  () => props.item.quantity,
  (newVal) => {
    if (newVal != null) {
      initialQty.value = newVal;
      // Only set quantity if user hasn't modified it locally
      if (!isQtyChanged.value) {
        quantity.value = newVal;
      }
    }
  },
  { immediate: true },
);

const isConfirmedOrBeyond = computed(() => {
  return ['confirmed', 'procuring', 'ordered', 'delivered'].includes(props.status);
});

const staffOfferAmount = computed(() => {
  if (props.item.is_first_offer_manual && props.item.staff_offer_amount != null) {
    return Number(props.item.staff_offer_amount);
  }
  if (props.order) {
    const computedOffer = calculateItemFirstOfferPrice(
      props.item,
      {
        conversion_rate: props.order.conversion_rate,
        cargo_rate: props.order.cargo_rate,
        first_offer_rate: props.order.first_offer_rate ?? props.order.profit_rate,
        profit_basis: props.order.profit_basis,
      },
      props.order.package_weight_kg,
    );
    if (computedOffer > 0) return computedOffer;
  }
  if (props.item.staff_offer_amount != null && props.item.staff_offer_amount > 0) {
    return Number(props.item.staff_offer_amount);
  }
  return Number(props.item.unit_sell_price_amount || props.item.unit_list_price_amount || 0);
});

const isEditingCounter = ref<boolean>(false);

const needsDecision = computed(
  () => props.status === 'priced' && props.isNegotiable,
);

const hasCustomerCounter = computed(() => {
  return props.item.customer_offer_amount != null && Number(props.item.customer_offer_amount) > 0;
});

const isOfferAccepted = computed(() => {
  return (
    hasCustomerCounter.value &&
    Number(props.item.customer_offer_amount) === staffOfferAmount.value
  );
});

const decisionTone = computed(() => {
  if (!needsDecision.value) return 'neutral';
  if (!hasCustomerCounter.value) return 'pending';
  if (isOfferAccepted.value) return 'accepted';
  return 'countered';
});

const selectAcceptOffer = () => {
  isEditingCounter.value = false;
  const amount = staffOfferAmount.value;
  emit('update:customerOffer', { itemId: props.item.id, amount });
  emit('save-item-counter', { itemId: props.item.id, amount });
};

const enableCounterEditing = () => {
  isEditingCounter.value = true;
  if (!props.item.customer_offer_amount || Number(props.item.customer_offer_amount) === 0) {
    emit('update:customerOffer', { itemId: props.item.id, amount: staffOfferAmount.value });
  }
};

const cancelCounterEditing = () => {
  isEditingCounter.value = false;
};

const saveItemCounter = () => {
  const amount = Number(props.item.customer_offer_amount || 0);
  isEditingCounter.value = false;
  if (amount <= 0) {
    cancelCounterEditing();
    return;
  }
  emit('save-item-counter', { itemId: props.item.id, amount });
};

const effectiveUnitPrice = computed(() => {
  if (props.status === 'final_offered' || isConfirmedOrBeyond.value) {
    return Number(props.item.final_offer_amount || staffOfferAmount.value);
  }
  if (props.status === 'priced' || props.status === 'countered') {
    if (hasCustomerCounter.value) {
      return Number(props.item.customer_offer_amount);
    }
    return staffOfferAmount.value;
  }
  return Number(props.item.unit_sell_price_amount || props.item.unit_list_price_amount || 0);
});

const minQtyStep = computed(() => {
  const itemAny = props.item as any;
  const step = itemAny.minimum_order_quantity ?? itemAny.minimum_quantity ?? itemAny.moq ?? 1;
  return Math.max(1, Number(step) || 1);
});

const calculatedLineTotal = computed(() => {
  const qty = props.status === 'final_offered' || isConfirmedOrBeyond.value ? quantity.value : props.item.quantity;
  return effectiveUnitPrice.value * qty;
});

const updateQuantity = (val: number) => {
  const bounded = Math.max(0, val);
  quantity.value = bounded;
};

const saveQuantity = () => {
  initialQty.value = quantity.value;
  emit('save-quantity', { itemId: props.item.id, quantity: quantity.value });
};

const onQtyInput = (val: any) => {
  const num = Math.max(0, Number(val || 0));
  updateQuantity(num);
};
const onOfferInput = (val: any) => {
  const amount = Number(val || 0);
  // Auto-remove counter if amount equals offer price
  if (amount === staffOfferAmount.value || amount <= 0) {
    if (amount === staffOfferAmount.value) {
      isCountering.value = false;
      emit('update:customerOffer', { itemId: props.item.id, amount: 0 });
      return;
    }
  }
  emit('update:customerOffer', { itemId: props.item.id, amount });
};
</script>

<script lang="ts">
export default {
  name: 'CustomerCatalogOrderItemCard',
};
</script>

<style scoped>
.item-card {
  border-radius: 12px;
  background: #ffffff;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  width: 100%;
  max-width: 640px;
  margin-left: auto;
  margin-right: auto;
}

.item-thumb {
  width: 80px;
  min-width: 80px;
  height: 80px;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.06);
  background: #f5f5f5;
}

.item-thumb__img {
  width: 100%;
  height: 100%;
  min-height: 80px;
}

.item-thumb__placeholder {
  width: 100%;
  height: 100%;
  min-height: 80px;
}

.display-block {
  display: block;
}

.price-cells-row {
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.06);
}

.price-cell {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  min-width: 0;
  padding: 8px 10px;
  text-align: center;
}

.price-cell__label {
  font-size: 10px;
  line-height: 1.2;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.price-cell__value {
  font-size: 0.95rem;
  line-height: 1.2;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.price-cell--first-offer {
  background-color: #f3e5f5;
}

.price-cell--first-offer .price-cell__label {
  color: #7b1fa2;
}

.price-cell--first-offer .price-cell__value {
  color: #4a148c;
}

.price-cell--counter {
  background-color: #fff8f0;
}

.price-cell--counter .price-cell__label {
  color: #e65100;
}

.price-cell--counter .price-cell__value {
  color: #bf360c;
}

.price-cell--final {
  background-color: #e8f5e9;
}

.price-cell--final .price-cell__label {
  color: #2e7d32;
}

.price-cell--final .price-cell__value {
  color: #1b5e20;
}

.bg-blue-1-soft {
  background: #f0f7ff;
}

.border-grey {
  border: 1px solid #e0e0e0;
}

.border-amber {
  border: 1px solid #ffecb3;
}

.border-green {
  border: 1px solid #c8e6c9;
}

.item-card__full-width {
  width: 100%;
}

.decision-btn {
  border-radius: 8px;
  min-height: 44px;
}

@media (min-width: 600px) {
  .item-card {
    border-radius: 10px;
    box-shadow: none;
  }

  .item-card__section {
    padding: 12px 14px !important;
    gap: 8px !important;
  }

  .item-thumb {
    width: 56px;
    min-width: 56px;
    height: 56px;
    border-radius: 8px;
  }

  .item-thumb__img,
  .item-thumb__placeholder {
    min-height: 56px;
  }

  .item-card__title {
    font-size: 0.95rem;
    line-height: 1.35;
  }

  .price-cells-row {
    flex-wrap: wrap;
  }

  .price-cell {
    flex: 1 1 auto;
    min-width: 120px;
    padding: 6px 8px;
  }

  .price-cell__label {
    font-size: 9px;
  }

  .price-cell__value {
    font-size: 0.9rem;
  }

  .decision-box {
    background: transparent;
    padding: 0;
    border-top: 1px solid rgba(0, 0, 0, 0.06);
    padding-top: 8px;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;
  }

  .decision-box > .row.justify-between {
    margin-bottom: 0;
    flex: 0 0 auto;
    margin-right: 8px;
  }

  .decision-box > .row.justify-between .text-caption:first-child {
    display: none;
  }

  .decision-actions {
    flex-direction: row !important;
    flex: 1 1 auto;
    justify-content: flex-end;
    gap: 8px;
    margin-left: auto;
  }

  .decision-actions .decision-btn {
    flex: 0 0 auto;
    width: auto !important;
    min-height: 36px;
    padding: 0 14px;
    font-size: 12px;
  }

  .counter-input-container {
    flex: 1 1 100%;
    padding: 8px 10px !important;
    box-shadow: none !important;
  }

  .counter-input-container .row {
    flex-wrap: nowrap;
  }

  .counter-input-container .counter-field {
    max-width: 140px;
  }

  .line-total-row {
    border-top: none;
    padding-top: 0;
    margin-top: 0;
  }

  .line-total-row .text-subtitle1 {
    font-size: 0.95rem;
  }

  .qty-stepper-box {
    padding: 8px 10px !important;
  }
}

@media (max-width: 599px) {
  .decision-actions {
    width: 100%;
  }
}

.touch-stepper-btn {
  width: 44px;
  height: 44px;
  border-radius: 8px;
}

.border-top {
  border-top: 1px dashed rgba(0, 0, 0, 0.1);
}

.counter-field :deep(.q-field__control) {
  border-radius: 6px;
}

.item-card--neutral {
  border-left: 3px solid transparent;
}

.item-card--pending {
  border-left: 3px solid #bdbdbd;
}

.item-card--accepted {
  border-left: 3px solid #43a047;
}

.item-card--countered {
  border-left: 3px solid #ff8f00;
}
</style>


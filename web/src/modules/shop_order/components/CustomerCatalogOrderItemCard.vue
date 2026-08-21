<template>
  <q-card flat bordered class="item-card q-mb-md">
    <q-card-section class="q-pa-md">
      <!-- Item Header: Image + Details -->
      <div class="row items-start no-wrap q-gutter-x-md">
        <!-- Thumbnail -->
        <div class="col-auto">
          <q-avatar size="72px" rounded class="bg-grey-2 item-avatar shadow-1">
            <q-img v-if="item.image_url" :src="item.image_url" fit="cover" />
            <q-icon v-else name="ph ph-image" size="32px" color="grey-5" />
          </q-avatar>
        </div>

        <!-- Details -->
        <div class="col">
          <div class="text-subtitle1 text-weight-bold text-grey-9 leading-snug">
            {{ item.name }}
          </div>
          
          <div class="row items-center q-gutter-x-sm q-mt-xs">
            <q-chip dense color="grey-2" text-color="grey-8" class="q-ma-none text-caption text-weight-medium">
              Qty: <span class="text-weight-bolder q-ml-xs">{{ item.quantity }}</span>
            </q-chip>
            
            <!-- List Price badge if available -->
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

      <!-- Pricing Summary Badges (1st Offer + Counter Pill side by side) -->
      <div v-if="status === 'priced' || status === 'countered' || status === 'final_offered' || isConfirmedOrBeyond" class="price-chips-container q-mt-md q-pa-xs rounded-borders bg-grey-1">
        <div class="row items-center justify-start q-gutter-x-sm">
          <!-- 1st Offer Unit Price -->
          <div class="col-auto">
            <div class="price-pill bg-white q-px-sm q-py-xs rounded-borders border-grey">
              <span class="text-caption text-grey-7 display-block">1st Offer / Unit</span>
              <span class="text-subtitle2 text-weight-bolder text-primary">
                {{ currencySymbol }}{{ staffOfferAmount.toFixed(2) }}
              </span>
            </div>
          </div>

          <!-- Counter Price Badge (Shown beside 1st Offer whenever customer_offer_amount is set) -->
          <div v-if="hasCustomerCounter" class="col-auto">
            <div class="price-pill bg-amber-1 q-px-sm q-py-xs rounded-borders border-amber column">
              <span class="text-caption text-amber-9 display-block" style="font-size: 10px; line-height: 1.1;">Your Counter</span>
              <span class="text-subtitle2 text-weight-bolder text-amber-10">
                {{ currencySymbol }}{{ Number(item.customer_offer_amount).toFixed(2) }}
              </span>
            </div>
          </div>

          <!-- Final Offered Price -->
          <div v-if="status === 'final_offered' || isConfirmedOrBeyond" class="col-auto">
            <div class="price-pill bg-green-1 q-px-sm q-py-xs rounded-borders border-green">
              <span class="text-caption text-green-9 display-block">Final Offer</span>
              <span class="text-subtitle2 text-weight-bolder text-positive">
                {{ currencySymbol }}{{ Number(item.final_offer_amount || item.staff_offer_amount || 0).toFixed(2) }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Decision Buttons Box for 'priced' state -->
      <div v-if="status === 'priced' && isNegotiable" class="decision-box q-mt-md q-pa-sm bg-blue-1-soft rounded-borders">
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
        <div v-if="!isEditingCounter" class="row items-center q-gutter-x-sm">
          <!-- Shown when customer_offer_amount is null/0 -->
          <template v-if="!hasCustomerCounter">
            <q-btn
              unelevated
              color="positive"
              text-color="white"
              dense
              no-caps
              class="col text-caption text-weight-bold decision-btn border-grey shadow-1"
              @click="selectAcceptOffer"
            >
              <q-icon name="ph ph-check-circle" size="16px" class="q-mr-xs" />
              Accept 1st Offer
            </q-btn>

            <q-btn
              unelevated
              color="white"
              text-color="grey-8"
              dense
              no-caps
              class="col text-caption text-weight-bold decision-btn border-grey"
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
              dense
              no-caps
              class="col text-caption text-weight-bold decision-btn border-grey shadow-1"
              @click="enableCounterEditing"
            >
              <q-icon name="ph ph-pencil-simple" size="16px" class="q-mr-xs" />
              Edit Counter Offer
            </q-btn>
          </template>
        </div>

        <!-- Inline Counter Edit Input -->
        <div v-else class="counter-input-container q-pa-sm bg-white rounded-borders border-amber shadow-1">
          <div class="row items-center justify-between q-gutter-x-sm">
            <span class="text-caption text-weight-bold text-amber-9 col">Enter Counter Price:</span>
            <div class="row items-center q-gutter-x-xs">
              <q-input
                :model-value="item.customer_offer_amount"
                type="number"
                outlined
                dense
                bg-color="white"
                class="counter-field"
                :prefix="currencySymbol"
                style="width: 110px"
                placeholder="0.00"
                @update:model-value="onOfferInput"
              />
              <q-btn
                unelevated
                color="amber-9"
                dense
                no-caps
                class="q-px-sm text-caption text-weight-bold"
                style="height: 38px; border-radius: 6px;"
                label="Save"
                @click="saveItemCounter"
              />
              <q-btn
                flat
                round
                dense
                color="grey-6"
                icon="ph ph-x"
                size="sm"
                @click="cancelCounterEditing"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Quantity Stepper for status == 'final_offered' -->
      <div v-if="status === 'final_offered'" class="qty-stepper-box q-mt-md q-pa-sm bg-green-1 rounded-borders border-green">
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
      <div class="line-total-row row items-center justify-between q-mt-md q-pt-sm border-top">
        <span class="text-caption text-weight-medium text-grey-7">Line Total</span>
        <span class="text-subtitle1 text-weight-bolder text-grey-9">
          {{ currencySymbol }}{{ calculatedLineTotal.toFixed(2) }}
        </span>
      </div>

      <!-- Progress Tracking Post-Confirmed (procuring, ordered, delivered) -->
      <div v-if="isConfirmedOrBeyond && status !== 'confirmed'" class="progress-section q-mt-sm q-pa-xs bg-grey-2 rounded-borders text-caption text-grey-8">
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

const hasCustomerCounter = computed(() => {
  return props.item.customer_offer_amount != null && Number(props.item.customer_offer_amount) > 0;
});

const isOfferAccepted = computed(() => {
  return (
    hasCustomerCounter.value &&
    Number(props.item.customer_offer_amount) === staffOfferAmount.value
  );
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
}

.item-avatar {
  border: 1px solid rgba(0, 0, 0, 0.06);
}

.display-block {
  display: block;
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

.decision-btn {
  border-radius: 8px;
  min-height: 38px;
}

.touch-stepper-btn {
  width: 38px;
  height: 38px;
  border-radius: 8px;
}

.border-top {
  border-top: 1px dashed rgba(0, 0, 0, 0.1);
}

.counter-field :deep(.q-field__control) {
  border-radius: 6px;
}
</style>


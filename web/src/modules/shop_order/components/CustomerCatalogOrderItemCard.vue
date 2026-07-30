<template>
  <q-card flat bordered class="item-card q-mb-md">
    <q-card-section class="q-pa-md">
      <div class="row items-start q-col-gutter-md">
        <!-- Thumbnail -->
        <div class="col-auto">
          <q-avatar size="64px" rounded class="bg-grey-2">
            <q-img v-if="item.image_url" :src="item.image_url" />
            <q-icon v-else name="ph ph-image" size="28px" color="grey-5" />
          </q-avatar>
        </div>

        <!-- Details -->
        <div class="col">
          <div class="text-subtitle1 text-weight-bold text-grey-9 leading-tight">
            {{ item.name }}
          </div>
          <div class="text-caption text-grey-6 q-mt-xs">
            Quantity requested: <span class="text-weight-bold text-grey-8">{{ item.quantity }}</span>
          </div>

          <!-- Unit List Price (if visible) -->
          <div v-if="item.unit_list_price_amount" class="text-caption text-grey-6 q-mt-xs">
            List price: {{ currencySymbol }}{{ Number(item.unit_list_price_amount).toFixed(2) }}
          </div>

          <!-- Price Breakdowns based on status -->
          <div class="q-mt-sm">
            <!-- Staff Offer display in priced state -->
            <div v-if="status === 'priced' || status === 'countered' || status === 'final_offered' || isConfirmedOrBeyond" class="price-chip-row row items-center q-gutter-x-sm">
              <span class="text-caption text-grey-7">Staff offer:</span>
              <span class="text-subtitle2 text-weight-bold text-primary">
                {{ currencySymbol }}{{ Number(item.staff_offer_amount || item.unit_sell_price_amount || 0).toFixed(2) }}
              </span>
            </div>

            <!-- Customer Counter display -->
            <div v-if="(status === 'countered' || status === 'final_offered' || isConfirmedOrBeyond) && item.customer_offer_amount" class="price-chip-row row items-center q-gutter-x-sm q-mt-xs">
              <span class="text-caption text-grey-7">Your counter:</span>
              <span class="text-caption text-weight-bold text-amber-9">
                {{ currencySymbol }}{{ Number(item.customer_offer_amount).toFixed(2) }}
              </span>
            </div>

            <!-- Final Offered Price -->
            <div v-if="status === 'final_offered' || isConfirmedOrBeyond" class="price-chip-row row items-center q-gutter-x-sm q-mt-xs">
              <span class="text-caption text-grey-7">Final unit offer:</span>
              <span class="text-subtitle2 text-weight-bolder text-positive">
                {{ currencySymbol }}{{ Number(item.final_offer_amount || item.staff_offer_amount || 0).toFixed(2) }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Action Inputs Section -->

      <!-- 1. Counter Input for Path A when status == 'priced' -->
      <div v-if="status === 'priced' && isNegotiable" class="counter-input-box q-mt-md q-pa-sm bg-amber-1 rounded-borders">
        <div class="row items-center justify-between">
          <span class="text-caption text-weight-bold text-amber-9">Your Counter Unit Offer:</span>
          <q-input
            v-model.number="item.customer_offer_amount"
            type="number"
            outlined
            dense
            bg-color="white"
            class="counter-field"
            :prefix="currencySymbol"
            style="width: 130px"
          />
        </div>
      </div>

      <!-- 2. Confirmed Quantity Stepper for status == 'final_offered' -->
      <div v-if="status === 'final_offered'" class="qty-stepper-box q-mt-md q-pa-sm bg-green-1 rounded-borders">
        <div class="row items-center justify-between">
          <div class="column">
            <span class="text-caption text-weight-bold text-green-9">Confirm Quantity:</span>
            <span class="text-caption text-grey-7" style="font-size: 11px;">Max requested: {{ item.quantity }}</span>
          </div>
          <div class="row items-center q-gutter-x-xs">
            <q-btn
              flat
              dense
              round
              icon="ph ph-minus"
              size="sm"
              color="green-9"
              :disable="confirmedQty <= 1"
              @click="updateConfirmedQty(confirmedQty - 1)"
            />
            <q-input
              v-model.number="confirmedQty"
              type="number"
              outlined
              dense
              bg-color="white"
              input-class="text-center text-weight-bold"
              style="width: 65px"
              @update:model-value="onQtyInput"
            />
            <q-btn
              flat
              dense
              round
              icon="ph ph-plus"
              size="sm"
              color="green-9"
              :disable="confirmedQty >= item.quantity"
              @click="updateConfirmedQty(confirmedQty + 1)"
            />
          </div>
        </div>
      </div>

      <!-- Line Total Summary -->
      <div class="line-total-row row items-center justify-between q-mt-md q-pt-sm border-top">
        <span class="text-caption text-grey-6">Line Total</span>
        <span class="text-subtitle1 text-weight-bold text-grey-9">
          {{ currencySymbol }}{{ calculatedLineTotal.toFixed(2) }}
        </span>
      </div>

      <!-- Progress Tracking Post-Confirmed -->
      <div v-if="isConfirmedOrBeyond" class="progress-section q-mt-sm q-pa-xs bg-grey-2 rounded-borders text-caption text-grey-8">
        <div class="row items-center justify-around text-center">
          <div>
            <div class="text-weight-bold">{{ item.confirmed_quantity ?? item.quantity }}</div>
            <div style="font-size: 10px;" class="text-grey-6">Confirmed</div>
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
import type { ShopOrderItem } from '../types';

const props = defineProps<{
  item: ShopOrderItem;
  status: string;
  isNegotiable: boolean;
  currencySymbol: string;
}>();

const emit = defineEmits<{
  (e: 'update:confirmedQty', payload: { itemId: number; confirmedQuantity: number }): void;
}>();

const confirmedQty = ref<number>(props.item.confirmed_quantity ?? props.item.quantity);

watch(
  () => props.item.confirmed_quantity,
  (newVal) => {
    if (newVal != null) {
      confirmedQty.value = newVal;
    }
  },
  { immediate: true },
);

const isConfirmedOrBeyond = computed(() => {
  return ['confirmed', 'procuring', 'ordered', 'delivered'].includes(props.status);
});

const effectiveUnitPrice = computed(() => {
  if (props.status === 'final_offered' || isConfirmedOrBeyond.value) {
    return Number(props.item.final_offer_amount || props.item.staff_offer_amount || props.item.unit_sell_price_amount || 0);
  }
  if (props.status === 'priced' || props.status === 'countered') {
    return Number(props.item.staff_offer_amount || props.item.unit_sell_price_amount || 0);
  }
  return Number(props.item.unit_sell_price_amount || props.item.unit_list_price_amount || 0);
});

const calculatedLineTotal = computed(() => {
  const qty = props.status === 'final_offered' || isConfirmedOrBeyond.value ? confirmedQty.value : props.item.quantity;
  return effectiveUnitPrice.value * qty;
});

const updateConfirmedQty = (val: number) => {
  const bounded = Math.max(1, Math.min(props.item.quantity, val));
  confirmedQty.value = bounded;
  props.item.confirmed_quantity = bounded;
  emit('update:confirmedQty', { itemId: props.item.id, confirmedQuantity: bounded });
};

const onQtyInput = (val: any) => {
  const num = Number(val || 1);
  updateConfirmedQty(num);
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
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
}

.border-top {
  border-top: 1px dashed rgba(0, 0, 0, 0.08);
}

.counter-field :deep(.q-field__control) {
  border-radius: 6px;
}
</style>

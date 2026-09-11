<template>
  <q-card flat bordered class="details-card">
    <q-card-section class="q-px-md q-py-sm border-bottom row items-center justify-between">
      <div class="text-subtitle1 text-weight-bold text-grey-9">
        {{ $t('shop_admin.items_in_order') }}
        <span class="text-grey-6 text-body2 text-weight-medium">({{ orderItems.length }})</span>
      </div>
      <div
        v-if="order.is_negotiable_snapshot"
        class="text-caption text-grey-6"
      >
        {{ $t('shop_admin.negotiation_round') }} {{ order.negotiate_round }}
      </div>
    </q-card-section>

    <q-list separator>
      <q-item
        v-for="item in orderItems"
        :key="item.id"
        class="dropship-item q-py-sm q-px-md"
      >
        <q-item-section avatar class="dropship-item__avatar">
          <div class="dropship-item__image shop-product-thumb bg-grey-2">
            <q-img
              v-if="item.image_url"
              :src="item.image_url"
              :alt="item.name"
              fit="contain"
              class="dropship-item__image-img"
            />
            <q-icon
              v-else
              name="ph ph-image"
              color="grey-4"
              size="24px"
            />
          </div>
        </q-item-section>

        <q-item-section>
          <div class="text-body2 text-weight-bold text-grey-9 leading-snug">{{ item.name }}</div>
          <div class="text-caption text-grey-6 q-mt-xs">
            {{ $t('shop_admin.quantity') }} {{ item.quantity }}
          </div>

          <div
            v-if="isNegotiationOpen"
            class="row items-center q-gutter-x-sm q-mt-sm"
          >
            <span class="text-caption text-grey-7">{{ $t('shop_admin.your_counter') }}</span>
            <q-input
              v-model.number="item.customer_offer_amount"
              type="number"
              outlined
              dense
              class="counter-input"
              :prefix="currencySymbol"
              style="max-width: 120px"
            />
          </div>
        </q-item-section>

        <q-item-section v-if="canSeeLinePrices" side class="text-right">
          <template v-if="order.shop_type_snapshot === 'dropship'">
            <span class="text-caption text-grey-6">{{ $t('shop_admin.line_total') }}</span>
            <div class="text-body1 text-weight-bold text-primary">
              {{ currencySymbol }}{{ getRecipientLineTotal(item).toFixed(2) }}
            </div>
          </template>
          <template v-else>
            <span class="text-caption text-grey-6">{{ $t('shop_admin.unit_price') }}</span>
            <div class="text-body2 text-weight-bold text-grey-8">
              {{ currencySymbol }}{{ getDisplayUnitPrice(item).toFixed(2) }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              {{ currencySymbol }}{{ (getDisplayUnitPrice(item) * item.quantity).toFixed(2) }}
            </div>
          </template>
        </q-item-section>
      </q-item>
    </q-list>
  </q-card>
</template>

<script setup lang="ts">
import type { ShopOrderItem } from '../types';

withDefaults(
  defineProps<{
    orderItems: ShopOrderItem[];
    order: any;
    isNegotiationOpen: boolean;
    currencySymbol: string;
    canSeeLinePrices?: boolean;
  }>(),
  { canSeeLinePrices: true },
);

const getRecipientLineTotal = (item: ShopOrderItem) => {
  return Number(item.customer_sell_price_amount ?? 0) * item.quantity;
};

const getDisplayUnitPrice = (item: ShopOrderItem) => {
  return (
    item.final_price_amount ??
    item.staff_offer_amount ??
    item.customer_offer_amount ??
    item.unit_sell_price_amount ??
    item.unit_list_price_amount ??
    0
  );
};
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderItemsList',
};
</script>

<style scoped>
.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.counter-input :deep(.q-field__control) {
  border-radius: 8px;
}

.dropship-item__avatar {
  min-width: 56px;
  padding-right: 8px;
}

.dropship-item__image {
  width: 56px;
  height: 56px;
  min-width: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 8px;
  overflow: hidden;
}

.dropship-item__image-img {
  width: 100%;
  height: 100%;
}

@media (max-width: 599px) {
  .dropship-item {
    flex-wrap: wrap;
    align-items: flex-start;
  }

  .dropship-item :deep(.q-item__section--side) {
    width: 100%;
    padding-left: 0;
    margin-top: 8px;
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
    text-align: left;
  }
}
</style>

<template>
  <div>
    <q-card flat bordered class="details-card">
      <q-card-section class="q-px-lg q-py-md border-bottom row items-center justify-between">
        <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.items_in_order') }}</div>
        <div
          class="text-caption text-grey-6"
          v-if="order.is_negotiable_snapshot"
        >
          {{ $t('shop_admin.negotiation_round') }} {{ order.negotiate_round }}
        </div>
      </q-card-section>

      <q-list separator>
        <q-item v-for="item in orderItems" :key="item.id" class="q-py-md q-px-lg">
          <q-item-section avatar>
            <q-avatar size="50px" rounded class="bg-grey-2">
              <q-img v-if="item.image_url" :src="item.image_url" />
              <q-icon v-else name="ph ph-image" size="24px" color="grey-4" />
            </q-avatar>
          </q-item-section>

          <q-item-section>
            <div class="text-body1 text-weight-bold text-grey-9">{{ item.name }}</div>
            <div class="text-caption text-grey-6">{{ $t('shop_admin.quantity') }}: {{ item.quantity }}</div>
          </q-item-section>

          <q-item-section side class="column items-end justify-center">
            <!-- Pricing display -->
            <template v-if="order.shop_type_snapshot === 'dropship'">
              <div class="column text-right q-mb-xs">
                <span class="text-caption text-grey-6" style="font-size: 10px;">{{ $t('shop_admin.accounting_cost') }}</span>
                <span class="text-body2 text-weight-medium text-grey-8">
                  {{ currencySymbol }}{{ (item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0).toFixed(2) }} {{ $t('shop.each') }}
                </span>
                <span class="text-caption text-grey-6" style="font-size: 10px;">
                  Total Cost: {{ currencySymbol }}{{ ((item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0) * item.quantity).toFixed(2) }}
                </span>
              </div>
              <div class="column text-right">
                <span class="text-caption text-grey-6" style="font-size: 10px;">{{ $t('shop_admin.recipient_price') }}</span>
                <span class="text-body2 text-weight-bold text-primary">
                  {{ currencySymbol }}{{ (item.customer_sell_price_amount ?? 0).toFixed(2) }} {{ $t('shop.each') }}
                </span>
                <span class="text-caption text-weight-bold text-primary" style="font-size: 11px;">
                  Total Recipient: {{ currencySymbol }}{{ ((item.customer_sell_price_amount ?? 0) * item.quantity).toFixed(2) }}
                </span>
              </div>
            </template>
            <template v-else>
              <div class="column text-right">
                <span class="text-caption text-grey-6">{{ $t('shop_admin.unit_price') }}</span>
                <span class="text-body2 text-weight-bold text-grey-8">
                  {{ currencySymbol }}{{ getDisplayUnitPrice(item).toFixed(2) }}
                </span>
                <span class="text-caption text-grey-6">
                  Total: {{ currencySymbol }}{{ (getDisplayUnitPrice(item) * item.quantity).toFixed(2) }}
                </span>
              </div>
            </template>

            <!-- Offer editing if in negotiation status -->
            <div v-if="isNegotiationOpen" class="q-mt-sm row items-center q-gutter-x-sm">
              <span class="text-caption text-grey-7">{{ $t('shop_admin.your_counter') }}</span>
              <q-input
                v-model.number="item.customer_offer_amount"
                type="number"
                outlined
                dense
                class="counter-input"
                :prefix="currencySymbol"
                style="width: 100px"
              />
            </div>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card>

    <!-- Negotiation submit banner -->
    <q-card
      v-if="isNegotiationOpen"
      flat
      bordered
      class="negotiate-action-card q-mt-md bg-amber-1 border-amber"
    >
      <q-card-section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-subtitle2 text-weight-bold text-amber-9">
            Counter Offer Action Required
          </div>
          <div class="text-body2 text-amber-8">
            Propose counter unit prices for the items above and submit them to staff.
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            color="amber-9"
            unelevated
            no-caps
            :label="$t('shop_admin.submit_counter_offer')"
            class="pill-btn text-weight-bold"
            :loading="isSendingCounter"
            @click="emit('submit-counter-offer')"
          />
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import type { ShopOrderItem } from '../types';

defineProps<{
  orderItems: ShopOrderItem[];
  order: any;
  isNegotiationOpen: boolean;
  isSendingCounter: boolean;
  currencySymbol: string;
}>();

const emit = defineEmits<{
  (e: 'submit-counter-offer'): void;
}>();

const getDisplayUnitPrice = (item: any) => {
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

.pill-btn {
  border-radius: 30px;
}

.negotiate-action-card {
  border-radius: 12px;
}

.border-amber {
  border-color: #ffb300 !important;
}

.counter-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>

<template>
  <q-card flat bordered class="dropship-charge-options">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
        <q-icon name="ph ph-currency-circle-dollar" size="18px" class="q-mr-xs text-primary" />
        {{ $t('shop.dropship_charge_options') }}
      </div>
    </q-card-section>

    <q-card-section class="column q-gutter-y-md">
      <div class="charge-toggle-block">
        <q-toggle
          :model-value="recipientPaysDelivery"
          color="primary"
          dense
          :label="$t('shop.dropship_recipient_pays_delivery')"
          @update:model-value="$emit('update:recipientPaysDelivery', $event)"
        />
        <div class="text-caption text-grey-7 q-ml-lg q-mt-xs">
          {{
            recipientPaysDelivery
              ? $t('shop.dropship_delivery_recipient_hint')
              : $t('shop.dropship_delivery_merchant_hint')
          }}
        </div>
      </div>

      <div class="charge-toggle-block">
        <q-toggle
          :model-value="recipientPaysCod"
          color="primary"
          dense
          :label="$t('shop.dropship_recipient_pays_cod')"
          @update:model-value="$emit('update:recipientPaysCod', $event)"
        />
        <div class="text-caption text-grey-7 q-ml-lg q-mt-xs">
          {{
            recipientPaysCod
              ? $t('shop.dropship_cod_recipient_hint')
              : $t('shop.dropship_cod_merchant_hint')
          }}
        </div>
      </div>

      <q-separator />

      <div class="column q-gutter-y-xs">
        <div class="row justify-between text-body2 text-grey-7">
          <span>{{ $t('shop.delivery_charge') }}</span>
          <span class="text-weight-medium">
            {{ formatMoney(charges.deliveryCharge) }}
            <span class="text-caption text-grey-6">
              ({{ charges.recipientPaysDelivery ? $t('shop.dropship_paid_by_recipient') : $t('shop.dropship_deducted_from_profit') }})
            </span>
          </span>
        </div>
        <div class="row justify-between text-body2 text-grey-7">
          <span>{{ $t('shop.cod_fee') }}</span>
          <span class="text-weight-medium">
            {{ formatMoney(charges.codCharge) }}
            <span class="text-caption text-grey-6">
              ({{ charges.recipientPaysCod ? $t('shop.dropship_paid_by_recipient') : $t('shop.dropship_deducted_from_profit') }})
            </span>
          </span>
        </div>
        <div class="row justify-between text-body2 text-grey-7">
          <span>{{ $t('shop.print_charge') }}</span>
          <span class="text-weight-medium text-grey-8">
            {{ formatMoney(charges.printCharge) }}
            <span class="text-caption text-grey-6">({{ $t('shop.dropship_deducted_from_profit') }})</span>
          </span>
        </div>
        <div class="row justify-between text-body2 text-grey-7">
          <span>{{ $t('shop.packing_charge') }}</span>
          <span class="text-weight-medium text-grey-8">
            {{ formatMoney(charges.packingCharge) }}
            <span class="text-caption text-grey-6">({{ $t('shop.dropship_deducted_from_profit') }})</span>
          </span>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { formatCartMoney } from '../utils/cartPriceUtils';

export interface DropshipChargePreview {
  deliveryCharge: number;
  codCharge: number;
  printCharge: number;
  packingCharge: number;
  recipientPaysDelivery: boolean;
  recipientPaysCod: boolean;
}

const props = defineProps<{
  recipientPaysDelivery: boolean;
  recipientPaysCod: boolean;
  charges: DropshipChargePreview;
  currencySymbol?: string;
}>();

defineEmits<{
  (e: 'update:recipientPaysDelivery', value: boolean): void;
  (e: 'update:recipientPaysCod', value: boolean): void;
}>();

const formatMoney = (amount: number) =>
  formatCartMoney(amount, props.currencySymbol ?? '৳');
</script>

<style scoped>
.dropship-charge-options {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.charge-toggle-block {
  padding: 8px 10px;
  border-radius: 10px;
  background: rgba(34, 56, 101, 0.03);
}
</style>

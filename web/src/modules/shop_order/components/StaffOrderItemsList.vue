<script setup lang="ts">
defineProps<{
  order: any;
  orderItems: any[];
  currencySymbol: string;
  canAction: boolean;
  canFulfill: boolean;
  isDeletingOrder?: boolean;
  isSubmittingPricing?: boolean;
  isConfirmingOrder?: boolean;
  isPlacingProcurement?: boolean;
  isFulfillingToInvoice?: boolean;
}>();

const emit = defineEmits<{
  (e: 'delete-order'): void;
  (e: 'submit-pricing'): void;
  (e: 'confirm-order'): void;
  (e: 'place-procurement'): void;
  (e: 'fulfill-invoice'): void;
}>();
</script>

<template>
  <div>
    <q-card flat bordered class="details-card">
      <q-card-section class="q-px-lg q-py-md border-bottom row items-center justify-between">
        <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.order_lines') }}</div>
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
            <div
              class="text-caption text-amber-9 text-weight-bold"
              v-if="item.customer_offer_amount"
            >
              {{ $t('shop_admin.customer_offer') }} {{ currencySymbol }}{{ Number(item.customer_offer_amount).toFixed(2) }}
            </div>
          </q-item-section>

          <q-item-section side class="column items-end justify-center">
            <!-- Pricing display -->
            <template v-if="order.shop_type_snapshot === 'dropship'">
              <div class="column text-right q-mb-xs">
                <span class="text-caption text-grey-6" style="font-size: 10px;">{{ $t('shop_admin.middle_man_cost') }}</span>
                <span class="text-body2 text-weight-medium text-grey-8">
                  {{ currencySymbol }}{{ (item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0).toFixed(2) }} {{ $t('shop.each') }}
                </span>
                <span class="text-caption text-grey-6" style="font-size: 10px;">
                  Total: {{ currencySymbol }}{{ ((item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0) * item.quantity).toFixed(2) }}
                </span>
              </div>
              <div class="column text-right">
                <span class="text-caption text-grey-6" style="font-size: 10px;">{{ $t('shop_admin.recipient_price') }}</span>
                <span class="text-body2 text-weight-bold text-primary">
                  {{ currencySymbol }}{{ (item.customer_sell_price_amount ?? 0).toFixed(2) }} {{ $t('shop.each') }}
                </span>
                <span class="text-caption text-weight-bold text-primary" style="font-size: 11px;">
                  Total: {{ currencySymbol }}{{ ((item.customer_sell_price_amount ?? 0) * item.quantity).toFixed(2) }}
                </span>
              </div>
            </template>
            <template v-else>
              <div class="column text-right">
                <span class="text-caption text-grey-6">{{ $t('shop_admin.catalog_sell_price') }}</span>
                <span class="text-body2 text-weight-bold text-grey-8">
                  {{ currencySymbol }}{{
                    (item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0).toFixed(2)
                  }}
                </span>
              </div>
            </template>

            <!-- Offer editing if in editable negotiation/price status -->
            <div v-if="canAction" class="q-mt-sm row items-center q-gutter-x-sm">
              <span class="text-caption text-grey-7">{{ $t('shop_admin.staff_price') }}</span>
              <q-input
                v-model.number="item.staff_offer_amount"
                type="number"
                outlined
                dense
                class="counter-input"
                :prefix="currencySymbol"
                style="width: 100px"
              />
            </div>
            <div
              v-else-if="item.final_price_amount"
              class="q-mt-xs text-weight-bold text-primary"
            >
              {{ $t('shop_admin.final_price') }} {{ currencySymbol }}{{ Number(item.final_price_amount).toFixed(2) }}
            </div>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card>

    <!-- Action Buttons Panel -->
    <div class="q-mt-md row items-center justify-between">
      <div>
        <q-btn
          v-if="order.status !== 'fulfilled'"
          outline
          color="negative"
          no-caps
          icon="ph ph-trash"
          :label="$t('shop_admin.delete_order')"
          class="text-weight-bold q-px-lg q-py-sm rounded-borders"
          style="border-radius: 8px;"
          :loading="isDeletingOrder"
          @click="emit('delete-order')"
        />
      </div>

      <div class="row q-gutter-md justify-end">
        <div v-if="canAction" class="row q-gutter-md justify-end">
          <q-btn
            outline
            color="primary"
            no-caps
            :label="$t('shop_admin.save_price_counter')"
            class="pill-btn text-weight-bold q-px-lg q-py-sm"
            :loading="isSubmittingPricing"
            @click="emit('submit-pricing')"
          />
          <q-btn
            color="green-7"
            unelevated
            no-caps
            :label="$t('shop_admin.confirm_order')"
            class="pill-btn text-weight-bold q-px-lg q-py-sm"
            :loading="isConfirmingOrder"
            @click="emit('confirm-order')"
          />
        </div>

        <div v-if="canFulfill" class="row q-gutter-md justify-end">
          <q-btn
            v-if="order.shop_type_snapshot === 'vendor_catalog'"
            color="indigo-7"
            unelevated
            no-caps
            :label="$t('shop_admin.place_for_procurement')"
            class="pill-btn text-weight-bold q-px-lg q-py-sm"
            :loading="isPlacingProcurement"
            @click="emit('place-procurement')"
          />
          <q-btn
            v-else-if="order.shop_type_snapshot !== 'dropship'"
            color="teal-7"
            unelevated
            no-caps
            :label="$t('shop_admin.fulfill_to_invoice')"
            class="pill-btn text-weight-bold q-px-lg q-py-sm"
            :loading="isFulfillingToInvoice"
            @click="emit('fulfill-invoice')"
          />
        </div>
      </div>
    </div>
  </div>
</template>

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
  border-radius: 8px;
}

.counter-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>

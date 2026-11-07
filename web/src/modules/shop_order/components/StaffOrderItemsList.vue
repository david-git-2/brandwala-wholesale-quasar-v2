<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
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
  canDeleteLines?: boolean;
  selectedLineIds?: number[];
  isRemovingLines?: boolean;
}>(),
  {
    canDeleteLines: false,
    selectedLineIds: () => [],
    isRemovingLines: false,
  },
);

const emit = defineEmits<{
  (e: 'delete-order'): void;
  (e: 'submit-pricing'): void;
  (e: 'confirm-order'): void;
  (e: 'place-procurement'): void;
  (e: 'fulfill-invoice'): void;
  (e: 'update:selectedLineIds', ids: number[]): void;
  (e: 'remove-selected-lines'): void;
}>();

const selectedIdSet = computed(() => new Set(props.selectedLineIds ?? []));

const allLinesSelected = computed(() => {
  if (!props.canDeleteLines || !props.orderItems?.length) return false;
  return props.orderItems.every((it: { id: number }) => selectedIdSet.value.has(it.id));
});

function isLineSelected(id: number): boolean {
  return selectedIdSet.value.has(id);
}

function toggleLine(id: number, val: boolean) {
  const next = new Set(props.selectedLineIds ?? []);
  if (val) next.add(id);
  else next.delete(id);
  emit('update:selectedLineIds', [...next]);
}

function toggleSelectAll(val: boolean) {
  const ids = props.orderItems.map((it: { id: number }) => it.id);
  if (ids.length === 0) return;
  const next = new Set(props.selectedLineIds ?? []);
  if (val) ids.forEach((id) => next.add(id));
  else ids.forEach((id) => next.delete(id));
  emit('update:selectedLineIds', [...next]);
}
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

      <q-card-section
        v-if="canDeleteLines && (selectedLineIds?.length ?? 0) > 0"
        class="q-px-lg q-pt-sm q-pb-none row items-center justify-end"
      >
        <q-btn
          outline
          dense
          no-caps
          color="negative"
          icon="ph ph-trash"
          :loading="isRemovingLines"
          :label="$t('shop_admin.remove_selected_lines')"
          @click="emit('remove-selected-lines')"
        />
      </q-card-section>

      <q-list separator>
        <q-item v-if="canDeleteLines" class="q-px-lg q-py-sm staff-order-lines-select-row">
          <q-item-section side class="staff-order-line-select-cell">
            <q-checkbox
              dense
              size="xs"
              :model-value="allLinesSelected"
              :disable="!orderItems.length"
              color="primary"
              :aria-label="$t('shop_admin.select_lines_hint')"
              @update:model-value="toggleSelectAll"
            />
          </q-item-section>
          <q-item-section>
            <span class="text-caption text-grey-7">{{ $t('shop_admin.select_lines_hint') }}</span>
          </q-item-section>
        </q-item>
        <q-item v-for="item in orderItems" :key="item.id" class="q-py-md q-px-lg">
          <q-item-section v-if="canDeleteLines" side class="staff-order-line-select-cell" @click.stop>
            <q-checkbox
              dense
              size="xs"
              :model-value="isLineSelected(item.id)"
              color="primary"
              :aria-label="$t('shop_admin.select_lines_hint')"
              @update:model-value="(v: boolean) => toggleLine(item.id, v)"
            />
          </q-item-section>
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
          v-if="order.status === 'cancelled'"
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

.staff-order-line-select-cell {
  min-width: 28px;
  max-width: 32px;
  padding-right: 4px !important;
  align-items: center;
  justify-content: center;
}

.staff-order-line-select-cell :deep(.q-checkbox) {
  margin: -4px 0;
}
</style>

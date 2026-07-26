<template>
  <q-slide-transition>
    <q-card v-if="selectedCount > 0" flat class="bg-primary text-white q-mb-md">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-auto row items-center q-gutter-x-sm">
            <q-icon name="ph ph-check-square-offset" size="20px" />
            <span class="text-subtitle2 text-weight-bold">
              {{ $t('shop_admin.items_selected', { count: selectedCount }) }}
            </span>
          </div>

          <div class="col-auto row items-center q-gutter-x-md wrap">
            <!-- Price Markup Controls -->
            <div class="row items-center q-gutter-x-xs">
              <q-select
                v-model="targetPrice"
                dense
                outlined
                dark
                options-dense
                emit-value
                map-options
                bg-color="white-transparent"
                style="width: 130px"
                :options="[
                  { label: 'Sell Price', value: 'sell_price' },
                  { label: 'Dropship Floor', value: 'min_sell_price' },
                ]"
              />

              <q-btn-toggle
                v-model="markupType"
                dense
                flat
                dark
                toggle-color="white"
                :options="[
                  { label: '%', value: 'percentage' },
                  { label: '$', value: 'fixed' },
                ]"
              />

              <q-input
                v-model.number="markupAmount"
                type="number"
                dense
                outlined
                dark
                bg-color="white-transparent"
                style="width: 100px"
                :suffix="markupType === 'percentage' ? '%' : ''"
                :label="markupType === 'percentage' ? 'Markup %' : 'Amount'"
                step="0.1"
                min="0"
              />

              <q-btn
                unelevated
                color="white"
                text-color="primary"
                dense
                class="q-px-sm"
                icon="ph ph-lightning"
                :label="$t('shop_admin.apply_markup_selected')"
                :loading="isApplying"
                @click="onApplyMarkup"
              />
            </div>

            <q-separator vertical dark class="q-mx-xs" />

            <!-- Quantity Adjustment Controls -->
            <div class="row items-center q-gutter-x-xs">
              <q-btn-toggle
                v-model="qtyOperation"
                dense
                flat
                dark
                toggle-color="white"
                :options="[
                  { label: '+ Add', value: 'add' },
                  { label: '- Sub', value: 'subtract' },
                  { label: '= Set', value: 'set' },
                ]"
              />

              <q-input
                v-model.number="qtyDelta"
                type="number"
                dense
                outlined
                dark
                bg-color="white-transparent"
                style="width: 100px"
                label="Qty Value"
                step="1"
                min="0"
              />

              <q-btn
                unelevated
                color="white"
                text-color="primary"
                dense
                class="q-px-sm"
                icon="ph ph-plus-minus"
                label="Apply Qty"
                :loading="isApplying"
                @click="onApplyQtyDelta"
              >
                <q-tooltip>Adjust display quantity for non-manually locked items</q-tooltip>
              </q-btn>
            </div>

            <q-separator vertical dark class="q-mx-xs" />

            <!-- Bulk Actions -->
            <div class="row items-center q-gutter-x-xs">
              <q-btn
                unelevated
                color="negative"
                dense
                class="q-px-sm"
                icon="ph ph-trash"
                label="Remove Selected"
                @click="$emit('bulk-remove')"
              />

              <q-btn
                flat
                round
                dense
                icon="ph ph-x"
                color="white"
                @click="$emit('clear-selection')"
              >
                <q-tooltip>{{ $t('shop_admin.clear_selection') }}</q-tooltip>
              </q-btn>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-slide-transition>
</template>

<script setup lang="ts">
import { ref } from 'vue';

defineProps<{
  selectedCount: number;
  isApplying: boolean;
}>();

const emit = defineEmits<{
  (
    e: 'apply-markup',
    payload: {
      markupAmount: number;
      markupType: 'percentage' | 'fixed';
      targetPrice: 'sell_price' | 'min_sell_price';
    }
  ): void;
  (
    e: 'apply-qty-delta',
    payload: {
      qtyDelta: number;
      qtyOperation: 'add' | 'subtract' | 'set';
    }
  ): void;
  (e: 'bulk-remove'): void;
  (e: 'clear-selection'): void;
}>();

const markupAmount = ref<number>(20);
const markupType = ref<'percentage' | 'fixed'>('percentage');
const targetPrice = ref<'sell_price' | 'min_sell_price'>('sell_price');

const qtyDelta = ref<number>(10);
const qtyOperation = ref<'add' | 'subtract' | 'set'>('add');

const onApplyMarkup = () => {
  emit('apply-markup', {
    markupAmount: Number(markupAmount.value) || 0,
    markupType: markupType.value,
    targetPrice: targetPrice.value,
  });
};

const onApplyQtyDelta = () => {
  emit('apply-qty-delta', {
    qtyDelta: Number(qtyDelta.value) || 0,
    qtyOperation: qtyOperation.value,
  });
};
</script>

<style scoped>
.bg-white-transparent {
  background: rgba(255, 255, 255, 0.15);
}
</style>

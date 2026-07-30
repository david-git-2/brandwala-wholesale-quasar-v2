<template>
  <q-slide-transition>
    <q-card v-if="selectedCount > 0" flat bordered class="bg-white text-grey-9 q-mb-md">
      <q-card-section class="q-py-md q-px-lg">
        <div class="row items-center justify-between q-col-gutter-md wrap">
          <!-- Selected count badge -->
          <div class="col-auto row items-center">
            <q-chip color="primary" text-color="white" icon="ph ph-check-square-offset" class="text-weight-bold q-ma-none q-py-sm q-px-md">
              {{ $t('shop_admin.items_selected', { count: selectedCount }) }}
            </q-chip>
          </div>

          <div class="col-auto row items-center q-gutter-md wrap">
            <!-- Price Markup Controls -->
            <div class="row items-center q-gutter-x-sm">
              <q-select
                v-model="targetPrice"
                dense
                outlined
                options-dense
                emit-value
                map-options
                style="width: 140px"
                :options="[
                  { label: 'Sell Price', value: 'sell_price' },
                  { label: 'Dropship Floor', value: 'min_sell_price' },
                ]"
              />

              <q-btn-toggle
                v-model="markupType"
                dense
                unelevated
                toggle-color="primary"
                color="grey-2"
                text-color="grey-8"
                class="q-btn-toggle--custom"
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
                style="width: 100px"
                :suffix="markupType === 'percentage' ? '%' : ''"
                :label="markupType === 'percentage' ? 'Markup %' : 'Amount'"
                step="0.1"
                min="0"
              />

              <q-btn
                unelevated
                color="primary"
                class="q-px-md"
                icon="ph ph-lightning"
                :label="$t('shop_admin.apply_markup_selected')"
                :loading="isApplying"
                @click="onApplyMarkup"
              />
            </div>

            <q-separator vertical class="q-mx-sm self-stretch" />

            <!-- Quantity Adjustment Controls -->
            <div class="row items-center q-gutter-x-sm">
              <q-btn-toggle
                v-model="qtyOperation"
                dense
                unelevated
                toggle-color="primary"
                color="grey-2"
                text-color="grey-8"
                class="q-btn-toggle--custom"
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
                style="width: 100px"
                label="Qty Value"
                step="1"
                min="0"
              />

              <q-btn
                unelevated
                color="primary"
                class="q-px-md"
                icon="ph ph-plus-minus"
                label="Apply Qty"
                :loading="isApplying"
                @click="onApplyQtyDelta"
              >
                <q-tooltip>Adjust display quantity for non-manually locked items</q-tooltip>
              </q-btn>
            </div>

            <q-separator vertical class="q-mx-sm self-stretch" />

            <!-- Bulk Actions -->
            <div class="row items-center q-gutter-x-sm">
              <q-btn
                outline
                color="negative"
                class="q-px-md"
                icon="ph ph-trash"
                label="Remove Selected"
                @click="$emit('bulk-remove')"
              />

              <q-btn
                flat
                round
                dense
                icon="ph ph-x"
                color="grey-7"
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

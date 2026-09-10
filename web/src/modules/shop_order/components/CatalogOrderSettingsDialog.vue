<template>
  <q-dialog
    :model-value="modelValue"
    position="right"
    transition-show="jump-left"
    transition-hide="jump-right"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <q-card
      class="column no-wrap bg-white q-ma-md rounded-borders-lg overflow-hidden shadow-10"
      style="width: 480px; max-width: 95vw; height: calc(100vh - 32px); border-radius: 16px"
    >
      <div class="bg-grey-1 border-bottom q-px-sm">
        <q-tabs
          v-model="activeTab"
          dense
          no-caps
          active-color="primary"
          indicator-color="primary"
          align="justify"
          class="text-grey-7 text-weight-medium"
        >
          <q-tab name="summary" label="Summary" icon="ph ph-chart-pie-slice" />
          <q-tab name="actions" label="Actions" icon="ph ph-dots-three-outline" />
        </q-tabs>
      </div>

      <q-tab-panels v-model="activeTab" animated class="col bg-white overflow-auto">
        <q-tab-panel name="summary" class="q-pa-none bg-white">
          <CatalogOrderItemsSummaryCards
            :item-count="itemCount"
            :buy-currency-symbol="buyCurrencySymbol"
            :sell-currency-symbol="sellCurrencySymbol"
            :conversion-rate="conversionRate"
            :cargo-rate="cargoRate"
            :totals="totals"
          />
        </q-tab-panel>

        <q-tab-panel name="actions" class="q-pa-md bg-white">
          <div class="column q-gutter-y-sm">
            <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs q-mb-sm">
              <q-icon name="ph ph-dots-three-outline" size="18px" color="primary" />
              <span>Order actions</span>
            </div>

            <q-btn
              flat
              no-caps
              align="left"
              icon="ph ph-arrows-clockwise"
              label="Override status…"
              class="rounded-sq-btn action-list-btn"
              @click="emit('override-status')"
            />
            <q-btn
              v-if="showCancel"
              flat
              no-caps
              align="left"
              color="negative"
              icon="ph ph-trash"
              label="Cancel order"
              class="rounded-sq-btn action-list-btn"
              :loading="isDeleting"
              @click="emit('cancel-order')"
            />
          </div>
        </q-tab-panel>
      </q-tab-panels>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import CatalogOrderItemsSummaryCards from './CatalogOrderItemsSummaryCards.vue';

export type CatalogOrderSummaryTotals = {
  totalQuantity: number;
  totalWeightGm: number;
  grandTotalPurchasePrice: number;
  grandTotalLandedPurchase: number;
  grandTotalLandedSell: number;
  grandTotalFirstOffer: number;
  overallFirstOfferMargin: number;
  grandTotalCounterOffer: number;
  overallCounterOfferMargin: number;
  grandTotalFinalOffer: number;
  overallFinalOfferMargin: number;
};

defineProps<{
  modelValue: boolean;
  itemCount: number;
  buyCurrencySymbol: string;
  sellCurrencySymbol: string;
  conversionRate: number;
  cargoRate: number;
  totals: CatalogOrderSummaryTotals;
  showCancel?: boolean;
  isDeleting?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'override-status'): void;
  (e: 'cancel-order'): void;
}>();

const activeTab = ref('summary');
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.rounded-sq-btn {
  border-radius: 8px !important;
}

.action-list-btn {
  width: 100%;
}
</style>

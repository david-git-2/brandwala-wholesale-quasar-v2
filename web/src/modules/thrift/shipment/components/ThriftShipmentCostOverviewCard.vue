<template>
  <q-card flat class="floating-surface shadow-1">
    <q-card-section>
      <div class="text-subtitle2 text-weight-bold text-primary q-mb-md">
        SHIPMENT COST OVERVIEW
      </div>

      <div class="row q-col-gutter-md">
        <!-- Units Section -->
        <div class="col-12 col-md-3">
          <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">
            HOW COSTS ARE SPLIT
          </div>
          <div
            class="q-pa-sm bg-grey-1 rounded-borders h-100 column justify-center"
            style="min-height: 120px"
          >
            <div class="row justify-between items-center">
              <span class="text-body2 text-grey-8">Unit Count (U):</span>
              <span class="text-subtitle1 text-weight-bold text-grey-9">{{ totalUnits }}</span>
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              Cargo splits by item weight when set; ops bills divide by U.
            </div>
          </div>
        </div>

        <!-- Shipment Bills Section -->
        <div class="col-12 col-md-3">
          <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">
            SHIPMENT TOTALS ({{ costCurrencyCode || '—' }})
          </div>
          <div class="q-gutter-y-xs">
            <div class="row justify-between text-body2">
              <span class="text-grey-8">Cargo Total:</span>
              <span class="text-weight-medium">{{ formatCost(cargoCost) }}</span>
            </div>
            <div class="row justify-between text-body2">
              <span class="text-grey-8">Labor:</span>
              <span>{{ formatCost(costForm.labor_total_cost || 0) }}</span>
            </div>
            <div class="row justify-between text-body2">
              <span class="text-grey-8">Transport:</span>
              <span>{{ formatCost(costForm.transportation_total_cost || 0) }}</span>
            </div>
            <div class="row justify-between text-body2">
              <span class="text-grey-8">Washing:</span>
              <span>{{ formatCost(costForm.washing_total_cost || 0) }}</span>
            </div>
            <div class="row justify-between text-body2">
              <span class="text-grey-8">Hand tags (total):</span>
              <span>{{ formatCost(handTagTotal) }}</span>
            </div>
            <div class="row justify-between text-body2">
              <span class="text-grey-8">Stickers (total):</span>
              <span>{{ formatCost(stickerTotal) }}</span>
            </div>
            <q-separator class="q-my-xs" />
            <div class="row justify-between text-body2 text-weight-bold">
              <span class="text-grey-9">Ops Total:</span>
              <span class="text-primary">{{ formatCost(opsCost) }}</span>
            </div>
          </div>
        </div>

        <!-- Per Unit Share Section -->
        <div class="col-12 col-md-3">
          <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">
            PER-UNIT SHARE ({{ costCurrencyCode || '—' }})
          </div>
          <div class="q-gutter-y-sm">
            <div
              class="q-pa-sm bg-blue-1 rounded-borders"
              style="border: 1px solid rgba(33, 150, 243, 0.12)"
            >
              <div class="row justify-between items-baseline">
                <span class="text-caption text-blue-9">Cargo Share:</span>
                <span class="text-subtitle2 text-weight-bold text-blue-10">{{
                  formatCost(cargoSharePerUnit)
                }}</span>
              </div>
              <div class="text-caption text-grey-6" style="font-size: 10px">
                {{ usesWeightBasedCargo ? 'By weight (avg shown)' : 'Cargo Total ÷ U' }}
              </div>
            </div>
            <div
              class="q-pa-sm bg-orange-1 rounded-borders"
              style="border: 1px solid rgba(255, 152, 0, 0.12)"
            >
              <div class="row justify-between items-baseline">
                <span class="text-caption text-orange-9">Ops Share:</span>
                <span class="text-subtitle2 text-weight-bold text-orange-10">{{
                  formatCost(opsSharePerUnit)
                }}</span>
              </div>
              <div class="text-caption text-grey-6" style="font-size: 10px">
                Ops Total ÷ U
              </div>
            </div>
          </div>
        </div>

        <!-- Each Item Formula Section -->
        <div class="col-12 col-md-3">
          <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">
            PER-ITEM LANDED COST
          </div>
          <div
            class="q-pa-sm bg-teal-1 rounded-borders h-100 column justify-center"
            style="border: 1px solid rgba(0, 150, 136, 0.12); min-height: 120px"
          >
            <div class="text-caption text-teal-9 text-weight-bold q-mb-xs">
              Landed Cost Formula
            </div>
            <div class="text-caption text-grey-8" style="line-height: 1.4; font-size: 11px">
              <code>Product Cost</code> + <br />
              <code>Cargo Share</code> + <br />
              <code>Ops Share</code> + <br />
              <code>Add'l Charges</code>
            </div>
            <div class="text-caption text-grey-6 q-mt-xs" style="font-size: 10px">
              Computed per item from origin, weight-based cargo share, ops share, and add'l charges.
            </div>
          </div>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import type { CostFormState } from './ThriftShipmentCostInputsCard.vue';

defineProps<{
  costCurrencyCode?: string | undefined;
  totalUnits: number;
  cargoCost: number;
  costForm: CostFormState;
  handTagTotal: number;
  stickerTotal: number;
  opsCost: number;
  cargoSharePerUnit: number;
  opsSharePerUnit: number;
  usesWeightBasedCargo: boolean;
  formatCost: (amount: number) => string;
}>();
</script>

<style scoped>
.h-100 {
  height: 100%;
}
</style>

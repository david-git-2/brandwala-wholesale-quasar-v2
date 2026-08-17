<template>
  <div class="shipment-receive-tab-panel">
    <q-card
      v-if="shipment?.status === 'in_transit'"
      flat
      bordered
      class="q-pa-md bg-white text-grey-9 q-mb-md"
    >
      <div class="text-subtitle1 text-weight-bold text-primary q-mb-sm">Checklist</div>
      <div class="text-caption text-grey-7 q-mb-md">
        Complete each step before adding this shipment to stock.
      </div>
      <q-list dense separator>
        <q-item clickable @click="$emit('go-tab', 'lines')">
          <q-item-section avatar>
            <q-icon
              :name="hasLineItems ? 'ph ph-check-circle' : 'ph ph-circle'"
              :color="hasLineItems ? 'positive' : 'grey-5'"
            />
          </q-item-section>
          <q-item-section>
            <q-item-label>Items added</q-item-label>
            <q-item-label caption>{{
              hasLineItems
                ? `${currentShipmentItemsCount} products`
                : 'Add products on the Items tab'
            }}</q-item-label>
          </q-item-section>
        </q-item>
        <q-item clickable @click="$emit('go-tab', 'balance')">
          <q-item-section avatar>
            <q-icon
              :name="
                !hasCargoInvoiceWeight || !weightNeedsAttention
                  ? 'ph ph-check-circle'
                  : 'ph ph-circle'
              "
              :color="
                !hasCargoInvoiceWeight || !weightNeedsAttention ? 'positive' : 'grey-5'
              "
            />
          </q-item-section>
          <q-item-section>
            <q-item-label>Weight matched</q-item-label>
            <q-item-label caption>{{
              !hasCargoInvoiceWeight
                ? 'No cargo invoice weight set (optional skip)'
                : weightNeedsAttention
                  ? 'Invoice weight still differs from line weights'
                  : 'Line weights match cargo invoice'
            }}</q-item-label>
          </q-item-section>
        </q-item>
        <q-item clickable @click="$emit('go-tab', 'balance')">
          <q-item-section avatar>
            <q-icon
              :name="!purchaseNeedsAttention ? 'ph ph-check-circle' : 'ph ph-circle'"
              :color="!purchaseNeedsAttention ? 'positive' : 'grey-5'"
            />
          </q-item-section>
          <q-item-section>
            <q-item-label>Purchase matched</q-item-label>
            <q-item-label caption>{{
              !hasProductCostEntry
                ? 'No product cost entry amount set (optional skip)'
                : purchaseNeedsAttention
                  ? 'Paid invoice still differs from line purchases'
                  : 'Line purchases match paid invoice'
            }}</q-item-label>
          </q-item-section>
        </q-item>
        <q-item clickable @click="$emit('go-tab', 'lines')">
          <q-item-section avatar>
            <q-icon
              :name="isSplitsComplete ? 'ph ph-check-circle' : 'ph ph-circle'"
              :color="isSplitsComplete ? 'positive' : 'orange'"
            />
          </q-item-section>
          <q-item-section>
            <q-item-label>Splits complete</q-item-label>
            <q-item-label caption>{{
              isSplitsComplete
                ? `${splitsSummary.totalAllocated} / ${splitsSummary.totalOrdered} pcs allocated`
                : 'Configure quantity splits on the Items tab'
            }}</q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card>

    <q-card
      v-if="shipment?.status === 'in_transit'"
      flat
      bordered
      class="q-pa-md bg-white text-grey-9 q-mb-md"
    >
      <div class="row items-center justify-between q-mb-md">
        <div class="text-subtitle1 text-weight-bold text-primary">
          Quantity Splits Summary
        </div>
        <q-chip
          dense
          square
          :color="splitsSummary.isComplete ? 'green-1' : 'orange-1'"
          :text-color="splitsSummary.isComplete ? 'green-9' : 'orange-9'"
          class="text-weight-bold"
        >
          {{ splitsSummary.isComplete ? 'Complete' : 'Pending Splits' }}
        </q-chip>
      </div>

      <div class="q-gutter-y-sm">
        <div
          v-for="item in splitsSummary.breakdown"
          :key="item.id"
          class="row justify-between items-center q-py-xs"
          style="border-bottom: 1px dashed rgba(0, 0, 0, 0.08)"
        >
          <div class="column">
            <span class="text-subtitle2 text-weight-bold" style="line-height: 1.2">{{
              item.description
            }}</span>
            <span class="text-caption text-grey-6" style="font-size: 11px">
              {{ item.is_sellable ? 'Sellable Pool' : 'Non-Sellable Pool' }}
            </span>
          </div>
          <div class="text-subtitle2 text-weight-bold text-primary">
            {{ item.quantity }} pcs
          </div>
        </div>

        <div
          v-if="splitsSummary.breakdown.length === 0"
          class="text-center text-grey-6 q-py-md"
        >
          No splits yet. Split items on the Items tab first.
        </div>

        <q-separator class="q-my-sm" />

        <div
          class="row justify-between items-center q-py-sm bg-grey-1 q-px-sm rounded-borders"
        >
          <span class="text-caption text-weight-medium text-grey-8">Total Allocated:</span>
          <span class="text-subtitle2 text-weight-bolder text-primary">
            {{ splitsSummary.totalAllocated }} / {{ splitsSummary.totalOrdered }} pcs
          </span>
        </div>
      </div>

      <q-btn
        :color="isSplitsComplete ? 'green-7' : 'grey-5'"
        :disable="!isSplitsComplete"
        unelevated
        class="full-width q-mt-md text-weight-bold text-white"
        icon="ph ph-check-circle"
        label="Add to stock"
        no-caps
        @click="$emit('change-status', 'received')"
      >
        <q-tooltip v-if="!isSplitsComplete">
          Split every item first
        </q-tooltip>
      </q-btn>
    </q-card>

    <q-card
      v-if="shipment?.status === 'received'"
      flat
      bordered
      class="q-pa-md"
    >
      <div class="text-subtitle1 text-weight-bold text-negative q-mb-sm">Rollback</div>
      <div class="text-body2 text-grey-7 q-mb-md">
        Stock is already in the warehouse. Rollback deletes that stock and returns this shipment to Draft.
      </div>
      <q-btn
        color="negative"
        unelevated
        class="full-width text-weight-bold text-white"
        icon="ph ph-clock-counter-clockwise"
        label="Rollback shipment to Draft"
        no-caps
        :loading="updatingStatus"
        @click="$emit('rollback')"
      />
    </q-card>
  </div>
</template>

<script setup lang="ts">
import type { GlobalShipment } from '../repositories/globalShipmentRepository';

defineProps<{
  shipment: GlobalShipment | null;
  hasLineItems: boolean;
  currentShipmentItemsCount: number;
  hasCargoInvoiceWeight: boolean;
  weightNeedsAttention: boolean;
  purchaseNeedsAttention: boolean;
  hasProductCostEntry: boolean;
  isSplitsComplete: boolean;
  splitsSummary: {
    breakdown: Array<{ id: string; description: string; is_sellable: boolean; quantity: number }>;
    totalAllocated: number;
    totalOrdered: number;
    isComplete: boolean;
  };
  updatingStatus: boolean;
}>();

defineEmits<{
  'go-tab': [tab: 'lines' | 'balance'];
  'change-status': [status: string];
  rollback: [];
}>();
</script>

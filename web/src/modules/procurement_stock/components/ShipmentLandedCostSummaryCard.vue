<template>
  <q-card flat bordered class="q-pa-md bg-white text-grey-9 shipment-landed-cost-summary-card">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-subtitle1 text-weight-bold text-primary">Landed Cost Summary</div>
    </div>

    <div class="q-mb-md">
      <div
        class="text-xs text-weight-bold text-grey-6 uppercase q-mb-xs"
        style="font-size: 11px; letter-spacing: 0.5px"
      >
        Shipment Totals
      </div>
      <div class="row justify-between q-py-xs">
        <span class="text-caption text-grey-7">Total Quantity:</span>
        <span class="text-subtitle2 text-weight-bold">{{ totals.quantity }} pcs</span>
      </div>
      <div class="row justify-between q-py-xs">
        <span class="text-caption text-grey-7">Packaging Weight:</span>
        <span class="text-subtitle2 text-weight-bold"
          >{{ totals.packagingWeightKg.toFixed(2) }} kg</span
        >
      </div>
      <div class="row justify-between q-py-xs" v-if="hasCargoInvoiceWeight">
        <span class="text-caption text-grey-7">Invoice Weight:</span>
        <span class="text-subtitle2 text-weight-bold text-primary"
          >{{ totals.cargoWeightKg.toFixed(2) }} kg</span
        >
      </div>
      <div class="row justify-between q-py-xs">
        <span class="text-caption text-grey-7">Box Weight Sum:</span>
        <span class="text-subtitle2 text-weight-bold"
          >{{ currentShipmentBoxesTotal.toFixed(2) }} kg</span
        >
      </div>
    </div>

    <q-separator class="q-my-sm" />

    <div class="q-mb-md">
      <div
        class="text-xs text-weight-bold text-grey-6 uppercase q-mb-xs"
        style="font-size: 11px; letter-spacing: 0.5px"
      >
        Purchase Currency ({{ currentPurchaseCurrencySymbol }})
      </div>
      <div class="row justify-between q-py-xs">
        <span class="text-caption text-grey-7">Product Purchase Cost:</span>
        <span class="text-subtitle2 text-weight-bold">
          {{ currentPurchaseCurrencySymbol
          }}{{
            totals.goodsPurchase.toLocaleString(undefined, {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2,
            })
          }}
        </span>
      </div>
      <div
        class="row justify-between q-py-xs"
        v-if="totals.cargoPurchase > 0"
      >
        <span class="text-caption text-grey-7">Cargo Cost:</span>
        <div class="text-right">
          <div class="text-subtitle2 text-weight-bold">
            {{ currentPurchaseCurrencySymbol
            }}{{
              totals.cargoPurchase.toLocaleString(undefined, {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })
            }}
          </div>
          <div class="text-caption text-grey-5" style="font-size: 10px">
            {{ cargoCostWeightLabel }}
          </div>
        </div>
      </div>
      <div class="row justify-between q-py-xs bg-grey-1 q-px-sm rounded-borders">
        <span class="text-caption text-weight-medium text-grey-8"
          >Total Purchase Cost:</span
        >
        <span class="text-subtitle2 text-weight-bold text-primary">
          {{ currentPurchaseCurrencySymbol
          }}{{
            totals.totalPurchase.toLocaleString(undefined, {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2,
            })
          }}
        </span>
      </div>
    </div>

    <template v-if="shipmentType === 'international'">
      <q-separator class="q-my-sm" />
      <div class="q-mb-md">
        <div
          class="text-xs text-weight-bold text-grey-6 uppercase q-mb-xs"
          style="font-size: 11px; letter-spacing: 0.5px"
        >
          Cost Currency ({{ currentCostCurrencySymbol }})
        </div>
        <div class="row justify-between q-py-xs">
          <span class="text-caption text-grey-7">Product Cost:</span>
          <span class="text-subtitle2 text-weight-bold">
            {{ currentCostCurrencySymbol
            }}{{
              totals.goodsCost.toLocaleString(undefined, {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })
            }}
          </span>
        </div>
        <div
          class="row justify-between q-py-xs"
          v-if="totals.cargoPurchase > 0"
        >
          <span class="text-caption text-grey-7">Cargo Cost:</span>
          <span class="text-subtitle2 text-weight-bold">
            {{ currentCostCurrencySymbol
            }}{{
              totals.cargoCost.toLocaleString(undefined, {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })
            }}
          </span>
        </div>
        <div
          class="row justify-between items-center q-py-sm bg-primary text-white q-px-sm rounded-borders"
        >
          <span class="text-subtitle2 text-weight-bold">Total Cost:</span>
          <span class="text-h6 text-weight-bolder">
            {{ currentCostCurrencySymbol
            }}{{
              totals.totalCost.toLocaleString(undefined, {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })
            }}
          </span>
        </div>
      </div>

      <div class="bg-blue-1 text-blue-10 q-pa-sm rounded-borders text-center">
        <div
          class="text-caption text-weight-medium uppercase"
          style="font-size: 10px; letter-spacing: 0.5px"
        >
          Live Blended Transaction Rate
        </div>
        <div class="text-h5 text-weight-bolder q-my-xs">
          {{
            totals.transactionRate !== null
              ? `${currentCostCurrencySymbol}${totals.transactionRate.toFixed(4)}`
              : '-'
          }}
        </div>
        <div class="text-caption text-blue-8" style="font-size: 10px; line-height: 1.2">
          {{ transactionRateWeightLabel }}
        </div>
      </div>
    </template>
  </q-card>
</template>

<script setup lang="ts">
defineProps<{
  totals: {
    quantity: number;
    packagingWeightKg: number;
    cargoWeightKg: number;
    goodsPurchase: number;
    cargoPurchase: number;
    totalPurchase: number;
    goodsCost: number;
    cargoCost: number;
    totalCost: number;
    transactionRate: number | null;
    lineLandedCostTotal: number;
  };
  hasCargoInvoiceWeight: boolean;
  currentShipmentBoxesTotal: number;
  currentPurchaseCurrencySymbol: string;
  currentCostCurrencySymbol: string;
  cargoCostWeightLabel: string;
  transactionRateWeightLabel: string;
  shipmentType?: 'international' | 'local' | 'transfer' | undefined;
  isCostFinalized?: boolean;
}>();

defineEmits<{
  (e: 'section-matched'): void;
}>();
</script>

<style scoped>
.shipment-landed-cost-summary-card {
  position: sticky;
  top: 16px;
  z-index: 1;
}
</style>

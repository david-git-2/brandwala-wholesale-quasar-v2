<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Shipment Accounting"
        @click="onBack"
      />
    </div>

    <PageInitialLoader v-if="shipmentStore.loading" />

    <q-banner v-else-if="shipmentStore.error" class="bg-red-1 text-negative q-mb-md">
      {{ shipmentStore.error }}
    </q-banner>

    <template v-else-if="shipmentStore.selectedShipment">
      <p class="text-h6 text-weight-bold q-mb-sm">
        #{{ shipmentStore.selectedShipment.id }} {{ shipmentStore.selectedShipment.name }}
      </p>
      <p class="text-body2 text-grey-8 q-mb-xs">Status: {{ shipmentStore.selectedShipment.status }}</p>
      <p class="text-body2 text-grey-8 q-mb-md">Items: {{ shipmentStore.shipmentItems.length }}</p>
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-sm-4">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Total Cost by Quantity (BDT)</div>
              <div class="text-h6 text-weight-bold">{{ formatFixed2(totalQuantityCostBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-4">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Total Received Cost (BDT)</div>
              <div class="text-h6 text-weight-bold">{{ formatFixed2(totalReceivedCostBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-4">
          <q-card flat bordered>
            <q-card-section>
              <div class="text-caption text-grey-8">Total Loss (BDT)</div>
              <div class="text-h6 text-weight-bold text-negative">{{ formatFixed2(totalLossBdt) }}</div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <q-markup-table flat bordered wrap-cells>
        <thead>
          <tr>
            <th class="text-left">SL</th>
            <th class="text-left">Name</th>
            <th class="text-right">Cost/Unit (BDT)</th>
            <th class="text-right">Qty</th>
            <th class="text-right">Received Total (BDT)</th>
            <th class="text-right">Loss Total (BDT)</th>
            <th class="text-right">Received</th>
            <th class="text-right">Damaged</th>
            <th class="text-right">Stolen</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!shipmentStore.shipmentItems.length">
            <td colspan="9" class="text-center text-grey-7">No shipment items found.</td>
          </tr>
          <tr v-for="(item, index) in shipmentRows" :key="item.id">
            <td>{{ index + 1 }}</td>
            <td>{{ item.name ?? '-' }}</td>
            <td class="text-right">{{ formatFixed2(item.costPerUnitBdt) }}</td>
            <td class="text-right">{{ item.quantity }}</td>
            <td class="text-right">{{ formatFixed2(item.receivedTotalBdt) }}</td>
            <td class="text-right text-negative">{{ formatFixed2(item.lossTotalBdt) }}</td>
            <td class="text-right">{{ item.received_quantity }}</td>
            <td class="text-right">{{ item.damaged_quantity }}</td>
            <td class="text-right">{{ item.stolen_quantity }}</td>
          </tr>
          <tr v-if="shipmentRows.length" class="text-weight-bold">
            <td colspan="4" class="text-right">Total Received Cost</td>
            <td class="text-right">{{ formatFixed2(totalReceivedCostBdt) }}</td>
            <td class="text-right text-negative">{{ formatFixed2(totalLossBdt) }}</td>
            <td colspan="3"></td>
          </tr>
        </tbody>
      </q-markup-table>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { calculateCostBdt } from 'src/modules/shipment/utils/costing'

const route = useRoute()
const router = useRouter()
const shipmentStore = useShipmentStore()

const shipmentId = computed(() => {
  const parsed = Number(route.params.id)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
})

const shipmentRows = computed(() => {
  const shipment = shipmentStore.selectedShipment
  return (shipmentStore.shipmentItems ?? []).map((item) => {
    const costPerUnitBdt = calculateCostBdt({
      productWeight: item.product_weight,
      packageWeight: item.package_weight,
      cargoRate: shipment?.cargo_rate,
      priceGbp: item.price_gbp,
      productConversionRate: shipment?.product_conversion_rate,
      cargoConversionRate: shipment?.cargo_conversion_rate,
    })
    return {
      ...item,
      costPerUnitBdt,
      quantityTotalBdt: costPerUnitBdt * Number(item.quantity ?? 0),
      receivedTotalBdt: costPerUnitBdt * Number(item.received_quantity ?? 0),
      lossTotalBdt:
        costPerUnitBdt * (Number(item.stolen_quantity ?? 0) + Number(item.damaged_quantity ?? 0)),
    }
  })
})

const totalQuantityCostBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.quantityTotalBdt, 0),
)

const totalReceivedCostBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.receivedTotalBdt, 0),
)

const totalLossBdt = computed(() =>
  shipmentRows.value.reduce((sum, item) => sum + item.lossTotalBdt, 0),
)

const formatFixed2 = (value: number | null | undefined) => {
  const parsed = Number(value ?? 0)
  return Number.isFinite(parsed) ? parsed.toFixed(2) : '0.00'
}

const fetchDetails = async () => {
  if (!shipmentId.value) {
    return
  }
  await shipmentStore.fetchShipmentById(shipmentId.value)
}

const onBack = async () => {
  await router.push({
    name: 'app-accounting-shipment-page',
    params: { tenantSlug: route.params.tenantSlug },
  })
}

onMounted(() => {
  void fetchDetails()
})

watch(
  () => route.params.id,
  () => {
    void fetchDetails()
  },
)
</script>

<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5 text-weight-bold">Inventory Accounting Summary</div>
      <q-btn
        color="primary"
        no-caps
        icon="refresh"
        label="Refresh Summary"
        :loading="inventoryStore.saving"
        @click="onRefreshSummary"
      />
    </div>

    <div class="row q-col-gutter-md q-mb-md">
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-caption text-grey-8">Usable Qty</div>
            <div class="text-h6 text-weight-bold">{{ totals.usableQty }}</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-caption text-grey-8">Damaged Qty</div>
            <div class="text-h6 text-weight-bold">{{ totals.damagedQty }}</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-caption text-grey-8">Stolen Qty</div>
            <div class="text-h6 text-weight-bold">{{ totals.stolenQty }}</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-caption text-grey-8">Expired Qty</div>
            <div class="text-h6 text-weight-bold">{{ totals.expiredQty }}</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-caption text-grey-8">Open Box Qty</div>
            <div class="text-h6 text-weight-bold">{{ totals.openBoxQty }}</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <q-markup-table flat bordered wrap-cells>
      <thead>
        <tr>
          <th class="text-left">SL</th>
          <th class="text-left">Shipment</th>
          <th class="text-left">Status</th>
          <th class="text-right">Usable Qty</th>
          <th class="text-right">Damaged Qty</th>
          <th class="text-right">Stolen Qty</th>
          <th class="text-right">Expired Qty</th>
          <th class="text-right">Open Box Qty</th>
          <th class="text-right">Usable Cost</th>
          <th class="text-right">Damaged Cost</th>
          <th class="text-right">Stolen Cost</th>
          <th class="text-right">Expired Cost</th>
          <th class="text-right">Open Box Cost</th>
          <th class="text-right">Total Inventory Cost</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!visibleSummaries.length && !inventoryStore.loading">
          <td colspan="14" class="text-center text-grey-7">No shipment inventory accounting summary found.</td>
        </tr>
        <tr
          v-for="(row, index) in visibleSummaries"
          :key="row.id"
        >
          <td>{{ index + 1 }}</td>
          <td>#{{ row.shipment_id }} {{ row.shipment_name ?? '-' }}</td>
          <td>{{ row.shipment_status ?? '-' }}</td>
          <td class="text-right">{{ row.usable_quantity }}</td>
          <td class="text-right">{{ row.damaged_quantity }}</td>
          <td class="text-right">{{ row.stolen_quantity }}</td>
          <td class="text-right">{{ row.expired_quantity }}</td>
          <td class="text-right">{{ row.open_box_quantity }}</td>
          <td class="text-right">{{ formatFixed2(row.usable_cost_total) }}</td>
          <td class="text-right">{{ formatFixed2(row.damaged_cost_total) }}</td>
          <td class="text-right">{{ formatFixed2(row.stolen_cost_total) }}</td>
          <td class="text-right">{{ formatFixed2(row.expired_cost_total) }}</td>
          <td class="text-right">{{ formatFixed2(row.open_box_cost_total) }}</td>
          <td class="text-right text-weight-bold">{{ formatFixed2(row.inventory_cost_total) }}</td>
        </tr>
        <tr v-if="visibleSummaries.length" class="text-weight-bold">
          <td colspan="3" class="text-right">Total</td>
          <td class="text-right">{{ totals.usableQty }}</td>
          <td class="text-right">{{ totals.damagedQty }}</td>
          <td class="text-right">{{ totals.stolenQty }}</td>
          <td class="text-right">{{ totals.expiredQty }}</td>
          <td class="text-right">{{ totals.openBoxQty }}</td>
          <td class="text-right">{{ formatFixed2(totals.usableCost) }}</td>
          <td class="text-right">{{ formatFixed2(totals.damagedCost) }}</td>
          <td class="text-right">{{ formatFixed2(totals.stolenCost) }}</td>
          <td class="text-right">{{ formatFixed2(totals.expiredCost) }}</td>
          <td class="text-right">{{ formatFixed2(totals.openBoxCost) }}</td>
          <td class="text-right">{{ formatFixed2(totals.totalCost) }}</td>
        </tr>
      </tbody>
    </q-markup-table>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInventoryStore } from 'src/modules/inventory/stores/inventoryStore'
import { formatAmountBdt } from 'src/utils/currency'

const authStore = useAuthStore()
const inventoryStore = useInventoryStore()

const visibleSummaries = computed(() =>
  inventoryStore.shipmentInventoryAccountingSummaries.filter(
    (row) =>
      Number(row.usable_quantity ?? 0) > 0 ||
      Number(row.damaged_quantity ?? 0) > 0 ||
      Number(row.stolen_quantity ?? 0) > 0 ||
      Number(row.expired_quantity ?? 0) > 0 ||
      Number(row.open_box_quantity ?? 0) > 0 ||
      Number(row.inventory_cost_total ?? 0) > 0,
  ),
)

const totals = computed(() =>
  visibleSummaries.value.reduce(
    (sum, row) => ({
      usableQty: sum.usableQty + row.usable_quantity,
      damagedQty: sum.damagedQty + row.damaged_quantity,
      stolenQty: sum.stolenQty + row.stolen_quantity,
      expiredQty: sum.expiredQty + row.expired_quantity,
      openBoxQty: sum.openBoxQty + row.open_box_quantity,
      usableCost: sum.usableCost + row.usable_cost_total,
      damagedCost: sum.damagedCost + row.damaged_cost_total,
      stolenCost: sum.stolenCost + row.stolen_cost_total,
      expiredCost: sum.expiredCost + row.expired_cost_total,
      openBoxCost: sum.openBoxCost + row.open_box_cost_total,
      totalCost: sum.totalCost + row.inventory_cost_total,
    }),
    {
      usableQty: 0,
      damagedQty: 0,
      stolenQty: 0,
      expiredQty: 0,
      openBoxQty: 0,
      usableCost: 0,
      damagedCost: 0,
      stolenCost: 0,
      expiredCost: 0,
      openBoxCost: 0,
      totalCost: 0,
    },
  ),
)

const formatFixed2 = (value: number | null | undefined) => formatAmountBdt(value)

const loadSummaries = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    return
  }
  await inventoryStore.fetchShipmentInventoryAccountingSummaries({
    tenant_id: tenantId,
    page: 1,
    page_size: 200,
    sortBy: 'shipment_id',
    sortOrder: 'desc',
  })
}

const onRefreshSummary = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    return
  }
  const refreshResult = await inventoryStore.refreshShipmentInventoryAccountingSummaries({
    tenant_id: tenantId,
  })
  if (!refreshResult.success) {
    return
  }
  await loadSummaries()
}

onMounted(() => {
  void onRefreshSummary()
})
</script>

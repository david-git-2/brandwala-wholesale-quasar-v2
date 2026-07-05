<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn flat color="primary" icon="arrow_back" label="Back to Investor Shipments" @click="onBack" />
      <q-btn
        color="secondary"
        icon="refresh"
        label="Refresh Profits"
        unelevated
        :loading="capitalStore.saving"
        @click="onRefreshProfits"
      />
    </div>

    <div v-if="shipmentStore.selectedShipment" class="q-mb-md">
      <div class="text-h6 text-weight-bold">
        #{{ shipmentStore.selectedShipment.tenant_shipment_id ?? shipmentStore.selectedShipment.id }} {{ shipmentStore.selectedShipment.name }}
      </div>
      <div class="text-body2 text-grey-8">Status: {{ shipmentStore.selectedShipment.status }}</div>
      <div class="text-body2 text-grey-8">Total Shipment Cost (BDT): {{ formatAmount(totalShipmentCost) }}</div>
    </div>

    <!-- Parent Remainder Banner -->
    <q-banner v-slot:avatar v-if="parentRemainderPct > 0" class="bg-amber-1 text-amber-9 q-mb-md rounded-borders">
      <q-icon name="warning" color="warning" size="md" class="q-mr-sm" />
      Parent company retains <strong>{{ parentRemainderPct.toFixed(2) }}%</strong> remainder cost share of this shipment batch.
    </q-banner>

    <q-tabs v-model="activeTab" dense class="text-primary q-mb-md" align="left">
      <q-tab name="allocate" label="Allocate Investment" />
      <q-tab name="investments" label="Shipment Investments" />
    </q-tabs>

    <q-tab-panels v-model="activeTab" animated>
      <q-tab-panel name="allocate" class="q-pa-none">
        <q-markup-table flat bordered wrap-cells>
          <thead>
            <tr>
              <th class="text-left">Investor</th>
              <th class="text-right">Available Balance</th>
              <th class="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!capitalStore.investors.length">
              <td colspan="3" class="text-center text-grey-7">No investors found.</td>
            </tr>
            <tr v-for="investor in capitalStore.investors" :key="investor.investor_id">
              <td>{{ investor.name }}</td>
              <td class="text-right">{{ formatAmount(investor.available_balance) }}</td>
              <td class="text-right">
                <q-btn
                  color="primary"
                  size="sm"
                  label="Add Share"
                  :disable="parentRemainderPct <= 0 || hasExistingInvestment(investor.investor_id)"
                  @click="openAddDialog(investor)"
                />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-tab-panel>

      <q-tab-panel name="investments" class="q-pa-none">
        <q-markup-table flat bordered wrap-cells>
          <thead>
            <tr>
              <th class="text-left">SL</th>
              <th class="text-left">Investor</th>
              <th class="text-right">Cost Share %</th>
              <th class="text-right">Allocated cost</th>
              <th class="text-right">Computed profit</th>
              <th class="text-left">Status</th>
              <th class="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!capitalStore.shipmentInvestments.length">
              <td colspan="7" class="text-center text-grey-7">No shipment investments found.</td>
            </tr>
            <tr v-for="(row, index) in capitalStore.shipmentInvestments" :key="row.id">
              <td>{{ index + 1 }}</td>
              <td>{{ investorNameById(row.investor_id) }}</td>
              <td class="text-right text-weight-bold">{{ row.cost_share_pct }}%</td>
              <td class="text-right">{{ formatAmount(row.allocated_cost) }}</td>
              <td class="text-right text-weight-bold text-positive">{{ formatAmount(row.computed_profit) }}</td>
              <td>{{ row.profit_status || row.status }}</td>
              <td class="text-right">
                <q-btn flat round dense icon="more_vert">
                  <q-menu auto-close>
                    <q-list dense style="min-width: 140px">
                      <q-item clickable v-ripple @click="openEditDialog(row)">
                        <q-item-section>Edit</q-item-section>
                      </q-item>
                      <q-item clickable v-ripple @click="openDeleteDialog(row)">
                        <q-item-section class="text-negative">Delete</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-tab-panel>
    </q-tab-panels>

    <ShipmentShareEditor
      v-model="openDialog"
      :initial-data="editingInvestment"
      :investors="capitalStore.investors"
      :remaining-pct="parentRemainderPct"
      :tenant-id="resolvedTenantId"
      :global-shipment-id="shipmentId"
      @save="saveInvestment"
    />

    <q-dialog v-model="openDeleteConfirmDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete this cost share allocation?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteConfirmDialog = false" />
          <q-btn color="negative" label="Delete" @click="deleteInvestment" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvestorCapitalStore } from 'src/modules/investor_capital/stores/investorCapitalStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { calculateCostBdt } from 'src/modules/shipment/utils/costing'
import type { ShipmentInvestment, InvestorBalance } from 'src/modules/investor_capital/types'
import { formatAmountBdt } from 'src/utils/currency'
import ShipmentShareEditor from '../../components/ShipmentShareEditor.vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const capitalStore = useInvestorCapitalStore()
const shipmentStore = useShipmentStore()

const activeTab = ref<'allocate' | 'investments'>('investments')
const openDialog = ref(false)
const openDeleteConfirmDialog = ref(false)
const editingInvestment = ref<ShipmentInvestment | null>(null)
const deletingInvestment = ref<ShipmentInvestment | null>(null)

const resolvedTenantId = computed(() => authStore.tenantId ?? 0)

const shipmentId = computed(() => {
  const parsed = Number(route.params.id)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
})

const totalShipmentCost = computed(() => {
  const shipment = shipmentStore.selectedShipment
  return shipmentStore.shipmentItems.reduce((sum, item) => {
    const unitCost = shipment && shipment.shipment_type === 'local'
      ? Number(item.cost_bdt ?? 0)
      : calculateCostBdt({
          productWeight: item.product_weight,
          packageWeight: item.package_weight,
          cargoRate: shipment?.cargo_rate,
          priceGbp: item.price_gbp,
          transactionRate: shipment?.transaction_rate,
          productConversionRate: shipment?.product_conversion_rate,
          cargoConversionRate: shipment?.cargo_conversion_rate,
        })
    return sum + unitCost * Number(item.quantity ?? 0)
  }, 0)
})

// Calculate parent remainder percentage (100 - sum of cost share % of active allocations)
const parentRemainderPct = computed(() => {
  const sum = capitalStore.shipmentInvestments.reduce(
    (acc, item) => acc + Number(item.cost_share_pct ?? 0),
    0
  )
  return Math.max(0, 100 - sum)
})

const formatAmount = (value: number | null | undefined) => formatAmountBdt(value)

const investorNameById = (investorId: number) =>
  capitalStore.investors.find((item) => item.investor_id === investorId)?.name ?? `#${investorId}`

const hasExistingInvestment = (investorId: number) =>
  capitalStore.shipmentInvestments.some((item) => item.investor_id === investorId)

const openAddDialog = (investor: InvestorBalance) => {
  editingInvestment.value = null
  openDialog.value = true
}

const openEditDialog = (row: ShipmentInvestment) => {
  editingInvestment.value = row
  openDialog.value = true
}

const openDeleteDialog = (row: ShipmentInvestment) => {
  deletingInvestment.value = row
  openDeleteConfirmDialog.value = true
}

const saveInvestment = async (payload: { id: number | null; investor_id: number; cost_share_pct: number }) => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) return

  await capitalStore.upsertShipmentInvestment({
    id: payload.id,
    tenant_id: tenantId,
    global_shipment_id: shipmentId.value,
    investor_id: payload.investor_id,
    cost_share_pct: payload.cost_share_pct,
  })

  openDialog.value = false
}

const deleteInvestment = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !deletingInvestment.value) return

  await capitalStore.deleteShipmentInvestment({
    id: deletingInvestment.value.id,
    tenant_id: tenantId,
    global_shipment_id: shipmentId.value,
  })

  deletingInvestment.value = null
  openDeleteConfirmDialog.value = false
}

const onRefreshProfits = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) return
  await capitalStore.refreshProfits(tenantId, shipmentId.value)
}

const load = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) return

  await Promise.all([
    shipmentStore.fetchShipmentById(shipmentId.value),
    capitalStore.fetchInvestorsByTenant(tenantId),
    capitalStore.fetchShipmentInvestmentsByShipment(tenantId, shipmentId.value),
  ])
}

const onBack = async () => {
  await router.push({
    name: 'app-capital-shipments-page',
    params: { tenantSlug: authStore.tenantSlug ?? undefined },
  })
}

onMounted(() => {
  void load()
})
</script>

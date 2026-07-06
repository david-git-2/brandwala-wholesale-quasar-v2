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

    <div v-if="shipmentStore.currentShipment" class="q-mb-md">
      <div class="text-h6 text-weight-bold">
        #{{ shipmentStore.currentShipment.tenant_shipment_id ?? shipmentStore.currentShipment.id }} {{ shipmentStore.currentShipment.name }}
      </div>
      <div class="text-body2 text-grey-8">Status: {{ shipmentStore.currentShipment.status }}</div>
      <div class="text-body2 text-grey-8">Total Shipment Cost (BDT): {{ formatAmount(totalShipmentCost) }}</div>
    </div>

    <!-- Parent Remainder Banner -->
    <q-banner v-if="parentRemainderPct > 0" class="bg-amber-1 text-amber-9 q-mb-md rounded-borders">
      <template #avatar>
        <q-icon name="warning" color="warning" size="md" class="q-mr-sm" />
      </template>
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
              <td class="text-left">{{ investor.name }}</td>
              <td class="text-right">BDT {{ formatAmount(investor.balance) }}</td>
              <td class="text-right">
                <q-btn
                  color="primary"
                  label="Allocate"
                  dense
                  flat
                  no-caps
                  :disabled="hasExistingInvestment(investor.investor_id) || parentRemainderPct <= 0"
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
              <th class="text-left">Investor</th>
              <th class="text-right">Cost Share</th>
              <th class="text-right">Profit Share</th>
              <th class="text-right">Allocated Cost</th>
              <th class="text-right">Realized Profit</th>
              <th class="text-right">Status</th>
              <th class="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!capitalStore.shipmentInvestments.length">
              <td colspan="7" class="text-center text-grey-7">No shipment investments found.</td>
            </tr>
            <tr v-for="row in capitalStore.shipmentInvestments" :key="row.id">
              <td class="text-left">{{ investorNameById(row.investor_id) }}</td>
              <td class="text-right">{{ row.cost_share_pct }}%</td>
              <td class="text-right">{{ row.cost_share_pct }}%</td>
              <td class="text-right">BDT {{ formatAmount(row.allocated_cost) }}</td>
              <td class="text-right">BDT {{ formatAmount(row.computed_profit) }}</td>
              <td class="text-right">
                <q-badge :color="row.profit_status === 'distributed' ? 'green' : 'orange'">
                  {{ row.profit_status }}
                </q-badge>
              </td>
              <td class="text-right">
                <q-btn flat round dense icon="more_vert" color="grey-7">
                  <q-menu>
                    <q-list dense style="min-width: 100px">
                      <q-item clickable v-close-popup @click="openEditDialog(row)">
                        <q-item-section>Edit</q-item-section>
                      </q-item>
                      <q-item clickable v-close-popup class="text-negative" @click="openDeleteDialog(row)">
                        <q-item-section>Delete</q-item-section>
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
import { useGlobalShipmentStore } from 'src/modules/procurement_stock/stores/globalShipmentStore'
import { calculateLineLandedCostBdt } from 'src/modules/procurement_stock/utils/landedCost'
import type { ShipmentInvestment } from 'src/modules/investor_capital/types'
import { formatAmountBdt } from 'src/utils/currency'
import ShipmentShareEditor from '../../components/ShipmentShareEditor.vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const capitalStore = useInvestorCapitalStore()
const shipmentStore = useGlobalShipmentStore()

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
  const shipment = shipmentStore.currentShipment
  if (!shipment) return 0
  return shipmentStore.currentShipmentItems.reduce((sum, item) => {
    const unitCost = calculateLineLandedCostBdt(
      {
        purchase_price: item.purchase_price ?? 0,
        product_weight: item.product_weight ?? 0,
        package_weight: item.package_weight ?? 0,
        ordered_quantity: item.ordered_quantity ?? 0,
      },
      shipment,
      shipmentStore.currentShipmentItems,
    )
    return sum + unitCost * Number(item.ordered_quantity ?? 0)
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

const openAddDialog = (investor?: any) => {
  editingInvestment.value = investor ? { investor_id: investor.investor_id } as any : null
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
    shipmentStore.fetchShipmentDetails(shipmentId.value),
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

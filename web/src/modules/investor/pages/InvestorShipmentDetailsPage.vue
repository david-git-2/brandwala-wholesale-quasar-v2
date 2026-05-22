<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn flat color="primary" icon="arrow_back" label="Back to Investor Shipment" @click="onBack" />
    </div>

    <div v-if="shipmentStore.selectedShipment" class="q-mb-md">
      <div class="text-h6 text-weight-bold">
        #{{ shipmentStore.selectedShipment.tenant_shipment_id ?? shipmentStore.selectedShipment.id }} {{ shipmentStore.selectedShipment.name }}
      </div>
      <div class="text-body2 text-grey-8">Status: {{ shipmentStore.selectedShipment.status }}</div>
      <div class="text-body2 text-grey-8">Total Shipment Cost (BDT): {{ formatAmount(totalShipmentCost) }}</div>
    </div>

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
            <tr v-if="!investorStore.investors.length">
              <td colspan="3" class="text-center text-grey-7">No investors found.</td>
            </tr>
            <tr v-for="investor in investorStore.investors" :key="investor.id">
              <td>{{ investor.name }}</td>
              <td class="text-right">{{ formatAmount(getAvailableBalance(investor.id)) }}</td>
              <td class="text-right">
                <q-btn color="primary" size="sm" label="Add" @click="openAddDialog(investor.id, investor.name)" />
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
              <th class="text-right">Invested Amount</th>
              <th class="text-right">Coverage %</th>
              <th class="text-right">Covered Amount</th>
              <th class="text-left">Status</th>
              <th class="text-right">Actual Profit</th>
              <th class="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!investorStore.shipmentInvestments.length">
              <td colspan="8" class="text-center text-grey-7">No shipment investments found.</td>
            </tr>
            <tr v-for="(row, index) in investorStore.shipmentInvestments" :key="row.id">
              <td>{{ index + 1 }}</td>
              <td>{{ investorNameById(row.investor_id) }}</td>
              <td class="text-right">{{ formatAmount(row.invested_amount) }}</td>
              <td class="text-right">{{ formatCoveragePercentage(row.invested_amount) }}</td>
              <td class="text-right">{{ formatAmount(getCoveredAmount(row.invested_amount)) }}</td>
              <td>{{ row.status }}</td>
              <td class="text-right">{{ formatAmount(row.actual_profit) }}</td>
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

    <q-dialog v-model="openDialog" persistent>
      <q-card style="min-width: 380px; max-width: 95vw">
        <q-card-section>
          <div class="text-h6">Add Shipment Investment</div>
          <div class="text-body2 text-grey-7 q-mt-xs">Investor: {{ selectedInvestorName }}</div>
        </q-card-section>
        <q-card-section>
          <q-input v-model.number="investedAmount" type="number" min="0.01" step="0.01" label="Amount" outlined dense />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDialog = false" />
          <q-btn color="primary" :label="isEditMode ? 'Update' : 'Save'" :disable="!canSave" @click="saveInvestment" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteConfirmDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete this shipment investment?
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
import { useInvestorStore } from '../stores/investorStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { calculateCostBdt } from 'src/modules/shipment/utils/costing'
import type { ShipmentInvestment } from '../types'
import { formatAmountBdt } from 'src/utils/currency'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const investorStore = useInvestorStore()
const shipmentStore = useShipmentStore()

const activeTab = ref<'allocate' | 'investments'>('investments')
const openDialog = ref(false)
const openDeleteConfirmDialog = ref(false)
const selectedInvestorId = ref<number | null>(null)
const selectedInvestorName = ref('')
const investedAmount = ref<number | null>(null)
const editingInvestment = ref<ShipmentInvestment | null>(null)
const deletingInvestment = ref<ShipmentInvestment | null>(null)

const shipmentId = computed(() => {
  const parsed = Number(route.params.id)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
})

const totalShipmentCost = computed(() => {
  const shipment = shipmentStore.selectedShipment
  return shipmentStore.shipmentItems.reduce((sum, item) => {
    const unitCost = calculateCostBdt({
      productWeight: item.product_weight,
      packageWeight: item.package_weight,
      cargoRate: shipment?.cargo_rate,
      priceGbp: item.price_gbp,
      productConversionRate: shipment?.product_conversion_rate,
      cargoConversionRate: shipment?.cargo_conversion_rate,
    })
    return sum + unitCost * Number(item.quantity ?? 0)
  }, 0)
})

const canSave = computed(() => Number(investedAmount.value ?? 0) > 0 && Number(selectedInvestorId.value ?? 0) > 0)
const isEditMode = computed(() => Boolean(editingInvestment.value))

const formatAmount = (value: number | null | undefined) => formatAmountBdt(value)
const formatCoveragePercentage = (investedAmount: number | null | undefined) => {
  const shipmentCost = Number(totalShipmentCost.value ?? 0)
  if (shipmentCost <= 0) {
    return '0.00%'
  }

  const invested = Number(investedAmount ?? 0)
  return `${((invested / shipmentCost) * 100).toFixed(2)}%`
}

const getCoveredAmount = (investedAmount: number | null | undefined) => {
  const shipmentCost = Number(totalShipmentCost.value ?? 0)
  const invested = Number(investedAmount ?? 0)
  return Math.min(invested, shipmentCost)
}

const getAvailableBalance = (investorId: number) =>
  Number(investorStore.balancesByInvestorId[investorId]?.available_balance ?? 0)

const investorNameById = (investorId: number) =>
  investorStore.investors.find((item) => item.id === investorId)?.name ?? `#${investorId}`

const openAddDialog = (investorId: number, investorName: string) => {
  editingInvestment.value = null
  selectedInvestorId.value = investorId
  selectedInvestorName.value = investorName
  investedAmount.value = null
  openDialog.value = true
}

const openEditDialog = (row: ShipmentInvestment) => {
  editingInvestment.value = row
  selectedInvestorId.value = row.investor_id
  selectedInvestorName.value = investorNameById(row.investor_id)
  investedAmount.value = Number(row.invested_amount)
  openDialog.value = true
}

const openDeleteDialog = (row: ShipmentInvestment) => {
  deletingInvestment.value = row
  openDeleteConfirmDialog.value = true
}

const saveInvestment = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value || !selectedInvestorId.value || !canSave.value) return

  if (editingInvestment.value) {
    await investorStore.updateShipmentInvestment({
      id: editingInvestment.value.id,
      tenant_id: tenantId,
      shipment_id: shipmentId.value,
      investor_id: selectedInvestorId.value,
      invested_amount: Number(investedAmount.value ?? 0),
      status: editingInvestment.value.status,
      actual_profit: editingInvestment.value.actual_profit,
    })
  } else {
    await investorStore.createShipmentInvestment({
      tenant_id: tenantId,
      shipment_id: shipmentId.value,
      investor_id: selectedInvestorId.value,
      invested_amount: Number(investedAmount.value ?? 0),
      status: 'active',
      actual_profit: 0,
    })
  }

  await investorStore.fetchShipmentInvestmentsByShipment(tenantId, shipmentId.value)
  editingInvestment.value = null
  openDialog.value = false
}

const deleteInvestment = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !deletingInvestment.value) return

  await investorStore.deleteShipmentInvestment({
    id: deletingInvestment.value.id,
    tenant_id: tenantId,
  })

  if (shipmentId.value) {
    await investorStore.fetchShipmentInvestmentsByShipment(tenantId, shipmentId.value)
  }

  deletingInvestment.value = null
  openDeleteConfirmDialog.value = false
}

const load = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) return

  await Promise.all([
    shipmentStore.fetchShipmentById(shipmentId.value),
    investorStore.fetchInvestorsByTenant(tenantId),
    investorStore.fetchShipmentInvestmentsByShipment(tenantId, shipmentId.value),
  ])
}

const onBack = async () => {
  await router.push({
    name: 'app-investor-shipment-page',
    params: { tenantSlug: route.params.tenantSlug },
  })
}

onMounted(() => {
  void load()
})
</script>

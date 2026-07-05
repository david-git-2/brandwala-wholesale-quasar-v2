<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
      <AppPageHeader
        title="Capital Deployment"
        subtitle="Detailed record of capital allocation across shipment batches"
      />
    </q-card>

    <PageInitialLoader v-if="loading" message="Loading allocations..." />

    <q-banner v-else-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <template v-else>
      <q-card flat class="floating-surface shadow-1 q-pa-md">
        <q-markup-table flat bordered wrap-cells class="cursor-pointer">
          <thead>
            <tr>
              <th class="text-left">SL</th>
              <th class="text-left">Shipment batch</th>
              <th class="text-left">Status</th>
              <th class="text-right">Cost share %</th>
              <th class="text-right">Allocated cost</th>
              <th class="text-right">Computed profit</th>
              <th class="text-left">Profit status</th>
              <th class="text-left">Created at</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!allocations.length">
              <td colspan="8" class="text-center text-grey-7">No allocations found.</td>
            </tr>
            <tr v-for="(row, index) in allocations" :key="row.id" @click="onSelectAllocation(row)">
              <td>{{ offset + index + 1 }}</td>
              <td class="text-left">#{{ row.global_shipment_id }} - {{ row.shipment_name ?? 'Unnamed shipment' }}</td>
              <td class="text-left text-capitalize">{{ row.shipment_status }}</td>
              <td class="text-right">{{ row.cost_share_pct }}%</td>
              <td class="text-right">{{ formatCurrency(row.allocated_cost) }}</td>
              <td class="text-right text-weight-bold text-positive">{{ formatCurrency(row.computed_profit) }}</td>
              <td class="text-left text-capitalize">
                <q-chip
                  dense
                  square
                  :color="row.profit_status === 'realized' ? 'green-1' : 'amber-1'"
                  :text-color="row.profit_status === 'realized' ? 'green-9' : 'amber-9'"
                  class="text-weight-bold text-xs"
                >
                  {{ row.profit_status || 'unrealized' }}
                </q-chip>
              </td>
              <td class="text-left">{{ formatDate(row.created_at) }}</td>
            </tr>
          </tbody>
        </q-markup-table>

        <div class="row items-center justify-end q-mt-md q-gutter-sm">
          <q-btn
            flat
            round
            dense
            icon="chevron_left"
            :disable="page === 1"
            @click="prevPage"
          />
          <span class="text-caption">Page {{ page }} of {{ totalPages }}</span>
          <q-btn
            flat
            round
            dense
            icon="chevron_right"
            :disable="page >= totalPages"
            @click="nextPage"
          />
        </div>
      </q-card>
    </template>

    <!-- Drill-down Dialog -->
    <q-dialog v-model="openDrillDown" persistent>
      <q-card style="width: 600px; max-width: 95vw;">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">Allocation Details</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="q-pt-none" v-if="selectedAllocation">
          <div class="text-subtitle1 text-weight-bold q-mb-xs">
            {{ selectedAllocation.shipment_name }}
          </div>
          <div class="text-body2 text-grey-7 q-mb-md">
            Shipment ID: #{{ selectedAllocation.global_shipment_id }} · Status: <span class="text-capitalize text-weight-medium">{{ selectedAllocation.shipment_status }}</span>
          </div>

          <div class="row q-col-gutter-sm q-mb-md">
            <div class="col-6">
              <q-card flat class="bg-grey-1 q-pa-sm">
                <div class="text-caption text-grey-7">Invested Amount</div>
                <div class="text-weight-bold text-primary">{{ formatCurrency(selectedAllocation.invested_amount) }}</div>
              </q-card>
            </div>
            <div class="col-6">
              <q-card flat class="bg-grey-1 q-pa-sm">
                <div class="text-caption text-grey-7">Cost Share Percentage</div>
                <div class="text-weight-bold">{{ selectedAllocation.cost_share_pct }}%</div>
              </q-card>
            </div>
          </div>

          <q-card flat bordered class="q-pa-md q-mb-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm text-primary">Shipment P&amp;L Performance</div>
            <div class="q-gutter-y-xs">
              <div class="row justify-between">
                <span class="text-grey-7">Total Landed Cost:</span>
                <span class="text-weight-medium">{{ formatCurrency(selectedAllocation.total_landed_cost) }}</span>
              </div>
              <div class="row justify-between">
                <span class="text-grey-7">Realized Revenue:</span>
                <span class="text-weight-medium text-positive">{{ formatCurrency(selectedAllocation.realized_revenue) }}</span>
              </div>
              <div class="row justify-between">
                <span class="text-grey-7">Gross Profit:</span>
                <span class="text-weight-bold text-positive">{{ formatCurrency(selectedAllocation.gross_profit) }}</span>
              </div>
              <div class="row justify-between">
                <span class="text-grey-7">Unsold Asset Stock:</span>
                <span class="text-weight-medium text-warning">{{ formatCurrency(selectedAllocation.unsold_value) }}</span>
              </div>
            </div>
          </q-card>

          <q-card flat bordered class="q-pa-md bg-green-1 text-green-9" v-if="selectedAllocation.profit_status === 'realized'">
            <div class="row items-center">
              <q-icon name="check_circle" size="sm" class="q-mr-sm" />
              <div>
                <strong>Earnings Realized:</strong> Your net share of BDT {{ formatCurrency(selectedAllocation.computed_profit) }} has been added to your withdrawable balance.
              </div>
            </div>
          </q-card>
          <q-card flat bordered class="q-pa-md bg-amber-1 text-amber-9" v-else>
            <div class="row items-center">
              <q-icon name="info" size="sm" class="q-mr-sm" />
              <div>
                <strong>Earnings Unrealized:</strong> Estimated profit share of BDT {{ formatCurrency(selectedAllocation.computed_profit) }} is subject to change until shipment is fully sold and closed.
              </div>
            </div>
          </q-card>
        </q-card-section>
      </q-card>
    </q-dialog>

    <q-inner-loading :showing="loadingDetail">
      <q-spinner-dots size="50px" color="primary" />
    </q-inner-loading>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useQuasar } from 'quasar'

import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvestorPortalStore } from '../stores/investorPortalStore'

const authStore = useAuthStore()
const $q = useQuasar()
const investorPortalStore = useInvestorPortalStore()
const { allocations, totalAllocationsCount } = storeToRefs(investorPortalStore)

const loading = ref(true)
const loadingDetail = ref(false)
const error = ref<string | null>(null)

const openDrillDown = ref(false)
const selectedAllocation = ref<any>(null)

const page = ref(1)
const limit = 20
const offset = computed(() => (page.value - 1) * limit)
const totalPages = computed(() => Math.ceil(totalAllocationsCount.value / limit) || 1)

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT', maximumFractionDigits: 0 }).format(
    Number(value ?? 0),
  )

const formatDate = (value: string) => {
  if (!value) return '-'
  return new Date(value).toLocaleDateString()
}

const loadData = async () => {
  loading.value = true
  const tenantId = authStore.tenantId
  const investorId = authStore.member?.id

  if (!tenantId || !investorId) {
    error.value = 'Auth session context invalid.'
    loading.value = false
    return
  }

  const result = await investorPortalStore.fetchAllocations(tenantId, investorId, limit, offset.value)
  if (!result.success) {
    error.value = result.error ?? 'Failed to load allocations.'
  }
  loading.value = false
}

const onSelectAllocation = async (row: any) => {
  loadingDetail.value = true
  const tenantId = authStore.tenantId
  const investorId = authStore.member?.id
  if (!tenantId || !investorId) {
    loadingDetail.value = false
    return
  }

  const res = await investorPortalStore.fetchAllocationDetail(tenantId, investorId, row.global_shipment_id)
  if (res.success && res.data) {
    selectedAllocation.value = res.data
    openDrillDown.value = true
  } else {
    $q.notify({ type: 'negative', message: 'Failed to load allocation details.' })
  }
  loadingDetail.value = false
}

const nextPage = () => {
  if (page.value < totalPages.value) {
    page.value++
    void loadData()
  }
}

const prevPage = () => {
  if (page.value > 1) {
    page.value--
    void loadData()
  }
}

onMounted(() => {
  void loadData()
})
</script>

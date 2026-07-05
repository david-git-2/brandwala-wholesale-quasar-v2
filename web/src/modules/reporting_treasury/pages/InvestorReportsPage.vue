<template>
  <TreasuryPageShell
    title="Investor Capital Tracking"
    subtitle="Analyze capital deployment: shipment landed costs, realized revenues, and distributed cost/profit splits for partners."
    :error="error"
  >
    <!-- Loading State -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <div v-else class="q-gutter-y-lg">
      <!-- Metrics Grid -->
      <TreasuryStatGrid :items="statCards" />

      <!-- Export Report Panel -->
      <TreasuryFilterBar>
        <div class="row q-col-gutter-md items-end">
          <div class="col-12 col-sm-3">
            <q-select
              v-model="selectedExportInvestorId"
              outlined
              dense
              label="Select Investor"
              emit-value
              map-options
              :options="investorOptions"
            />
          </div>
          <div class="col-12 col-sm-3">
            <q-input v-model="reportStartDate" outlined dense label="Start Date" type="date" />
          </div>
          <div class="col-12 col-sm-3">
            <q-input v-model="reportEndDate" outlined dense label="End Date" type="date" />
          </div>
          <div class="col-12 col-sm-3">
            <q-btn
              color="primary"
              label="Export to CSV"
              class="full-width"
              unelevated
              :disable="!selectedExportInvestorId"
              @click="exportCapitalReport"
            />
          </div>
        </div>
      </TreasuryFilterBar>

      <!-- Active Shipment Batches Table -->
      <q-card flat bordered class="q-pa-md bg-white">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-primary">
          Shipment Investment Performance
        </div>

        <q-table
          flat
          row-key="id"
          :rows="shipmentPnLs"
          :columns="shipmentColumns"
          :pagination="{ rowsPerPage: 20 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-name="props">
            <q-td :props="props" class="text-weight-bold">
              {{ props.row.name }}
            </q-td>
          </template>

          <template #body-cell-landed_cost="props">
            <q-td :props="props" class="text-right">
              {{ formatAmountBdt(props.row.totals.landed_cost) }}
            </q-td>
          </template>

          <template #body-cell-sold_cost="props">
            <q-td :props="props" class="text-right text-indigo-9">
              {{ formatAmountBdt(props.row.totals.sold_cost) }}
            </q-td>
          </template>

          <template #body-cell-revenue="props">
            <q-td :props="props" class="text-right text-positive">
              {{ formatAmountBdt(props.row.totals.revenue) }}
            </q-td>
          </template>

          <template #body-cell-gross_profit="props">
            <q-td :props="props" class="text-right text-weight-bold text-primary">
              {{ formatAmountBdt(props.row.totals.gross_profit) }}
            </q-td>
          </template>

          <template #body-cell-unsold_value="props">
            <q-td :props="props" class="text-right text-warning">
              {{ formatAmountBdt(props.row.totals.unsold_value) }}
            </q-td>
          </template>
        </q-table>
      </q-card>

      <!-- Capital Partner Profit Shares -->
      <q-card flat bordered class="q-pa-md bg-white">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-primary">
          Capital Partner Balances &amp; Contributions
        </div>

        <q-table
          flat
          row-key="id"
          :rows="partners"
          :columns="partnerColumns"
          :pagination="{ rowsPerPage: 20 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-name="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <q-avatar
                  size="32px"
                  class="q-mr-sm text-weight-bold text-slate-900"
                  :style="{ backgroundColor: props.row.color }"
                >
                  {{ props.row.name.charAt(0) }}
                </q-avatar>
                <div>
                  <div class="text-weight-bold">{{ props.row.name }}</div>
                </div>
              </div>
            </q-td>
          </template>

          <template #body-cell-total_in="props">
            <q-td :props="props" class="text-right">
              {{ formatAmountBdt(props.row.total_in) }}
            </q-td>
          </template>

          <template #body-cell-deployed="props">
            <q-td :props="props" class="text-right text-indigo-9">
              {{ formatAmountBdt(props.row.deployed) }}
            </q-td>
          </template>

          <template #body-cell-available="props">
            <q-td :props="props" class="text-right text-weight-bold text-primary">
              {{ formatAmountBdt(props.row.available) }}
            </q-td>
          </template>

          <template #body-cell-total_out="props">
            <q-td :props="props" class="text-right text-positive">
              {{ formatAmountBdt(props.row.total_out) }}
            </q-td>
          </template>
        </q-table>
      </q-card>
    </div>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useQuasar, QTableColumn } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'
import { treasuryRepository } from '../repositories/treasuryRepository'
import TreasuryPageShell from '../components/TreasuryPageShell.vue'
import TreasuryStatGrid from '../components/TreasuryStatGrid.vue'
import TreasuryFilterBar from '../components/TreasuryFilterBar.vue'

const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const error = ref<string | null>(null)
const shipmentPnLs = ref<any[]>([])
const partners = ref<any[]>([])

const reportStartDate = ref(new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10))
const reportEndDate = ref(new Date().toISOString().slice(0, 10))
const selectedExportInvestorId = ref<number | null>(null)

const totals = ref({
  invested_cost: 0,
  realized_revenue: 0,
  gross_profit: 0,
  unsold_stock: 0,
})

const shipmentColumns: QTableColumn[] = [
  { name: 'name', label: 'Shipment Name', field: 'name', align: 'left', sortable: true },
  { name: 'landed_cost', label: 'Total Landed Cost', field: 'id', align: 'right' },
  { name: 'sold_cost', label: 'Sold Cost', field: 'id', align: 'right' },
  { name: 'revenue', label: 'Revenue', field: 'id', align: 'right' },
  { name: 'gross_profit', label: 'Gross Profit', field: 'id', align: 'right' },
  { name: 'unsold_value', label: 'Unsold Value', field: 'id', align: 'right' },
]

const partnerColumns: QTableColumn[] = [
  { name: 'name', label: 'Partner Profile', field: 'name', align: 'left', sortable: true },
  { name: 'total_in', label: 'Total Capital In', field: 'total_in', align: 'right', sortable: true },
  { name: 'deployed', label: 'Deployed Capital', field: 'deployed', align: 'right', sortable: true },
  { name: 'available', label: 'Available Balance', field: 'available', align: 'right', sortable: true },
  { name: 'total_out', label: 'Total Withdrawn', field: 'total_out', align: 'right', sortable: true },
]

const investorOptions = computed(() =>
  partners.value.map((p) => ({
    label: p.name,
    value: p.id,
  }))
)

const statCards = computed(() => [
  {
    label: 'Total Invested Landed Cost',
    value: totals.value.invested_cost,
    caption: 'LCs of imported shipments',
  },
  {
    label: 'Realized Revenue',
    value: totals.value.realized_revenue,
    caption: 'Sold item revenue rollup',
    valueClass: 'text-positive',
  },
  {
    label: 'Gross Profit Realized',
    value: totals.value.gross_profit,
    caption: 'Accumulated batch margins',
    valueClass: 'text-primary',
  },
  {
    label: 'Unsold Asset Stock',
    value: totals.value.unsold_stock,
    caption: 'Remaining inventory asset estimate',
    valueClass: 'text-warning',
  },
])

const loadReports = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  error.value = null
  try {
    const parentId = await resolveParentTenantId(tenantId)

    // 1. Fetch completed shipments
    const { data: shipments, error: err } = await supabase
      .from('global_shipments')
      .select('id, name')
      .eq('parent_tenant_id', parentId)
      .in('status', ['delivered', 'completed'])

    if (err) throw err

    const pnlList: any[] = []
    let cost = 0
    let rev = 0
    let gp = 0
    let unsold = 0

    // 2. Fetch PnL for each shipment
    for (const ship of (shipments || [])) {
      try {
        const res = await treasuryRepository.getShipmentPnL(tenantId, ship.id)
        pnlList.push({
          id: ship.id,
          name: ship.name,
          totals: res.totals,
        })
        cost += res.totals.landed_cost
        rev += res.totals.revenue
        gp += res.totals.gross_profit
        unsold += res.totals.unsold_value
      } catch {
        // Skip individual errors to not break dashboard
      }
    }

    shipmentPnLs.value = pnlList
    totals.value = {
      invested_cost: cost,
      realized_revenue: rev,
      gross_profit: gp,
      unsold_stock: unsold,
    }

    // 3. Fetch real active partners
    const { data: profiles, error: pError } = await supabase.rpc('list_investor_profiles', {
      p_tenant_id: parentId,
      p_limit: 1000,
    })

    if (pError) throw pError

    partners.value = (profiles || []).map((p: any, idx: number) => ({
      id: p.id,
      name: p.name,
      deployed: Number(p.deployed_capital),
      available: Number(p.available_balance),
      total_in: Number(p.total_capital_in),
      total_out: Number(p.total_withdrawn),
      color: ['#0ea5e9', '#10b981', '#f59e0b', '#ec4899', '#8b5cf6'][idx % 5],
    }))

    if (partners.value.length > 0) {
      selectedExportInvestorId.value = partners.value[0].id
    }
  } catch (err: any) {
    error.value = err.message
    $q.notify({ type: 'negative', message: `Failed to load investor report: ${err.message}` })
  } finally {
    loading.value = false
  }
}

const resolveParentTenantId = async (id: number): Promise<number> => {
  const { data, error: err } = await supabase.rpc('resolve_parent_tenant_id', { p_tenant_id: id })
  if (err) return id
  return Number(data)
}

const exportCapitalReport = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !selectedExportInvestorId.value) return

  try {
    const { data, error: err } = await supabase.rpc('get_investor_capital_report', {
      p_tenant_id: tenantId,
      p_investor_id: selectedExportInvestorId.value,
      p_start_date: reportStartDate.value,
      p_end_date: reportEndDate.value,
    })

    if (err) throw err

    const reportData = data as any
    const investorName = partners.value.find((p) => p.id === selectedExportInvestorId.value)?.name ?? 'Investor'

    const csvContent = [
      ['Capital Partner Report', investorName],
      ['Period', `${reportStartDate.value} to ${reportEndDate.value}`],
      [],
      ['Metric', 'Amount (BDT)'],
      ['Starting Capital Balance', reportData.starting_balance],
      ['Deposits / Additions', reportData.deposits_sum],
      ['Withdrawals / Payouts', reportData.withdrawals_sum],
      ['Profit Earned in Period', reportData.profit_earned_sum],
      ['Ending Capital Balance', reportData.ending_balance],
    ].map(e => e.join(',')).join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    link.href = URL.createObjectURL(blob)
    link.setAttribute('download', `Capital_Report_${investorName.replace(/\s+/g, '_')}_${reportStartDate.value}_to_${reportEndDate.value}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)

    $q.notify({ type: 'positive', message: 'Report CSV exported successfully.' })
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Export failed: ${err.message}` })
  }
}

onMounted(() => {
  void loadReports()
})
</script>

<template>
  <q-page class="q-pa-lg bg-slate-900 text-white">
    <!-- Header Block -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="text-h4 text-weight-bolder tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-teal-400 to-emerald-400">
          Investor Capital Tracking
        </div>
        <div class="text-subtitle2 text-slate-400 q-mt-xs">
          Analyze capital deployment: shipment landed costs, realized revenues, and distributed cost/profit splits for partners.
        </div>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="teal" />
    </div>

    <div v-else class="q-gutter-y-xl">
      <!-- Metrics Grid -->
      <div class="row q-col-gutter-lg">
        <div class="col-12 col-md-3">
          <div class="glass-card q-pa-lg">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Total Invested Landed Cost</div>
            <div class="text-h5 text-weight-black q-mt-sm text-slate-300">
              {{ formatAmountBdt(totals.invested_cost) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs"> LCs of imported shipments</div>
          </div>
        </div>
        <div class="col-12 col-md-3">
          <div class="glass-card q-pa-lg">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Realized Revenue</div>
            <div class="text-h5 text-weight-black q-mt-sm text-emerald-400">
              {{ formatAmountBdt(totals.realized_revenue) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Sold item revenue rollup</div>
          </div>
        </div>
        <div class="col-12 col-md-3">
          <div class="glass-card q-pa-lg">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Gross Profit Realized</div>
            <div class="text-h5 text-weight-black q-mt-sm text-teal-300">
              {{ formatAmountBdt(totals.gross_profit) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Accumulated batch margins</div>
          </div>
        </div>
        <div class="col-12 col-md-3">
          <div class="glass-card q-pa-lg">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Unsold Asset Stock</div>
            <div class="text-h5 text-weight-black q-mt-sm text-amber-400">
              {{ formatAmountBdt(totals.unsold_stock) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Remaining inventory asset estimate</div>
          </div>
        </div>
      </div>

      <!-- Active Shipment Batches Table -->
      <div class="glass-card q-pa-lg">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-teal-300">
          Shipment Investment Performance
        </div>

        <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
          <thead>
            <tr class="text-slate-400 border-b border-slate-800">
              <th class="text-left font-semibold py-4">Shipment Name</th>
              <th class="text-right font-semibold">Total Landed Cost</th>
              <th class="text-right font-semibold">Sold Cost</th>
              <th class="text-right font-semibold">Revenue</th>
              <th class="text-right font-semibold">Gross Profit</th>
              <th class="text-right font-semibold">Unsold Value</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!shipmentPnLs.length" class="border-b border-slate-800/50">
              <td colspan="6" class="text-center py-8 text-slate-500">
                No active shipment investments found.
              </td>
            </tr>
            <tr
              v-for="s in shipmentPnLs"
              :key="s.id"
              class="hover:bg-slate-800/20 border-b border-slate-800/40"
            >
              <td class="py-3 text-weight-bold text-slate-200">
                {{ s.name }}
              </td>
              <td class="text-right text-slate-300">{{ formatAmountBdt(s.totals.landed_cost) }}</td>
              <td class="text-right text-indigo-300">{{ formatAmountBdt(s.totals.sold_cost) }}</td>
              <td class="text-right text-emerald-400">{{ formatAmountBdt(s.totals.revenue) }}</td>
              <td class="text-right text-weight-bold text-teal-300">{{ formatAmountBdt(s.totals.gross_profit) }}</td>
              <td class="text-right text-amber-400">{{ formatAmountBdt(s.totals.unsold_value) }}</td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>

      <!-- Capital Partner Profit Shares -->
      <div class="glass-card q-pa-lg">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-emerald-400">
          Capital Partner Distributions (50% Reinvested / 50% Profit Share)
        </div>

        <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
          <thead>
            <tr class="text-slate-400 border-b border-slate-800">
              <th class="text-left font-semibold py-4">Partner Profile</th>
              <th class="text-center font-semibold">Profit Share %</th>
              <th class="text-right font-semibold">Capital Contribution MTD</th>
              <th class="text-right font-semibold">Net Profit Allocation</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="partner in partners"
              :key="partner.name"
              class="hover:bg-slate-800/20 border-b border-slate-800/40"
            >
              <td class="py-3">
                <div class="row items-center no-wrap">
                  <q-avatar
                    size="32px"
                    class="q-mr-sm text-weight-bold shadow-1 text-slate-900"
                    :style="{ backgroundColor: partner.color }"
                  >
                    {{ partner.name.charAt(0) }}
                  </q-avatar>
                  <div>
                    <div class="text-weight-bold text-slate-200">{{ partner.name }}</div>
                  </div>
                </div>
              </td>
              <td class="text-center text-teal-300 font-semibold">{{ partner.share }}%</td>
              <td class="text-right text-slate-300">{{ formatAmountBdt(totals.invested_cost * (partner.share / 100)) }}</td>
              <td class="text-right text-weight-bold text-emerald-400">
                {{ formatAmountBdt(totals.gross_profit * (partner.share / 100)) }}
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { treasuryRepository } from '../repositories/treasuryRepository'

const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const shipmentPnLs = ref<any[]>([])

const totals = ref({
  invested_cost: 0,
  realized_revenue: 0,
  gross_profit: 0,
  unsold_stock: 0,
})

const partners = [
  { name: 'Sovereign Treasury Fund', share: 40, color: '#0ea5e9' },
  { name: 'Lead Operations Partner', share: 35, color: '#10b981' },
  { name: 'Reseller Consortium Capital', share: 25, color: '#f59e0b' },
]

const loadReports = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  try {
    const parentId = await resolveParentTenantId(tenantId)
    // 1. Fetch completed shipments
    const { data: shipments, error } = await supabase
      .from('global_shipments')
      .select('id, name')
      .eq('parent_tenant_id', parentId)
      .in('status', ['delivered', 'completed'])

    if (error) throw error

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
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Failed to load investor report: ${err.message}` })
  } finally {
    loading.value = false
  }
}

const resolveParentTenantId = async (id: number): Promise<number> => {
  const { data, error } = await supabase.rpc('resolve_parent_tenant_id', { p_tenant_id: id })
  if (error) return id
  return Number(data)
}

const formatAmountBdt = (val: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'BDT',
  }).format(val)
}

onMounted(() => {
  void loadReports()
})
</script>

<style scoped>
.bg-slate-900 {
  background-color: #0f172a;
}
.text-slate-400 {
  color: #94a3b8;
}
.text-slate-500 {
  color: #64748b;
}
.text-slate-200 {
  color: #e2e8f0;
}
.text-slate-300 {
  color: #cbd5e1;
}
.border-slate-800 {
  border-color: #1e293b;
}
.border-slate-800\/40 {
  border-color: rgba(30, 41, 59, 0.4);
}

/* Glassmorphism Classes */
.glass-card {
  background: rgba(30, 41, 59, 0.4);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px border-solid rgba(255, 255, 255, 0.05);
  border-radius: 12px;
}
</style>

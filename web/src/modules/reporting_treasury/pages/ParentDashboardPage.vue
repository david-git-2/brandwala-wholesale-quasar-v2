<template>
  <q-page class="q-pa-lg bg-slate-900 text-white">
    <!-- Header Block -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="text-h4 text-weight-bolder tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-teal-400 to-emerald-400">
          Consolidated Treasury Rollup
        </div>
        <div class="text-subtitle2 text-slate-400 q-mt-xs">
          Multi-tenant operations summary: sales performance, cash collections, accounts receivable, and middle-man obligations.
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
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Consolidated Sales</div>
            <div class="text-h4 text-weight-black q-mt-sm text-teal-300">
              {{ formatAmountBdt(totals.revenue) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">All posted invoices subtotal</div>
          </div>
        </div>
        <div class="col-12 col-md-3">
          <div class="glass-card q-pa-lg">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Total Cash Collected</div>
            <div class="text-h4 text-weight-black q-mt-sm text-emerald-400">
              {{ formatAmountBdt(totals.cash_collected) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Aggregated global payments</div>
          </div>
        </div>
        <div class="col-12 col-md-3">
          <div class="glass-card q-pa-lg">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Active AR (Receivables)</div>
            <div class="text-h4 text-weight-black q-mt-sm text-red-400">
              {{ formatAmountBdt(totals.active_ar) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Outstanding buyer obligations</div>
          </div>
        </div>
        <div class="col-12 col-md-3">
          <div class="glass-card q-pa-lg">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Middle-Man Liabilities</div>
            <div class="text-h4 text-weight-black q-mt-sm text-amber-400">
              {{ formatAmountBdt(totals.middleman_liability) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Pending dropship payouts</div>
          </div>
        </div>
      </div>

      <div class="row q-col-gutter-lg">
        <!-- Sales Split by Invoice Type -->
        <div class="col-12 col-md-5">
          <div class="glass-card q-pa-lg full-height">
            <div class="text-subtitle1 text-weight-bold q-mb-lg text-teal-300">
              Sales Distribution (by Channels)
            </div>
            <div class="q-gutter-y-lg">
              <div v-for="type in typeDistribution" :key="type.name">
                <div class="row justify-between text-caption text-weight-bold q-mb-xs">
                  <span class="text-slate-300 text-capitalize">{{ type.name }}</span>
                  <span class="text-teal-400">{{ formatAmountBdt(type.amount) }} ({{ type.percent }}%)</span>
                </div>
                <q-linear-progress
                  :value="type.percent / 100"
                  color="teal"
                  class="rounded-borders"
                  style="height: 10px;"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- System Summary details -->
        <div class="col-12 col-md-7">
          <div class="glass-card q-pa-lg full-height">
            <div class="text-subtitle1 text-weight-bold q-mb-lg text-emerald-400">
              Treasury Clearances MTD
            </div>
            <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
              <thead>
                <tr class="text-slate-400 border-b border-slate-800">
                  <th class="text-left font-semibold">Financial Area</th>
                  <th class="text-right font-semibold">Total Amount</th>
                  <th class="text-right font-semibold">Unallocated/Pending</th>
                  <th class="text-right font-semibold">Clearance Rate</th>
                </tr>
              </thead>
              <tbody>
                <tr class="border-b border-slate-800/40">
                  <td class="py-3 font-semibold text-slate-200">Customer Invoices</td>
                  <td class="text-right">{{ formatAmountBdt(totals.revenue) }}</td>
                  <td class="text-right text-red-400">{{ formatAmountBdt(totals.active_ar) }}</td>
                  <td class="text-right text-teal-300 font-semibold">
                    {{ totals.revenue > 0 ? (((totals.revenue - totals.active_ar) / totals.revenue) * 100).toFixed(1) : '0.0' }}%
                  </td>
                </tr>
                <tr class="border-b border-slate-800/40">
                  <td class="py-3 font-semibold text-slate-200">Received Payments</td>
                  <td class="text-right">{{ formatAmountBdt(totals.cash_collected) }}</td>
                  <td class="text-right text-amber-400">{{ formatAmountBdt(totals.unallocated_payments) }}</td>
                  <td class="text-right text-teal-300 font-semibold">
                    {{ totals.cash_collected > 0 ? (((totals.cash_collected - totals.unallocated_payments) / totals.cash_collected) * 100).toFixed(1) : '0.0' }}%
                  </td>
                </tr>
                <tr class="border-b border-slate-800/40">
                  <td class="py-3 font-semibold text-slate-200">Middle-Man Payouts</td>
                  <td class="text-right">{{ formatAmountBdt(totals.middleman_total) }}</td>
                  <td class="text-right text-amber-400">{{ formatAmountBdt(totals.middleman_liability) }}</td>
                  <td class="text-right text-teal-300 font-semibold">
                    {{ totals.middleman_total > 0 ? (((totals.middleman_total - totals.middleman_liability) / totals.middleman_total) * 100).toFixed(1) : '0.0' }}%
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'

const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const invoices = ref<any[]>([])
const payments = ref<any[]>([])

const totals = ref({
  revenue: 0,
  cash_collected: 0,
  active_ar: 0,
  unallocated_payments: 0,
  middleman_total: 0,
  middleman_liability: 0,
})

const loadStats = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  try {
    // 1. Fetch invoices
    const { data: invData, error: invError } = await supabase
      .from('global_invoices')
      .select('invoice_type, total_amount, paid_amount, due_amount, middle_man_payout_amount, middle_man_payout_status')
      .eq('tenant_id', tenantId)
      .eq('invoice_status', 'posted')

    if (invError) throw invError
    invoices.value = invData || []

    // 2. Fetch payments
    const { data: payData, error: payError } = await supabase
      .from('global_payments')
      .select('amount, unallocated_amount')
      .eq('tenant_id', tenantId)

    if (payError) throw payError
    payments.value = payData || []

    // Calculate aggregations
    let rev = 0
    let ar = 0
    let mmTotal = 0
    let mmLiability = 0

    invoices.value.forEach((inv) => {
      rev += Number(inv.total_amount) || 0
      ar += Number(inv.due_amount) || 0
      
      if (inv.invoice_type === 'dropship') {
        const mmAmt = Number(inv.middle_man_payout_amount) || 0
        mmTotal += mmAmt
        if (inv.middle_man_payout_status !== 'paid') {
          mmLiability += mmAmt
        }
      }
    })

    let cash = 0
    let unallocated = 0

    payments.value.forEach((p) => {
      cash += Number(p.amount) || 0
      unallocated += Number(p.unallocated_amount) || 0
    })

    totals.value = {
      revenue: rev,
      cash_collected: cash,
      active_ar: ar,
      unallocated_payments: unallocated,
      middleman_total: mmTotal,
      middleman_liability: mmLiability,
    }
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Failed to load dashboard: ${err.message}` })
  } finally {
    loading.value = false
  }
}

// Distribution by type
const typeDistribution = computed(() => {
  const map: Record<string, number> = {
    wholesale: 0,
    retail: 0,
    dropship: 0,
  }

  invoices.value.forEach((inv) => {
    const t = inv.invoice_type || 'wholesale'
    if (map[t] !== undefined) {
      map[t] += Number(inv.total_amount) || 0
    }
  })

  const sum = Object.values(map).reduce((a, b) => a + b, 0)

  return Object.entries(map).map(([name, amount]) => {
    const percent = sum > 0 ? Math.round((amount / sum) * 100) : 0
    return { name, amount, percent }
  })
})

const formatAmountBdt = (val: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'BDT',
  }).format(val)
}

onMounted(() => {
  void loadStats()
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

.full-height {
  height: 100%;
}
</style>

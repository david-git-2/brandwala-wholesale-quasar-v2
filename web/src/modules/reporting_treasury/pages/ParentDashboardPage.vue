<template>
  <TreasuryPageShell
    title="Consolidated Treasury Rollup"
    subtitle="Multi-tenant operations summary: sales performance, cash collections, accounts receivable, and middle-man obligations."
    :error="error"
  >
    <!-- Loading State -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <div v-else class="q-gutter-y-lg">
      <!-- Metrics Grid -->
      <TreasuryStatGrid :items="statCards" />

      <div class="row q-col-gutter-lg">
        <!-- Sales Split by Invoice Type -->
        <div class="col-12 col-md-5">
          <q-card flat bordered class="q-pa-md full-height">
            <div class="text-subtitle1 text-weight-bold q-mb-lg text-primary">
              Sales Distribution (by Channels)
            </div>
            <div class="q-gutter-y-lg">
              <div v-for="type in typeDistribution" :key="type.name">
                <div class="row justify-between text-caption text-weight-bold q-mb-xs">
                  <span class="text-grey-8 text-capitalize">{{ type.name }}</span>
                  <span class="text-primary">{{ formatAmountBdt(type.amount) }} ({{ type.percent }}%)</span>
                </div>
                <q-linear-progress
                  :value="type.percent / 100"
                  color="primary"
                  class="rounded-borders"
                  style="height: 10px;"
                />
              </div>
            </div>
          </q-card>
        </div>

        <!-- System Summary details -->
        <div class="col-12 col-md-7">
          <q-card flat bordered class="q-pa-md full-height">
            <div class="text-subtitle1 text-weight-bold q-mb-lg text-primary">
              Treasury Clearances MTD
            </div>
            <q-markup-table flat bordered wrap-cells>
              <thead>
                <tr>
                  <th class="text-left font-semibold">Financial Area</th>
                  <th class="text-right font-semibold">Total Amount</th>
                  <th class="text-right font-semibold">Unallocated/Pending</th>
                  <th class="text-right font-semibold">Clearance Rate</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td class="py-3 font-semibold">Customer Invoices</td>
                  <td class="text-right">{{ formatAmountBdt(totals.revenue) }}</td>
                  <td class="text-right text-negative">{{ formatAmountBdt(totals.active_ar) }}</td>
                  <td class="text-right text-primary font-semibold">
                    {{ totals.revenue > 0 ? (((totals.revenue - totals.active_ar) / totals.revenue) * 100).toFixed(1) : '0.0' }}%
                  </td>
                </tr>
                <tr>
                  <td class="py-3 font-semibold">Received Payments</td>
                  <td class="text-right">{{ formatAmountBdt(totals.cash_collected) }}</td>
                  <td class="text-right text-warning">{{ formatAmountBdt(totals.unallocated_payments) }}</td>
                  <td class="text-right text-primary font-semibold">
                    {{ totals.cash_collected > 0 ? (((totals.cash_collected - totals.unallocated_payments) / totals.cash_collected) * 100).toFixed(1) : '0.0' }}%
                  </td>
                </tr>
                <tr>
                  <td class="py-3 font-semibold">Middle-Man Payouts</td>
                  <td class="text-right">{{ formatAmountBdt(totals.middleman_total) }}</td>
                  <td class="text-right text-warning">{{ formatAmountBdt(totals.middleman_liability) }}</td>
                  <td class="text-right text-primary font-semibold">
                    {{ totals.middleman_total > 0 ? (((totals.middleman_total - totals.middleman_liability) / totals.middleman_total) * 100).toFixed(1) : '0.0' }}%
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>
        </div>
      </div>
    </div>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'
import TreasuryPageShell from '../components/TreasuryPageShell.vue'
import TreasuryStatGrid from '../components/TreasuryStatGrid.vue'

const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const error = ref<string | null>(null)
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

const statCards = computed(() => [
  {
    label: 'Consolidated Sales',
    value: totals.value.revenue,
    caption: 'All posted invoices subtotal',
  },
  {
    label: 'Total Cash Collected',
    value: totals.value.cash_collected,
    caption: 'Aggregated global payments',
    valueClass: 'text-positive',
  },
  {
    label: 'Active AR (Receivables)',
    value: totals.value.active_ar,
    caption: 'Outstanding buyer obligations',
    valueClass: 'text-negative',
  },
  {
    label: 'Middle-Man Liabilities',
    value: totals.value.middleman_liability,
    caption: 'Pending dropship payouts',
    valueClass: 'text-warning',
  },
])

const loadStats = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  error.value = null
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
    error.value = err.message
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

onMounted(() => {
  void loadStats()
})
</script>

<style scoped>
.full-height {
  height: 100%;
}
</style>

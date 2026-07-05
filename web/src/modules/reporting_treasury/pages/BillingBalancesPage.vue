<template>
  <q-page class="q-pa-lg bg-slate-900 text-white">
    <!-- Header Block -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="text-h4 text-weight-bolder tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-teal-400 to-emerald-400">
          Customer Balances &amp; Outstanding AR
        </div>
        <div class="text-subtitle2 text-slate-400 q-mt-xs">
          Analyze real-time Accounts Receivable (AR) rollups, active credit balances, and age-of-invoices tracking.
        </div>
      </div>
    </div>

    <!-- Metrics Grid -->
    <div class="row q-col-gutter-lg q-mb-xl">
      <div class="col-12 col-md-4">
        <div class="glass-card q-pa-lg">
          <div class="text-caption text-slate-400 text-uppercase tracking-wider">Total Outstanding AR</div>
          <div class="text-h3 text-weight-black q-mt-sm text-red-400">
            {{ formatAmountBdt(totalOutstandingDue) }}
          </div>
          <div class="text-caption text-slate-500 q-mt-xs">Active unpaid balance sheet</div>
        </div>
      </div>
      <div class="col-12 col-md-4">
        <div class="glass-card q-pa-lg">
          <div class="text-caption text-slate-400 text-uppercase tracking-wider">Total Paid Collections</div>
          <div class="text-h3 text-weight-black q-mt-sm text-emerald-400">
            {{ formatAmountBdt(totalInvoiced - totalOutstandingDue) }}
          </div>
          <div class="text-caption text-slate-500 q-mt-xs">Cleared cash receipts</div>
        </div>
      </div>
      <div class="col-12 col-md-4">
        <div class="glass-card q-pa-lg">
          <div class="text-caption text-slate-400 text-uppercase tracking-wider">Average Collection Rate</div>
          <div class="text-h3 text-weight-black q-mt-sm text-teal-300">
            {{ averageCollectionRate }}
          </div>
          <div class="text-caption text-slate-500 q-mt-xs">Invoiced to cash conversion percentage</div>
        </div>
      </div>
    </div>

    <!-- Filter Control Card -->
    <div class="glass-card q-pa-md q-mb-lg row items-center justify-between q-col-gutter-sm">
      <div class="col-12 col-md-5">
        <q-input
          v-model="search"
          placeholder="Search by profile name, invoice no, email..."
          dark
          dense
          outlined
          class="glass-input"
          @update:model-value="loadData"
        >
          <template #append>
            <q-icon name="search" class="text-slate-400" />
          </template>
        </q-input>
      </div>

      <div class="col-auto">
        <q-tabs
          v-model="activeTab"
          dense
          dark
          no-caps
          class="text-slate-400"
          active-color="teal"
          indicator-color="teal"
        >
          <q-tab name="profiles" label="Billing Profiles" icon="people" />
          <q-tab name="outstanding" label="Outstanding Invoices" icon="description" />
        </q-tabs>
      </div>
    </div>

    <!-- Tab Panels Card -->
    <div class="glass-card overflow-hidden">
      <q-tab-panels v-model="activeTab" animated class="bg-transparent text-white">
        <!-- Billing Profiles Panel -->
        <q-tab-panel name="profiles" class="q-pa-none">
          <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
            <thead>
              <tr class="text-slate-400 border-b border-slate-800">
                <th class="text-left font-semibold py-4">Customer Profile</th>
                <th class="text-right font-semibold">Total Invoiced</th>
                <th class="text-right font-semibold">Total Paid</th>
                <th class="text-right font-semibold">Balance Due</th>
                <th class="text-center font-semibold">Collection %</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="loading" class="border-b border-slate-800/50">
                <td colspan="5" class="text-center py-8 text-slate-400">
                  <q-spinner-dots size="40px" color="teal" />
                </td>
              </tr>
              <tr v-else-if="!profiles.length" class="border-b border-slate-800/50">
                <td colspan="5" class="text-center py-8 text-slate-500">
                  No billing profiles found.
                </td>
              </tr>
              <tr
                v-for="prof in profiles"
                :key="prof.id"
                class="hover:bg-slate-800/40 transition-colors duration-200 border-b border-slate-800/50"
              >
                <td class="py-3">
                  <div class="row items-center no-wrap">
                    <q-avatar
                      size="32px"
                      class="q-mr-sm text-weight-bold shadow-1 text-slate-900"
                      :style="{ backgroundColor: prof.color || '#14b8a6' }"
                    >
                      {{ prof.name.charAt(0) }}
                    </q-avatar>
                    <div>
                      <div class="text-weight-bold text-slate-200">{{ prof.name }}</div>
                      <div class="text-caption text-slate-400">{{ prof.email || '-' }}</div>
                    </div>
                  </div>
                </td>
                <td class="text-right text-slate-300">{{ formatAmountBdt(prof.total_invoiced) }}</td>
                <td class="text-right text-emerald-400">{{ formatAmountBdt(prof.total_paid) }}</td>
                <td class="text-right text-weight-bold" :class="prof.balance_due > 0 ? 'text-red-400' : 'text-slate-500'">
                  {{ formatAmountBdt(prof.balance_due) }}
                </td>
                <td>
                  <div class="row items-center justify-center no-wrap">
                    <q-linear-progress
                      :value="prof.total_invoiced > 0 ? (prof.total_paid / prof.total_invoiced) : 0"
                      color="teal"
                      class="q-mr-sm rounded-borders"
                      style="width: 60px; height: 6px;"
                    />
                    <span class="text-caption text-slate-300 text-weight-bold">
                      {{ prof.total_invoiced > 0 ? ((prof.total_paid / prof.total_invoiced) * 100).toFixed(0) : '0' }}%
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-tab-panel>

        <!-- Outstanding Invoices Panel -->
        <q-tab-panel name="outstanding" class="q-pa-none">
          <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
            <thead>
              <tr class="text-slate-400 border-b border-slate-800">
                <th class="text-left font-semibold py-4">Invoice No</th>
                <th class="text-left font-semibold">Invoice Date</th>
                <th class="text-left font-semibold">Billing Profile</th>
                <th class="text-left font-semibold">Recipient / Phone</th>
                <th class="text-right font-semibold">Total Amount</th>
                <th class="text-right font-semibold">Paid Amount</th>
                <th class="text-right font-semibold">Due Balance</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="loading" class="border-b border-slate-800/50">
                <td colspan="7" class="text-center py-8 text-slate-400">
                  <q-spinner-dots size="40px" color="teal" />
                </td>
              </tr>
              <tr v-else-if="!outstandingInvoices.length" class="border-b border-slate-800/50">
                <td colspan="7" class="text-center py-8 text-slate-500">
                  No outstanding invoices found.
                </td>
              </tr>
              <tr
                v-for="inv in outstandingInvoices"
                :key="inv.id"
                class="hover:bg-slate-800/40 transition-colors duration-200 border-b border-slate-800/50"
              >
                <td class="py-4 text-weight-bold text-teal-400">
                  {{ inv.invoice_no }}
                </td>
                <td>{{ formatDate(inv.invoice_date) }}</td>
                <td>{{ inv.billing_profile_name || 'Walk-in / Direct' }}</td>
                <td>
                  <div class="text-weight-medium">{{ inv.recipient_name || '-' }}</div>
                  <div v-if="inv.recipient_phone" class="text-caption text-slate-400">{{ inv.recipient_phone }}</div>
                </td>
                <td class="text-right text-slate-300">{{ formatAmountBdt(inv.total_amount) }}</td>
                <td class="text-right text-emerald-400">{{ formatAmountBdt(inv.paid_amount) }}</td>
                <td class="text-right text-weight-bold text-red-400">{{ formatAmountBdt(inv.due_amount) }}</td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-tab-panel>
      </q-tab-panels>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { treasuryRepository } from '../repositories/treasuryRepository'

const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const activeTab = ref('profiles')
const search = ref('')

const profiles = ref<any[]>([])
const outstandingInvoices = ref<any[]>([])

const loadData = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  try {
    const [profRes, outRes] = await Promise.all([
      treasuryRepository.listBillingBalances(tenantId, search.value || undefined),
      treasuryRepository.listInvoiceOutstanding(tenantId, search.value || undefined),
    ])

    profiles.value = profRes || []
    outstandingInvoices.value = outRes || []
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Failed to load balances: ${err.message}` })
  } finally {
    loading.value = false
  }
}

// Stats rollups
const totalOutstandingDue = computed(() => {
  return outstandingInvoices.value.reduce((sum, inv) => sum + inv.due_amount, 0)
})

const totalInvoiced = computed(() => {
  return profiles.value.reduce((sum, p) => sum + p.total_invoiced, 0)
})

const averageCollectionRate = computed(() => {
  if (totalInvoiced.value <= 0) return '0.0%'
  const paid = totalInvoiced.value - totalOutstandingDue.value
  const pct = (paid / totalInvoiced.value) * 100
  return `${pct.toFixed(1)}%`
})

const formatAmountBdt = (val: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'BDT',
  }).format(val)
}

const formatDate = (val: string | null | undefined) => {
  if (!val) return '—'
  try {
    return new Date(val).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  } catch {
    return val
  }
}

onMounted(() => {
  void loadData()
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
.border-slate-800\/50 {
  border-color: rgba(30, 41, 59, 0.5);
}
.hover\:bg-slate-800\/40:hover {
  background-color: rgba(30, 41, 59, 0.4);
}

/* Glassmorphism Classes */
.glass-card {
  background: rgba(30, 41, 59, 0.4);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px border-solid rgba(255, 255, 255, 0.05);
  border-radius: 12px;
}

.glass-input :deep(.q-field__control) {
  border-radius: 8px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px border-solid rgba(255, 255, 255, 0.08);
}
</style>

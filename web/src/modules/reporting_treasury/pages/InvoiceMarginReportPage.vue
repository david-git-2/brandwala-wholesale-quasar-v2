<template>
  <q-page class="q-pa-lg bg-slate-900 text-white">
    <!-- Header Block -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="text-h4 text-weight-bolder tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-teal-400 to-emerald-400">
          Invoice Margin Reports
        </div>
        <div class="text-subtitle2 text-slate-400 q-mt-xs">
          Analyze sales revenue, calculate real-time product margins, and track collections performance.
        </div>
      </div>
    </div>

    <!-- Filter Control Card -->
    <div class="glass-card q-pa-md q-mb-lg row items-center justify-between q-col-gutter-sm">
      <div class="col-12 col-md-3">
        <q-input
          v-model="search"
          placeholder="Search invoice no, customer name..."
          dark
          dense
          outlined
          class="glass-input"
          @update:model-value="resetAndFetch"
        >
          <template #append>
            <q-icon name="search" class="text-slate-400" />
          </template>
        </q-input>
      </div>

      <div class="col-12 col-sm-6 col-md-2">
        <q-select
          v-model="typeFilter"
          :options="typeOptions"
          label="Invoice Type"
          dark
          dense
          outlined
          emit-value
          map-options
          class="glass-input"
          @update:model-value="resetAndFetch"
        />
      </div>

      <div class="col-12 col-sm-6 col-md-2">
        <q-input
          v-model="startDate"
          type="date"
          label="Start Date"
          dark
          dense
          outlined
          class="glass-input"
          @update:model-value="resetAndFetch"
        />
      </div>

      <div class="col-12 col-sm-6 col-md-2">
        <q-input
          v-model="endDate"
          type="date"
          label="End Date"
          dark
          dense
          outlined
          class="glass-input"
          @update:model-value="resetAndFetch"
        />
      </div>

      <div class="col-auto">
        <q-btn
          color="teal"
          outline
          icon="refresh"
          no-caps
          label="Reset Filters"
          class="glass-btn-outline px-3"
          @click="resetFilters"
        />
      </div>
    </div>

    <!-- Invoices List Table -->
    <div class="glass-card overflow-hidden">
      <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
        <thead>
          <tr class="text-slate-400 border-b border-slate-800">
            <th class="text-left font-semibold py-4">Invoice No</th>
            <th class="text-left font-semibold">Date</th>
            <th class="text-left font-semibold">Customer / Recipient</th>
            <th class="text-left font-semibold">Type</th>
            <th class="text-right font-semibold">Total Amount</th>
            <th class="text-right font-semibold">Paid Amount</th>
            <th class="text-right font-semibold">Due Amount</th>
            <th class="text-right font-semibold">Gross Profit</th>
            <th class="text-right font-semibold">Margin %</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading" class="border-b border-slate-800/50">
            <td colspan="9" class="text-center py-8 text-slate-400">
              <q-spinner-dots size="40px" color="teal" />
            </td>
          </tr>
          <tr v-else-if="!invoices.length" class="border-b border-slate-800/50">
            <td colspan="9" class="text-center py-8 text-slate-500">
              No posted invoices found.
            </td>
          </tr>
          <tr
            v-for="row in invoices"
            :key="row.id"
            class="hover:bg-slate-800/40 transition-colors duration-200 border-b border-slate-800/50"
          >
            <td class="py-4 text-weight-bold text-teal-400">
              {{ row.invoice_no }}
            </td>
            <td>{{ formatDate(row.invoice_date) }}</td>
            <td>
              <div class="text-weight-medium">{{ row.recipient_name || 'Walk-in / Direct' }}</div>
              <div v-if="row.recipient_phone" class="text-caption text-slate-400">{{ row.recipient_phone }}</div>
            </td>
            <td>
              <q-chip
                dense
                square
                color="slate-800"
                text-color="teal-300"
                class="text-weight-bold text-uppercase text-xs"
              >
                {{ row.invoice_type }}
              </q-chip>
            </td>
            <td class="text-right text-slate-300">{{ formatAmountBdt(row.total_amount) }}</td>
            <td class="text-right text-emerald-400">{{ formatAmountBdt(row.paid_amount) }}</td>
            <td class="text-right text-negative">{{ formatAmountBdt(row.due_amount) }}</td>
            <td class="text-right text-weight-bold text-teal-300">{{ formatAmountBdt(row.gross_profit) }}</td>
            <td class="text-right text-weight-bold" :class="getMarginClass(row.gross_profit, row.total_amount)">
              {{ formatPercent(row.gross_profit, row.total_amount) }}
            </td>
          </tr>
        </tbody>
      </q-markup-table>

      <!-- Pagination Block -->
      <div v-if="totalPages > 1" class="row justify-between items-center q-pa-md border-t border-slate-800">
        <div class="text-caption text-slate-400">
          Showing page {{ page }} of {{ totalPages }} ({{ totalCount }} total records)
        </div>
        <q-pagination
          v-model="page"
          :max="totalPages"
          :max-pages="5"
          boundary-links
          direction-links
          dark
          color="teal"
          @update:model-value="fetchReport"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { treasuryRepository } from '../repositories/treasuryRepository'

const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const invoices = ref<any[]>([])

// Query Filters
const search = ref('')
const typeFilter = ref('__all__')
const startDate = ref('')
const endDate = ref('')

// Pagination
const page = ref(1)
const pageSize = ref(20)
const totalCount = ref(0)
const totalPages = ref(0)

const typeOptions = [
  { label: 'All Types', value: '__all__' },
  { label: 'Wholesale', value: 'wholesale' },
  { label: 'Retail', value: 'retail' },
  { label: 'Dropship', value: 'dropship' },
]

const resetFilters = () => {
  search.value = ''
  typeFilter.value = '__all__'
  startDate.value = ''
  endDate.value = ''
  resetAndFetch()
}

const resetAndFetch = () => {
  page.value = 1
  void fetchReport()
}

const fetchReport = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  try {
    const res = await treasuryRepository.listInvoiceMarginReport({
      tenantId,
      page: page.value,
      pageSize: pageSize.value,
      search: search.value || undefined,
      invoiceType: typeFilter.value === '__all__' ? undefined : typeFilter.value,
      startDate: startDate.value || undefined,
      endDate: endDate.value || undefined,
    })

    invoices.value = res.data || []
    totalCount.value = res.meta.total
    totalPages.value = res.meta.total_pages
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Failed to load margins report: ${err.message}` })
  } finally {
    loading.value = false
  }
}

const getMarginClass = (profit: number, total: number) => {
  if (total <= 0) return 'text-slate-400'
  const pct = (profit / total) * 100
  if (pct >= 40) return 'text-emerald-400'
  if (pct >= 20) return 'text-teal-300'
  if (pct >= 0) return 'text-amber-400'
  return 'text-red-400'
}

const formatPercent = (profit: number, total: number) => {
  if (total <= 0) return '0.0%'
  const pct = (profit / total) * 100
  return `${pct.toFixed(1)}%`
}

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
  void fetchReport()
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

.glass-btn-outline {
  border: 1px border-solid rgba(20, 184, 166, 0.4);
  background: rgba(20, 184, 166, 0.05);
  border-radius: 8px;
  color: #14b8a6;
  transition: background 0.15s ease;
}
.glass-btn-outline:hover {
  background: rgba(20, 184, 166, 0.15);
}

.glass-input :deep(.q-field__control) {
  border-radius: 8px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px border-solid rgba(255, 255, 255, 0.08);
}
</style>

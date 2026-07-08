<template>
  <TreasuryPageShell
    title="Invoice Margin Reports"
    subtitle="Analyze sales revenue, calculate real-time product margins, and track collections performance."
    :error="error"
  >
    <div class="q-gutter-y-lg">
      <!-- Filter Control Card -->
      <TreasuryFilterBar>
        <div class="row q-col-gutter-md items-center justify-between">
          <div class="col-12 col-md-3">
            <q-input
              v-model="search"
              placeholder="Search invoice no, customer name..."
              dense
              outlined
              @update:model-value="resetAndFetch"
            >
              <template #append>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>

          <div class="col-12 col-sm-6 col-md-2">
            <q-select
              v-model="typeFilter"
              :options="typeOptions"
              label="Invoice Type"
              dense
              outlined
              emit-value
              map-options
              @update:model-value="resetAndFetch"
            />
          </div>

          <div class="col-12 col-sm-6 col-md-2">
            <q-input
              v-model="startDate"
              type="date"
              label="Start Date"
              dense
              outlined
              @update:model-value="resetAndFetch"
            />
          </div>

          <div class="col-12 col-sm-6 col-md-2">
            <q-input
              v-model="endDate"
              type="date"
              label="End Date"
              dense
              outlined
              @update:model-value="resetAndFetch"
            />
          </div>

          <div class="col-auto">
            <q-btn
              color="primary"
              outline
              icon="refresh"
              no-caps
              label="Reset Filters"
              class="px-3"
              @click="resetFilters"
            />
          </div>
        </div>
      </TreasuryFilterBar>

      <!-- Invoices List Table -->
      <q-card flat bordered>
        <TreasuryTableWrap>
          <q-table
            flat
            row-key="id"
            :rows="invoices"
            :columns="columns"
            :loading="loading"
            :pagination="{ rowsPerPage: pageSize }"
            hide-pagination
            :dense="$q.screen.lt.md"
            table-style="min-width: 1000px;"
          >
            <template #body-cell-invoice_no="props">
              <q-td :props="props" class="text-weight-bold text-primary cursor-pointer" @click="navigateToDetails(props.row.id)">
                {{ props.row.invoice_no }}
              </q-td>
            </template>

            <template #body-cell-recipient="props">
              <q-td :props="props">
                <div class="text-weight-medium">{{ props.row.recipient_name || 'Walk-in / Direct' }}</div>
                <div v-if="props.row.recipient_phone" class="text-caption text-grey-6">{{ props.row.recipient_phone }}</div>
              </q-td>
            </template>

            <template #body-cell-invoice_type="props">
              <q-td :props="props">
                <q-chip
                  dense
                  square
                  color="blue-1"
                  text-color="blue-9"
                  class="text-weight-bold text-uppercase text-xs"
                >
                  {{ props.row.invoice_type }}
                </q-chip>
              </q-td>
            </template>

            <template #body-cell-total_amount="props">
              <q-td :props="props" class="text-right">
                {{ formatAmountBdt(props.row.total_amount) }}
              </q-td>
            </template>

            <template #body-cell-paid_amount="props">
              <q-td :props="props" class="text-right text-positive">
                {{ formatAmountBdt(props.row.paid_amount) }}
              </q-td>
            </template>

            <template #body-cell-due_amount="props">
              <q-td :props="props" class="text-right text-negative">
                {{ formatAmountBdt(props.row.due_amount) }}
              </q-td>
            </template>

            <template #body-cell-gross_profit="props">
              <q-td :props="props" class="text-right text-weight-bold text-primary">
                {{ formatAmountBdt(props.row.gross_profit) }}
              </q-td>
            </template>

            <template #body-cell-margin_pct="props">
              <q-td :props="props" class="text-right text-weight-bold" :class="getMarginClass(props.row.gross_profit, props.row.total_amount)">
                {{ formatPercent(props.row.gross_profit, props.row.total_amount) }}
              </q-td>
            </template>
          </q-table>
        </TreasuryTableWrap>

        <!-- Pagination Block -->
        <div v-if="totalPages > 1" class="row justify-between items-center q-pa-md border-t">
          <div class="text-caption text-grey-7">
            Showing page {{ page }} of {{ totalPages }} ({{ totalCount }} total records)
          </div>
          <q-pagination
            v-model="page"
            :max="totalPages"
            :max-pages="5"
            boundary-links
            direction-links
            color="primary"
            @update:model-value="fetchReport"
          />
        </div>
      </q-card>
    </div>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import type { QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'
import { treasuryRepository } from '../repositories/treasuryRepository'
import TreasuryPageShell from '../components/TreasuryPageShell.vue'
import TreasuryFilterBar from '../components/TreasuryFilterBar.vue'
import TreasuryTableWrap from '../components/TreasuryTableWrap.vue'

const router = useRouter()

const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const error = ref<string | null>(null)
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

const columns: QTableColumn[] = [
  { name: 'invoice_no', label: 'Invoice No', field: 'invoice_no', align: 'left', sortable: true },
  { name: 'invoice_date', label: 'Date', field: 'invoice_date', align: 'left', sortable: true },
  { name: 'recipient', label: 'Customer / Recipient', field: 'recipient_name', align: 'left', sortable: true },
  { name: 'invoice_type', label: 'Type', field: 'invoice_type', align: 'left', sortable: true },
  { name: 'total_amount', label: 'Total Amount', field: 'total_amount', align: 'right', sortable: true },
  { name: 'paid_amount', label: 'Paid Amount', field: 'paid_amount', align: 'right', sortable: true },
  { name: 'due_amount', label: 'Due Amount', field: 'due_amount', align: 'right', sortable: true },
  { name: 'gross_profit', label: 'Gross Profit', field: 'gross_profit', align: 'right', sortable: true },
  { name: 'margin_pct', label: 'GP %', field: 'gross_profit', align: 'right' },
]

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
  error.value = null
  try {
    const res = await treasuryRepository.listInvoiceMarginReport({
      tenantId,
      page: page.value,
      pageSize: pageSize.value,
      search: search.value || undefined,
      invoiceType: typeFilter.value === '__all__' ? undefined : typeFilter.value,
      startDate: startDate.value || undefined,
      endDate: endDate.value || undefined,
    } as any)

    invoices.value = res.data || []
    totalCount.value = res.meta.total
    totalPages.value = res.meta.total_pages
  } catch (err: any) {
    error.value = err.message
    $q.notify({ type: 'negative', message: `Failed to load margins report: ${err.message}` })
  } finally {
    loading.value = false
  }
}

const getMarginClass = (profit: number, total: number) => {
  if (total <= 0) return 'text-grey-6'
  const pct = (profit / total) * 100
  if (pct >= 40) return 'text-positive'
  if (pct >= 20) return 'text-primary'
  if (pct >= 0) return 'text-warning'
  return 'text-negative'
}

const formatPercent = (profit: number, total: number) => {
  if (total <= 0) return '0.0%'
  const pct = (profit / total) * 100
  return `${pct.toFixed(1)}%`
}

const navigateToDetails = (id: number) => {
  void router.push({
    name: 'app-finance-invoice-margin-details-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      id,
    },
  })
}

onMounted(() => {
  void fetchReport()
})
</script>

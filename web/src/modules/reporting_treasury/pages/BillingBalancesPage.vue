<template>
  <TreasuryPageShell
    title="Customer Balances &amp; Outstanding AR"
    subtitle="Analyze real-time Accounts Receivable (AR) rollups and active credit balances."
    :error="error"
  >
    <div class="q-gutter-y-lg">
      <!-- Metrics Grid -->
      <TreasuryStatGrid :items="statCards" />

      <!-- Filter Control Card -->
      <TreasuryFilterBar>
        <div class="row q-col-gutter-md items-center justify-between">
          <div class="col-12 col-md-5">
            <q-input
              v-model="search"
              placeholder="Search by profile name, invoice no, email..."
              dense
              outlined
              @update:model-value="loadData"
            >
              <template #append>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>

          <div class="col-auto">
            <q-tabs
              v-model="activeTab"
              dense
              no-caps
              active-color="primary"
              indicator-color="primary"
            >
              <q-tab name="profiles" label="Billing Profiles" icon="people" />
              <q-tab name="outstanding" label="Outstanding Invoices" icon="description" />
            </q-tabs>
          </div>
        </div>
      </TreasuryFilterBar>

      <!-- Tab Panels Card -->
      <q-card flat bordered class="bg-white overflow-hidden">
        <q-tab-panels v-model="activeTab" animated class="bg-transparent text-black">
          <!-- Billing Profiles Panel -->
          <q-tab-panel name="profiles" class="q-pa-none">
            <TreasuryTableWrap>
              <q-table
                flat
                row-key="id"
                :rows="profiles"
                :columns="profileColumns"
                :loading="loading"
                :pagination="{ rowsPerPage: 50 }"
                :dense="$q.screen.lt.md"
                table-style="min-width: 900px;"
              >
                <template #body-cell-name="props">
                  <div class="row items-center no-wrap">
                    <q-avatar
                      size="32px"
                      class="q-mr-sm text-weight-bold text-white"
                      :style="{ backgroundColor: props.row.color || '#1976D2' }"
                    >
                      {{ props.row.name.charAt(0) }}
                    </q-avatar>
                    <div>
                      <div class="text-weight-bold">{{ props.row.name }}</div>
                      <div class="text-caption text-grey-6">{{ props.row.email || '-' }}</div>
                    </div>
                  </div>
                </template>

                <template #body-cell-total_invoiced="props">
                  <q-td :props="props" class="text-right">
                    {{ formatAmountBdt(props.row.total_invoiced) }}
                  </q-td>
                </template>

                <template #body-cell-total_paid="props">
                  <q-td :props="props" class="text-right text-positive">
                    {{ formatAmountBdt(props.row.total_paid) }}
                  </q-td>
                </template>

                <template #body-cell-balance_due="props">
                  <q-td :props="props" class="text-right text-weight-bold" :class="props.row.balance_due > 0 ? 'text-negative' : 'text-grey-6'">
                    {{ formatAmountBdt(props.row.balance_due) }}
                  </q-td>
                </template>

                <template #body-cell-collection_pct="props">
                  <q-td :props="props" class="text-center">
                    <div class="row items-center justify-center no-wrap">
                      <q-linear-progress
                        :value="props.row.total_invoiced > 0 ? (props.row.total_paid / props.row.total_invoiced) : 0"
                        color="primary"
                        class="q-mr-sm rounded-borders"
                        style="width: 60px; height: 6px;"
                      />
                      <span class="text-caption text-grey-8 text-weight-bold">
                        {{ props.row.total_invoiced > 0 ? ((props.row.total_paid / props.row.total_invoiced) * 100).toFixed(0) : '0' }}%
                      </span>
                    </div>
                  </q-td>
                </template>
              </q-table>
            </TreasuryTableWrap>
          </q-tab-panel>

          <!-- Outstanding Invoices Panel -->
          <q-tab-panel name="outstanding" class="q-pa-none">
            <TreasuryTableWrap>
              <q-table
                flat
                row-key="id"
                :rows="outstandingInvoices"
                :columns="invoiceColumns"
                :loading="loading"
                :pagination="{ rowsPerPage: 50 }"
                :dense="$q.screen.lt.md"
                table-style="min-width: 900px;"
              >
                <template #body-cell-invoice_no="props">
                  <q-td :props="props" class="text-weight-bold text-primary">
                    {{ props.row.invoice_no }}
                  </q-td>
                </template>

                <template #body-cell-invoice_date="props">
                  <q-td :props="props">
                    {{ props.row.invoice_date || '-' }}
                  </q-td>
                </template>

                <template #body-cell-billing_profile_name="props">
                  <q-td :props="props">
                    {{ props.row.billing_profile_name || 'Walk-in / Direct' }}
                  </q-td>
                </template>

                <template #body-cell-recipient="props">
                  <q-td :props="props">
                    <div class="text-weight-medium">{{ props.row.recipient_name || '-' }}</div>
                    <div v-if="props.row.recipient_phone" class="text-caption text-grey-6">{{ props.row.recipient_phone }}</div>
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
                  <q-td :props="props" class="text-right text-weight-bold text-negative">
                    {{ formatAmountBdt(props.row.due_amount) }}
                  </q-td>
                </template>
              </q-table>
            </TreasuryTableWrap>
          </q-tab-panel>
        </q-tab-panels>
      </q-card>
    </div>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import type { QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'
import { treasuryRepository } from '../repositories/treasuryRepository'
import TreasuryPageShell from '../components/TreasuryPageShell.vue'
import TreasuryStatGrid from '../components/TreasuryStatGrid.vue'
import TreasuryFilterBar from '../components/TreasuryFilterBar.vue'
import TreasuryTableWrap from '../components/TreasuryTableWrap.vue'

const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const error = ref<string | null>(null)
const activeTab = ref('profiles')
const search = ref('')

const profiles = ref<any[]>([])
const outstandingInvoices = ref<any[]>([])

const profileColumns: QTableColumn[] = [
  { name: 'name', label: 'Customer Profile', field: 'name', align: 'left', sortable: true },
  { name: 'total_invoiced', label: 'Total Invoiced', field: 'total_invoiced', align: 'right', sortable: true },
  { name: 'total_paid', label: 'Total Paid', field: 'total_paid', align: 'right', sortable: true },
  { name: 'balance_due', label: 'Balance Due', field: 'balance_due', align: 'right', sortable: true },
  { name: 'collection_pct', label: 'Collection %', field: 'total_paid', align: 'center' },
]

const invoiceColumns: QTableColumn[] = [
  { name: 'invoice_no', label: 'Invoice No', field: 'invoice_no', align: 'left', sortable: true },
  { name: 'invoice_date', label: 'Invoice Date', field: 'invoice_date', align: 'left', sortable: true },
  { name: 'billing_profile_name', label: 'Billing Profile', field: 'billing_profile_name', align: 'left', sortable: true },
  { name: 'recipient', label: 'Recipient / Phone', field: 'recipient_name', align: 'left', sortable: true },
  { name: 'total_amount', label: 'Total Amount', field: 'total_amount', align: 'right', sortable: true },
  { name: 'paid_amount', label: 'Paid Amount', field: 'paid_amount', align: 'right', sortable: true },
  { name: 'due_amount', label: 'Due Balance', field: 'due_amount', align: 'right', sortable: true },
]

const loadData = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  error.value = null
  try {
    const [profRes, outRes] = await Promise.all([
      treasuryRepository.listBillingBalances(tenantId, search.value || undefined),
      treasuryRepository.listInvoiceOutstanding(tenantId, search.value || undefined),
    ])

    profiles.value = profRes || []
    outstandingInvoices.value = outRes || []
  } catch (err: any) {
    error.value = err.message
    $q.notify({ type: 'negative', message: `Failed to load balances: ${err.message}` })
  } finally {
    loading.value = false
  }
}

// Stats rollups
const totalInvoiced = computed(() => {
  return profiles.value.reduce((sum, p) => sum + (p.total_invoiced || 0), 0)
})

const totalPaid = computed(() => {
  return profiles.value.reduce((sum, p) => sum + (p.total_paid || 0), 0)
})

const totalOutstandingDue = computed(() => {
  return profiles.value.reduce((sum, p) => sum + (p.balance_due || 0), 0)
})

const collectionRate = computed(() => {
  return totalInvoiced.value > 0 ? (totalPaid.value / totalInvoiced.value) * 100 : 0
})

const statCards = computed(() => [
  {
    label: 'Total Outstanding AR',
    value: totalOutstandingDue.value,
    caption: search.value ? 'Based on filtered profiles (includes Walk-in)' : 'Based on billing profiles tab (includes Walk-in / Direct)',
    valueClass: 'text-negative',
    format: 'currency' as const,
  },
  {
    label: 'Total Paid Collections',
    value: totalPaid.value,
    caption: search.value ? 'Based on filtered profiles (includes Walk-in)' : 'Based on billing profiles tab (includes Walk-in / Direct)',
    valueClass: 'text-positive',
    format: 'currency' as const,
  },
  {
    label: 'Average Collection Rate',
    value: collectionRate.value,
    caption: search.value ? 'Invoiced to cash conversion (filtered)' : 'Invoiced to cash conversion percentage',
    valueClass: 'text-primary',
    format: 'percent' as const,
  },
])

onMounted(() => {
  void loadData()
})
</script>

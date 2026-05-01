<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back"
        @click="goBack"
      />
      <div class="text-h5">Invoice Accounting</div>
    </div>

    <PageInitialLoader v-if="loading" />

    <template v-else>
      <q-card flat bordered>
        <q-card-section class="row items-center justify-between q-col-gutter-md">
          <div class="text-subtitle1">
            <span v-if="selectedInvoiceId">Invoice #{{ selectedInvoiceId }} Accounting</span>
            <span v-else>All Invoice Accounting Entries</span>
          </div>
          <div class="text-caption text-grey-7">Total entries: {{ total }}</div>
        </q-card-section>

        <q-separator />

        <q-card-section class="q-pa-none">
          <q-markup-table flat bordered separator="cell" wrap-cells>
            <thead>
              <tr>
                <th class="text-left" style="width: 70px">SL</th>
                <th class="text-left" style="width: 120px">Entry ID</th>
                <th class="text-left" style="width: 120px">Invoice ID</th>
                <th class="text-left" style="width: 140px">Invoice Item ID</th>
                <th class="text-left" style="width: 140px">Inventory Item ID</th>
                <th class="text-left" style="width: 120px">Shipment ID</th>
                <th class="text-left" style="width: 140px">Shipment Item ID</th>
                <th class="text-right" style="width: 120px">Qty</th>
                <th class="text-right" style="width: 140px">Cost</th>
                <th class="text-right" style="width: 140px">Sell</th>
                <th class="text-right" style="width: 160px">Total Cost</th>
                <th class="text-right" style="width: 160px">Total Sell</th>
                <th class="text-right" style="width: 160px">Profit</th>
                <th class="text-left" style="width: 120px">Status</th>
                <th class="text-left" style="width: 140px">Entry Date</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!rows.length">
                <td colspan="15" class="text-center text-grey-7">No accounting entries found.</td>
              </tr>
              <tr v-for="(row, index) in rows" :key="row.id">
                <td>{{ (page - 1) * pageSize + index + 1 }}</td>
                <td>{{ row.id }}</td>
                <td>{{ row.invoice_id ?? 'N/A' }}</td>
                <td>{{ row.invoice_item_id ?? 'N/A' }}</td>
                <td>{{ row.inventory_item_id }}</td>
                <td>{{ row.shipment_id ?? 'N/A' }}</td>
                <td>{{ row.shipment_item_id ?? 'N/A' }}</td>
                <td class="text-right">{{ row.quantity }}</td>
                <td class="text-right">{{ formatAmount(row.cost_amount) }}</td>
                <td class="text-right">{{ formatAmount(row.sell_price_amount) }}</td>
                <td class="text-right">{{ formatAmount(row.total_cost_amount) }}</td>
                <td class="text-right">{{ formatAmount(row.total_sell_amount) }}</td>
                <td class="text-right">{{ formatAmount(row.gross_profit_amount) }}</td>
                <td>{{ row.status }}</td>
                <td>{{ row.entry_date }}</td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-card-section>
      </q-card>

      <div v-if="totalPages > 1" class="row justify-center q-mt-md">
        <q-pagination
          :model-value="page"
          :max="totalPages"
          :max-pages="8"
          direction-links
          boundary-links
          @update:model-value="onPageChange"
        />
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { showWarningDialog } from 'src/utils/appFeedback'
import { invoiceService } from 'src/modules/invoice/services/invoiceService'
import type { InventoryAccountingEntry } from 'src/modules/invoice/types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const loading = ref(false)
const rows = ref<InventoryAccountingEntry[]>([])
const page = ref(1)
const pageSize = ref(20)
const total = ref(0)
const totalPages = ref(1)

const selectedInvoiceId = computed(() => {
  const raw = route.params.invoiceId
  const normalized = Array.isArray(raw) ? raw[0] : raw
  const parsed = Number(normalized)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null
})

const formatAmount = (value: number) => Number(value ?? 0).toFixed(2)

const loadEntries = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  try {
    const filters: Record<string, unknown> = {}
    const operators: Record<string, 'eq'> = {}

    if (selectedInvoiceId.value != null) {
      filters.invoice_id = selectedInvoiceId.value
      operators.invoice_id = 'eq'
    }

    const result = await invoiceService.listInventoryAccountingEntries({
      tenant_id: tenantId,
      filters,
      operators,
      page: page.value,
      page_size: pageSize.value,
      sortBy: 'id',
      sortOrder: 'desc',
    })

    if (!result.success) {
      rows.value = []
      total.value = 0
      totalPages.value = 1
      showWarningDialog(result.error ?? 'Failed to load accounting entries.')
      return
    }

    rows.value = result.data?.data ?? []
    total.value = result.data?.meta.total ?? 0
    totalPages.value = result.data?.meta.total_pages ?? 1
  } finally {
    loading.value = false
  }
}

const onPageChange = async (nextPage: number) => {
  page.value = nextPage
  await loadEntries()
}

const goBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  if (selectedInvoiceId.value != null) {
    await router.push(`${tenantPrefix}/app/invoices/${selectedInvoiceId.value}`)
    return
  }
  await router.push(`${tenantPrefix}/app/invoice-accounting`)
}

watch(
  () => route.params.invoiceId,
  async () => {
    page.value = 1
    await loadEntries()
  },
)

onMounted(loadEntries)
</script>

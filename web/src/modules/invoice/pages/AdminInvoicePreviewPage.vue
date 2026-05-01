<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Invoice"
        @click="goBack"
      />
      <div class="text-subtitle1 text-weight-medium">Invoice Preview</div>
    </div>

    <PageInitialLoader v-if="loading" />

    <q-banner v-else-if="!invoice" class="bg-grey-2 text-grey-8">
      Invoice not found.
    </q-banner>

    <template v-else>
      <q-card flat bordered class="q-mb-md">
        <q-card-section>
          <div class="text-h6">{{ invoice.invoice_no }}</div>
          <div class="text-caption text-grey-7 q-mt-xs">Invoice ID: {{ invoice.id }}</div>
          <div class="text-caption text-grey-7">Invoice Date: {{ invoice.invoice_date }}</div>
          <div class="text-caption text-grey-7">Source: {{ invoice.source_type }} | Source ID: {{ invoice.source_id }}</div>
        </q-card-section>
      </q-card>

      <q-card flat bordered>
        <q-card-section class="q-pa-none">
          <q-markup-table flat bordered>
            <thead>
              <tr>
                <th class="text-left" style="width: 60px">SL</th>
                <th class="text-left">Item Name</th>
                <th class="text-right" style="width: 160px">Allocated Qty</th>
                <th class="text-right" style="width: 160px">Price</th>
                <th class="text-right" style="width: 180px">Total</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!previewRows.length">
                <td colspan="5" class="text-center text-grey-7">No allocated items yet.</td>
              </tr>
              <tr v-for="(row, index) in previewRows" :key="`preview-${row.id}`">
                <td>{{ index + 1 }}</td>
                <td>{{ row.name }}</td>
                <td class="text-right">{{ row.allocatedQuantity }}</td>
                <td class="text-right">{{ formatAmount(row.price) }}</td>
                <td class="text-right">{{ formatAmount(row.total) }}</td>
              </tr>
            </tbody>
            <tfoot v-if="previewRows.length">
              <tr>
                <td colspan="4" class="text-right text-weight-medium">Grand Total</td>
                <td class="text-right text-weight-medium">{{ formatAmount(grandTotal) }}</td>
              </tr>
            </tfoot>
          </q-markup-table>
        </q-card-section>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { invoiceService } from '../services/invoiceService'
import type { Invoice, InvoiceItem } from '../types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const loading = ref(false)
const invoices = ref<Invoice[]>([])
const items = ref<InvoiceItem[]>([])
const accountingRows = ref<
  Array<{
    invoice_item_id: number | null
    quantity: number
  }>
>([])

const invoice = computed(() => invoices.value[0] ?? null)

const toNumber = (value: unknown): number => {
  const n = Number(value)
  return Number.isFinite(n) ? n : 0
}

const allocatedByItemId = computed(() => {
  const map = new Map<number, number>()
  for (const row of accountingRows.value) {
    if (row.invoice_item_id == null) continue
    const current = map.get(row.invoice_item_id) ?? 0
    map.set(row.invoice_item_id, current + Math.max(0, row.quantity))
  }
  return map
})

const previewRows = computed(() =>
  items.value
    .map((item) => {
      const allocatedQuantity = Math.max(0, allocatedByItemId.value.get(item.id) ?? 0)
      const price = Math.max(0, toNumber(item.sell_price_amount))
      return {
        id: item.id,
        name: item.name_snapshot,
        allocatedQuantity,
        price,
        total: allocatedQuantity * price,
      }
    })
    .filter((row) => row.allocatedQuantity > 0),
)

const grandTotal = computed(() =>
  previewRows.value.reduce((sum, row) => sum + row.total, 0),
)

const formatAmount = (value: number) => value.toFixed(2)

const fetchAllAccountingEntriesForInvoice = async (invoiceId: number, tenantId: number) => {
  const pageSize = 200
  let page = 1
  const allRows: Array<{ invoice_item_id: number | null; quantity: number }> = []

  while (true) {
    const result = await invoiceService.listInventoryAccountingEntries({
      tenant_id: tenantId,
      filters: { invoice_id: invoiceId },
      operators: { invoice_id: 'eq' },
      page,
      page_size: pageSize,
      sortBy: 'id',
      sortOrder: 'asc',
    })

    if (!result.success) {
      throw new Error(result.error ?? 'Failed to load accounting entries.')
    }

    const rows = result.data?.data ?? []
    allRows.push(
      ...rows.map((row) => ({
        invoice_item_id: row.invoice_item_id,
        quantity: toNumber(row.quantity),
      })),
    )

    const totalPages = result.data?.meta.total_pages ?? 1
    if (page >= totalPages) break
    page += 1
  }

  return allRows
}

const loadData = async () => {
  const invoiceId = Number(route.params.id)
  const tenantId = authStore.tenantId
  if (!invoiceId || !tenantId) return

  loading.value = true
  try {
    const [invoiceResult, itemResult, accountingResult] = await Promise.all([
      invoiceService.listInvoices({
        tenant_id: tenantId,
        filters: { id: invoiceId },
        operators: { id: 'eq' },
        page: 1,
        page_size: 1,
      }),
      invoiceService.listInvoiceItems({
        tenant_id: tenantId,
        filters: { invoice_id: invoiceId },
        operators: { invoice_id: 'eq' },
        page: 1,
        page_size: 500,
        sortBy: 'id',
        sortOrder: 'asc',
      }),
      fetchAllAccountingEntriesForInvoice(invoiceId, tenantId),
    ])

    if (invoiceResult.success) {
      invoices.value = invoiceResult.data?.data ?? []
    }

    if (itemResult.success) {
      items.value = itemResult.data?.data ?? []
    }

    accountingRows.value = accountingResult
  } finally {
    loading.value = false
  }
}

const goBack = async () => {
  const invoiceId = Number(route.params.id)
  if (!invoiceId) return
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/invoices/${invoiceId}`)
}

onMounted(loadData)
</script>

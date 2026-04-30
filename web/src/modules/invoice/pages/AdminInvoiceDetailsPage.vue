<template>
  <q-page class="q-pa-md">
    <q-btn flat no-caps color="primary" icon="arrow_back" label="Back to Invoices" @click="goBack" class="q-mb-md" />

    <PageInitialLoader v-if="loading" />

    <q-banner v-else-if="!invoice" class="bg-grey-2 text-grey-8">
      Invoice not found.
    </q-banner>

    <template v-else>
      <q-card flat bordered class="q-mb-md">
        <q-card-section>
          <div class="text-h6">#{{ invoice.id }} {{ invoice.invoice_no }}</div>
          <div class="row items-center q-col-gutter-md q-mt-sm q-mb-xs">
            <div class="col-12 col-sm-4">
              <q-select
                outlined
                dense
                emit-value
                map-options
                label="Status"
                :options="statusOptions"
                :model-value="selectedStatus"
                :loading="savingStatus"
                @update:model-value="onStatusChange"
              />
            </div>
            <div class="col-12 col-sm-4 text-caption text-grey-7">
              Payment: {{ invoice.payment_status }}
            </div>
          </div>
          <div class="text-caption text-grey-7">Source: {{ invoice.source_type }} | Source ID: {{ invoice.source_id }}</div>
          <div class="text-caption text-grey-7">Invoice Date: {{ invoice.invoice_date }} | Due: {{ invoice.due_date || 'N/A' }}</div>
          <div class="text-body2 q-mt-sm">Subtotal: {{ invoice.subtotal_amount }} | Total: {{ invoice.total_amount }} | Paid: {{ invoice.paid_amount }}</div>
        </q-card-section>
      </q-card>

      <q-card flat bordered>
        <q-card-section class="text-subtitle1">Items</q-card-section>
        <q-separator />
        <q-list separator>
          <q-item v-for="row in items" :key="row.id">
            <q-item-section>
              <q-item-label>{{ row.name_snapshot }}</q-item-label>
              <q-item-label caption>
                Qty: {{ row.quantity }} | Cost: {{ row.cost_amount }} | Sell: {{ row.sell_price_amount }}
              </q-item-label>
              <div
                v-if="invoice?.status === 'draft' && row.product_id != null"
                class="q-mt-xs text-caption text-grey-8"
              >
                <div class="text-weight-medium q-mb-xs">Matched Inventory:</div>
                <div v-if="inventoryByProductId[row.product_id]?.length">
                  <div
                    v-for="inventoryRow in inventoryByProductId[row.product_id]"
                    :key="inventoryRow.id"
                  >
                    #{{ inventoryRow.id }} {{ inventoryRow.name }} | Available:
                    {{ inventoryRow.quantities.available }}
                  </div>
                </div>
                <div v-else>No inventory found for this product.</div>
              </div>
            </q-item-section>
            <q-item-section side class="text-weight-medium">{{ row.line_total_amount }}</q-item-section>
          </q-item>
        </q-list>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import { invoiceService } from '../services/invoiceService'
import type { Invoice, InvoiceItem, InvoiceStatus } from '../types'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const loading = ref(false)
const savingStatus = ref(false)
const invoices = ref<Invoice[]>([])
const items = ref<InvoiceItem[]>([])
const inventoryByProductId = ref<Record<number, InventoryItemWithStock[]>>({})
const selectedStatus = ref<InvoiceStatus>('draft')

const statusOptions: Array<{ label: string; value: InvoiceStatus }> = [
  { label: 'Draft', value: 'draft' },
  { label: 'Issued', value: 'issued' },
  { label: 'Partially Paid', value: 'partially_paid' },
  { label: 'Paid', value: 'paid' },
  { label: 'Overdue', value: 'overdue' },
  { label: 'Cancelled', value: 'cancelled' },
]

const invoice = computed(() => invoices.value[0] ?? null)

const loadDetails = async () => {
  const invoiceId = Number(route.params.id)
  if (!invoiceId || !authStore.tenantId) return

  loading.value = true
  try {
    const [invoiceResult, itemResult] = await Promise.all([
      invoiceService.listInvoices({
        tenant_id: authStore.tenantId,
        filters: { id: invoiceId },
        operators: { id: 'eq' },
        page: 1,
        page_size: 1,
      }),
      invoiceService.listInvoiceItems({
        tenant_id: authStore.tenantId,
        filters: { invoice_id: invoiceId },
        operators: { invoice_id: 'eq' },
        page: 1,
        page_size: 200,
        sortBy: 'id',
        sortOrder: 'asc',
      }),
    ])

    if (invoiceResult.success) {
      invoices.value = invoiceResult.data?.data ?? []
      selectedStatus.value = invoices.value[0]?.status ?? 'draft'
    }
    if (itemResult.success) items.value = itemResult.data?.data ?? []
    await loadInventoryMatches()
  } finally {
    loading.value = false
  }
}

const loadInventoryMatches = async () => {
  if (!authStore.tenantId || invoice.value?.status !== 'draft') {
    inventoryByProductId.value = {}
    return
  }

  const uniqueProductIds = Array.from(
    new Set(
      items.value
        .map((row) => row.product_id)
        .filter((id): id is number => typeof id === 'number'),
    ),
  )

  if (!uniqueProductIds.length) {
    inventoryByProductId.value = {}
    return
  }

  const nextMap: Record<number, InventoryItemWithStock[]> = {}
  const tenantId = authStore.tenantId
  if (!tenantId) {
    inventoryByProductId.value = {}
    return
  }
  await Promise.all(
    uniqueProductIds.map(async (productId) => {
      const result = await inventoryService.listInventoryItems({
        tenant_id: tenantId,
        filters: { product_id: productId },
        operators: { product_id: 'eq' },
        page: 1,
        page_size: 100,
        sortBy: 'id',
        sortOrder: 'desc',
      })

      nextMap[productId] = result.success ? result.data?.data ?? [] : []
    }),
  )

  inventoryByProductId.value = nextMap
}

const onStatusChange = async (nextStatus: InvoiceStatus) => {
  if (!invoice.value || nextStatus === invoice.value.status) {
    return
  }

  savingStatus.value = true
  try {
    const result = await invoiceService.updateInvoice({
      id: invoice.value.id,
      patch: { status: nextStatus },
    })

    if (result.success && result.data) {
      invoices.value = [result.data]
      selectedStatus.value = result.data.status
      await loadInventoryMatches()
      return
    }

    selectedStatus.value = invoice.value.status
  } finally {
    savingStatus.value = false
  }
}

const goBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/invoices`)
}

onMounted(loadDetails)
</script>

<template>
  <q-page class="invoice-preview-page q-pa-md">
    <div class="invoice-sheet">
      <div class="row items-start justify-between q-mb-md">
        <div>
          <div class="text-h6 text-weight-bold">Invoice</div>
          <div class="text-body2 text-grey-7">{{ invoice?.invoice_no ?? '-' }}</div>
        </div>
        <div class="text-right text-body2">
          <div><strong>Status:</strong> {{ invoice?.status ?? '-' }}</div>
          <div><strong>Date:</strong> {{ invoice?.invoice_date ?? '-' }}</div>
          <div><strong>Due:</strong> {{ invoice?.due_date ?? '-' }}</div>
        </div>
      </div>

      <q-markup-table flat bordered wrap-cells>
        <thead>
          <tr>
            <th class="text-left">SL</th>
            <th class="text-left">Description</th>
            <th class="text-right">Qty</th>
            <th class="text-right">Sell Price</th>
            <th class="text-right">Line Total</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!invoiceStore.invoiceItems.length">
            <td colspan="5" class="text-center text-grey-7">No invoice items found.</td>
          </tr>
          <tr v-for="(row, index) in invoiceStore.invoiceItems" :key="row.id">
            <td>{{ index + 1 }}</td>
            <td>{{ row.name_snapshot }}</td>
            <td class="text-right">{{ row.quantity }}</td>
            <td class="text-right">{{ formatAmount(row.sell_price_amount) }}</td>
            <td class="text-right">{{ formatAmount(Number(row.sell_price_amount) * Number(row.quantity)) }}</td>
          </tr>
        </tbody>
      </q-markup-table>

      <div class="row justify-end q-mt-md">
        <div class="invoice-total-box">
          <div class="row justify-between q-mb-xs">
            <div>Total Sell</div>
            <div class="text-weight-bold">{{ formatAmount(totalSell) }}</div>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvoiceStore } from '../stores/invoiceStore'

const route = useRoute()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()

const invoiceId = computed(() => Number(route.params.invoiceId))
const invoice = computed(() => invoiceStore.invoices.find((row) => row.id === invoiceId.value) ?? null)

const totalSell = computed(() =>
  invoiceStore.invoiceItems.reduce(
    (sum, row) => sum + Number(row.sell_price_amount ?? 0) * Number(row.quantity ?? 0),
    0,
  ),
)

const formatAmount = (value: number | null | undefined) => Number(value ?? 0).toFixed(2)

const load = async () => {
  if (!authStore.tenantId || !Number.isFinite(invoiceId.value)) return

  await invoiceStore.fetchInvoices({
    tenant_id: authStore.tenantId,
    filters: { id: invoiceId.value },
    operators: { id: 'eq' },
    page: 1,
    page_size: 1,
  })

  await invoiceStore.fetchInvoiceItems({
    tenant_id: authStore.tenantId,
    filters: { invoice_id: invoiceId.value },
    operators: { invoice_id: 'eq' },
    page: 1,
    page_size: 500,
    sortBy: 'created_at',
    sortOrder: 'asc',
  })
}

onMounted(() => {
  void load()
})
</script>

<style scoped>
.invoice-preview-page {
  background: #f5f6f8;
}

.invoice-sheet {
  width: 210mm;
  min-height: 297mm;
  max-width: 100%;
  margin: 0 auto;
  background: #fff;
  border: 1px solid #e6e8ec;
  padding: 20px;
  box-sizing: border-box;
}

.invoice-total-box {
  width: 320px;
  border: 1px solid #e6e8ec;
  padding: 12px;
}

@media print {
  .invoice-preview-page {
    background: #fff;
    padding: 0;
  }

  .invoice-sheet {
    width: 210mm;
    min-height: 297mm;
    border: none;
    margin: 0;
    padding: 12mm;
  }
}
</style>

<template>
  <q-page class="invoice-preview-page q-pa-md">
    <div class="invoice-sheet">
      <div class="row items-start justify-between q-mb-md">
        <div>
          <div class="text-h6 text-weight-bold">Invoice</div>
          <div class="text-body2 text-grey-7">{{ invoice?.invoice_no ?? '-' }}</div>
        </div>
        <div class="column items-end q-gutter-sm">
          <div class="text-right text-body2">
            <div><strong>Status:</strong> {{ invoice?.status ?? '-' }}</div>
            <div><strong>Date:</strong> {{ invoice?.invoice_date ?? '-' }}</div>
            <div><strong>Due:</strong> {{ invoice?.due_date ?? '-' }}</div>
          </div>
          <q-checkbox
            v-model="showImages"
            dense
            label="Show Images"
          />
        </div>
      </div>

      <q-markup-table flat bordered wrap-cells>
        <thead>
          <tr>
            <th class="text-left">SL</th>
            <th v-if="showImages" class="text-left">Image</th>
            <th class="text-left">Description</th>
            <th class="text-right">Qty</th>
            <th class="text-right">Sell Price</th>
            <th class="text-right">Line Total</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!invoiceStore.invoiceItems.length">
            <td :colspan="showImages ? 6 : 5" class="text-center text-grey-7">No invoice items found.</td>
          </tr>
          <tr v-for="(row, index) in invoiceStore.invoiceItems" :key="row.id">
            <td>{{ index + 1 }}</td>
            <td v-if="showImages">
              <q-avatar rounded size="48px">
                <img
                  :src="invoiceItemImageMap[row.inventory_item_id ?? -1] ?? fallbackImageUrl"
                  alt="item image"
                  class="invoice-image"
                />
              </q-avatar>
            </td>
            <td>{{ row.name_snapshot }}</td>
            <td class="text-right">{{ getNetQuantity(row) }}</td>
            <td class="text-right">{{ formatAmount(row.sell_price_amount) }}</td>
            <td class="text-right">{{ formatAmount(getNetSellAmount(row)) }}</td>
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
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import { useInvoiceStore } from '../stores/invoiceStore'
import { formatAmountBdt } from 'src/utils/currency'

const route = useRoute()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const showImages = ref(false)
const invoiceItemImageMap = ref<Record<number, string>>({})
const fallbackImageUrl = 'https://placehold.co/56x56?text=No+Image'

const invoiceId = computed(() => Number(route.params.invoiceId))
const invoice = computed(() => invoiceStore.invoices.find((row) => row.id === invoiceId.value) ?? null)
const getReturnedQuantity = (row: { return_normal_quantity?: number; return_open_box_quantity?: number }) =>
  Number(row.return_normal_quantity ?? 0) + Number(row.return_open_box_quantity ?? 0)
const getNetQuantity = (row: { quantity: number; return_normal_quantity?: number; return_open_box_quantity?: number }) =>
  Math.max(0, Number(row.quantity ?? 0) - getReturnedQuantity(row))
const getNetSellAmount = (row: { quantity: number; sell_price_amount: number; return_amount?: number }) =>
  Math.max(0, Number(row.quantity ?? 0) * Number(row.sell_price_amount ?? 0) - Number(row.return_amount ?? 0))

const totalSell = computed(() =>
  invoiceStore.invoiceItems.reduce(
    (sum, row) => sum + getNetSellAmount(row),
    0,
  ),
)

const formatAmount = (value: number | null | undefined) => formatAmountBdt(value)

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
  await loadInvoiceItemImages()
}

const loadInvoiceItemImages = async () => {
  const ids = Array.from(
    new Set(
      invoiceStore.invoiceItems
        .map((item) => item.inventory_item_id)
        .filter((id): id is number => typeof id === 'number'),
    ),
  )
  if (!ids.length) {
    invoiceItemImageMap.value = {}
    return
  }

  const entries = await Promise.all(
    ids.map(async (id) => {
      const result = await inventoryService.getInventoryItemById(id)
      return [id, result.success ? (result.data?.image_url ?? fallbackImageUrl) : fallbackImageUrl] as const
    }),
  )
  invoiceItemImageMap.value = Object.fromEntries(entries)
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

.invoice-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
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

<template>
  <q-page class="q-pa-md">
    <div class="text-h5 text-weight-bold q-mb-md">Invoice Accounting</div>

    <q-markup-table flat bordered wrap-cells>
      <thead>
        <tr>
          <th class="text-left">SL</th>
          <th class="text-left">Invoice ID</th>
          <th class="text-left">Invoice Item ID</th>
          <th class="text-left">Shipment ID</th>
          <th class="text-left">Product ID</th>
          <th class="text-right">Quantity</th>
          <th class="text-right">Cost</th>
          <th class="text-right">Sell Price</th>
          <th class="text-right">Total Cost</th>
          <th class="text-right">Total Sell</th>
          <th class="text-right">Gross Profit</th>
          <th class="text-left">Status</th>
          <th class="text-left">Entry Date</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!accountingStore.accountingEntries.length && !accountingStore.loading">
          <td colspan="13" class="text-center text-grey-7">No accounting entries found.</td>
        </tr>
        <tr v-for="(row, index) in accountingStore.accountingEntries" :key="row.id">
          <td>{{ index + 1 }}</td>
          <td>{{ row.invoice_id ?? '-' }}</td>
          <td>{{ row.invoice_item_id ?? '-' }}</td>
          <td>{{ row.shipment_id ?? '-' }}</td>
          <td>{{ row.product_id ?? '-' }}</td>
          <td class="text-right">{{ row.quantity }}</td>
          <td class="text-right">{{ row.cost_amount }}</td>
          <td class="text-right">{{ row.sell_price_amount }}</td>
          <td class="text-right">{{ row.total_cost_amount }}</td>
          <td class="text-right">{{ row.total_sell_amount }}</td>
          <td class="text-right">{{ row.gross_profit_amount }}</td>
          <td class="text-capitalize">{{ row.status }}</td>
          <td>{{ row.entry_date }}</td>
        </tr>
      </tbody>
    </q-markup-table>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useAccountingStore } from '../stores/accountingStore'

const authStore = useAuthStore()
const accountingStore = useAccountingStore()

const load = async () => {
  if (!authStore.tenantId) return

  await accountingStore.fetchInventoryAccountingEntries({
    tenant_id: authStore.tenantId,
    page: 1,
    page_size: 200,
    sortBy: 'entry_date',
    sortOrder: 'desc',
  })
}

onMounted(load)
</script>

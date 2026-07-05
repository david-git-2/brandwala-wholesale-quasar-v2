<template>
  <TreasuryPageShell
    :title="`Shipment P&amp;L: ${shipment?.name || '#' + id}`"
    subtitle="Analyze itemized landed costs, sales revenue conversion, gross profit margin, and current unsold inventory value."
    :error="error"
  >
    <template #action>
      <q-btn flat dense no-caps icon="arrow_back" label="Back to Shipments" @click="goBack" />
    </template>

    <!-- Loading spinner -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <div v-else-if="shipment" class="q-gutter-y-lg">
      <!-- Stats Row -->
      <TreasuryStatGrid :items="statCards" />

      <!-- Itemized Table Card -->
      <q-card flat bordered class="q-pa-md bg-white">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-primary">
          Itemized Cost &amp; Profit Allocations
        </div>

        <q-table
          flat
          row-key="id"
          :rows="items"
          :columns="columns"
          :pagination="{ rowsPerPage: 50 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-id="props">
            <q-td :props="props" class="font-mono text-grey-6 text-sm">
              #{{ props.row.id }}
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props" class="text-weight-bold">
              {{ props.row.name }}
            </q-td>
          </template>

          <template #body-cell-ordered_quantity="props">
            <q-td :props="props" class="text-right">
              {{ props.row.ordered_quantity }}
            </q-td>
          </template>

          <template #body-cell-landed_unit_cost="props">
            <q-td :props="props" class="text-right">
              {{ formatAmountBdt(props.row.landed_unit_cost) }}
            </q-td>
          </template>

          <template #body-cell-total_landed_cost="props">
            <q-td :props="props" class="text-right">
              {{ formatAmountBdt(props.row.landed_unit_cost * props.row.ordered_quantity) }}
            </q-td>
          </template>

          <template #body-cell-sold_qty="props">
            <q-td :props="props" class="text-right text-primary text-weight-bold">
              {{ props.row.sold_qty }}
            </q-td>
          </template>

          <template #body-cell-sold_cost="props">
            <q-td :props="props" class="text-right text-grey-8">
              {{ formatAmountBdt(props.row.sold_cost) }}
            </q-td>
          </template>

          <template #body-cell-revenue="props">
            <q-td :props="props" class="text-right text-positive">
              {{ formatAmountBdt(props.row.revenue) }}
            </q-td>
          </template>

          <template #body-cell-gross_profit="props">
            <q-td :props="props" class="text-right text-weight-bold text-primary">
              {{ formatAmountBdt(props.row.revenue - props.row.sold_cost) }}
            </q-td>
          </template>

          <template #body-cell-unsold_qty="props">
            <q-td :props="props" class="text-right text-warning text-weight-bold">
              {{ props.row.ordered_quantity - props.row.sold_qty }}
            </q-td>
          </template>

          <template #body-cell-unsold_value="props">
            <q-td :props="props" class="text-right text-warning text-weight-bold">
              {{ formatAmountBdt((props.row.ordered_quantity - props.row.sold_qty) * props.row.landed_unit_cost) }}
            </q-td>
          </template>
        </q-table>
      </q-card>
    </div>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import type { QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'
import { treasuryRepository } from '../repositories/treasuryRepository'
import TreasuryPageShell from '../components/TreasuryPageShell.vue'
import TreasuryStatGrid from '../components/TreasuryStatGrid.vue'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()

const id = Number(route.params.id)
const loading = ref(false)
const error = ref<string | null>(null)

const shipment = ref<any>(null)
const items = ref<any[]>([])
const totals = ref({
  landed_cost: 0,
  sold_cost: 0,
  revenue: 0,
  gross_profit: 0,
  unsold_value: 0,
})

const columns: QTableColumn[] = [
  { name: 'id', label: 'Item ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'ordered_quantity', label: 'Received Qty', field: 'ordered_quantity', align: 'right', sortable: true },
  { name: 'landed_unit_cost', label: 'Landed Unit Cost', field: 'landed_unit_cost', align: 'right', sortable: true },
  { name: 'total_landed_cost', label: 'Total Landed Cost', field: 'id', align: 'right' },
  { name: 'sold_qty', label: 'Sold Qty', field: 'sold_qty', align: 'right', sortable: true },
  { name: 'sold_cost', label: 'Sold Cost', field: 'sold_cost', align: 'right', sortable: true },
  { name: 'revenue', label: 'Revenue', field: 'revenue', align: 'right', sortable: true },
  { name: 'gross_profit', label: 'Gross Profit', field: 'id', align: 'right' },
  { name: 'unsold_qty', label: 'Unsold Qty', field: 'id', align: 'right' },
  { name: 'unsold_value', label: 'Unsold Value', field: 'id', align: 'right' },
]

const statCards = computed(() => [
  {
    label: 'Landed Cost BDT',
    value: totals.value.landed_cost,
    caption: 'Total import asset cost',
  },
  {
    label: 'Sold Cost BDT',
    value: totals.value.sold_cost,
    caption: 'Landed cost of sold items',
  },
  {
    label: 'Gross Revenue BDT',
    value: totals.value.revenue,
    caption: 'Sales subtotal less returns',
    valueClass: 'text-positive',
  },
  {
    label: 'Gross Profit BDT',
    value: totals.value.gross_profit,
    caption: 'Derived profit rollup',
    valueClass: 'text-primary',
  },
  {
    label: 'Unsold Stock Value',
    value: totals.value.unsold_value,
    caption: 'Dead stock asset estimate',
    valueClass: 'text-warning',
  },
])

const loadPnL = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  error.value = null
  try {
    const res = await treasuryRepository.getShipmentPnL(tenantId, id)
    shipment.value = res.shipment
    items.value = res.items || []
    totals.value = res.totals
  } catch (err: any) {
    error.value = err.message
    $q.notify({ type: 'negative', message: `Failed to load shipment details: ${err.message}` })
  } finally {
    loading.value = false
  }
}

const goBack = () => {
  void router.push({
    name: 'app-finance-shipments-page',
    params: { tenantSlug: authStore.tenantSlug ?? undefined },
  })
}

onMounted(() => {
  void loadPnL()
})
</script>

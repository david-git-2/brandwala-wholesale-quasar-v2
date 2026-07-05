<template>
  <q-page class="q-pa-lg bg-slate-900 text-white">
    <!-- Header Block -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="row items-center q-gutter-sm text-slate-400 q-mb-xs">
          <q-btn flat dense no-caps icon="arrow_back" label="Back to Shipments" @click="goBack" color="slate-400" />
        </div>
        <div class="text-h4 text-weight-bolder tracking-tight">
          Shipment P&amp;L: <span class="text-teal-400">{{ shipment?.name || `#${id}` }}</span>
        </div>
        <div class="text-subtitle2 text-slate-400 q-mt-xs">
          Analyze itemized landed costs, sales revenue conversion, gross profit margin, and current unsold inventory value.
        </div>
      </div>
    </div>

    <!-- Loading spinner -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="teal" />
    </div>

    <div v-else-if="shipment" class="q-gutter-y-xl">
      <!-- Stats Row -->
      <div class="row q-col-gutter-lg">
        <div class="col-12 col-sm-6 col-md-2.4 col-lg-2.4" style="flex: 1">
          <div class="glass-card q-pa-md">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Landed Cost BDT</div>
            <div class="text-h5 text-weight-bold q-mt-sm text-slate-300">
              {{ formatAmountBdt(totals.landed_cost) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Total import asset cost</div>
          </div>
        </div>
        <div class="col-12 col-sm-6 col-md-2.4 col-lg-2.4" style="flex: 1">
          <div class="glass-card q-pa-md">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Sold Cost BDT</div>
            <div class="text-h5 text-weight-bold q-mt-sm text-indigo-300">
              {{ formatAmountBdt(totals.sold_cost) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Landed cost of sold items</div>
          </div>
        </div>
        <div class="col-12 col-sm-6 col-md-2.4 col-lg-2.4" style="flex: 1">
          <div class="glass-card q-pa-md">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Gross Revenue BDT</div>
            <div class="text-h5 text-weight-bold q-mt-sm text-emerald-400">
              {{ formatAmountBdt(totals.revenue) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Sales subtotal less returns</div>
          </div>
        </div>
        <div class="col-12 col-sm-6 col-md-2.4 col-lg-2.4" style="flex: 1">
          <div class="glass-card q-pa-md">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Gross Profit BDT</div>
            <div class="text-h5 text-weight-bold q-mt-sm text-teal-300">
              {{ formatAmountBdt(totals.gross_profit) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Derived profit rollup</div>
          </div>
        </div>
        <div class="col-12 col-sm-6 col-md-2.4 col-lg-2.4" style="flex: 1">
          <div class="glass-card q-pa-md">
            <div class="text-caption text-slate-400 text-uppercase tracking-wider">Unsold Stock Value</div>
            <div class="text-h5 text-weight-bold q-mt-sm text-amber-400">
              {{ formatAmountBdt(totals.unsold_value) }}
            </div>
            <div class="text-caption text-slate-500 q-mt-xs">Dead stock asset estimate</div>
          </div>
        </div>
      </div>

      <!-- Itemized Table Card -->
      <div class="glass-card q-pa-lg">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-teal-300">
          Itemized Cost &amp; Profit Allocations
        </div>

        <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
          <thead>
            <tr class="text-slate-400 border-b border-slate-800">
              <th class="text-left font-semibold py-4">Item ID</th>
              <th class="text-left font-semibold">Name</th>
              <th class="text-right font-semibold">Received Qty</th>
              <th class="text-right font-semibold">Landed Unit Cost</th>
              <th class="text-right font-semibold">Total Landed Cost</th>
              <th class="text-right font-semibold">Sold Qty</th>
              <th class="text-right font-semibold">Sold Cost</th>
              <th class="text-right font-semibold">Revenue</th>
              <th class="text-right font-semibold">Gross Profit</th>
              <th class="text-right font-semibold">Unsold Qty</th>
              <th class="text-right font-semibold">Unsold Value</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!items.length" class="border-b border-slate-800/50">
              <td colspan="11" class="text-center py-8 text-slate-500">
                No items found for this shipment.
              </td>
            </tr>
            <tr
              v-for="row in items"
              :key="row.id"
              class="hover:bg-slate-800/20 border-b border-slate-800/40"
            >
              <td class="py-3 font-mono text-slate-400 text-sm">#{{ row.id }}</td>
              <td class="text-weight-bold text-slate-200">{{ row.name }}</td>
              <td class="text-right">{{ row.ordered_quantity }}</td>
              <td class="text-right">{{ formatAmountBdt(row.landed_unit_cost) }}</td>
              <td class="text-right text-slate-300">
                {{ formatAmountBdt(row.landed_unit_cost * row.ordered_quantity) }}
              </td>
              <td class="text-right text-teal-300">{{ row.sold_qty }}</td>
              <td class="text-right text-indigo-300">{{ formatAmountBdt(row.sold_cost) }}</td>
              <td class="text-right text-emerald-400">{{ formatAmountBdt(row.revenue) }}</td>
              <td class="text-right text-weight-bold text-teal-300">
                {{ formatAmountBdt(row.revenue - row.sold_cost) }}
              </td>
              <td class="text-right text-amber-400">
                {{ row.ordered_quantity - row.sold_qty }}
              </td>
              <td class="text-right text-weight-bold text-amber-400">
                {{ formatAmountBdt((row.ordered_quantity - row.sold_qty) * row.landed_unit_cost) }}
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { treasuryRepository } from '../repositories/treasuryRepository'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()

const id = Number(route.params.id)
const loading = ref(false)

const shipment = ref<any>(null)
const items = ref<any[]>([])
const totals = ref({
  landed_cost: 0,
  sold_cost: 0,
  revenue: 0,
  gross_profit: 0,
  unsold_value: 0,
})

const loadPnL = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  try {
    const res = await treasuryRepository.getShipmentPnL(tenantId, id)
    shipment.value = res.shipment
    items.value = res.items || []
    totals.value = res.totals
  } catch (err: any) {
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

const formatAmountBdt = (val: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'BDT',
  }).format(val)
}

onMounted(() => {
  void loadPnL()
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
.text-slate-200 {
  color: #e2e8f0;
}
.text-slate-300 {
  color: #cbd5e1;
}
.border-slate-800 {
  border-color: #1e293b;
}
.border-slate-800\/40 {
  border-color: rgba(30, 41, 59, 0.4);
}

/* Glassmorphism Classes */
.glass-card {
  background: rgba(30, 41, 59, 0.4);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px border-solid rgba(255, 255, 255, 0.05);
  border-radius: 12px;
}
</style>

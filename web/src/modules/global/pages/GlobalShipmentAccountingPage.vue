<template>
  <q-page class="q-pa-md shipment-acct-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Global Shipment Accounting</div>
            <div class="text-caption text-grey-7">Select a shipment to view buy/sell cost and profit rollups</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <template v-if="loading && !rows.length">
      <div class="row q-col-gutter-md q-mb-md">
        <div v-for="n in 3" :key="n" class="col-12 col-sm-4">
          <q-card flat class="floating-surface shadow-1">
            <q-card-section>
              <q-skeleton type="text" width="60%" />
              <q-skeleton type="text" width="40%" class="q-mt-xs" />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </template>

    <q-banner v-else-if="error" class="bg-red-1 text-negative q-mb-md" rounded>{{ error }}</q-banner>

    <q-card v-else flat class="floating-surface shadow-1">
      <q-card-section class="q-pa-none">
        <q-markup-table flat class="shipment-acct-list-table">
          <thead>
            <tr>
              <th class="text-left" style="width: 48px">#</th>
              <th class="text-left">Shipment</th>
              <th class="text-right">Buy Cost</th>
              <th class="text-right">Sell Total</th>
              <th class="text-right">Gross Profit</th>
              <th class="text-left">Refreshed</th>
              <th class="text-right" style="width: 60px"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!rows.length">
              <td colspan="7" class="text-center text-grey-6 q-py-xl">
                <q-icon name="inventory_2" size="32px" color="grey-4" class="q-mb-sm block" />
                <div class="text-body2">No shipment accounting rows found.</div>
              </td>
            </tr>
            <tr
              v-for="(row, index) in rows"
              :key="row.id"
              class="cursor-pointer shipment-row"
              @click="onSelectShipment(row.shipment_id)"
            >
              <td class="text-grey-6 text-caption">{{ index + 1 }}</td>
              <td>
                <span class="text-weight-medium text-primary">#{{ shipmentLabel(row.shipment_id) }}</span>
              </td>
              <td class="text-right">{{ formatAmount(row.buy_cost_total) }}</td>
              <td class="text-right">{{ formatAmount(row.sell_total) }}</td>
              <td
                class="text-right text-weight-medium"
                :class="Number(row.gross_profit_total) >= 0 ? 'text-positive' : 'text-negative'"
              >
                {{ formatAmount(row.gross_profit_total) }}
              </td>
              <td class="text-grey-7 text-caption">{{ formatDate(row.refreshed_at) }}</td>
              <td class="text-right">
                <q-icon name="chevron_right" color="grey-5" size="18px" />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { formatAmountBdt } from 'src/utils/currency'

import { useGlobalAccountingStore } from '../stores/globalAccountingStore'

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const globalAccountingStore = useGlobalAccountingStore()
const router = useRouter()
const route = useRoute()

const loading = ref(true)
const error = ref<string | null>(null)

const rows = computed(() => globalAccountingStore.shipmentAccountingRows)
const formatAmount = (value: number) => formatAmountBdt(value)

const shipmentLabel = (shipmentId: number) => {
  const shipment = shipmentStore.shipments.find((item) => item.id === shipmentId)
  return shipment?.tenant_shipment_id ?? shipmentId
}

const formatDate = (val: string | null | undefined) => {
  if (!val) return '—'
  try {
    return new Date(val).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  } catch {
    return val
  }
}

const load = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  error.value = null
  try {
    await Promise.all([
      shipmentStore.fetchShipments(tenantId),
      globalAccountingStore.fetchShipmentAccounting(tenantId),
    ])
    if (globalAccountingStore.error) {
      error.value = globalAccountingStore.error
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load shipment accounting.'
  } finally {
    loading.value = false
  }
}

const onSelectShipment = async (shipmentId: number) => {
  await router.push({
    name: 'app-global-shipment-accounting-details-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      id: shipmentId,
    },
  })
}

onMounted(() => {
  void load()
})
</script>

<style scoped>
.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  font-size: 12px;
}
</style>

<template>
  <q-page class="q-pa-md shipment-acct-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Global Shipment Accounting</div>
            <div class="text-caption text-grey-7">Select a shipment to view buy/sell cost and profit rollups</div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              outline
              no-caps
              size="sm"
              icon="refresh"
              label="Refresh"
              :loading="loading"
              class="pill-btn slim-btn"
              @click="load"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <template v-if="loading && !shipmentStore.shipments.length">
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
              <th class="text-left">Name</th>
              <th class="text-left">Status</th>
              <th class="text-right">Buy Cost</th>
              <th class="text-right">Sell Total</th>
              <th class="text-right">Gross Profit</th>
              <th class="text-left">Created</th>
              <th class="text-right" style="width: 60px"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!tableRows.length">
              <td colspan="9" class="text-center text-grey-6 q-py-xl">
                <q-icon name="inventory_2" size="32px" color="grey-4" class="q-mb-sm block" />
                <div class="text-body2">No shipments found.</div>
              </td>
            </tr>
            <tr
              v-for="(row, index) in tableRows"
              :key="row.shipment.id"
              class="cursor-pointer shipment-row"
              @click="onSelectShipment(row.shipment.id)"
            >
              <td class="text-grey-6 text-caption">{{ index + 1 }}</td>
              <td>
                <span class="text-weight-medium text-primary">#{{ row.shipment.tenant_shipment_id ?? row.shipment.id }}</span>
              </td>
              <td>
                <span class="text-weight-medium">{{ row.shipment.name ?? '—' }}</span>
              </td>
              <td>
                <q-chip
                  dense
                  square
                  :color="statusColor(row.shipment.status).bg"
                  :text-color="statusColor(row.shipment.status).text"
                  :icon="statusColor(row.shipment.status).icon"
                  class="status-chip text-capitalize"
                >
                  {{ row.shipment.status ?? 'unknown' }}
                </q-chip>
              </td>
              <td class="text-right">{{ row.accounting ? formatAmount(row.accounting.buy_cost_total) : '—' }}</td>
              <td class="text-right">{{ row.accounting ? formatAmount(row.accounting.sell_total) : '—' }}</td>
              <td
                class="text-right text-weight-medium"
                :class="row.accounting && Number(row.accounting.gross_profit_total) >= 0 ? 'text-positive' : row.accounting ? 'text-negative' : ''"
              >
                {{ row.accounting ? formatAmount(row.accounting.gross_profit_total) : '—' }}
              </td>
              <td class="text-grey-7 text-caption">{{ formatDate(row.shipment.created_at) }}</td>
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
import type { GlobalShipmentAccountingRow } from '../types'

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const globalAccountingStore = useGlobalAccountingStore()
const router = useRouter()
const route = useRoute()

const loading = ref(true)
const error = ref<string | null>(null)

const formatAmount = (value: number) => formatAmountBdt(value)

const accountingByShipmentId = computed(() => {
  const map = new Map<number, GlobalShipmentAccountingRow>()
  for (const row of globalAccountingStore.shipmentAccountingRows) {
    map.set(row.shipment_id, row)
  }
  return map
})

const tableRows = computed(() =>
  shipmentStore.shipments.map((shipment) => ({
    shipment,
    accounting: accountingByShipmentId.value.get(shipment.id) ?? null,
  })),
)

const statusColor = (status: string | null | undefined) => {
  const s = (status ?? '').trim().toLowerCase()
  if (s === 'completed' || s === 'delivered') return { bg: 'green-1', text: 'green-9', icon: 'check_circle' }
  if (s === 'in_transit' || s === 'transit' || s === 'shipped') return { bg: 'blue-1', text: 'blue-9', icon: 'local_shipping' }
  if (s === 'pending') return { bg: 'orange-1', text: 'orange-9', icon: 'pending' }
  if (s === 'cancelled') return { bg: 'red-1', text: 'red-9', icon: 'cancel' }
  return { bg: 'grey-2', text: 'grey-8', icon: 'inventory_2' }
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

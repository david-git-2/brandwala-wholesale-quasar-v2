<template>
  <q-page class="q-pa-md shipment-accounting-details-page">
    <PageInitialLoader v-if="loading" />

    <template v-else>
      <q-banner v-if="error" class="bg-red-1 text-negative q-mb-md" rounded>{{ error }}</q-banner>

      <template v-if="shipment">
        <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
          <q-card-section class="q-py-sm">
            <div class="row items-center justify-between q-col-gutter-sm">
              <div class="col-12 col-sm">
                <div class="row items-center q-gutter-sm">
                  <q-badge color="primary" outline class="text-weight-medium">
                    #{{ shipment.tenant_shipment_id ?? shipment.id }}
                  </q-badge>
                  <div class="text-subtitle1 text-weight-bold">{{ shipment.name }}</div>
                </div>
                <div class="text-caption text-grey-8 q-mt-xs">Global shipment accounting rollup</div>
              </div>
              <div class="col-12 col-sm-auto">
                <q-chip dense square :color="statusColor(shipment.status).bg" :text-color="statusColor(shipment.status).text">
                  {{ shipment.status ?? 'unknown' }}
                </q-chip>
              </div>
            </div>
          </q-card-section>
        </q-card>

        <q-card flat class="floating-surface shadow-1">
          <q-card-section>
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-4">
                <div class="stat-card">
                  <div class="stat-label">Buy Cost Total</div>
                  <div class="stat-value">{{ formatAmount(accountingRow?.buy_cost_total ?? 0) }}</div>
                  <div class="stat-unit">BDT</div>
                </div>
              </div>
              <div class="col-12 col-sm-4">
                <div class="stat-card stat-card--primary">
                  <div class="stat-label">Sell Total</div>
                  <div class="stat-value text-primary">{{ formatAmount(accountingRow?.sell_total ?? 0) }}</div>
                  <div class="stat-unit">BDT</div>
                </div>
              </div>
              <div class="col-12 col-sm-4">
                <div
                  class="stat-card"
                  :class="Number(accountingRow?.gross_profit_total ?? 0) >= 0 ? 'stat-card--positive' : 'stat-card--negative'"
                >
                  <div class="stat-label">Gross Profit</div>
                  <div
                    class="stat-value"
                    :class="Number(accountingRow?.gross_profit_total ?? 0) >= 0 ? 'text-positive' : 'text-negative'"
                  >
                    {{ formatAmount(accountingRow?.gross_profit_total ?? 0) }}
                  </div>
                  <div class="stat-unit">BDT</div>
                </div>
              </div>
            </div>
            <div v-if="accountingRow?.refreshed_at" class="text-caption text-grey-7 q-mt-sm">
              Last refreshed: {{ formatDate(accountingRow.refreshed_at) }}
            </div>
            <div v-else class="text-caption text-grey-7 q-mt-sm">
              No accounting rollup recorded for this shipment yet.
            </div>
          </q-card-section>
        </q-card>
      </template>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { formatAmountBdt } from 'src/utils/currency'

import { globalRepository } from '../repositories/globalRepository'
import type { GlobalShipmentAccountingRow } from '../types'

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const route = useRoute()

const loading = ref(true)
const error = ref<string | null>(null)
const accountingRow = ref<GlobalShipmentAccountingRow | null>(null)

const shipmentId = computed(() => Number(route.params.id))
const shipment = computed(() => shipmentStore.selectedShipment)

const formatAmount = (value: number) => formatAmountBdt(value)

const statusColor = (status: string | null | undefined) => {
  const s = (status ?? '').trim().toLowerCase()
  if (s === 'completed' || s === 'delivered') return { bg: 'green-1', text: 'green-9' }
  if (s === 'in_transit' || s === 'transit' || s === 'shipped') return { bg: 'blue-1', text: 'blue-9' }
  if (s === 'pending') return { bg: 'orange-1', text: 'orange-9' }
  if (s === 'cancelled') return { bg: 'red-1', text: 'red-9' }
  return { bg: 'grey-2', text: 'grey-8' }
}

const formatDate = (val: string) => {
  try {
    return new Date(val).toLocaleString()
  } catch {
    return val
  }
}

onMounted(async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) {
    error.value = 'Shipment not found.'
    loading.value = false
    return
  }

  try {
    await shipmentStore.fetchShipmentById(shipmentId.value)
    accountingRow.value = await globalRepository.getGlobalShipmentAccounting(tenantId, shipmentId.value)
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load shipment accounting.'
  } finally {
    loading.value = false
  }
})
</script>

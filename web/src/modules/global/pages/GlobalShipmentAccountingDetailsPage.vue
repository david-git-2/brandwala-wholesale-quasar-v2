<template>
  <q-page class="q-pa-xs q-sm-pa-md shipment-accounting-details-page">
    <PageInitialLoader v-if="loading" />

    <template v-else>
      <q-banner v-if="error" class="bg-red-1 text-negative q-mb-md" rounded>{{ error }}</q-banner>

      <ShipmentAccountingReport
        v-if="shipment"
        :shipment="shipment"
        :shipment-items="shipmentStore.shipmentItems"
        :accounting-entries="accountingEntries"
        :invoice-paid-by-id="invoicePaidById"
        :parent-tenant-id="authStore.tenantId ?? 0"
        :accounting-loading="accountingLoading"
        :accounting-error="accountingError"
        :refreshed-at="accountingRow?.refreshed_at ?? null"
      >
        <template #header-actions>
          <q-btn
            color="primary"
            outline
            no-caps
            size="sm"
            icon="refresh"
            label="Refresh"
            :loading="refreshing"
            class="pill-btn slim-btn"
            @click="refresh"
          />
        </template>
      </ShipmentAccountingReport>

      <div v-else class="text-grey-7 q-pa-lg text-center">
        <q-icon name="search_off" size="48px" class="text-grey-4 q-mb-md" /><br />
        Shipment not found.
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import type { InventoryAccountingEntry } from 'src/modules/accounting/types'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import ShipmentAccountingReport from 'src/modules/shipment/components/ShipmentAccountingReport.vue'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'

import { globalRepository } from '../repositories/globalRepository'
import { useGlobalAccountingStore } from '../stores/globalAccountingStore'
import type { GlobalShipmentAccountingRow } from '../types'
import { mapGlobalLedgerToAccountingEntry } from '../utils/mapGlobalLedgerToAccountingEntry'

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const globalAccountingStore = useGlobalAccountingStore()
const route = useRoute()

const loading = ref(true)
const refreshing = ref(false)
const accountingLoading = ref(false)
const error = ref<string | null>(null)
const accountingError = ref<string | null>(null)
const accountingRow = ref<GlobalShipmentAccountingRow | null>(null)
const accountingEntries = ref<InventoryAccountingEntry[]>([])
const invoicePaidById = ref<Record<string, number>>({})

const shipmentId = computed(() => Number(route.params.id))
const shipment = computed(() => shipmentStore.selectedShipment)

const fetchInvoicePaidAmounts = async (entries: InventoryAccountingEntry[]) => {
  const invoiceIds = Array.from(
    new Set(
      entries
        .map((row) => Number(row.invoice_id))
        .filter((id) => Number.isFinite(id) && id > 0),
    ),
  )

  if (!invoiceIds.length) {
    invoicePaidById.value = {}
    return
  }

  invoicePaidById.value = await globalRepository.getGlobalInvoicesPaidAmounts(invoiceIds)
}

const fetchLedger = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) {
    accountingEntries.value = []
    return
  }

  accountingLoading.value = true
  accountingError.value = null

  try {
    const ledgerRows = await globalRepository.listGlobalLedgerByShipment(tenantId, shipmentId.value)
    const entries = ledgerRows.map(mapGlobalLedgerToAccountingEntry)
    accountingEntries.value = entries
    await fetchInvoicePaidAmounts(entries)
  } catch (err) {
    accountingError.value = err instanceof Error ? err.message : 'Failed to load shipment ledger entries.'
    accountingEntries.value = []
  } finally {
    accountingLoading.value = false
  }
}

const load = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) {
    error.value = 'Shipment not found.'
    loading.value = false
    return
  }

  loading.value = true
  error.value = null

  try {
    await shipmentStore.fetchShipmentById(shipmentId.value)
    accountingRow.value = await globalRepository.getGlobalShipmentAccounting(tenantId, shipmentId.value)
    await fetchLedger()
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load shipment accounting.'
  } finally {
    loading.value = false
  }
}

const refresh = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !shipmentId.value) return

  refreshing.value = true
  accountingError.value = null

  try {
    accountingRow.value = await globalRepository.refreshGlobalShipmentAccounting(tenantId, shipmentId.value)
    await globalAccountingStore.refreshShipmentAccounting(tenantId, shipmentId.value)
    await fetchLedger()
  } catch (err) {
    accountingError.value = err instanceof Error ? err.message : 'Failed to refresh shipment accounting.'
  } finally {
    refreshing.value = false
  }
}

onMounted(() => {
  void load()
})

watch(
  () => route.params.id,
  () => {
    void load()
  },
)
</script>

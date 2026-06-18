<template>
  <q-page class="q-pa-xs q-sm-pa-md shipment-accounting-details-page">
    <PageInitialLoader v-if="shipmentStore.loading" />

    <template v-else>
      <q-banner
        v-if="shipmentStore.error"
        class="bg-red-1 text-negative q-mb-md"
        rounded
      >
        {{ shipmentStore.error }}
      </q-banner>

      <ShipmentAccountingReport
        v-if="shipmentStore.selectedShipment"
        :shipment="shipmentStore.selectedShipment"
        :shipment-items="shipmentStore.shipmentItems"
        :accounting-entries="shipmentAccountingEntries"
        :invoice-paid-by-id="shipmentInvoicePaidById"
        :parent-tenant-id="authStore.tenantId ?? 0"
        :accounting-loading="accountingLoading"
        :accounting-error="accountingError"
      />

      <div v-else class="text-grey-7 q-pa-lg text-center">
        <q-icon name="search_off" size="48px" class="text-grey-4 q-mb-md" /><br />
        Shipment not found.
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import { supabase } from 'src/boot/supabase'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { accountingService } from 'src/modules/accounting/services/accountingService'
import type { InventoryAccountingEntry } from 'src/modules/accounting/types'
import { useInvoiceStore } from 'src/modules/invoice/stores/invoiceStore'
import ShipmentAccountingReport from 'src/modules/shipment/components/ShipmentAccountingReport.vue'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'

const route = useRoute()

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const invoiceStore = useInvoiceStore()
const shipmentAccountingEntries = ref<InventoryAccountingEntry[]>([])
const accountingLoading = ref(false)
const accountingError = ref<string | null>(null)
const shipmentInvoicePaidById = ref<Record<string, number>>({})

const shipmentId = () => {
  const parsed = Number(route.params.id)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
}

const fetchShipmentInvoicePaidAmounts = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    shipmentInvoicePaidById.value = {}
    return
  }

  const normalInvoiceIds = Array.from(
    new Set(
      shipmentAccountingEntries.value
        .filter((row) => row.type === 'normal')
        .map((row) => Number(row.invoice_id))
        .filter((id) => Number.isFinite(id) && id > 0),
    ),
  )

  const commerceInvoiceIds = Array.from(
    new Set(
      shipmentAccountingEntries.value
        .filter((row) => row.type === 'commerce')
        .map((row) => Number(row.invoice_id))
        .filter((id) => Number.isFinite(id) && id > 0),
    ),
  )

  const paidAmounts: Record<string, number> = {}

  if (normalInvoiceIds.length > 0) {
    const invoicesResult = await invoiceStore.fetchInvoices({
      tenant_id: tenantId,
      filters: { id: normalInvoiceIds },
      operators: { id: 'in' },
      page: 1,
      page_size: Math.max(normalInvoiceIds.length, 100),
      sortBy: 'id',
      sortOrder: 'asc',
    })
    if (invoicesResult.success) {
      ;(invoiceStore.invoices ?? []).forEach((invoice) => {
        paidAmounts[`normal_${invoice.id}`] = Number(invoice.paid_amount ?? 0)
      })
    }
  }

  if (commerceInvoiceIds.length > 0) {
    const { data: commerceInvoices, error: commerceErr } = await supabase
      .from('commerce_invoices')
      .select('id, amount_paid')
      .in('id', commerceInvoiceIds)
    if (!commerceErr && commerceInvoices) {
      commerceInvoices.forEach((invoice) => {
        paidAmounts[`commerce_${invoice.id}`] = Number(invoice.amount_paid ?? 0)
      })
    }
  }

  shipmentInvoicePaidById.value = paidAmounts
}

const fetchAccountingEntries = async () => {
  const tenantId = authStore.tenantId
  const id = shipmentId()
  if (!tenantId || !id) {
    shipmentAccountingEntries.value = []
    return
  }

  accountingLoading.value = true
  accountingError.value = null

  try {
    const result = await accountingService.listInventoryAccountingEntries({
      tenant_id: tenantId,
      filters: { shipment_id: id },
      operators: { shipment_id: 'eq' },
      page: 1,
      page_size: 1000,
      sortBy: 'id',
      sortOrder: 'desc',
    })

    if (!result.success) {
      accountingError.value = result.error ?? 'Failed to load shipment accounting entries.'
      shipmentAccountingEntries.value = []
      return
    }

    shipmentAccountingEntries.value = result.data?.data ?? []
    await fetchShipmentInvoicePaidAmounts()
  } finally {
    accountingLoading.value = false
  }
}

const fetchDetails = async () => {
  const id = shipmentId()
  if (!id) return
  await Promise.all([shipmentStore.fetchShipmentById(id), fetchAccountingEntries()])
}

onMounted(() => {
  void fetchDetails()
})

watch(
  () => route.params.id,
  () => {
    void fetchDetails()
  },
)
</script>

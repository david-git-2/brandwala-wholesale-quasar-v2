<template>
  <q-page class="q-pa-md">
    <div class="text-h5 q-mb-md text-weight-bold">Invoices</div>

    <PageInitialLoader v-if="invoiceStore.loading" />

    <q-banner v-else-if="!invoiceStore.invoices.length" class="bg-grey-2 text-grey-8">
      No invoices found.
    </q-banner>

    <div v-else class="invoice-grid">
      <q-card
        v-for="invoice in invoiceStore.invoices"
        :key="invoice.id"
        flat
        bordered
        class="invoice-card"
        clickable
        @click="goToInvoice(invoice.id)"
      >
        <q-card-section>
          <div class="row items-center justify-between q-mb-xs">
            <div class="text-subtitle1 text-weight-medium">#{{ invoice.id }} {{ invoice.invoice_no }}</div>
            <div class="row items-center q-gutter-xs">
              <q-chip dense square>{{ invoice.payment_status }}</q-chip>
              <q-btn
                dense
                flat
                round
                icon="more_vert"
                :loading="deletingInvoiceId === invoice.id"
                @click.stop
              >
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable v-ripple @click="onAskDelete(invoice.id)">
                      <q-item-section class="text-negative">Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </div>
          </div>
          <div class="text-caption text-grey-7">Source: {{ invoice.source_type }} | Source ID: {{ invoice.source_id }}</div>
          <div class="text-caption text-grey-7">Invoice Date: {{ invoice.invoice_date }}</div>
          <div class="text-caption text-grey-7">Due Date: {{ invoice.due_date || 'N/A' }}</div>
          <div class="text-body2 text-weight-medium q-mt-sm">
            Total: {{ invoice.total_amount }} | Paid: {{ invoice.paid_amount }}
          </div>
        </q-card-section>
      </q-card>
    </div>

    <q-dialog v-model="confirmDeleteOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Invoice</q-card-section>
        <q-card-section>
          Are you sure you want to delete this invoice?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            label="Delete"
            :loading="deletingInvoiceId != null"
            @click="onConfirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvoiceStore } from '../stores/invoiceStore'
import { invoiceService } from '../services/invoiceService'
import { showWarningDialog } from 'src/utils/appFeedback'
import { orderService } from 'src/modules/order/services/orderService'

const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const router = useRouter()
const confirmDeleteOpen = ref(false)
const deletingInvoiceId = ref<number | null>(null)
const pendingDeleteInvoiceId = ref<number | null>(null)

onMounted(async () => {
  if (!authStore.tenantId) {
    return
  }

  await invoiceStore.fetchInvoices({
    tenant_id: authStore.tenantId,
    page: 1,
    page_size: 50,
    sortBy: 'created_at',
    sortOrder: 'desc',
  })
})

const goToInvoice = async (id: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/invoices/${id}`)
}

const onAskDelete = (id: number) => {
  pendingDeleteInvoiceId.value = id
  confirmDeleteOpen.value = true
}

const onConfirmDelete = async () => {
  if (!pendingDeleteInvoiceId.value || !authStore.tenantId) {
    return
  }

  const invoiceId = pendingDeleteInvoiceId.value
  deletingInvoiceId.value = invoiceId
  try {
    const clearOrdersResult = await orderService.clearInvoiceFromOrders(invoiceId)
    if (!clearOrdersResult.success) {
      showWarningDialog(clearOrdersResult.error ?? 'Failed to clear invoice from linked orders.')
      return
    }

    const deleteAccountingResult =
      await invoiceService.deleteInventoryAccountingEntriesByInvoiceId(invoiceId)
    if (!deleteAccountingResult.success) {
      showWarningDialog(
        deleteAccountingResult.error ?? 'Failed to delete invoice accounting entries.',
      )
      return
    }

    const result = await invoiceService.deleteInvoice({ id: invoiceId })
    if (!result.success) {
      showWarningDialog(result.error ?? 'Failed to delete invoice.')
      return
    }

    await invoiceStore.fetchInvoices({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 50,
      sortBy: 'created_at',
      sortOrder: 'desc',
    })
    confirmDeleteOpen.value = false
    pendingDeleteInvoiceId.value = null
  } finally {
    deletingInvoiceId.value = null
  }
}
</script>

<style scoped>
.invoice-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.invoice-card {
  border-radius: 10px;
}

@media (max-width: 700px) {
  .invoice-grid {
    grid-template-columns: 1fr;
  }
}
</style>

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
            <q-chip dense square>{{ invoice.payment_status }}</q-chip>
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
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvoiceStore } from '../stores/invoiceStore'

const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const router = useRouter()

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

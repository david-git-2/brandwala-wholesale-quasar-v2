<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5 text-weight-bold text-primary">Commerce Invoices</div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="row justify-center q-my-xl">
      <q-spinner-dots size="40px" color="primary" />
    </div>

    <!-- Empty State -->
    <div v-else-if="!invoices.length" class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block">
      <q-icon name="description" size="64px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium">No Commerce Invoices Found</div>
      <div class="text-caption text-grey-5">Commerce invoices will appear here once generated from reviewed orders.</div>
    </div>

    <!-- Invoices Table -->
    <div v-else>
      <q-table
        flat
        bordered
        :rows="invoices"
        :columns="columns"
        row-key="id"
        class="floating-surface shadow-1 rounded-borders"
      >
        <template #body-cell-is_customer_group_paid="props">
          <q-td :props="props">
            <q-chip
              square
              dense
              :color="props.value ? 'green' : 'red'"
              text-color="white"
              class="text-weight-bold"
            >
              {{ props.value ? 'PAID' : 'UNPAID' }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-created_at="props">
          <q-td :props="props">
            {{ formatDate(props.value) }}
          </q-td>
        </template>

        <template #body-cell-actions="props">
          <q-td :props="props" class="q-gutter-xs text-center">
            <q-btn
              flat
              round
              color="primary"
              icon="payment"
              size="sm"
              :disable="props.row.is_customer_group_paid"
              @click="openPaymentDialog(props.row)"
            >
              <q-tooltip>Record Payment</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </div>

    <!-- Record Payment Dialog -->
    <q-dialog v-model="paymentDialog">
      <q-card style="width: 400px; max-width: 90vw;" class="rounded-borders">
        <q-card-section class="bg-primary text-white row items-center justify-between">
          <div class="text-h6">Record Payment for Invoice #{{ selectedInvoice?.id }}</div>
          <q-btn flat round icon="close" v-close-popup color="white" />
        </q-card-section>

        <q-card-section class="q-pa-md" v-if="selectedInvoice">
          <q-form @submit="submitPayment" class="q-gutter-md">
            <div class="text-subtitle2 text-grey-7 q-mb-sm">
              Total Amount: ৳{{ selectedInvoice.total_amount }} | Due: ৳{{ selectedInvoice.amount_due }}
            </div>
            <q-input
              v-model.number="paymentAmount"
              type="number"
              label="Payment Amount (BDT)"
              outlined
              dense
              class="soft-input"
              :rules="[
                val => val > 0 || 'Must be > 0',
                val => val <= Number(selectedInvoice?.amount_due) || 'Cannot exceed amount due'
              ]"
            />

            <div class="row justify-end q-mt-md">
              <q-btn label="Cancel" flat color="grey-7" v-close-popup class="q-mr-sm" />
              <q-btn label="Record Payment" type="submit" color="primary" unelevated :loading="submittingPayment" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar'
import { onMounted, ref } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceInvoiceService } from '../services/commerceInvoiceService'
import type { CommerceInvoice } from '../types'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'

const authStore = useAuthStore()

// State
const loading = ref(true)
const invoices = ref<CommerceInvoice[]>([])
const paymentDialog = ref(false)
const selectedInvoice = ref<CommerceInvoice | null>(null)
const paymentAmount = ref(0)
const submittingPayment = ref(false)

const columns: QTableColumn[] = [
  { name: 'id', label: 'Invoice ID', field: 'id', align: 'left', sortable: true },
  { name: 'order_id', label: 'Order ID', field: 'order_id', align: 'left', sortable: true },
  { name: 'total_amount', label: 'Total (BDT)', field: 'total_amount', align: 'left' },
  { name: 'amount_paid', label: 'Paid (BDT)', field: 'amount_paid', align: 'left' },
  { name: 'amount_due', label: 'Due (BDT)', field: 'amount_due', align: 'left' },
  { name: 'is_customer_group_paid', label: 'Status', field: 'is_customer_group_paid', align: 'left', sortable: true },
  { name: 'delivered_by', label: 'Delivered By', field: 'delivered_by', align: 'left' },
  { name: 'created_at', label: 'Created Date', field: 'created_at', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'id', align: 'center' },
]

const loadInvoices = async () => {
  if (!authStore.tenantId) return
  loading.value = true
  try {
    const res = await commerceInvoiceService.listCommerceInvoices(authStore.tenantId)
    if (res.success && res.data) {
      invoices.value = res.data
    } else {
      invoices.value = []
    }
  } finally {
    loading.value = false
  }
}

const openPaymentDialog = (invoice: CommerceInvoice) => {
  selectedInvoice.value = invoice
  paymentAmount.value = Number(invoice.amount_due) || 0
  paymentDialog.value = true
}

const submitPayment = async () => {
  if (!selectedInvoice.value) return
  submittingPayment.value = true
  try {
    const res = await commerceInvoiceService.updateInvoicePayment(selectedInvoice.value.id, paymentAmount.value)
    if (res.success) {
      showSuccessNotification('Payment recorded successfully.')
      paymentDialog.value = false
      await loadInvoices()
    } else {
      showWarningDialog(res.error || 'Failed to record payment.')
    }
  } finally {
    submittingPayment.value = false
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString()
}

onMounted(() => {
  void loadInvoices()
})
</script>

<style scoped>
.empty-state-block {
  background: rgba(255, 255, 255, 0.7);
  border: 1px solid #e7e2d8;
  border-radius: 14px;
  backdrop-filter: blur(6px);
}
</style>

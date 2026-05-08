<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5 text-weight-bold">Customer Payments</div>
      <q-btn color="primary" icon="add" label="Create Payment" @click="openCreateDialog" />
    </div>

    <div class="text-subtitle1 text-weight-medium q-mb-sm">Recent Payments</div>
    <q-markup-table flat bordered wrap-cells>
      <thead>
        <tr>
          <th class="text-left">Payment ID</th>
          <th class="text-left">Billing Profile</th>
          <th class="text-right">Amount</th>
          <th class="text-left">Date</th>
          <th class="text-left">Method</th>
          <th class="text-left">Reference</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!invoiceStore.payments.length && !invoiceStore.loading">
          <td colspan="6" class="text-center text-grey-7">No payments found.</td>
        </tr>
        <tr v-for="row in invoiceStore.payments" :key="row.id">
          <td>#{{ row.id }}</td>
          <td>{{ billingProfileNameById(row.billing_profile_id) }}</td>
          <td class="text-right">{{ Number(row.amount).toFixed(2) }}</td>
          <td>{{ row.payment_date }}</td>
          <td>{{ row.method ?? '-' }}</td>
          <td>{{ row.reference ?? '-' }}</td>
        </tr>
      </tbody>
    </q-markup-table>

    <q-dialog v-model="openDialog" persistent>
      <q-card style="width: 1100px; max-width: 95vw;">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">Create Payment</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-select
              v-model="billingProfileId"
              :options="billingProfileOptions"
              label="Billing Profile"
              outlined
              dense
              emit-value
              map-options
              @update:model-value="onChangeBillingProfile"
            />
          </div>
          <div class="col-12 col-sm-2">
            <q-input v-model.number="paymentAmount" type="number" min="0.01" step="0.01" label="Payment Amount" outlined dense />
          </div>
          <div class="col-12 col-sm-3">
            <q-input v-model="paymentDate" label="Payment Date" outlined dense readonly>
              <template #append>
                <q-icon name="event" class="cursor-pointer">
                  <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                    <q-date v-model="paymentDate" mask="YYYY-MM-DD" />
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-3">
            <q-select
              v-model="paymentMethod"
              :options="methodOptions"
              label="Method"
              outlined
              dense
              emit-value
              map-options
            />
          </div>
          <div class="col-12 col-sm-4">
            <q-input v-model="paymentReference" label="Reference" outlined dense />
          </div>
          <div class="col-12 col-sm-8">
            <q-input v-model="paymentNote" label="Note" outlined dense />
          </div>
        </q-card-section>

        <q-card-section>
          <q-banner class="bg-grey-2 q-mb-md">
            Allocated: <strong>{{ allocatedAmount.toFixed(2) }}</strong>
            | Remaining: <strong>{{ remainingAmount.toFixed(2) }}</strong>
          </q-banner>

          <q-markup-table flat bordered wrap-cells>
            <thead>
              <tr>
                <th class="text-left">Invoice ID</th>
                <th class="text-right">Total</th>
                <th class="text-right">Paid</th>
                <th class="text-right">Due</th>
                <th class="text-right">Allocate</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!billingProfileInvoices.length">
                <td colspan="5" class="text-center text-grey-7">Select billing profile to load invoices.</td>
              </tr>
              <tr v-for="invoice in billingProfileInvoices" :key="invoice.id">
                <td>#{{ invoice.id }} ({{ invoice.invoice_no }})</td>
                <td class="text-right">{{ Number(invoice.total_amount).toFixed(2) }}</td>
                <td class="text-right">{{ Number(invoice.paid_amount).toFixed(2) }}</td>
                <td class="text-right">{{ invoiceDue(invoice).toFixed(2) }}</td>
                <td class="text-right" style="width: 180px;">
                  <q-input
                    v-model.number="allocationMap[invoice.id]"
                    type="number"
                    min="0"
                    :max="invoiceDue(invoice)"
                    step="0.01"
                    dense
                    outlined
                  />
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Save Payment" :disable="!canSave" @click="savePayment" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvoiceStore } from 'src/modules/invoice/stores/invoiceStore'
import { useBillingProfileStore } from 'src/modules/invoice/stores/billingProfileStore'
import type { Invoice, PaymentMethod } from 'src/modules/invoice/types'

const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const billingProfileStore = useBillingProfileStore()

const openDialog = ref(false)
const billingProfileId = ref<number | null>(null)
const paymentAmount = ref<number | null>(null)
const paymentDate = ref(new Date().toISOString().slice(0, 10))
const paymentMethod = ref<PaymentMethod | null>('cash')
const paymentReference = ref('')
const paymentNote = ref('')

const billingProfileInvoices = ref<Invoice[]>([])
const allocationMap = ref<Record<number, number | null>>({})

const methodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'Bank', value: 'bank' },
  { label: 'Mobile Banking', value: 'mobile_banking' },
  { label: 'Other', value: 'other' },
]

const billingProfileOptions = computed(() =>
  billingProfileStore.items.map((item) => ({
    label: item.name,
    value: item.id,
  })),
)

const invoiceDue = (invoice: Invoice) =>
  Math.max(0, Number(invoice.total_amount ?? 0) - Number(invoice.paid_amount ?? 0))

const allocatedAmount = computed<number>(() =>
  Object.values(allocationMap.value).reduce<number>((sum, item) => sum + Number(item ?? 0), 0),
)

const remainingAmount = computed<number>(
  () => Number(paymentAmount.value ?? 0) - Number(allocatedAmount.value ?? 0),
)

const canSave = computed(() => {
  const tenantId = authStore.tenantId
  return Boolean(
    tenantId &&
      billingProfileId.value &&
      Number(paymentAmount.value ?? 0) > 0 &&
      remainingAmount.value >= 0,
  )
})

const billingProfileNameById = (id: number) =>
  billingProfileStore.items.find((item) => item.id === id)?.name ?? `#${id}`

const loadBillingProfiles = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  await billingProfileStore.fetchBillingProfiles({
    tenant_id: tenantId,
    page: 1,
    page_size: 500,
    sortBy: 'name',
    sortOrder: 'asc',
  })
}

const loadInvoicesByBillingProfile = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !billingProfileId.value) return

  const result = await invoiceStore.fetchInvoices({
    tenant_id: tenantId,
    page: 1,
    page_size: 500,
    filters: {
      billing_profile_id: billingProfileId.value,
      payment_status: ['due', 'partially_paid'],
    },
    operators: {
      payment_status: 'in',
    },
    sortBy: 'id',
    sortOrder: 'asc',
  })

  if (!result.success) return

  billingProfileInvoices.value = invoiceStore.invoices
  const next: Record<number, number | null> = {}
  for (const item of billingProfileInvoices.value) {
    next[item.id] = null
  }
  allocationMap.value = next
}

const onChangeBillingProfile = async () => {
  await loadInvoicesByBillingProfile()
}

const loadPayments = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  await invoiceStore.fetchPayments({
    tenant_id: tenantId,
    page: 1,
    page_size: 200,
    sortBy: 'id',
    sortOrder: 'desc',
  })
}

const openCreateDialog = async () => {
  openDialog.value = true
  paymentAmount.value = null
  paymentReference.value = ''
  paymentNote.value = ''
  allocationMap.value = {}
  billingProfileInvoices.value = []

  if (!billingProfileStore.items.length) {
    await loadBillingProfiles()
  }
}

const savePayment = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !billingProfileId.value || !canSave.value) return

  const allocations = billingProfileInvoices.value
    .map((invoice) => ({
      invoice_id: invoice.id,
      amount: Number(allocationMap.value[invoice.id] ?? 0),
    }))
    .filter((item) => item.amount > 0)

  const result = await invoiceStore.createPaymentWithAllocations({
    tenant_id: tenantId,
    billing_profile_id: billingProfileId.value,
    amount: Number(paymentAmount.value ?? 0),
    payment_date: paymentDate.value,
    method: paymentMethod.value,
    reference: paymentReference.value || null,
    note: paymentNote.value || null,
    allocations,
  })

  if (!result.success) return

  openDialog.value = false
  await Promise.all([loadPayments(), loadInvoicesByBillingProfile()])
}

onMounted(() => {
  void Promise.all([loadPayments(), loadBillingProfiles()])
})
</script>

<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="text-h5 text-weight-bold">Customer Transactions</div>
        <div class="text-caption text-grey-7">
          {{ selectedCustomer?.name ?? `Customer #${billingProfileId}` }}
        </div>
      </div>
      <div class="row items-center q-gutter-sm">
        <q-btn outline no-caps icon="arrow_back" label="Back" @click="goBack" />
        <q-btn color="primary" icon="add" no-caps label="Create Transaction" @click="openCreateDialog" />
      </div>
    </div>

    <q-markup-table flat bordered wrap-cells>
      <thead>
        <tr>
          <th class="text-left">Payment ID</th>
          <th class="text-right">Amount</th>
          <th class="text-left">Date</th>
          <th class="text-left">Method</th>
          <th class="text-left">Reference</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!customerPayments.length && !invoiceStore.loading">
          <td colspan="5" class="text-center text-grey-7">No transactions found.</td>
        </tr>
        <tr v-for="row in customerPayments" :key="row.id" class="cursor-pointer" @click="openTransactionDetails(row.id)">
          <td>#{{ row.id }}</td>
          <td class="text-right">{{ Number(row.amount).toFixed(2) }}</td>
          <td>{{ row.payment_date }}</td>
          <td>{{ row.method ?? '-' }}</td>
          <td>{{ row.reference ?? '-' }}</td>
        </tr>
      </tbody>
    </q-markup-table>

    <q-dialog v-model="detailsDialogOpen">
      <q-card style="width: 1100px; max-width: 95vw;">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">Transaction Split Details</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section v-if="selectedPayment" class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Payment Amount</div>
                <div class="text-h6">{{ Number(selectedPayment.amount ?? 0).toFixed(2) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Allocated</div>
                <div class="text-h6">{{ selectedPaymentAllocatedAmount.toFixed(2) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Remaining</div>
                <div class="text-h6 text-primary">{{ selectedPaymentRemainingAmount.toFixed(2) }}</div>
              </q-card-section>
            </q-card>
          </div>
        </q-card-section>

        <q-card-section>
          <div class="text-subtitle1 text-weight-medium q-mb-sm">Current Split</div>
          <q-markup-table flat bordered wrap-cells>
            <thead>
              <tr>
                <th class="text-left">Invoice</th>
                <th class="text-right">Allocated Amount</th>
                <th class="text-right" style="width: 100px;">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!selectedPaymentAllocations.length">
                <td colspan="3" class="text-center text-grey-7">No allocation found.</td>
              </tr>
              <tr v-for="allocation in selectedPaymentAllocations" :key="allocation.id">
                <td>#{{ allocation.invoice_id }}</td>
                <td class="text-right">{{ Number(allocation.amount ?? 0).toFixed(2) }}</td>
                <td class="text-right">
                  <q-btn
                    flat
                    round
                    icon="edit"
                    color="primary"
                    @click.stop="openEditAllocationDialog(allocation)"
                  />
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-card-section>

        <q-card-section v-if="selectedPaymentRemainingAmount > 0">
          <div class="text-subtitle1 text-weight-medium q-mb-sm">Allocate Remaining To Invoice</div>
          <q-banner class="bg-grey-2 q-mb-md">
            New Allocated: <strong>{{ detailsAllocatedAmount.toFixed(2) }}</strong>
            | After Allocate Remaining: <strong>{{ detailsRemainingAmount.toFixed(2) }}</strong>
          </q-banner>

          <q-markup-table flat bordered wrap-cells>
            <thead>
              <tr>
                <th class="text-left">Invoice</th>
                <th class="text-right">Due</th>
                <th class="text-right">Allocate</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!billingProfileInvoices.length">
                <td colspan="3" class="text-center text-grey-7">No due invoices found.</td>
              </tr>
              <tr v-for="invoice in billingProfileInvoices" :key="invoice.id">
                <td>#{{ invoice.id }} ({{ invoice.invoice_no }})</td>
                <td class="text-right">{{ invoiceDue(invoice).toFixed(2) }}</td>
                <td class="text-right" style="width: 180px;">
                  <q-input
                    v-model.number="detailsAllocationMap[invoice.id]"
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
          <q-btn flat no-caps label="Close" v-close-popup />
          <q-btn
            v-if="selectedPaymentRemainingAmount > 0"
            color="primary"
            no-caps
            label="Save Split"
            :disable="!canSaveDetailsSplit"
            :loading="invoiceStore.saving"
            @click="saveDetailsSplit"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="editAllocationDialogOpen">
      <q-card style="width: 420px; max-width: 92vw;">
        <q-card-section class="text-h6">Edit Allocation</q-card-section>
        <q-card-section>
          <div class="text-caption text-grey-7 q-mb-sm">
            Invoice: #{{ selectedAllocationForEdit?.invoice_id ?? '-' }}
          </div>
          <q-input
            v-model.number="editAllocationAmount"
            type="number"
            min="0.01"
            step="0.01"
            label="Allocated Amount"
            outlined
            dense
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            no-caps
            label="Save"
            :loading="invoiceStore.saving"
            :disable="!canSaveEditAllocation"
            @click="saveEditAllocation"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDialog" persistent>
      <q-card style="width: 1100px; max-width: 95vw;">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">Create Transaction</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="row q-col-gutter-md">
          <div class="col-12 col-sm-3">
            <q-input v-model.number="paymentAmount" type="number" min="0.01" step="0.01" label="Amount" outlined dense />
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
          <div class="col-12 col-sm-3">
            <q-input v-model="paymentReference" label="Reference" outlined dense />
          </div>
          <div class="col-12">
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
                <td colspan="5" class="text-center text-grey-7">No due invoices found for this customer.</td>
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
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" no-caps label="Save Transaction" :disable="!canSave" @click="savePayment" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useBillingProfileStore } from 'src/modules/invoice/stores/billingProfileStore'
import { useInvoiceStore } from 'src/modules/invoice/stores/invoiceStore'
import type { Invoice, Payment, PaymentAllocation, PaymentMethod } from 'src/modules/invoice/types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const billingProfileStore = useBillingProfileStore()

const openDialog = ref(false)
const paymentAmount = ref<number | null>(null)
const paymentDate = ref(new Date().toISOString().slice(0, 10))
const paymentMethod = ref<PaymentMethod | null>('cash')
const paymentReference = ref('')
const paymentNote = ref('')
const billingProfileInvoices = ref<Invoice[]>([])
const allocationMap = ref<Record<number, number | null>>({})
const detailsDialogOpen = ref(false)
const selectedPaymentId = ref<number | null>(null)
const detailsAllocationMap = ref<Record<number, number | null>>({})
const editAllocationDialogOpen = ref(false)
const selectedAllocationForEdit = ref<PaymentAllocation | null>(null)
const editAllocationAmount = ref<number | null>(null)

const methodOptions = [
  { label: 'Cash', value: 'cash' },
  { label: 'Bank', value: 'bank' },
  { label: 'Mobile Banking', value: 'mobile_banking' },
  { label: 'Other', value: 'other' },
]

const billingProfileId = computed(() => Number(route.params.billingProfileId))
const selectedCustomer = computed(() =>
  billingProfileStore.items.find((item) => item.id === billingProfileId.value) ?? null,
)
const customerPayments = computed(() =>
  invoiceStore.payments.filter((item) => item.billing_profile_id === billingProfileId.value),
)
const selectedPayment = computed<Payment | null>(() =>
  customerPayments.value.find((item) => item.id === selectedPaymentId.value) ?? null,
)
const selectedPaymentAllocations = computed<PaymentAllocation[]>(() =>
  invoiceStore.paymentAllocations.filter((item) => item.payment_id === selectedPaymentId.value),
)

const invoiceDue = (invoice: Invoice) =>
  Math.max(0, Number(invoice.total_amount ?? 0) - Number(invoice.paid_amount ?? 0))

const allocatedAmount = computed<number>(() =>
  Object.values(allocationMap.value).reduce<number>((sum, item) => sum + Number(item ?? 0), 0),
)
const remainingAmount = computed<number>(
  () => Number(paymentAmount.value ?? 0) - Number(allocatedAmount.value ?? 0),
)
const canSave = computed(() =>
  Boolean(
    authStore.tenantId &&
      Number.isFinite(billingProfileId.value) &&
      billingProfileId.value > 0 &&
      Number(paymentAmount.value ?? 0) > 0 &&
      remainingAmount.value >= 0,
  ),
)
const selectedPaymentAllocatedAmount = computed(() =>
  selectedPaymentAllocations.value.reduce((sum, item) => sum + Number(item.amount ?? 0), 0),
)
const selectedPaymentRemainingAmount = computed(() =>
  Math.max(0, Number(selectedPayment.value?.amount ?? 0) - selectedPaymentAllocatedAmount.value),
)
const detailsAllocatedAmount = computed<number>(() =>
  Object.values(detailsAllocationMap.value).reduce<number>((sum, item) => sum + Number(item ?? 0), 0),
)
const detailsRemainingAmount = computed(() =>
  Number(selectedPaymentRemainingAmount.value ?? 0) - Number(detailsAllocatedAmount.value ?? 0),
)
const canSaveDetailsSplit = computed(() =>
  Boolean(
    authStore.tenantId &&
      selectedPayment.value &&
      detailsAllocatedAmount.value > 0 &&
      detailsRemainingAmount.value >= 0,
  ),
)
const canSaveEditAllocation = computed(() =>
  Boolean(
    authStore.tenantId &&
      selectedAllocationForEdit.value &&
      Number(editAllocationAmount.value ?? 0) > 0,
  ),
)

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

const loadPayments = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !billingProfileId.value) return
  await invoiceStore.fetchPayments({
    tenant_id: tenantId,
    filters: { billing_profile_id: billingProfileId.value },
    operators: { billing_profile_id: 'eq' },
    page: 1,
    page_size: 500,
    sortBy: 'id',
    sortOrder: 'desc',
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
    operators: { payment_status: 'in' },
    sortBy: 'id',
    sortOrder: 'asc',
  })
  if (!result.success) return

  billingProfileInvoices.value = invoiceStore.invoices
  const next: Record<number, number | null> = {}
  for (const item of billingProfileInvoices.value) next[item.id] = null
  allocationMap.value = next
}

const openCreateDialog = async () => {
  openDialog.value = true
  paymentAmount.value = null
  paymentDate.value = new Date().toISOString().slice(0, 10)
  paymentMethod.value = 'cash'
  paymentReference.value = ''
  paymentNote.value = ''
  await loadInvoicesByBillingProfile()
}

const loadPaymentAllocations = async (paymentId: number) => {
  const tenantId = authStore.tenantId
  if (!tenantId) return
  await invoiceStore.fetchPaymentAllocations({
    tenant_id: tenantId,
    filters: { payment_id: paymentId },
    operators: { payment_id: 'eq' },
    page: 1,
    page_size: 500,
    sortBy: 'id',
    sortOrder: 'asc',
  })
}

const openTransactionDetails = async (paymentId: number) => {
  selectedPaymentId.value = paymentId
  detailsDialogOpen.value = true
  detailsAllocationMap.value = {}
  await Promise.all([loadPaymentAllocations(paymentId), loadInvoicesByBillingProfile()])
}

const openEditAllocationDialog = (allocation: PaymentAllocation) => {
  selectedAllocationForEdit.value = allocation
  editAllocationAmount.value = Number(allocation.amount ?? 0)
  editAllocationDialogOpen.value = true
}

const savePayment = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !canSave.value) return

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

const saveDetailsSplit = async () => {
  const tenantId = authStore.tenantId
  const payment = selectedPayment.value
  if (!tenantId || !payment || !canSaveDetailsSplit.value) return

  const entries = Object.entries(detailsAllocationMap.value)
    .map(([invoiceId, amount]) => ({ invoiceId: Number(invoiceId), amount: Number(amount ?? 0) }))
    .filter((item) => item.amount > 0)

  for (const entry of entries) {
    const result = await invoiceStore.addPaymentAllocation({
      tenant_id: tenantId,
      payment_id: payment.id,
      invoice_id: entry.invoiceId,
      amount: entry.amount,
    })
    if (!result.success) return
  }

  await Promise.all([
    loadPaymentAllocations(payment.id),
    loadInvoicesByBillingProfile(),
    loadPayments(),
  ])
  detailsAllocationMap.value = {}
}

const saveEditAllocation = async () => {
  const tenantId = authStore.tenantId
  const currentAllocation = selectedAllocationForEdit.value
  const payment = selectedPayment.value
  const amount = Number(editAllocationAmount.value ?? 0)
  if (!tenantId || !currentAllocation || !payment || amount <= 0) return

  const result = await invoiceStore.updatePaymentAllocationAmount({
    tenant_id: tenantId,
    allocation_id: currentAllocation.id,
    amount,
  })
  if (!result.success) return

  editAllocationDialogOpen.value = false
  await Promise.all([
    loadPaymentAllocations(payment.id),
    loadInvoicesByBillingProfile(),
    loadPayments(),
  ])
}

const goBack = async () => {
  await router.push({
    name: 'app-accounting-customer-payments-page',
    params: { tenantSlug: authStore.tenantSlug ?? undefined },
  })
}

onMounted(() => {
  void Promise.all([loadBillingProfiles(), loadPayments(), loadInvoicesByBillingProfile()])
})
</script>

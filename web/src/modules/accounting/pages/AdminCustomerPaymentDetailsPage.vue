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

    <div class="q-mb-md">
      <q-card flat bordered class="q-mb-sm bg-blue-1">
        <q-card-section class="row items-center q-col-gutter-md">
          <div class="col-12 col-md-7">
            <div class="text-subtitle1 text-weight-bold">Billing Profile Insights</div>
            <div class="text-caption text-grey-8">
              Quick summary of unpaid invoices and total outstanding amount for this customer.
            </div>
          </div>
          <div class="col-12 col-md-5">
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-card flat bordered class="bg-white">
                  <q-card-section class="q-py-sm">
                    <div class="text-caption text-grey-7">Invoices To Pay</div>
                    <div class="text-h6 text-weight-bold text-primary">{{ dueInvoiceCount }}</div>
                  </q-card-section>
                </q-card>
              </div>
              <div class="col-6">
                <q-card flat bordered class="bg-white">
                  <q-card-section class="q-py-sm">
                    <div class="text-caption text-grey-7">Outstanding Amount</div>
                    <div class="text-h6 text-weight-bold text-negative">{{ formatAmountBdt(totalDueAmount) }}</div>
                  </q-card-section>
                </q-card>
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <q-markup-table flat bordered wrap-cells>
        <thead>
          <tr>
            <th class="text-left">Status</th>
            <th class="text-left">Invoice ID</th>
            <th class="text-left">Invoice No</th>
            <th class="text-left">Date</th>
            <th class="text-right">Due Amount</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!billingProfileInvoices.length">
            <td colspan="5" class="text-center text-grey-7">No due invoices found for this customer.</td>
          </tr>
          <tr v-for="invoice in billingProfileInvoices" :key="invoice.id">
            <td>
              <q-chip dense square color="orange-1" text-color="orange-10" icon="pending_actions">
                Due
              </q-chip>
            </td>
            <td>#{{ invoice.id }}</td>
            <td>{{ invoice.invoice_no }}</td>
            <td>{{ invoice.invoice_date ?? '-' }}</td>
            <td class="text-right text-weight-bold text-negative">{{ formatAmountBdt(invoiceDue(invoice)) }}</td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <q-markup-table flat bordered wrap-cells>
      <thead>
        <tr>
          <th class="text-left">Payment ID</th>
          <th class="text-left">Date</th>
          <th class="text-left">Method</th>
          <th class="text-left">Reference</th>
          <th class="text-right">Amount</th>
          <th class="text-right">Remaining (Not Split)</th>
          <th class="text-right" style="width: 120px;">Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!customerPayments.length && !invoiceStore.loading">
          <td colspan="7" class="text-center text-grey-7">No transactions found.</td>
        </tr>
        <tr v-for="row in customerPayments" :key="row.id" class="cursor-pointer" @click="openTransactionDetails(row.id)">
          <td>#{{ row.id }}</td>
          <td>{{ row.payment_date }}</td>
          <td>{{ row.method ?? '-' }}</td>
          <td>{{ row.reference ?? '-' }}</td>
          <td class="text-right">{{ formatAmountBdt(row.amount) }}</td>
          <td class="text-right text-primary">{{ formatAmountBdt(paymentRemainingById[row.id]) }}</td>
          <td class="text-right">
            <q-btn flat round dense icon="more_vert" @click.stop>
              <q-menu anchor="bottom right" self="top right">
                <q-list dense style="min-width: 140px;">
                  <q-item clickable v-close-popup @click="openEditPaymentDialog(row)">
                    <q-item-section>Edit</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="openDeletePaymentDialog(row)">
                    <q-item-section class="text-negative">Delete</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </td>
        </tr>
      </tbody>
    </q-markup-table>

    <q-dialog v-model="editPaymentDialogOpen">
      <q-card style="width: 540px; max-width: 92vw;">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">Edit Transaction</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-card-section class="row q-col-gutter-md">
          <div class="col-12 col-sm-6">
            <q-input v-model.number="editPaymentAmount" type="number" min="0.01" step="0.01" label="Amount" outlined dense />
          </div>
          <div class="col-12 col-sm-6">
            <q-input v-model="editPaymentDate" label="Payment Date" outlined dense readonly>
              <template #append>
                <q-icon name="event" class="cursor-pointer">
                  <q-popup-proxy ref="editPaymentDateProxy" cover transition-show="scale" transition-hide="scale">
                    <q-date v-model="editPaymentDate" mask="YYYY-MM-DD" @update:model-value="() => editPaymentDateProxy?.hide()" />
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-6">
            <q-select v-model="editPaymentMethod" :options="methodOptions" label="Method" outlined dense emit-value map-options />
          </div>
          <div class="col-12 col-sm-6">
            <q-input v-model="editPaymentReference" label="Reference" outlined dense />
          </div>
          <div class="col-12">
            <q-input v-model="editPaymentNote" label="Note" outlined dense />
          </div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" no-caps label="Save" :loading="invoiceStore.saving" :disable="!canSaveEditPayment" @click="saveEditPayment" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deletePaymentDialogOpen">
      <q-card style="width: 420px; max-width: 92vw;">
        <q-card-section class="text-h6">Delete Transaction</q-card-section>
        <q-card-section>
          Are you sure you want to delete transaction #{{ selectedPaymentForEdit?.id }}?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="negative" no-caps label="Delete" :loading="invoiceStore.saving" @click="confirmDeletePayment" />
        </q-card-actions>
      </q-card>
    </q-dialog>

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
                <div class="text-h6">{{ formatAmountBdt(selectedPayment.amount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Allocated</div>
                <div class="text-h6">{{ formatAmountBdt(selectedPaymentAllocatedAmount) }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-caption text-grey-7">Remaining</div>
                <div class="text-h6 text-primary">{{ formatAmountBdt(selectedPaymentRemainingAmount) }}</div>
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
                <td class="text-right">{{ formatAmountBdt(allocation.amount) }}</td>
                <td class="text-right">
                  <q-btn
                    flat
                    round
                    icon="o_edit"
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
            New Allocated: <strong>{{ formatAmountBdt(detailsAllocatedAmount) }}</strong>
            | After Allocate Remaining: <strong>{{ formatAmountBdt(detailsRemainingAmount) }}</strong>
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
                <td class="text-right">{{ formatAmountBdt(invoiceDue(invoice)) }}</td>
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
                  <q-popup-proxy ref="paymentDateProxy" cover transition-show="scale" transition-hide="scale">
                    <q-date v-model="paymentDate" mask="YYYY-MM-DD" @update:model-value="() => paymentDateProxy?.hide()" />
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
            Allocated: <strong>{{ formatAmountBdt(allocatedAmount) }}</strong>
            | Remaining: <strong>{{ formatAmountBdt(remainingAmount) }}</strong>
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
                <td class="text-right">{{ formatAmountBdt(invoice.total_amount) }}</td>
                <td class="text-right">{{ formatAmountBdt(invoice.paid_amount) }}</td>
                <td class="text-right">{{ formatAmountBdt(invoiceDue(invoice)) }}</td>
                <td class="text-right" style="width: 180px;">
                  <q-input
                    :model-value="allocationMap[invoice.id]"
                    type="number"
                    min="0"
                    :max="invoiceDue(invoice)"
                    step="0.01"
                    dense
                    outlined
                    @update:model-value="(value) => setCreateAllocation(invoice.id, value)"
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
import type { QPopupProxy } from 'quasar'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useBillingProfileStore } from 'src/modules/invoice/stores/billingProfileStore'
import { useInvoiceStore } from 'src/modules/invoice/stores/invoiceStore'
import type { Invoice, Payment, PaymentAllocation, PaymentMethod } from 'src/modules/invoice/types'
import { formatAmountBdt } from 'src/utils/currency'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const invoiceStore = useInvoiceStore()
const billingProfileStore = useBillingProfileStore()

const paymentDateProxy = ref<QPopupProxy | null>(null)
const editPaymentDateProxy = ref<QPopupProxy | null>(null)

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
const editPaymentDialogOpen = ref(false)
const deletePaymentDialogOpen = ref(false)
const selectedPaymentForEdit = ref<Payment | null>(null)
const editPaymentAmount = ref<number | null>(null)
const editPaymentDate = ref(new Date().toISOString().slice(0, 10))
const editPaymentMethod = ref<PaymentMethod | null>('cash')
const editPaymentReference = ref('')
const editPaymentNote = ref('')

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
const paymentRemainingById = computed<Record<number, number>>(() => {
  const allocatedByPaymentId = invoiceStore.paymentAllocations.reduce<Record<number, number>>((sum, allocation) => {
    const paymentId = Number(allocation.payment_id ?? 0)
    if (!paymentId) return sum
    sum[paymentId] = Number(sum[paymentId] ?? 0) + Number(allocation.amount ?? 0)
    return sum
  }, {})

  return customerPayments.value.reduce<Record<number, number>>((sum, payment) => {
    const amount = Number(payment.amount ?? 0)
    const allocated = Number(allocatedByPaymentId[payment.id] ?? 0)
    sum[payment.id] = Math.max(0, Number((amount - allocated).toFixed(2)))
    return sum
  }, {})
})
const selectedPayment = computed<Payment | null>(() =>
  customerPayments.value.find((item) => item.id === selectedPaymentId.value) ?? null,
)
const selectedPaymentAllocations = computed<PaymentAllocation[]>(() =>
  invoiceStore.paymentAllocations.filter((item) => item.payment_id === selectedPaymentId.value),
)

const invoiceDue = (invoice: Invoice) =>
  Math.max(0, Number(invoice.total_amount ?? 0) - Number(invoice.paid_amount ?? 0))
const dueInvoiceCount = computed(() => billingProfileInvoices.value.length)
const totalDueAmount = computed(() =>
  billingProfileInvoices.value.reduce((sum, invoice) => sum + invoiceDue(invoice), 0),
)

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
const canSaveEditPayment = computed(() =>
  Boolean(
    authStore.tenantId &&
      selectedPaymentForEdit.value &&
      Number(editPaymentAmount.value ?? 0) > 0 &&
      editPaymentDate.value,
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
  const result = await invoiceStore.fetchPayments({
    tenant_id: tenantId,
    filters: { billing_profile_id: billingProfileId.value },
    operators: { billing_profile_id: 'eq' },
    page: 1,
    page_size: 500,
    sortBy: 'id',
    sortOrder: 'desc',
  })
  if (!result.success) return

  const paymentIds = (invoiceStore.payments ?? [])
    .map((item) => Number(item.id))
    .filter((id) => Number.isFinite(id) && id > 0)
  if (!paymentIds.length) {
    invoiceStore.paymentAllocations = []
    return
  }

  await invoiceStore.fetchPaymentAllocations({
    tenant_id: tenantId,
    filters: { payment_id: paymentIds },
    operators: { payment_id: 'in' },
    page: 1,
    page_size: 2000,
    sortBy: 'id',
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

const openEditPaymentDialog = (payment: Payment) => {
  selectedPaymentForEdit.value = payment
  editPaymentAmount.value = Number(payment.amount ?? 0)
  editPaymentDate.value = payment.payment_date ?? new Date().toISOString().slice(0, 10)
  editPaymentMethod.value = payment.method ?? 'cash'
  editPaymentReference.value = payment.reference ?? ''
  editPaymentNote.value = payment.note ?? ''
  editPaymentDialogOpen.value = true
}

const openDeletePaymentDialog = (payment: Payment) => {
  selectedPaymentForEdit.value = payment
  deletePaymentDialogOpen.value = true
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

const setCreateAllocation = (invoiceId: number, value: string | number | null) => {
  const raw = Number(value ?? 0)
  if (!Number.isFinite(raw) || raw <= 0) {
    allocationMap.value = { ...allocationMap.value, [invoiceId]: null }
    return
  }

  const invoice = billingProfileInvoices.value.find((item) => item.id === invoiceId)
  const due = invoice ? invoiceDue(invoice) : 0
  const clamped = Math.min(Number(raw.toFixed(2)), Number(due.toFixed(2)))
  allocationMap.value = { ...allocationMap.value, [invoiceId]: clamped }
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

const saveEditPayment = async () => {
  const tenantId = authStore.tenantId
  const payment = selectedPaymentForEdit.value
  if (!tenantId || !payment || !canSaveEditPayment.value) return

  const result = await invoiceStore.updatePayment({
    tenant_id: tenantId,
    payment_id: payment.id,
    patch: {
      amount: Number(editPaymentAmount.value ?? 0),
      payment_date: editPaymentDate.value,
      method: editPaymentMethod.value,
      reference: editPaymentReference.value || null,
      note: editPaymentNote.value || null,
    },
  })
  if (!result.success) return

  editPaymentDialogOpen.value = false
  await Promise.all([loadPayments(), loadInvoicesByBillingProfile()])
}

const confirmDeletePayment = async () => {
  const tenantId = authStore.tenantId
  const payment = selectedPaymentForEdit.value
  if (!tenantId || !payment) return
  const result = await invoiceStore.deletePayment({
    tenant_id: tenantId,
    payment_id: payment.id,
  })
  if (!result.success) return
  deletePaymentDialogOpen.value = false
  detailsDialogOpen.value = false
  await Promise.all([loadPayments(), loadInvoicesByBillingProfile()])
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

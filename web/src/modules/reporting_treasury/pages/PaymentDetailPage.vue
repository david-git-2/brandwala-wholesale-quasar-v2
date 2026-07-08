<template>
  <TreasuryPageShell
    :title="`Payment ID: #${id}`"
    subtitle="Verify allocations, trace settlement records, and clear customer outstanding balances."
    :error="error"
  >
    <template #action>
      <q-btn flat dense no-caps icon="arrow_back" label="Back to Payments" @click="goBack" class="q-mr-sm" />
      <q-btn
        v-if="payment && payment.unallocated_amount > 0"
        color="warning"
        icon="o_payments"
        no-caps
        label="Allocate Balance"
        unelevated
        @click="openAllocateDialog"
      />
    </template>

    <!-- Loading State -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <div v-else-if="payment" class="row q-col-gutter-lg">
      <!-- Left Panel: Payment Metadata Card -->
      <div class="col-12 col-md-4">
        <q-card flat bordered class="q-pa-md q-gutter-y-md bg-white">
          <div class="text-subtitle1 text-weight-bold pb-2 text-primary">
            Payment Summary
          </div>

          <div class="row justify-between">
            <span class="text-grey-7">Customer:</span>
            <span class="text-weight-bold">{{ payment.billing_profile?.name || 'Walk-in / Direct' }}</span>
          </div>
          <div class="row justify-between">
            <span class="text-grey-7">Date Received:</span>
            <span>{{ payment.payment_date }}</span>
          </div>
          <div class="row justify-between">
            <span class="text-grey-7">Payment Method:</span>
            <span class="text-weight-bold text-uppercase">{{ payment.method || 'cash' }}</span>
          </div>
          <div class="row justify-between">
            <span class="text-grey-7">Reference ID:</span>
            <span class="text-grey-9 font-mono">{{ payment.reference || '-' }}</span>
          </div>

          <div class="border-t pt-4 q-mt-md q-gutter-y-sm">
            <div class="row justify-between items-center">
              <span class="text-grey-7">Total Amount:</span>
              <span class="text-h6 text-weight-bold text-primary">{{ formatAmountBdt(payment.amount) }}</span>
            </div>
            <div class="row justify-between items-center">
              <span class="text-grey-7">Unallocated Balance:</span>
              <span class="text-h6 text-weight-bold text-warning">{{ formatAmountBdt(payment.unallocated_amount) }}</span>
            </div>
          </div>

          <div v-if="payment.note" class="border-t pt-4 q-mt-md">
            <div class="text-caption text-grey-7 q-mb-xs">Notes & Remarks:</div>
            <div class="bg-grey-1 q-pa-sm rounded text-grey-9 text-sm">
              {{ payment.note }}
            </div>
          </div>
        </q-card>
      </div>

      <!-- Right Panel: Allocations & Receipts -->
      <div class="col-12 col-md-8">
        <q-card flat bordered class="q-pa-md bg-white">
          <div class="text-subtitle1 text-weight-bold q-mb-md text-primary">
            Current Allocations Mapping
          </div>

          <TreasuryTableWrap>
            <q-markup-table flat bordered wrap-cells style="min-width: 700px;">
              <thead>
                <tr>
                  <th class="text-left font-semibold py-3">Allocation ID</th>
                  <th class="text-left font-semibold">Invoice No</th>
                  <th class="text-left font-semibold">Invoice Date</th>
                  <th class="text-right font-semibold">Invoice Amount</th>
                  <th class="text-right font-semibold">Allocated amount</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="!allocations.length">
                  <td colspan="5" class="text-center py-8 text-grey-5">
                    No invoice allocations recorded for this payment yet.
                  </td>
                </tr>
                <tr
                  v-for="alloc in allocations"
                  :key="alloc.id"
                >
                  <td class="py-3 text-grey-7">#{{ alloc.id }}</td>
                  <td class="text-weight-bold text-primary">
                    {{ alloc.global_invoice?.invoice_no || `Invoice #${alloc.global_invoice_id}` }}
                  </td>
                  <td>{{ alloc.global_invoice?.invoice_date || '-' }}</td>
                  <td class="text-right">
                    {{ alloc.global_invoice?.total_amount ? formatAmountBdt(alloc.global_invoice.total_amount) : '-' }}
                  </td>
                  <td class="text-right text-weight-bold text-positive">
                    {{ formatAmountBdt(alloc.amount) }}
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </TreasuryTableWrap>
        </q-card>
      </div>
    </div>

    <!-- Allocate Balance Dialog -->
    <q-dialog v-model="allocateDialogOpen" persistent>
      <q-card style="width: 700px; max-width: 95vw;">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">Allocate Payment Funds</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section>
          <div class="row items-center justify-between bg-amber-1 q-pa-md rounded border border-warning q-mb-lg">
            <div>
              <div class="text-caption text-amber-9 text-weight-medium">Available to Allocate</div>
              <div class="text-h5 text-weight-bold text-warning">{{ formatAmountBdt(payment.unallocated_amount) }}</div>
            </div>
            <div class="text-right">
              <div class="text-caption text-primary text-weight-medium">Currently Entering</div>
              <div class="text-h5 text-weight-bold text-primary">{{ formatAmountBdt(enteringAllocTotal) }}</div>
            </div>
          </div>

          <div class="text-subtitle2 text-grey-7 q-mb-sm">Outstanding Billing Profile Invoices</div>

          <TreasuryTableWrap>
            <q-markup-table flat bordered wrap-cells class="q-mb-md" style="min-width: 700px;">
              <thead>
                <tr>
                  <th class="text-left font-semibold py-3">Invoice No</th>
                  <th class="text-left font-semibold">Date</th>
                  <th class="text-right font-semibold">Due Balance</th>
                  <th class="text-right font-semibold" style="width: 180px;">Allocate Amount</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="!unpaidInvoices.length">
                  <td colspan="4" class="text-center py-8 text-grey-5">
                    No outstanding invoices found for this customer profile.
                  </td>
                </tr>
                <tr v-for="inv in unpaidInvoices" :key="inv.id">
                  <td class="py-3 text-weight-medium">{{ inv.invoice_no }}</td>
                  <td>{{ inv.invoice_date || '-' }}</td>
                  <td class="text-right text-weight-bold text-negative">{{ formatAmountBdt(inv.due_amount) }}</td>
                  <td class="text-right">
                    <q-input
                      v-model.number="allocationsMap[inv.id]"
                      type="number"
                      step="0.01"
                      min="0"
                      :max="maxForInvoice(inv)"
                      dense
                      outlined
                      class="text-right font-mono"
                      placeholder="0.00"
                      @update:model-value="val => handleAllocationUpdate(inv, val)"
                    />
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </TreasuryTableWrap>

          <div class="row justify-between items-center q-mt-lg">
            <div class="text-subtitle2 text-weight-medium text-grey-8">
              Allocating: <span class="text-primary text-weight-bold">{{ formatAmountBdt(enteringAllocTotal) }}</span> of <span class="text-weight-bold text-warning">{{ formatAmountBdt(payment.unallocated_amount) }}</span> BDT
            </div>
            <div class="row items-center">
              <q-btn flat no-caps label="Cancel" v-close-popup class="q-mr-sm" />
              <q-btn
                color="primary"
                no-caps
                label="Post Allocations"
                :disable="enteringAllocTotal <= 0 || enteringAllocTotal > payment.unallocated_amount"
                :loading="allocating"
                @click="submitAllocations"
                unelevated
              />
            </div>
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { formatAmountBdt } from 'src/utils/currency'
import TreasuryPageShell from '../components/TreasuryPageShell.vue'
import TreasuryTableWrap from '../components/TreasuryTableWrap.vue'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()

const id = Number(route.params.id)
const loading = ref(false)
const allocating = ref(false)
const error = ref<string | null>(null)

const payment = ref<any>(null)
const allocations = ref<any[]>([])
const unpaidInvoices = ref<any[]>([])

// Dialog Model
const allocateDialogOpen = ref(false)
const allocationsMap = ref<Record<number, number>>({})

// Compute sum of entered allocation amounts
const enteringAllocTotal = computed(() => {
  return Object.values(allocationsMap.value).reduce((sum, val) => {
    const num = Number(val)
    return sum + (Number.isFinite(num) && num > 0 ? num : 0)
  }, 0)
})

const remainingUnallocated = (excludeInvoiceId?: number) => {
  if (!payment.value) return 0
  const used = Object.entries(allocationsMap.value).reduce((sum, [id, val]) => {
    if (excludeInvoiceId !== undefined && Number(id) === excludeInvoiceId) return sum
    const n = Number(val)
    return sum + (Number.isFinite(n) && n > 0 ? n : 0)
  }, 0)
  return Math.max(0, payment.value.unallocated_amount - used)
}

const maxForInvoice = (inv: any) => {
  if (!payment.value) return 0
  return Math.min(inv.due_amount, remainingUnallocated(inv.id))
}

const handleAllocationUpdate = (inv: any, val: number | string | null) => {
  if (val === null || val === '') {
    allocationsMap.value[inv.id] = 0
    return
  }
  const num = Number(val)
  if (!Number.isFinite(num) || num <= 0) {
    allocationsMap.value[inv.id] = 0
    return
  }
  const maxVal = maxForInvoice(inv)
  if (num > maxVal) {
    allocationsMap.value[inv.id] = maxVal
  }
}

// Load Payment Details
const loadPaymentData = async () => {
  loading.value = true
  error.value = null
  try {
    // 1. Get payment
    const { data: payData, error: payError } = await supabase
      .from('global_payments')
      .select(`
        *,
        billing_profile:billing_profiles(*)
      `)
      .eq('id', id)
      .single()

    if (payError) throw payError
    payment.value = payData

    // 2. Get allocations
    const { data: allocData, error: allocError } = await supabase
      .from('invoice_payments')
      .select(`
        *,
        global_invoice:global_invoices(invoice_no, invoice_date, total_amount)
      `)
      .eq('payment_id', id)

    if (allocError) throw allocError
    allocations.value = allocData || []

    // 3. Get outstanding invoices of same billing profile
    if (payData?.billing_profile_id) {
      const { data: invData, error: invError } = await supabase
        .from('global_invoices')
        .select('*')
        .eq('billing_profile_id', payData.billing_profile_id)
        .eq('invoice_status', 'posted')
        .gt('due_amount', 0)
        .order('invoice_date', { ascending: true })

      if (invError) throw invError
      unpaidInvoices.value = invData || []
    }
  } catch (err: any) {
    error.value = err.message
    $q.notify({ type: 'negative', message: `Failed to load details: ${err.message}` })
  } finally {
    loading.value = false
  }
}

const openAllocateDialog = () => {
  allocationsMap.value = {}
  unpaidInvoices.value.forEach((inv) => {
    allocationsMap.value[inv.id] = 0
  })
  allocateDialogOpen.value = true
}

const submitAllocations = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !payment.value) return

  allocating.value = true
  try {
    // Call the database function sequentially for each selected allocation
    for (const [invoiceIdStr, val] of Object.entries(allocationsMap.value)) {
      const valNum = Number(val)
      if (!valNum || valNum <= 0) continue

      const invoiceId = Number(invoiceIdStr)
      const { error: err } = await supabase.rpc('allocate_payment_to_global_invoice', {
        p_tenant_id: tenantId,
        p_payment_id: id,
        p_global_invoice_id: invoiceId,
        p_amount: valNum,
      })

      if (err) throw err
    }
    $q.notify({ type: 'positive', message: 'Payment allocated successfully.' })
    allocateDialogOpen.value = false
    await loadPaymentData()
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Allocation error: ${err.message}` })
  } finally {
    allocating.value = false
  }
}

const goBack = () => {
  void router.push({
    name: 'app-finance-payments-page',
    params: { tenantSlug: authStore.tenantSlug ?? undefined },
  })
}

onMounted(() => {
  void loadPaymentData()
})
</script>

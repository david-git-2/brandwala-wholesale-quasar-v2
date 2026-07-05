<template>
  <q-page class="q-pa-lg bg-slate-900 text-white">
    <!-- Header/Back Navigation -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="row items-center q-gutter-sm text-slate-400 q-mb-xs">
          <q-btn flat dense no-caps icon="arrow_back" label="Back to Payments" @click="goBack" color="slate-400" />
        </div>
        <div class="text-h4 text-weight-bolder tracking-tight">
          Payment ID: <span class="text-teal-400">#{{ id }}</span>
        </div>
        <div class="text-subtitle2 text-slate-400 q-mt-xs">
          Verify allocations, trace settlement records, and clear customer outstanding balances.
        </div>
      </div>
      <div>
        <q-btn
          v-if="payment && payment.unallocated_amount > 0"
          color="amber"
          icon="o_payments"
          no-caps
          label="Allocate Balance"
          class="glass-btn-amber text-weight-bold px-4 py-2"
          @click="openAllocateDialog"
        />
      </div>
    </div>

    <!-- Main Content Details Grid -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="teal" />
    </div>

    <div v-else-if="payment" class="row q-col-gutter-lg">
      <!-- Left Panel: Payment Metadata Card -->
      <div class="col-12 col-md-4">
        <div class="glass-card q-pa-lg q-gutter-y-md">
          <div class="text-subtitle1 text-weight-bold border-b border-slate-800 pb-2 text-teal-300">
            Payment Summary
          </div>

          <div class="row justify-between">
            <span class="text-slate-400">Customer:</span>
            <span class="text-weight-bold">{{ payment.billing_profile?.name || 'Walk-in / Direct' }}</span>
          </div>
          <div class="row justify-between">
            <span class="text-slate-400">Date Received:</span>
            <span>{{ payment.payment_date }}</span>
          </div>
          <div class="row justify-between">
            <span class="text-slate-400">Payment Method:</span>
            <span class="text-weight-bold text-uppercase">{{ payment.method || 'cash' }}</span>
          </div>
          <div class="row justify-between">
            <span class="text-slate-400">Reference ID:</span>
            <span class="text-slate-300 font-mono">{{ payment.reference || '-' }}</span>
          </div>

          <div class="border-t border-slate-800 pt-4 q-mt-md q-gutter-y-sm">
            <div class="row justify-between items-center">
              <span class="text-slate-400">Total Amount:</span>
              <span class="text-h6 text-weight-bold">{{ formatAmountBdt(payment.amount) }}</span>
            </div>
            <div class="row justify-between items-center">
              <span class="text-slate-400">Unallocated Balance:</span>
              <span class="text-h6 text-weight-bold text-amber-400">{{ formatAmountBdt(payment.unallocated_amount) }}</span>
            </div>
          </div>

          <div v-if="payment.note" class="border-t border-slate-800 pt-4 q-mt-md">
            <div class="text-caption text-slate-400 q-mb-xs">Notes & Remarks:</div>
            <div class="bg-slate-900/50 q-pa-sm rounded text-slate-300 text-sm">
              {{ payment.note }}
            </div>
          </div>
        </div>
      </div>

      <!-- Right Panel: Allocations & Receipts -->
      <div class="col-12 col-md-8">
        <div class="glass-card q-pa-lg">
          <div class="text-subtitle1 text-weight-bold q-mb-md text-emerald-400">
            Current Allocations Mapping
          </div>

          <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
            <thead>
              <tr class="text-slate-400 border-b border-slate-800">
                <th class="text-left font-semibold py-3">Allocation ID</th>
                <th class="text-left font-semibold">Invoice No</th>
                <th class="text-left font-semibold">Invoice Date</th>
                <th class="text-right font-semibold">Invoice Amount</th>
                <th class="text-right font-semibold">Allocated amount</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!allocations.length">
                <td colspan="5" class="text-center py-8 text-slate-500">
                  No invoice allocations recorded for this payment yet.
                </td>
              </tr>
              <tr
                v-for="alloc in allocations"
                :key="alloc.id"
                class="hover:bg-slate-800/20 border-b border-slate-800/40"
              >
                <td class="py-3 text-slate-400">#{{ alloc.id }}</td>
                <td class="text-weight-bold text-teal-400">
                  {{ alloc.global_invoice?.invoice_no || `Invoice #${alloc.global_invoice_id}` }}
                </td>
                <td>{{ alloc.global_invoice?.invoice_date || '-' }}</td>
                <td class="text-right">
                  {{ alloc.global_invoice?.total_amount ? formatAmountBdt(alloc.global_invoice.total_amount) : '-' }}
                </td>
                <td class="text-right text-weight-bold text-emerald-400">
                  {{ formatAmountBdt(alloc.amount) }}
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </div>
      </div>
    </div>

    <!-- Allocate Balance Dialog -->
    <q-dialog v-model="allocateDialogOpen">
      <div class="glass-dialog q-pa-lg text-white" style="width: 700px; max-width: 95vw;">
        <div class="row items-center justify-between q-mb-md">
          <div class="text-h6 text-weight-bold">Allocate Payment Funds</div>
          <q-btn flat round dense icon="close" color="slate-400" v-close-popup />
        </div>

        <div class="row items-center justify-between bg-slate-900/60 q-pa-md rounded border border-slate-800 q-mb-lg">
          <div>
            <div class="text-caption text-slate-400">Available to Allocate</div>
            <div class="text-h5 text-weight-bold text-amber-400">{{ formatAmountBdt(payment.unallocated_amount) }}</div>
          </div>
          <div class="text-right">
            <div class="text-caption text-slate-400">Currently Entering</div>
            <div class="text-h5 text-weight-bold text-teal-400">{{ formatAmountBdt(enteringAllocTotal) }}</div>
          </div>
        </div>

        <div class="text-subtitle2 text-slate-400 q-mb-sm">Outstanding Billing Profile Invoices</div>

        <q-markup-table flat dark class="bg-transparent text-white border border-slate-800/80 rounded" wrap-cells>
          <thead>
            <tr class="text-slate-400 border-b border-slate-800">
              <th class="text-left font-semibold py-3">Invoice No</th>
              <th class="text-left font-semibold">Date</th>
              <th class="text-right font-semibold">Due Balance</th>
              <th class="text-right font-semibold" style="width: 180px;">Allocate Amount</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!unpaidInvoices.length">
              <td colspan="4" class="text-center py-8 text-slate-500">
                No outstanding invoices found for this customer profile.
              </td>
            </tr>
            <tr v-for="inv in unpaidInvoices" :key="inv.id" class="border-b border-slate-800/40">
              <td class="py-3 text-weight-medium">{{ inv.invoice_no }}</td>
              <td>{{ inv.invoice_date || '-' }}</td>
              <td class="text-right text-weight-bold text-negative">{{ formatAmountBdt(inv.due_amount) }}</td>
              <td class="text-right">
                <q-input
                  v-model.number="allocationsMap[inv.id]"
                  type="number"
                  step="0.01"
                  min="0"
                  :max="Math.min(inv.due_amount, payment.unallocated_amount)"
                  dark
                  dense
                  outlined
                  class="glass-input text-right font-mono"
                  placeholder="0.00"
                />
              </td>
            </tr>
          </tbody>
        </q-markup-table>

        <div class="row justify-end q-mt-lg">
          <q-btn flat no-caps label="Cancel" color="slate-400" v-close-popup class="q-mr-sm" />
          <q-btn
            color="emerald"
            no-caps
            label="Post Allocations"
            :disable="enteringAllocTotal <= 0 || enteringAllocTotal > payment.unallocated_amount"
            :loading="allocating"
            @click="submitAllocations"
            class="glass-btn px-4"
          />
        </div>
      </div>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()

const id = Number(route.params.id)
const loading = ref(false)
const allocating = ref(false)

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

// Load Payment Details
const loadPaymentData = async () => {
  loading.value = true
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
      const { error } = await supabase.rpc('allocate_payment_to_global_invoice', {
        p_tenant_id: tenantId,
        p_payment_id: id,
        p_global_invoice_id: invoiceId,
        p_amount: valNum,
      })

      if (error) throw error
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

const formatAmountBdt = (val: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'BDT',
  }).format(val)
}

onMounted(() => {
  void loadPaymentData()
})
</script>

<style scoped>
.bg-slate-900 {
  background-color: #0f172a;
}
.text-slate-400 {
  color: #94a3b8;
}
.text-slate-300 {
  color: #cbd5e1;
}
.border-slate-800 {
  border-color: #1e293b;
}
.border-slate-800\/40 {
  border-color: rgba(30, 41, 59, 0.4);
}
.border-slate-800\/80 {
  border-color: rgba(30, 41, 59, 0.8);
}
.hover\:bg-slate-800\/20:hover {
  background-color: rgba(30, 41, 59, 0.2);
}

/* Glassmorphism Classes */
.glass-card {
  background: rgba(30, 41, 59, 0.4);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px border-solid rgba(255, 255, 255, 0.05);
  border-radius: 12px;
}

.glass-dialog {
  background: rgba(15, 23, 42, 0.95);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px border-solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
  box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.5);
}

.glass-btn-amber {
  background: linear-gradient(135deg, #d97706 0%, #b45309 100%);
  border-radius: 8px;
  box-shadow: 0 4px 6px -1px rgba(217, 119, 6, 0.2);
  transition: transform 0.1s ease, box-shadow 0.1s ease;
}
.glass-btn-amber:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 12px -1px rgba(217, 119, 6, 0.3);
}

.glass-btn {
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  border-radius: 8px;
  box-shadow: 0 4px 6px -1px rgba(16, 185, 129, 0.2);
  transition: transform 0.1s ease, box-shadow 0.1s ease;
}
.glass-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 12px -1px rgba(16, 185, 129, 0.3);
}

.glass-input :deep(.q-field__control) {
  border-radius: 8px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px border-solid rgba(255, 255, 255, 0.08);
}
</style>

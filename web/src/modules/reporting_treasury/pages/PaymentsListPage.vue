<template>
  <q-page class="q-pa-lg bg-slate-900 text-white">
    <!-- Header Block -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="text-h4 text-weight-bolder tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-teal-400 to-emerald-400">
          Payment Treasury
        </div>
        <div class="text-subtitle2 text-slate-400 q-mt-xs">
          Manage capital collections, analyze unallocated funds, and link payments to sales invoices.
        </div>
      </div>
      <div>
        <q-btn
          color="emerald"
          icon="add"
          no-caps
          label="Record Payment"
          class="glass-btn text-weight-bold px-4 py-2"
          @click="openCreateDialog"
        />
      </div>
    </div>

    <!-- Stats Banner -->
    <div class="row q-col-gutter-lg q-mb-xl">
      <div class="col-12 col-md-4">
        <div class="glass-card q-pa-lg">
          <div class="text-caption text-slate-400 text-uppercase tracking-wider">Total Received Payments</div>
          <div class="text-h3 text-weight-black q-mt-sm text-teal-300">
            {{ formatAmountBdt(totalPaymentsSum) }}
          </div>
          <div class="text-caption text-slate-500 q-mt-xs">Cumulative across all channels</div>
        </div>
      </div>
      <div class="col-12 col-md-4">
        <div class="glass-card q-pa-lg">
          <div class="text-caption text-slate-400 text-uppercase tracking-wider">Unallocated Treasury</div>
          <div class="text-h3 text-weight-black q-mt-sm text-amber-400">
            {{ formatAmountBdt(totalUnallocatedSum) }}
          </div>
          <div class="text-caption text-slate-500 q-mt-xs">Funds pending invoice assignment</div>
        </div>
      </div>
      <div class="col-12 col-md-4">
        <div class="glass-card q-pa-lg">
          <div class="text-caption text-slate-400 text-uppercase tracking-wider">Allocated Funds</div>
          <div class="text-h3 text-weight-black q-mt-sm text-emerald-400">
            {{ formatAmountBdt(totalPaymentsSum - totalUnallocatedSum) }}
          </div>
          <div class="text-caption text-slate-500 q-mt-xs">Directly cleared against liabilities</div>
        </div>
      </div>
    </div>

    <!-- Filter Control Card -->
    <div class="glass-card q-pa-md q-mb-lg row items-center justify-between q-col-gutter-sm">
      <div class="col-12 col-md-4">
        <q-input
          v-model="search"
          placeholder="Search by customer name, ref, or note..."
          dark
          dense
          outlined
          class="glass-input"
        >
          <template #append>
            <q-icon name="search" class="text-slate-400" />
          </template>
        </q-input>
      </div>
      <div class="col-12 col-md-3">
        <q-select
          v-model="methodFilter"
          :options="methodOptions"
          label="Method"
          dark
          dense
          outlined
          emit-value
          map-options
          class="glass-input"
        />
      </div>
      <div class="col-12 col-md-3">
        <q-toggle
          v-model="unallocatedOnly"
          label="Show Unallocated Only"
          color="amber"
          dark
        />
      </div>
    </div>

    <!-- Payments List Table -->
    <div class="glass-card overflow-hidden">
      <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
        <thead>
          <tr class="text-slate-400 border-b border-slate-800">
            <th class="text-left font-semibold py-4">Payment ID</th>
            <th class="text-left font-semibold">Date</th>
            <th class="text-left font-semibold">Customer / Profile</th>
            <th class="text-left font-semibold">Method</th>
            <th class="text-left font-semibold">Reference</th>
            <th class="text-right font-semibold">Amount</th>
            <th class="text-right font-semibold">Unallocated</th>
            <th class="text-center font-semibold" style="width: 100px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading" class="border-b border-slate-800/50">
            <td colspan="8" class="text-center py-8 text-slate-400">
              <q-spinner-dots size="40px" color="teal" />
            </td>
          </tr>
          <tr v-else-if="!filteredPayments.length" class="border-b border-slate-800/50">
            <td colspan="8" class="text-center py-8 text-slate-500">
              No payments found matching the selected filters.
            </td>
          </tr>
          <tr
            v-for="row in filteredPayments"
            :key="row.id"
            class="hover:bg-slate-800/40 cursor-pointer transition-colors duration-200 border-b border-slate-800/50"
            @click="navigateToDetails(row.id)"
          >
            <td class="py-4 text-weight-bold text-teal-400">#{{ row.id }}</td>
            <td>{{ row.payment_date }}</td>
            <td>
              <div class="text-weight-medium">{{ row.billing_profile?.name || 'Walk-in / Direct' }}</div>
            </td>
            <td>
              <q-chip
                dense
                square
                color="slate-800"
                text-color="teal-300"
                class="text-weight-bold text-uppercase text-xs"
              >
                {{ row.method || 'cash' }}
              </q-chip>
            </td>
            <td class="text-slate-400 text-caption">{{ row.reference || '-' }}</td>
            <td class="text-right text-weight-bold">{{ formatAmountBdt(row.amount) }}</td>
            <td class="text-right font-semibold">
              <span :class="row.unallocated_amount > 0 ? 'text-amber-400' : 'text-slate-500'">
                {{ formatAmountBdt(row.unallocated_amount) }}
              </span>
            </td>
            <td class="text-center" @click.stop>
              <q-btn
                flat
                round
                dense
                color="teal"
                icon="o_visibility"
                @click="navigateToDetails(row.id)"
              >
                <q-tooltip>View Details & Allocate</q-tooltip>
              </q-btn>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <!-- Create Payment Dialog -->
    <q-dialog v-model="createDialogOpen">
      <div class="glass-dialog q-pa-lg text-white" style="width: 500px; max-width: 90vw;">
        <div class="row items-center justify-between q-mb-lg">
          <div class="text-h6 text-weight-bold">Record Customer Payment</div>
          <q-btn flat round dense icon="close" color="slate-400" v-close-popup />
        </div>

        <q-form @submit.prevent="submitPayment" class="q-gutter-md">
          <q-select
            v-model="newPayment.billing_profile_id"
            :options="profileOptions"
            label="Customer Billing Profile"
            dark
            outlined
            emit-value
            map-options
            :rules="[val => !!val || 'Billing profile is required']"
            class="glass-input"
          />

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="newPayment.amount"
                type="number"
                step="0.01"
                min="0.01"
                label="Amount (BDT)"
                dark
                outlined
                :rules="[val => val > 0 || 'Amount must be positive']"
                class="glass-input"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model="newPayment.payment_date"
                label="Payment Date"
                dark
                outlined
                readonly
                class="glass-input"
              >
                <template #append>
                  <q-icon name="event" class="cursor-pointer text-slate-400">
                    <q-popup-proxy ref="qDateProxy" cover transition-show="scale" transition-hide="scale">
                      <q-date v-model="newPayment.payment_date" mask="YYYY-MM-DD" @update:model-value="() => qDateProxy?.hide()" />
                    </q-popup-proxy>
                  </q-icon>
                </template>
              </q-input>
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-select
                v-model="newPayment.method"
                :options="methodSelectOptions"
                label="Payment Method"
                dark
                outlined
                class="glass-input"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model="newPayment.reference"
                label="Reference ID"
                dark
                outlined
                class="glass-input"
              />
            </div>
          </div>

          <q-input
            v-model="newPayment.note"
            label="Note"
            dark
            outlined
            type="textarea"
            rows="2"
            class="glass-input"
          />

          <div class="row justify-end q-mt-lg">
            <q-btn flat no-caps label="Cancel" color="slate-400" v-close-popup class="q-mr-sm" />
            <q-btn
              color="emerald"
              no-caps
              label="Save Payment"
              type="submit"
              :loading="saving"
              class="glass-btn px-4"
            />
          </div>
        </q-form>
      </div>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useBillingProfileStore } from 'src/modules/invoice/stores/billingProfileStore'

const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()
const billingProfileStore = useBillingProfileStore()

const loading = ref(false)
const saving = ref(false)
const payments = ref<any[]>([])

// Filters
const search = ref('')
const methodFilter = ref('__all__')
const unallocatedOnly = ref(false)

const methodOptions = [
  { label: 'All Methods', value: '__all__' },
  { label: 'Cash', value: 'cash' },
  { label: 'Bkash', value: 'bkash' },
  { label: 'Bank Transfer', value: 'bank_transfer' },
  { label: 'Nagad', value: 'nagad' },
]

const methodSelectOptions = ['cash', 'bkash', 'bank_transfer', 'nagad']

// Dialog Model
const createDialogOpen = ref(false)
const newPayment = ref({
  billing_profile_id: null as number | null,
  amount: 0,
  payment_date: new Date().toISOString().split('T')[0],
  method: 'cash',
  reference: '',
  note: '',
})

// Load Payments
const fetchPayments = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  try {
    const { data, error } = await supabase
      .from('global_payments')
      .select(`
        *,
        billing_profile:billing_profiles(name)
      `)
      .eq('tenant_id', tenantId)
      .order('payment_date', { ascending: false })

    if (error) throw error
    payments.value = data || []
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Failed to load payments: ${err.message}` })
  } finally {
    loading.value = false
  }
}

// Profile Options
const profileOptions = computed(() => {
  return billingProfileStore.items.map((p) => ({
    label: p.name,
    value: p.id,
  }))
})

// Sums
const totalPaymentsSum = computed(() => {
  return payments.value.reduce((sum, p) => sum + p.amount, 0)
})

const totalUnallocatedSum = computed(() => {
  return payments.value.reduce((sum, p) => sum + p.unallocated_amount, 0)
})

// Filtered payments
const filteredPayments = computed(() => {
  return payments.value.filter((p) => {
    const custName = p.billing_profile?.name || ''
    const refText = p.reference || ''
    const noteText = p.note || ''
    const matchesSearch =
      !search.value ||
      custName.toLowerCase().includes(search.value.toLowerCase()) ||
      refText.toLowerCase().includes(search.value.toLowerCase()) ||
      noteText.toLowerCase().includes(search.value.toLowerCase())

    const matchesMethod =
      methodFilter.value === '__all__' || p.method === methodFilter.value

    const matchesAlloc = !unallocatedOnly.value || p.unallocated_amount > 0

    return matchesSearch && matchesMethod && matchesAlloc
  })
})

const openCreateDialog = () => {
  newPayment.value = {
    billing_profile_id: null,
    amount: 0,
    payment_date: new Date().toISOString().split('T')[0],
    method: 'cash',
    reference: '',
    note: '',
  }
  createDialogOpen.value = true
}

const submitPayment = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !newPayment.value.billing_profile_id) return

  saving.value = true
  try {
    const { error } = await supabase.rpc('create_billing_profile_payment_with_allocations', {
      p_tenant_id: tenantId,
      p_billing_profile_id: newPayment.value.billing_profile_id,
      p_amount: newPayment.value.amount,
      p_payment_date: newPayment.value.payment_date,
      p_method: newPayment.value.method,
      p_reference: newPayment.value.reference || null,
      p_note: newPayment.value.note || null,
      p_allocations: [],
    })

    if (error) throw error

    $q.notify({ type: 'positive', message: 'Payment recorded successfully.' })
    createDialogOpen.value = false
    await fetchPayments()
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Error creating payment: ${err.message}` })
  } finally {
    saving.value = false
  }
}

const navigateToDetails = (id: number) => {
  void router.push({
    name: 'app-finance-payment-details-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      id,
    },
  })
}

const formatAmountBdt = (val: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'BDT',
  }).format(val)
}

onMounted(async () => {
  await fetchPayments()
  if (authStore.tenantId && !billingProfileStore.items.length) {
    await billingProfileStore.fetchBillingProfiles({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 500,
      sortBy: 'name',
      sortOrder: 'asc',
    })
  }
})
</script>

<style scoped>
.bg-slate-900 {
  background-color: #0f172a;
}
.text-slate-400 {
  color: #94a3b8;
}
.text-slate-500 {
  color: #64748b;
}
.border-slate-800 {
  border-color: #1e293b;
}
.border-slate-800\/50 {
  border-color: rgba(30, 41, 59, 0.5);
}
.hover\:bg-slate-800\/40:hover {
  background-color: rgba(30, 41, 59, 0.4);
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

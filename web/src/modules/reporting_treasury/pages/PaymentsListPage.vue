<template>
  <TreasuryPageShell
    title="Payment Treasury"
    subtitle="Manage capital collections, analyze unallocated funds, and link payments to sales invoices."
    :error="error"
  >
    <template #action>
      <q-btn
        color="primary"
        icon="add"
        no-caps
        label="Record Payment"
        unelevated
        @click="openCreateDialog"
      />
    </template>

    <div class="q-gutter-y-lg">
      <!-- Stats Grid -->
      <TreasuryStatGrid :items="statCards" />

      <!-- Filter Bar -->
      <TreasuryFilterBar>
        <div class="row q-col-gutter-md items-center justify-between">
          <div class="col-12 col-md-4">
            <q-input
              v-model="search"
              placeholder="Search by customer name, ref, or note..."
              dense
              outlined
            >
              <template #append>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>
          <div class="col-12 col-md-3">
            <q-select
              v-model="methodFilter"
              :options="methodOptions"
              label="Method"
              dense
              outlined
              emit-value
              map-options
            />
          </div>
          <div class="col-12 col-md-3">
            <q-toggle v-model="unallocatedOnly" label="Show Unallocated Only" color="primary" />
          </div>
        </div>
      </TreasuryFilterBar>

      <!-- Payments Table -->
      <q-card flat bordered>
        <TreasuryTableWrap>
          <q-table
            flat
            row-key="id"
            :rows="filteredPayments"
            :columns="columns"
            :loading="loading"
            :pagination="{ rowsPerPage: 20 }"
            :dense="$q.screen.lt.md"
            table-style="min-width: 900px;"
          >
            <template #body-cell-id="props">
              <q-td :props="props" class="text-weight-bold text-primary">
                #{{ props.row.id }}
              </q-td>
            </template>

            <template #body-cell-billing_profile="props">
              <q-td :props="props">
                {{ props.row.billing_profile?.name || 'Walk-in / Direct' }}
              </q-td>
            </template>

            <template #body-cell-method="props">
              <q-td :props="props">
                <q-chip
                  dense
                  square
                  color="blue-1"
                  text-color="blue-9"
                  class="text-weight-bold text-uppercase text-xs"
                >
                  {{ props.row.method || 'cash' }}
                </q-chip>
              </q-td>
            </template>

            <template #body-cell-amount="props">
              <q-td :props="props" class="text-right">
                {{ formatAmountBdt(props.row.amount) }}
              </q-td>
            </template>

            <template #body-cell-unallocated_amount="props">
              <q-td :props="props" class="text-right font-semibold">
                <span
                  :class="
                    props.row.unallocated_amount > 0
                      ? 'text-warning text-weight-bold'
                      : 'text-grey-5'
                  "
                >
                  {{ formatAmountBdt(props.row.unallocated_amount) }}
                </span>
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props" class="text-center">
                <q-btn
                  flat
                  round
                  dense
                  color="primary"
                  icon="o_visibility"
                  @click="navigateToDetails(props.row.id)"
                >
                  <q-tooltip>View Details & Allocate</q-tooltip>
                </q-btn>
              </q-td>
            </template>
          </q-table>
        </TreasuryTableWrap>
      </q-card>
    </div>

    <!-- Create Payment Dialog -->
    <q-dialog v-model="createDialogOpen" persistent>
      <q-card style="width: 500px; max-width: 90vw">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">Record Customer Payment</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section>
          <q-form @submit.prevent="submitPayment" class="q-gutter-md">
            <q-select
              v-model="newPayment.billing_profile_id"
              :options="profileOptions"
              label="Customer Billing Profile"
              outlined
              dense
              emit-value
              map-options
              :rules="[(val) => !!val || 'Billing profile is required']"
            />

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="newPayment.amount"
                  type="number"
                  step="0.01"
                  min="0.01"
                  label="Amount (BDT)"
                  outlined
                  dense
                  :rules="[(val) => val > 0 || 'Amount must be positive']"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="newPayment.payment_date"
                  label="Payment Date"
                  outlined
                  dense
                  readonly
                >
                  <template #append>
                    <q-icon name="event" class="cursor-pointer">
                      <q-popup-proxy
                        ref="qDateProxy"
                        cover
                        transition-show="scale"
                        transition-hide="scale"
                      >
                        <q-date
                          v-model="newPayment.payment_date"
                          mask="YYYY-MM-DD"
                          @update:model-value="closeDatePopup"
                        />
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
                  outlined
                  dense
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model="newPayment.reference" label="Reference ID" outlined dense />
              </div>
            </div>

            <q-input
              v-model="newPayment.note"
              label="Note"
              outlined
              dense
              type="textarea"
              rows="2"
            />

            <div class="row justify-end q-mt-lg">
              <q-btn flat no-caps label="Cancel" v-close-popup class="q-mr-sm" />
              <q-btn
                color="primary"
                no-caps
                label="Save Payment"
                type="submit"
                :loading="saving"
                unelevated
              />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import type { QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBillingProfileStore } from 'src/modules/sales_invoice/stores/billingProfileStore';
import { formatAmountBdt } from 'src/utils/currency';
import TreasuryPageShell from '../components/TreasuryPageShell.vue';
import TreasuryStatGrid from '../components/TreasuryStatGrid.vue';
import TreasuryFilterBar from '../components/TreasuryFilterBar.vue';

const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();
const billingProfileStore = useBillingProfileStore();

const loading = ref(false);
const saving = ref(false);
const error = ref<string | null>(null);
const payments = ref<any[]>([]);
const qDateProxy = ref<any>(null);

const closeDatePopup = () => {
  if (qDateProxy.value) {
    qDateProxy.value.hide();
  }
};

// Filters
const search = ref('');
const methodFilter = ref('__all__');
const unallocatedOnly = ref(false);

const columns: QTableColumn[] = [
  { name: 'id', label: 'Payment ID', field: 'id', align: 'left', sortable: true },
  { name: 'payment_date', label: 'Date', field: 'payment_date', align: 'left', sortable: true },
  {
    name: 'billing_profile',
    label: 'Customer / Profile',
    field: 'billing_profile_id',
    align: 'left',
    sortable: true,
  },
  { name: 'method', label: 'Method', field: 'method', align: 'left', sortable: true },
  { name: 'reference', label: 'Reference', field: 'reference', align: 'left' },
  { name: 'amount', label: 'Amount', field: 'amount', align: 'right', sortable: true },
  {
    name: 'unallocated_amount',
    label: 'Unallocated',
    field: 'unallocated_amount',
    align: 'right',
    sortable: true,
  },
  { name: 'actions', label: 'Actions', field: 'id', align: 'center' },
];

const methodOptions = [
  { label: 'All Methods', value: '__all__' },
  { label: 'Cash', value: 'cash' },
  { label: 'Bkash', value: 'bkash' },
  { label: 'Bank Transfer', value: 'bank_transfer' },
  { label: 'Nagad', value: 'nagad' },
];

const methodSelectOptions = ['cash', 'bkash', 'bank_transfer', 'nagad'];

// Dialog Model
const createDialogOpen = ref(false);
const newPayment = ref({
  billing_profile_id: null as number | null,
  amount: 0,
  payment_date: new Date().toISOString().split('T')[0],
  method: 'cash',
  reference: '',
  note: '',
});

// Load Payments
const fetchPayments = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId) return;

  loading.value = true;
  error.value = null;
  try {
    const { data, error: err } = await supabase
      .from('global_payments')
      .select(
        `
        *,
        billing_profile:billing_profiles(name)
      `,
      )
      .eq('tenant_id', tenantId)
      .order('payment_date', { ascending: false });

    if (err) throw err;
    payments.value = data || [];
  } catch (err: any) {
    error.value = err.message;
    $q.notify({ type: 'negative', message: `Failed to load payments: ${err.message}` });
  } finally {
    loading.value = false;
  }
};

// Profile Options
const profileOptions = computed(() => {
  return billingProfileStore.items.map((p) => ({
    label: p.name,
    value: p.id,
  }));
});

// Sums
const totalPaymentsSum = computed(() => {
  return filteredPayments.value.reduce((sum, p) => sum + p.amount, 0);
});

const totalUnallocatedSum = computed(() => {
  return filteredPayments.value.reduce((sum, p) => sum + p.unallocated_amount, 0);
});

const statCards = computed(() => [
  {
    label: 'Total Received Payments',
    value: totalPaymentsSum.value,
    caption: 'Cumulative across all channels',
  },
  {
    label: 'Unallocated Treasury',
    value: totalUnallocatedSum.value,
    caption: 'Funds pending invoice assignment',
    valueClass: 'text-warning',
  },
  {
    label: 'Allocated Funds',
    value: totalPaymentsSum.value - totalUnallocatedSum.value,
    caption: 'Directly cleared against liabilities',
    valueClass: 'text-positive',
  },
]);

// Filtered payments
const filteredPayments = computed(() => {
  return payments.value.filter((p) => {
    const custName = p.billing_profile?.name || '';
    const refText = p.reference || '';
    const noteText = p.note || '';
    const matchesSearch =
      !search.value ||
      custName.toLowerCase().includes(search.value.toLowerCase()) ||
      refText.toLowerCase().includes(search.value.toLowerCase()) ||
      noteText.toLowerCase().includes(search.value.toLowerCase());

    const matchesMethod = methodFilter.value === '__all__' || p.method === methodFilter.value;

    const matchesAlloc = !unallocatedOnly.value || p.unallocated_amount > 0;

    return matchesSearch && matchesMethod && matchesAlloc;
  });
});

const openCreateDialog = () => {
  newPayment.value = {
    billing_profile_id: null,
    amount: 0,
    payment_date: new Date().toISOString().split('T')[0],
    method: 'cash',
    reference: '',
    note: '',
  };
  createDialogOpen.value = true;
};

const submitPayment = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId || !newPayment.value.billing_profile_id) return;

  saving.value = true;
  try {
    const { error: err } = await supabase.rpc('create_billing_profile_payment_with_allocations', {
      p_tenant_id: tenantId,
      p_billing_profile_id: newPayment.value.billing_profile_id,
      p_amount: newPayment.value.amount,
      p_payment_date: newPayment.value.payment_date,
      p_method: newPayment.value.method,
      p_reference: newPayment.value.reference || null,
      p_note: newPayment.value.note || null,
      p_allocations: [],
    });

    if (err) throw err;

    $q.notify({ type: 'positive', message: 'Payment recorded successfully.' });
    createDialogOpen.value = false;
    await fetchPayments();
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Error creating payment: ${err.message}` });
  } finally {
    saving.value = false;
  }
};

const navigateToDetails = (id: number) => {
  void router.push({
    name: 'app-finance-payment-details-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      id,
    },
  });
};

onMounted(async () => {
  await fetchPayments();
  if (authStore.tenantId && !billingProfileStore.items.length) {
    await billingProfileStore.fetchBillingProfiles({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 500,
      sortBy: 'name',
      sortOrder: 'asc',
    });
  }
});
</script>

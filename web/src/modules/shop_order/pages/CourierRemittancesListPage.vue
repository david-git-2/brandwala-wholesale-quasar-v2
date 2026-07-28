<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Loading Skeleton -->
      <courier-remittance-skeleton v-if="isLoading" />

      <template v-else>
        <!-- Page Header -->
        <section class="row items-center justify-between q-col-gutter-md">
          <div class="col">
            <div class="text-overline text-primary">Shop &amp; Dropship</div>
            <h1 class="text-h5 text-weight-bold q-my-none">Courier Remittances</h1>
          </div>
          <div class="col-auto row q-gutter-sm items-center">
            <q-btn
              outline
              color="primary"
              icon="ph ph-arrow-left"
              label="Back to Operations"
              no-caps
              :to="{ name: 'app-shop-dropship-orders-page' }"
            />
            <q-btn
              color="primary"
              unelevated
              icon="add"
              label="New Remittance Batch"
              no-caps
              :to="{ name: 'app-shop-courier-remittance-new-page' }"
            />
          </div>
        </section>

        <!-- Filters & Toolbar Card -->
        <q-card flat bordered class="form-card q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-md">
            <div class="col-12 col-sm-6 col-md-4">
              <q-input
                v-model="searchQuery"
                dense
                outlined
                hide-bottom-space
                placeholder="Search statement no, bank TRX, notes..."
                clearable
              >
                <template #prepend>
                  <q-icon name="search" size="18px" />
                </template>
              </q-input>
            </div>

            <!-- Status Filter Chips -->
            <div class="col-12 col-sm-6 col-md-auto row q-gutter-xs items-center">
              <q-chip
                v-for="st in statusOptions"
                :key="st.val"
                clickable
                :outline="selectedStatus !== st.val"
                :color="selectedStatus === st.val ? 'primary' : 'grey-4'"
                :text-color="selectedStatus === st.val ? 'white' : 'grey-9'"
                @click="selectedStatus = st.val"
              >
                {{ st.label }}
              </q-chip>
            </div>
          </div>
        </q-card>

        <!-- Batches List Table -->
        <q-card flat bordered class="form-card">
          <div class="treasury-table-wrap">
            <q-table
              :rows="filteredBatches"
              :columns="columns"
              row-key="id"
              dense
              flat
              :pagination="pagination"
              no-data-label="No courier remittance statement batches found"
            >
              <!-- Batch No / ID Cell -->
              <template #body-cell-batch_no="props">
                <q-td :props="props">
                  <div
                    class="text-weight-bold text-primary cursor-pointer hover-underline flex items-center gap-1"
                    @click="goToDetail(props.row.id)"
                  >
                    <span>{{ props.row.batch_no }}</span>
                    <q-icon name="arrow_forward" size="14px" />
                  </div>
                  <div class="text-caption text-grey-7">
                    Created {{ formatDate(props.row.created_at) }}
                  </div>
                </q-td>
              </template>

              <!-- Courier Service Cell -->
              <template #body-cell-courier="props">
                <q-td :props="props">
                  <q-chip dense color="blue-1" text-color="primary" icon="local_shipping" class="text-weight-medium">
                    {{ props.row.courier_service?.name || 'Courier' }}
                  </q-chip>
                </q-td>
              </template>

              <!-- Status Cell -->
              <template #body-cell-status="props">
                <q-td :props="props">
                  <q-chip
                    dense
                    :color="getStatusColor(props.row.status)"
                    text-color="white"
                    class="text-weight-bold uppercase"
                    size="sm"
                  >
                    {{ props.row.status }}
                  </q-chip>
                </q-td>
              </template>

              <!-- Net Deposit Cell -->
              <template #body-cell-net_deposited_amount="props">
                <q-td :props="props" class="text-right">
                  <span class="text-weight-bold text-dark">
                    ৳ {{ formatAmount(props.row.net_deposited_amount) }}
                  </span>
                </q-td>
              </template>

              <!-- Allocated Amount Cell -->
              <template #body-cell-allocated_amount="props">
                <q-td :props="props" class="text-right">
                  <span class="text-weight-medium text-positive">
                    ৳ {{ formatAmount(props.row.allocated_amount) }}
                  </span>
                </q-td>
              </template>

              <!-- Variance Cell -->
              <template #body-cell-variance_amount="props">
                <q-td :props="props" class="text-right">
                  <span
                    :class="props.row.variance_amount !== 0 ? 'text-weight-bold text-negative' : 'text-grey-6'"
                  >
                    ৳ {{ formatAmount(props.row.variance_amount) }}
                  </span>
                </q-td>
              </template>

              <!-- Actions Cell -->
              <template #body-cell-actions="props">
                <q-td :props="props" class="text-right">
                  <q-btn
                    flat
                    round
                    dense
                    color="primary"
                    icon="visibility"
                    @click="goToDetail(props.row.id)"
                  >
                    <q-tooltip>View Statement Detail</q-tooltip>
                  </q-btn>
                </q-td>
              </template>
            </q-table>
          </div>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCourierRemittancesQuery } from '../composables/useCourierRemittancesQuery';
import CourierRemittanceSkeleton from '../components/CourierRemittanceSkeleton.vue';
import type { CourierRemittanceBatch } from '../types';

const router = useRouter();
const authStore = useAuthStore();
const tenantId = computed(() => (authStore.tenantId as number) ?? 0);

const searchQuery = ref('');
const selectedStatus = ref<string>('all');

const queryParams = computed(() => ({
  tenantId: tenantId.value,
  status: selectedStatus.value === 'all' ? null : selectedStatus.value,
}));

const { data: batches, isLoading } = useCourierRemittancesQuery(queryParams);

const statusOptions = [
  { label: 'All Batches', val: 'all' },
  { label: 'Draft', val: 'draft' },
  { label: 'Posted', val: 'posted' },
];

const filteredBatches = computed(() => {
  if (!batches.value) return [];
  return batches.value.filter((b) => {
    const matchesStatus = selectedStatus.value === 'all' || b.status === selectedStatus.value;
    const q = searchQuery.value.trim().toLowerCase();
    const matchesSearch =
      !q ||
      b.batch_no.toLowerCase().includes(q) ||
      (b.bank_trx_id && b.bank_trx_id.toLowerCase().includes(q)) ||
      (b.note && b.note.toLowerCase().includes(q));
    return matchesStatus && matchesSearch;
  });
});

const pagination = ref({
  rowsPerPage: 15,
  sortBy: 'created_at',
  descending: true,
});

const columns: QTableColumn<CourierRemittanceBatch>[] = [
  { name: 'batch_no', label: 'Statement ID / Date', field: 'batch_no', align: 'left', sortable: true },
  { name: 'courier', label: 'Courier Service', field: (r) => r.courier_service?.name, align: 'left' },
  { name: 'payment_date', label: 'Payment Date', field: 'payment_date', align: 'left', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: true },
  { name: 'net_deposited_amount', label: 'Bank Deposit Net', field: 'net_deposited_amount', align: 'right', sortable: true },
  { name: 'allocated_amount', label: 'Allocated Net', field: 'allocated_amount', align: 'right', sortable: true },
  { name: 'variance_amount', label: 'Variance', field: 'variance_amount', align: 'right', sortable: true },
  { name: 'actions', label: 'Action', field: () => '', align: 'right' },
];

function getStatusColor(status: string): string {
  switch (status) {
    case 'posted':
      return 'positive';
    case 'draft':
      return 'warning';
    case 'voided':
      return 'grey-7';
    default:
      return 'primary';
  }
}

function formatAmount(val: number): string {
  return (val || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function formatDate(isoStr: string): string {
  if (!isoStr) return '—';
  return isoStr.slice(0, 10);
}

function goToDetail(batchId: number) {
  const tenantSlug = authStore.selectedTenant?.slug;
  if (tenantSlug) {
    void router.push(`/${tenantSlug}/app/shop/dropship/courier-remittances/${batchId}`);
  } else {
    void router.push(`/app/shop/dropship/courier-remittances/${batchId}`);
  }
}
</script>

<style scoped lang="scss">
.form-card {
  border-radius: 12px;
  background: var(--bw-theme-surface);
  border: 1px solid var(--bw-theme-border);
}

.hover-underline:hover {
  text-decoration: underline;
}
</style>

<template>
  <q-page class="cash-in-report-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Compact Top Toolbar -->
    <div class="bg-white border-bottom q-px-md q-py-xs shrink-0 shadow-xs">
      <div class="row items-center justify-between q-col-gutter-xs">
        <!-- Date Preset Filter Pills -->
        <div class="col-auto row items-center q-gutter-xs">
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'today'"
            :outline="preset !== 'today'"
            :color="preset === 'today' ? 'primary' : 'grey-7'"
            label="Today"
            @click="setPreset('today')"
          />
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'week'"
            :outline="preset !== 'week'"
            :color="preset === 'week' ? 'primary' : 'grey-7'"
            label="Last 7 Days"
            @click="setPreset('week')"
          />
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'month'"
            :outline="preset !== 'month'"
            :color="preset === 'month' ? 'primary' : 'grey-7'"
            label="This Month"
            @click="setPreset('month')"
          />
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'custom'"
            :outline="preset !== 'custom'"
            :color="preset === 'custom' ? 'primary' : 'grey-7'"
            label="Custom"
            @click="preset = 'custom'"
          />

          <!-- Custom Pickers inline -->
          <template v-if="preset === 'custom'">
            <q-input
              v-model="startDate"
              dense
              outlined
              type="date"
              class="compact-date-input bg-white"
            />
            <span class="text-caption text-grey-6">to</span>
            <q-input
              v-model="endDate"
              dense
              outlined
              type="date"
              class="compact-date-input bg-white"
            />
          </template>
        </div>

        <!-- Right Controls: Search, Export, Refresh -->
        <div class="col-auto row items-center q-gutter-x-xs">
          <q-input
            v-model="searchText"
            outlined
            rounded
            dense
            clearable
            placeholder="Search transactions..."
            class="dense-search-input bg-white"
            style="min-width: 200px"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="14px" />
            </template>
          </q-input>

          <q-btn
            outline
            dense
            size="sm"
            color="primary"
            icon="ph ph-file-csv"
            label="Export CSV"
            no-caps
            class="rounded-sq-btn q-px-sm text-weight-bold"
            :disable="isLoading || !entries.length"
            @click="exportCsv"
          />

          <q-btn
            flat
            round
            dense
            size="sm"
            icon="ph ph-arrows-clockwise"
            color="grey-7"
            :loading="isLoading"
            @click="() => refetch()"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <!-- Error Banner -->
    <q-banner v-if="error" class="bg-negative text-white q-px-md q-py-xs shrink-0">
      {{ (error as Error).message }}
    </q-banner>

    <!-- Compact KPI & Method Summary Strip -->
    <div class="bg-white border-bottom q-px-md q-py-xs shrink-0">
      <div class="row items-center justify-between wrap q-gutter-y-xs">
        <!-- Summary Totals -->
        <div class="row items-center q-gutter-x-md">
          <div class="row items-baseline q-gutter-x-xs">
            <span class="text-caption text-grey-7 text-uppercase font-bold" style="font-size: 11px">Total Cash In:</span>
            <span class="text-subtitle2 text-weight-bolder text-primary bw-tabular">
              {{ formatAmountBdt(cashInTotal) }}
            </span>
            <span class="text-caption text-grey-5">({{ entryCount }} entries)</span>
          </div>

          <q-separator vertical inset class="gt-xs" />

          <!-- Method Pills -->
          <div class="row items-center q-gutter-xs">
            <q-chip
              clickable
              dense
              size="sm"
              :color="selectedMethod === null ? 'primary' : 'grey-2'"
              :text-color="selectedMethod === null ? 'white' : 'grey-9'"
              class="text-weight-bold"
              @click="selectedMethod = null"
            >
              All ({{ allEntries.length }})
            </q-chip>
            <q-chip
              v-for="m in byMethod"
              :key="m.method"
              clickable
              dense
              size="sm"
              :color="selectedMethod === m.method ? 'primary' : 'grey-2'"
              :text-color="selectedMethod === m.method ? 'white' : 'grey-9'"
              class="text-weight-bold"
              @click="selectedMethod = selectedMethod === m.method ? null : m.method"
            >
              {{ formatMethodName(m.method) }}: {{ formatAmountBdt(m.amount) }}
            </q-chip>
          </div>
        </div>
      </div>
    </div>

    <!-- Main Table Container (Flex with Internal Scroll) -->
    <div class="table-scroll-container col-grow overflow-hidden q-pa-xs">
      <q-table
        flat
        dense
        :rows="displayedEntries"
        :columns="columns"
        row-key="id"
        :loading="isLoading"
        :pagination="{ rowsPerPage: 50 }"
        class="compact-ops-table full-height bg-white"
        no-data-label="No cash-in records found for this period"
      >
        <template #body="props">
          <q-tr
            :props="props"
            class="cursor-pointer hover-row"
            @click="onRowClick(props.row)"
          >
            <!-- Date & Time -->
            <q-td key="created_at" :props="props" class="bw-tabular text-grey-9">
              {{ formatDateTime(props.row.created_at) }}
            </q-td>

            <!-- Method Badge -->
            <q-td key="method" :props="props">
              <span
                class="method-status-badge text-caption font-bold text-uppercase"
                :class="`method-${props.row.method}`"
              >
                {{ formatMethodName(props.row.method) }}
              </span>
            </q-td>

            <!-- Amount (BDT) -->
            <q-td key="amount" :props="props" class="text-weight-bold text-positive bw-tabular">
              +{{ formatAmountBdt(props.row.amount) }}
            </q-td>

            <!-- Description / Label -->
            <q-td key="label" :props="props">
              <div class="text-weight-medium text-grey-9 text-truncate" style="max-width: 320px">
                {{ props.row.label || props.row.source_type }}
              </div>
            </q-td>

            <!-- Source Details -->
            <q-td key="source_type" :props="props" class="text-grey-7">
              <span class="text-capitalize">{{ props.row.source_type?.replace(/_/g, ' ') }}</span>
              <span v-if="props.row.source_id" class="text-caption text-grey-5 q-ml-xs">
                #{{ props.row.source_id }}
              </span>
            </q-td>

            <!-- Linked Invoice -->
            <q-td key="invoice_id" :props="props">
              <q-chip
                v-if="props.row.invoice_id"
                dense
                size="sm"
                color="blue-1"
                text-color="primary"
                class="cursor-pointer text-weight-bold"
                icon="ph ph-receipt"
                @click.stop="openInvoice(props.row.invoice_id)"
              >
                #INV-{{ props.row.invoice_id }}
              </q-chip>
              <span v-else class="text-grey-4 text-caption">—</span>
            </q-td>

            <!-- Row Actions -->
            <q-td key="actions" :props="props" class="text-right">
              <q-btn
                v-if="props.row.invoice_id"
                flat
                round
                dense
                size="sm"
                icon="ph ph-arrow-square-out"
                color="primary"
                @click.stop="openInvoice(props.row.invoice_id)"
              >
                <q-tooltip>Open Invoice</q-tooltip>
              </q-btn>
            </q-td>
          </q-tr>
        </template>
      </q-table>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { useCashInReport } from 'src/modules/wallet/composables/useWalletReports';
import type { CashInReportEntry } from 'src/modules/wallet/types';

const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());
const searchText = ref('');

const {
  entries,
  allEntries,
  byMethod,
  cashInTotal,
  entryCount,
  isLoading,
  error,
  preset,
  startDate,
  endDate,
  selectedMethod,
  setPreset,
  exportCsv,
  refetch,
} = useCashInReport();

const displayedEntries = computed(() => {
  const list = entries.value || [];
  if (!searchText.value.trim()) return list;
  const q = searchText.value.toLowerCase().trim();
  return list.filter((item) => {
    return (
      (item.label && item.label.toLowerCase().includes(q)) ||
      (item.method && item.method.toLowerCase().includes(q)) ||
      (item.source_type && item.source_type.toLowerCase().includes(q)) ||
      (item.source_id && String(item.source_id).toLowerCase().includes(q)) ||
      (item.invoice_id && String(item.invoice_id).includes(q))
    );
  });
});

const columns: QTableColumn<CashInReportEntry>[] = [
  {
    name: 'created_at',
    label: 'Date & Time',
    field: 'created_at',
    align: 'left',
    sortable: true,
  },
  {
    name: 'method',
    label: 'Method',
    field: 'method',
    align: 'left',
    sortable: true,
  },
  {
    name: 'amount',
    label: 'Amount (BDT)',
    field: 'amount',
    align: 'right',
    sortable: true,
  },
  {
    name: 'label',
    label: 'Description / Purpose',
    field: 'label',
    align: 'left',
  },
  {
    name: 'source_type',
    label: 'Source',
    field: 'source_type',
    align: 'left',
  },
  {
    name: 'invoice_id',
    label: 'Invoice',
    field: 'invoice_id',
    align: 'center',
  },
  {
    name: 'actions',
    label: '',
    field: 'id',
    align: 'right',
  },
];

function formatMethodName(method: string): string {
  if (!method) return 'Other';
  const map: Record<string, string> = {
    cash: 'Cash',
    bank: 'Bank',
    bkash: 'bKash',
    nagad: 'Nagad',
    courier_remit: 'Courier Remit',
    cheque: 'Cheque',
    card: 'Card',
    deposit: 'Deposit',
  };
  return map[method.toLowerCase()] || method.charAt(0).toUpperCase() + method.slice(1).replace(/_/g, ' ');
}

function formatDateTime(iso: string): string {
  if (!iso) return '-';
  try {
    const d = new Date(iso);
    return `${d.toLocaleDateString()} ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
  } catch {
    return iso;
  }
}

function openInvoice(invoiceId: number) {
  void router.push(`/${tenantSlug.value || 'tenant'}/app/sales/invoices/${invoiceId}`);
}

function onRowClick(row: CashInReportEntry) {
  if (row.invoice_id) {
    openInvoice(row.invoice_id);
  }
}
</script>

<style scoped>
.rounded-sq-btn {
  border-radius: 8px !important;
}

.compact-date-input {
  width: 130px;
}

.dense-search-input :deep(.q-field__control) {
  height: 30px;
  min-height: 30px;
}

.shrink-0 {
  flex-shrink: 0;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}

.table-scroll-container {
  display: flex;
  flex-direction: column;
}

.table-scroll-container :deep(.q-table__container) {
  height: 100%;
  display: flex;
  flex-direction: column;
  border-radius: 0;
  border: 1px solid #e2e8f0;
}

.table-scroll-container :deep(.q-table__middle) {
  flex: 1 1 auto;
  overflow-y: auto;
}

.table-scroll-container :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #f8fafc;
  font-weight: 700;
  color: #475569;
  border-bottom: 2px solid #e2e8f0;
}

.hover-row:hover {
  background-color: #f8fafc;
}

.method-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 11px;
  letter-spacing: 0.5px;
  box-shadow: inset 3px 0 0 transparent;
}

.method-cash {
  background: #f0fdf4;
  color: #16a34a;
  border: 1px solid #bbf7d0;
}

.method-bank,
.method-deposit {
  background: #eff6ff;
  color: #2563eb;
  border: 1px solid #bfdbfe;
}

.method-bkash,
.method-nagad {
  background: #fff7ed;
  color: #ea580c;
  border: 1px solid #fed7aa;
}

.method-courier_remit {
  background: #faf5ff;
  color: #9333ea;
  border: 1px solid #e9d5ff;
}

.font-bold {
  font-weight: 700;
}
</style>



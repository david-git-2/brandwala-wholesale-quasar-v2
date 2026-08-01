<template>
  <div class="wallet-statement-view q-gutter-y-md">
    <!-- Filter Header Card -->
    <q-card flat bordered class="q-pa-md shadow-1 rounded-borders">
      <div class="row items-center justify-between q-col-gutter-md">
        <div class="col-xs-12 col-md-6">
          <div class="text-subtitle2 text-weight-bold text-ink">Account Statement Controls</div>
          <div class="text-caption text-grey-7">
            Filter transactions by date range for {{ entityName || entityType.toUpperCase() }} (#{{ entityId }})
          </div>
        </div>

        <div class="col-xs-12 col-md-6 text-right">
          <div class="row items-center justify-end q-gutter-xs">
            <q-btn
              flat
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-borders"
              :color="activePreset === 'today' ? 'primary' : 'grey-8'"
              label="Today"
              @click="applyPreset('today')"
            />
            <q-btn
              flat
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-borders"
              :color="activePreset === 'week' ? 'primary' : 'grey-8'"
              label="Last 7 Days"
              @click="applyPreset('week')"
            />
            <q-btn
              flat
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-borders"
              :color="activePreset === 'month' ? 'primary' : 'grey-8'"
              label="This Month"
              @click="applyPreset('month')"
            />
            <q-btn
              flat
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-borders"
              :color="activePreset === 'all' ? 'primary' : 'grey-8'"
              label="All Time"
              @click="applyPreset('all')"
            />
            <q-btn
              unelevated
              color="primary"
              icon="ph ph-download-simple"
              label="Export CSV"
              no-caps
              dense
              class="q-px-md q-ml-sm text-weight-bold"
              :disable="!statement || !statement.entries || statement.entries.length === 0"
              @click="onExportCsv"
            />
          </div>
        </div>
      </div>
    </q-card>

    <!-- Statement KPI Aggregates Card -->
    <div class="row q-col-gutter-md">
      <!-- Opening Balance -->
      <div class="col-xs-6 col-sm-3">
        <q-card flat bordered class="q-pa-sm text-center bg-grey-1">
          <div class="text-caption text-grey-7">Opening Balance</div>
          <div class="text-subtitle1 text-weight-bolder font-mono text-grey-9">
            ৳{{ formatCurrency(statement?.opening_balance || 0) }}
          </div>
        </q-card>
      </div>
      <!-- Total Credits -->
      <div class="col-xs-6 col-sm-3">
        <q-card flat bordered class="q-pa-sm text-center bg-green-1">
          <div class="text-caption text-positive text-weight-bold">Total Credits (+)</div>
          <div class="text-subtitle1 text-weight-bolder font-mono text-positive">
            +৳{{ formatCurrency(statement?.total_credits || 0) }}
          </div>
        </q-card>
      </div>
      <!-- Total Debits -->
      <div class="col-xs-6 col-sm-3">
        <q-card flat bordered class="q-pa-sm text-center bg-red-1">
          <div class="text-caption text-negative text-weight-bold">Total Debits (-)</div>
          <div class="text-subtitle1 text-weight-bolder font-mono text-negative">
            -৳{{ formatCurrency(statement?.total_debits || 0) }}
          </div>
        </q-card>
      </div>
      <!-- Closing Balance -->
      <div class="col-xs-6 col-sm-3">
        <q-card flat bordered class="q-pa-sm text-center bg-blue-1">
          <div class="text-caption text-primary text-weight-bold">Closing Balance</div>
          <div class="text-subtitle1 text-weight-bolder font-mono text-primary">
            ৳{{ formatCurrency(statement?.closing_balance || 0) }}
          </div>
        </q-card>
      </div>
    </div>

    <!-- Statement Entries Table -->
    <q-card flat bordered class="shadow-1 rounded-borders">
      <q-table
        flat
        dense
        :rows="statement?.entries || []"
        :columns="columns"
        row-key="id"
        :loading="isLoading"
        :pagination="{ rowsPerPage: 15 }"
        class="statement-table"
      >
        <template #body-cell-type="props">
          <q-td :props="props">
            <q-chip
              dense
              flat
              class="font-mono text-weight-bold text-caption"
              :class="props.row.type === 'credit' ? 'bg-positive-soft text-positive' : 'bg-negative-soft text-negative'"
            >
              <q-icon
                :name="props.row.type === 'credit' ? 'ph ph-arrow-down-left' : 'ph ph-arrow-up-right'"
                size="12px"
                class="q-mr-xs"
              />
              {{ props.row.type.toUpperCase() }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-amount="props">
          <q-td :props="props" class="font-mono text-weight-bold">
            <span :class="props.row.type === 'credit' ? 'text-positive' : 'text-negative'">
              {{ props.row.type === 'credit' ? '+' : '-' }}৳{{ formatCurrency(props.row.amount) }}
            </span>
          </q-td>
        </template>

        <template #body-cell-balance_after="props">
          <q-td :props="props" class="font-mono text-weight-bold text-primary">
            ৳{{ formatCurrency(props.row.balance_after) }}
          </q-td>
        </template>

        <template #body-cell-created_at="props">
          <q-td :props="props" class="text-caption text-grey-8">
            {{ formatDate(props.row.created_at) }}
          </q-td>
        </template>

        <template #no-data>
          <div class="full-width row flex-center q-pa-xl text-grey-6 text-caption">
            <q-icon name="ph ph-receipt-x" size="32px" class="q-mr-sm" />
            No statement transactions recorded for the selected date range.
          </div>
        </template>
      </q-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useWalletReports } from '../composables/useWalletReports';
import type { UniversalWalletEntityType, UniversalWalletLedgerEntry } from '../types';

const props = defineProps<{
  entityType: UniversalWalletEntityType;
  entityId: number;
  entityName?: string;
}>();

const activePreset = ref<'today' | 'week' | 'month' | 'all'>('month');
const { statement, isLoading, setDateRange, exportCsv } = useWalletReports(
  () => props.entityType,
  () => props.entityId,
);

const columns = [
  { name: 'created_at', label: 'Date & Time', field: 'created_at', align: 'left' as const, sortable: true },
  { name: 'source_type', label: 'Source', field: 'source_type', align: 'left' as const, sortable: true },
  { name: 'source_id', label: 'Source ID', field: (row: UniversalWalletLedgerEntry) => row.source_id || '-', align: 'left' as const },
  { name: 'type', label: 'Type', field: 'type', align: 'center' as const },
  { name: 'amount', label: 'Amount', field: 'amount', align: 'right' as const, sortable: true },
  { name: 'balance_after', label: 'Running Balance', field: 'balance_after', align: 'right' as const, sortable: true },
];

function applyPreset(preset: 'today' | 'week' | 'month' | 'all') {
  activePreset.value = preset;
  setDateRange(preset);
}

function onExportCsv() {
  exportCsv(props.entityName || props.entityType.toUpperCase());
}

function formatCurrency(val: number): string {
  return new Intl.NumberFormat('en-BD', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(val || 0);
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

onMounted(() => {
  applyPreset('month');
});
</script>

<style scoped>
.bg-positive-soft {
  background: rgba(34, 197, 94, 0.12) !important;
}

.bg-negative-soft {
  background: rgba(239, 68, 68, 0.12) !important;
}

.text-ink {
  color: var(--bw-theme-ink, #1e293b);
}
</style>

<template>
  <q-card flat bordered class="surface-card">
    <div class="treasury-table-wrap">
      <q-table
        flat
        dense
        :rows="entries"
        :columns="columns"
        row-key="id"
        :pagination="pagination"
        class="wallet-table"
        no-data-label="No wallet ledger entries found."
      >
        <!-- Type Column Slot -->
        <template #body-cell-type="props">
          <q-td :props="props">
            <q-chip
              dense
              square
              size="sm"
              :class="props.row.type === 'credit' ? 'chip-credit' : 'chip-debit'"
              class="text-weight-bold text-uppercase"
            >
              <q-icon
                :name="props.row.type === 'credit' ? 'arrow_downward' : 'arrow_upward'"
                size="12px"
                class="q-mr-xs"
              />
              {{ props.row.type }}
            </q-chip>
          </q-td>
        </template>

        <!-- Amount Column Slot -->
        <template #body-cell-amount="props">
          <q-td :props="props">
            <span
              :class="props.row.type === 'credit' ? 'text-positive text-weight-bold' : 'text-negative text-weight-bold'"
            >
              {{ props.row.type === 'credit' ? '+' : '-' }}{{ formatCurrency(props.row.amount, props.row.currency_code) }}
            </span>
          </q-td>
        </template>

        <!-- Balance After Column Slot -->
        <template #body-cell-balance_after="props">
          <q-td :props="props" class="text-weight-bolder">
            {{ formatCurrency(props.row.balance_after, props.row.currency_code) }}
          </q-td>
        </template>

        <!-- Source Column Slot -->
        <template #body-cell-source="props">
          <q-td :props="props">
            <div class="row items-center q-gutter-x-xs">
              <q-chip dense outline size="xs" color="primary">
                {{ props.row.source_type }}
              </q-chip>
              <span v-if="props.row.source_id" class="text-caption text-weight-medium">
                #{{ props.row.source_id }}
              </span>
            </div>
          </q-td>
        </template>

        <!-- Created At Column Slot -->
        <template #body-cell-created_at="props">
          <q-td :props="props" class="text-muted">
            {{ formatDate(props.row.created_at) }}
          </q-td>
        </template>

        <!-- Metadata Column Slot -->
        <template #body-cell-metadata="props">
          <q-td :props="props">
            <span v-if="props.row.metadata?.approved_by" class="text-caption text-muted">
              Approved by: {{ props.row.metadata.approved_by }}
            </span>
            <span v-else-if="props.row.metadata?.trx_id" class="text-caption text-muted">
              Trx: {{ props.row.metadata.trx_id }}
            </span>
            <span v-else class="text-caption text-muted">-</span>
          </q-td>
        </template>
      </q-table>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { QTableColumn } from 'quasar';
import type { UniversalWalletLedgerEntry } from '../types';

defineProps<{
  entries: UniversalWalletLedgerEntry[];
}>();

const pagination = ref({
  rowsPerPage: 15,
  sortBy: 'created_at',
  descending: true,
});

const columns: QTableColumn<UniversalWalletLedgerEntry>[] = [
  {
    name: 'created_at',
    label: 'Date & Time',
    field: 'created_at',
    align: 'left',
    sortable: true,
  },
  {
    name: 'type',
    label: 'Type',
    field: 'type',
    align: 'center',
    sortable: true,
  },
  {
    name: 'amount',
    label: 'Amount',
    field: 'amount',
    align: 'right',
    sortable: true,
  },
  {
    name: 'balance_after',
    label: 'Balance After',
    field: 'balance_after',
    align: 'right',
    sortable: true,
  },
  {
    name: 'source',
    label: 'Source / Reference',
    field: 'source_type',
    align: 'left',
    sortable: true,
  },
  {
    name: 'metadata',
    label: 'Details',
    field: 'metadata',
    align: 'left',
  },
];

const formatCurrency = (amount: number, currencyCode = 'BDT') => {
  return new Intl.NumberFormat('en-BD', {
    style: 'currency',
    currency: currencyCode,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
};

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  return d.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};
</script>

<style scoped>
.surface-card {
  background: var(--bw-theme-surface);
  border-color: var(--bw-theme-border);
  border-radius: 10px;
}

.chip-credit {
  background: rgba(33, 186, 69, 0.15);
  color: #21ba45;
}

.chip-debit {
  background: rgba(193, 0, 21, 0.15);
  color: #c10015;
}

.text-muted {
  color: var(--bw-theme-muted);
}
</style>

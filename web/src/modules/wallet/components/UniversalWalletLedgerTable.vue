<template>
  <q-card flat class="soft-table-card shadow-soft">
    <div class="treasury-table-wrap">
      <q-table
        flat
        dense
        :rows="entries"
        :columns="columns"
        row-key="id"
        :pagination="pagination"
        class="soft-wallet-table"
        no-data-label="No financial transaction records found."
      >
        <!-- Type Column Slot -->
        <template #body-cell-type="props">
          <q-td :props="props">
            <q-chip
              dense
              unelevated
              :class="props.row.type === 'credit' ? 'soft-chip-credit' : 'soft-chip-debit'"
              class="text-weight-bolder text-uppercase q-px-sm"
            >
              <q-icon
                :name="props.row.type === 'credit' ? 'ph ph-arrow-down-left' : 'ph ph-arrow-up-right'"
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
              :class="props.row.type === 'credit' ? 'text-emerald text-weight-bolder' : 'text-rose text-weight-bolder'"
              class="font-mono text-body2"
            >
              {{ props.row.type === 'credit' ? '+' : '-' }}{{ formatCurrency(props.row.amount, props.row.currency_code) }}
            </span>
          </q-td>
        </template>

        <!-- Balance After Column Slot -->
        <template #body-cell-balance_after="props">
          <q-td :props="props" class="text-weight-bolder font-mono text-ink text-body2">
            {{ formatCurrency(props.row.balance_after, props.row.currency_code) }}
          </q-td>
        </template>

        <!-- Category Column Slot -->
        <template #body-cell-category="props">
          <q-td :props="props">
            <q-chip
              v-if="props.row.metadata?.section"
              dense
              unelevated
              class="text-weight-bold text-caption"
              :class="sectionChipClass(props.row.metadata.section)"
            >
              {{ sectionLabel(props.row.metadata.section) }}
            </q-chip>
            <span v-else class="text-caption text-grey-4">—</span>
          </q-td>
        </template>

        <!-- Source Column Slot -->
        <template #body-cell-source="props">
          <q-td :props="props">
            <div class="row items-center q-gutter-x-xs">
              <q-chip dense flat class="bg-primary-soft text-primary text-weight-bold text-caption">
                {{ sourceTypeLabel(props.row.source_type) }}
              </q-chip>
              <span v-if="props.row.source_id" class="text-caption text-weight-medium font-mono text-muted">
                #{{ props.row.source_id }}
              </span>
            </div>
          </q-td>
        </template>

        <!-- Created At Column Slot -->
        <template #body-cell-created_at="props">
          <q-td :props="props" class="text-muted text-caption">
            {{ formatDate(props.row.created_at) }}
          </q-td>
        </template>

        <!-- Metadata Column Slot -->
        <template #body-cell-metadata="props">
          <q-td :props="props">
            <span v-if="props.row.metadata?.approved_by" class="text-caption text-muted">
              Approved by: {{ props.row.metadata.approved_by }}
            </span>
            <span v-else-if="props.row.metadata?.trx_id" class="text-caption text-muted font-mono">
              Trx: {{ props.row.metadata.trx_id }}
            </span>
            <span v-else-if="props.row.metadata?.note" class="text-caption text-muted">
              {{ props.row.metadata.note }}
            </span>
            <span v-else class="text-caption text-grey-4">-</span>
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
    label: 'Transaction',
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
    label: 'Running Balance',
    field: 'balance_after',
    align: 'right',
    sortable: true,
  },
  {
    name: 'category',
    label: 'Category',
    field: (row) => row.metadata?.section ?? '',
    align: 'left',
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
    label: 'Details & Notes',
    field: 'metadata',
    align: 'left',
  },
];

const SECTION_LABELS: Record<string, string> = {
  receivable: 'Invoice Billed',
  payout_earned: 'Profit Earned',
  cod_holding: 'COD Collected',
  delivery_fee: 'Delivery Fee',
  revenue: 'Revenue',
  adjustment: 'Manual Adjustment',
  payment_received: 'Payment Received',
  intercompany: 'Intercompany',
};

const SECTION_CHIP_CLASSES: Record<string, string> = {
  receivable: 'chip-orange',
  payout_earned: 'chip-green',
  cod_holding: 'chip-blue',
  delivery_fee: 'chip-grey',
  revenue: 'chip-teal',
  adjustment: 'chip-purple',
  payment_received: 'chip-green',
  intercompany: 'chip-grey',
};

const SOURCE_TYPE_LABELS: Record<string, string> = {
  shop_order: 'Sales Order',
  vendor_purchase: 'Vendor Purchase',
  payout: 'Payout',
  adjustment: 'Adjustment',
};

const sectionLabel = (section: string) => SECTION_LABELS[section] ?? section;
const sectionChipClass = (section: string) => SECTION_CHIP_CLASSES[section] ?? 'chip-grey';
const sourceTypeLabel = (sourceType: string) => SOURCE_TYPE_LABELS[sourceType] ?? sourceType;

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
.soft-table-card {
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  border-radius: 16px;
  overflow: hidden;
}

.shadow-soft {
  box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.04);
}

.soft-wallet-table :deep(.q-table__card) {
  background: transparent;
}

.soft-wallet-table :deep(thead tr th) {
  font-weight: 700;
  color: #64748b;
  text-transform: uppercase;
  font-size: 0.75rem;
  letter-spacing: 0.05em;
  border-bottom: 1px solid #f1f5f9;
  background: #f8fafc;
  padding-top: 12px;
  padding-bottom: 12px;
}

.soft-wallet-table :deep(tbody tr td) {
  border-bottom: 1px solid #f1f5f9;
  padding-top: 10px;
  padding-bottom: 10px;
  transition: background 0.15s ease;
}

.soft-wallet-table :deep(tbody tr:hover td) {
  background: rgba(241, 245, 249, 0.6);
}

.soft-chip-credit {
  background: rgba(16, 185, 129, 0.12) !important;
  color: #059669 !important;
  border-radius: 8px;
}

.soft-chip-debit {
  background: rgba(244, 63, 94, 0.12) !important;
  color: #e11d48 !important;
  border-radius: 8px;
}

.bg-primary-soft {
  background: rgba(59, 130, 246, 0.08) !important;
}

.chip-orange  { background: rgba(249, 115, 22, 0.12) !important; color: #ea580c !important; border-radius: 8px; }
.chip-green   { background: rgba(16, 185, 129, 0.12) !important; color: #059669 !important; border-radius: 8px; }
.chip-blue    { background: rgba(37, 99, 235, 0.12)  !important; color: #2563eb !important; border-radius: 8px; }
.chip-grey    { background: rgba(100, 116, 139, 0.1) !important; color: #475569 !important; border-radius: 8px; }
.chip-teal    { background: rgba(13, 148, 136, 0.12) !important; color: #0d9488 !important; border-radius: 8px; }
.chip-purple  { background: rgba(139, 92, 246, 0.12) !important; color: #7c3aed !important; border-radius: 8px; }

.text-emerald {
  color: #059669;
}

.text-rose {
  color: #e11d48;
}

.text-ink {
  color: #0f172a;
}

.text-muted {
  color: #64748b;
}
</style>


<template>
  <q-page class="q-pa-md thrift-ledger-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="col-12 col-sm">
          <div class="text-h6 text-weight-bold">Thrift Accounting Ledger</div>
          <div class="text-caption text-grey-8">Audited view of revenues, shipping expenses, and stock write-off losses</div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Table -->
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="ledgerEntries"
        :columns="columns"
        row-key="id"
        :loading="loading"
        class="thrift-table"
      >
        <template #body-cell-type="props">
          <q-td :props="props">
            <q-chip dense square :style="ledgerTypeStyle(props.value)" class="thrift-status-chip">
              <span class="status-dot" :style="{ backgroundColor: ledgerTypeDot(props.value) }" />
              {{ props.value }}
            </q-chip>
          </q-td>
        </template>
        <template #body-cell-amount="props">
          <q-td :props="props" :class="props.row.type === 'REVENUE' ? 'text-positive' : 'text-negative'">
            <strong>{{ props.value }}</strong>
          </q-td>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftLedgerStore } from '../stores/thriftLedgerStore';
import type { QTableColumn } from 'quasar';

const authStore = useAuthStore();
const store = useThriftLedgerStore();

const ledgerEntries = computed(() => store.ledgerEntries);
const loading = computed(() => store.loading);

const columns: QTableColumn[] = [
  { name: 'date', align: 'left', label: 'Date', field: 'date', format: (val: any) => new Date(val).toLocaleString(), sortable: true },
  { name: 'type', align: 'center', label: 'Type', field: 'type', sortable: true },
  { name: 'source', align: 'left', label: 'Source', field: 'source' },
  { name: 'amount', align: 'right', label: 'Amount', field: 'amount', sortable: true },
  { name: 'inserted_by', align: 'left', label: 'Logged By', field: 'inserted_by' },
  { name: 'note', align: 'left', label: 'Note', field: 'note' },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await store.loadLedger(authStore.tenantId);
  }
});

const ledgerTypeStyle = (v: string) => {
  if (v === 'REVENUE') return { backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #6ee7b7' }
  if (v === 'EXPENSE') return { backgroundColor: '#fef3c7', color: '#92400e', border: '1px solid #fcd34d' }
  if (v === 'REFUND') return { backgroundColor: '#eff6ff', color: '#1e40af', border: '1px solid #93c5fd' }
  if (v === 'LOSS') return { backgroundColor: '#fee2e2', color: '#7f1d1d', border: '1px solid #fca5a5' }
  return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' }
}
const ledgerTypeDot = (v: string) => {
  if (v === 'REVENUE') return '#059669'
  if (v === 'EXPENSE') return '#d97706'
  if (v === 'REFUND') return '#3b82f6'
  if (v === 'LOSS') return '#dc2626'
  return '#9ca3af'
}
</script>

<style scoped>
.thrift-ledger-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.thrift-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>

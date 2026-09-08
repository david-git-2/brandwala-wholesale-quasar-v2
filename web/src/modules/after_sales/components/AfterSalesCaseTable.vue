<template>
  <q-card flat bordered class="treasury-table-wrap">
    <q-table
      flat
      :rows="rows"
      :columns="columns"
      row-key="id"
      :loading="loading"
      v-model:pagination="pagination"
      :rows-per-page-options="[10, 20, 50]"
      class="after-sales-case-table cursor-pointer"
      @row-click="(_evt, row) => emit('row-click', row)"
    >
      <template #body-cell-case_no="props">
        <q-td :props="props">
          <span class="text-primary text-weight-medium">{{ props.row.case_no }}</span>
        </q-td>
      </template>

      <template #body-cell-party_name="props">
        <q-td :props="props">
          <div>{{ partyLabel(props.row) }}</div>
          <div class="case-table-party-caption">{{ partyCaption(props.row) }}</div>
        </q-td>
      </template>

      <template #body-cell-policy_name="props">
        <q-td :props="props">
          <div>{{ policyName(props.row) }}</div>
          <div class="case-table-party-caption">{{ formatProgram(props.row.policy_snapshot.program) }}</div>
        </q-td>
      </template>

      <template #body-cell-reason_code="props">
        <q-td :props="props">
          <q-badge outline color="grey-7" :label="formatReason(props.row.reason_code)" />
        </q-td>
      </template>

      <template #body-cell-status="props">
        <q-td :props="props">
          <q-badge :color="statusColor(props.row.status)" :label="formatStatus(props.row.status)" />
        </q-td>
      </template>
    </q-table>
  </q-card>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { QTableColumn } from 'quasar';
import type { AfterSalesCase, AfterSalesCaseStatus } from '../types/afterSales.types';

export type AfterSalesCaseTableRow = AfterSalesCase & { age_days?: number };

defineProps<{
  rows: AfterSalesCaseTableRow[];
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'row-click', row: AfterSalesCaseTableRow): void;
}>();

const pagination = ref({ page: 1, rowsPerPage: 20 });

const columns: QTableColumn<AfterSalesCaseTableRow>[] = [
  { name: 'case_no', label: 'Case no', field: 'case_no', align: 'left', sortable: true },
  {
    name: 'operating_tenant_name',
    label: 'Tenant',
    field: 'operating_tenant_name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'party_name',
    label: 'Customer / merchant',
    field: 'customer_name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'policy_name',
    label: 'Return policy',
    field: (row) => row.policy_snapshot.policy_name,
    align: 'left',
    sortable: true,
  },
  { name: 'reason_code', label: 'Reason', field: 'reason_code', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
];

const partyLabel = (row: AfterSalesCaseTableRow) => row.customer_name || '—';

const partyCaption = (row: AfterSalesCaseTableRow) => {
  if (row.source_channel === 'wholesale') {
    return row.sales_invoice_no ? `Invoice ${row.sales_invoice_no}` : 'Wholesale';
  }
  if (row.reporter_name) {
    return `Recipient · ${row.reporter_name}`;
  }
  return row.shop_order_no ? `Order ${row.shop_order_no}` : 'Dropship';
};

const policyName = (row: AfterSalesCaseTableRow) =>
  row.policy_snapshot.policy_name || formatProgram(row.policy_snapshot.program);

const formatProgram = (program: AfterSalesCaseTableRow['program']) =>
  program.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

const formatReason = (reason: string) => reason.replace(/_/g, ' ');

const formatStatus = (status: AfterSalesCaseStatus) => status.replace(/_/g, ' ');

const statusColor = (status: AfterSalesCaseStatus) => {
  if (status === 'closed') return 'positive';
  if (status === 'rejected') return 'negative';
  if (status === 'pending_approval') return 'warning';
  if (status === 'executing') return 'primary';
  return 'grey-6';
};
</script>

<style scoped>
.case-table-party-caption {
  margin-top: 0.15rem;
  font-size: 0.72rem;
  color: var(--bw-theme-muted);
}
</style>

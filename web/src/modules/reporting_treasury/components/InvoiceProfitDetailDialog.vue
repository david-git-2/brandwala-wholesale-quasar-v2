<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 720px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6">{{ title }}</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" @click="$emit('update:modelValue', false)" />
      </q-card-section>
      <q-card-section>
        <q-table
          flat dense :rows="lines" :columns="columns" row-key="item_id"
          :loading="loading" hide-pagination :pagination="{ rowsPerPage: 0 }"
        />
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar';
import type { InvoiceProfitLine } from '../types/financeReportTypes';
import { formatAmountBdt } from 'src/utils/currency';

defineProps<{
  modelValue: boolean;
  title: string;
  lines: InvoiceProfitLine[];
  loading?: boolean;
}>();

defineEmits<{ 'update:modelValue': [boolean] }>();

const columns: QTableColumn<InvoiceProfitLine>[] = [
  { name: 'name', label: 'SKU', field: 'name', align: 'left' },
  { name: 'barcode', label: 'Barcode', field: 'barcode', align: 'left' },
  { name: 'net_qty', label: 'Net Qty', field: 'net_qty', align: 'right' },
  { name: 'net_revenue', label: 'Revenue', field: 'net_revenue', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'cogs', label: 'COGS', field: 'cogs', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'line_gp', label: 'GP', field: 'line_gp', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
];
</script>

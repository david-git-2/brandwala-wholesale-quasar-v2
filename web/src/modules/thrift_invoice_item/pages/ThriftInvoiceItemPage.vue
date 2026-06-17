<template>
  <q-page class="q-pa-md thrift-invoice-item-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="col-12 col-sm">
          <div class="text-h6 text-weight-bold">Thrift Invoice Sales Registry</div>
          <div class="text-caption text-grey-8">Breakdown of item prices, platform fees, shipping costs, and net profit per sale</div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Table -->
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="invoiceItems"
        :columns="columns"
        row-key="id"
        :loading="loading"
        class="thrift-table"
      >
        <template #body-cell-item_status="props">
          <q-td :props="props">
            <q-chip dense square :style="itemStatusStyle(props.value)" class="thrift-status-chip">
              <span class="status-dot" :style="{ backgroundColor: itemStatusDot(props.value) }" />
              {{ props.value }}
            </q-chip>
          </q-td>
        </template>
        <template #body-cell-net_profit="props">
          <q-td :props="props" :class="props.value >= 0 ? 'text-positive' : 'text-negative'">
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
import { useThriftInvoiceItemStore } from '../stores/thriftInvoiceItemStore';
import type { QTableColumn } from 'quasar';

const authStore = useAuthStore();
const store = useThriftInvoiceItemStore();

const invoiceItems = computed(() => store.invoiceItems);
const loading = computed(() => store.loading);

const columns: QTableColumn[] = [
  { name: 'invoice_number', align: 'left', label: 'Invoice No', field: (row: any) => row.thrift_invoices?.invoice_number, sortable: true },
  { name: 'sku', align: 'left', label: 'SKU', field: (row: any) => row.thrift_stocks?.sku, sortable: true },
  { name: 'name', align: 'left', label: 'Item Name', field: (row: any) => row.thrift_stocks?.name, sortable: true },
  { name: 'quantity', align: 'right', label: 'Qty', field: 'quantity', sortable: true },
  { name: 'sold_price', align: 'right', label: 'Sold Price', field: 'sold_price', format: (val: any) => `${val}`, sortable: true },
  { name: 'platform_fees', align: 'right', label: 'Platform Fees', field: 'platform_fees', format: (val: any) => `${val}`, sortable: true },
  { name: 'shipping_cost_paid_by_shop', align: 'right', label: 'Shop Shipping', field: 'shipping_cost_paid_by_shop', format: (val: any) => `${val}`, sortable: true },
  { name: 'net_profit', align: 'right', label: 'Net Profit', field: 'net_profit', sortable: true },
  { name: 'item_status', align: 'center', label: 'Status', field: 'item_status', sortable: true },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await store.loadInvoiceItems(authStore.tenantId);
  }
});

const itemStatusStyle = (v: string) => {
  if (v === 'SOLD') return { backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #6ee7b7' }
  if (v === 'RETURNED') return { backgroundColor: '#fef3c7', color: '#92400e', border: '1px solid #fcd34d' }
  return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' }
}
const itemStatusDot = (v: string) => {
  if (v === 'SOLD') return '#059669'
  if (v === 'RETURNED') return '#d97706'
  return '#9ca3af'
}
</script>

<style scoped>
.thrift-invoice-item-page {
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

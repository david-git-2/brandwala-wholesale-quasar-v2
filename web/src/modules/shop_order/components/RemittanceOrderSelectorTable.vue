<template>
  <q-card flat bordered class="remittance-table-card">
    <!-- Toolbar header inside table card -->
    <q-card-section class="q-pb-xs">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="row items-center gap-2">
          <div class="text-subtitle1 text-weight-bold">
            Delivered Orders ({{ orders.length }})
          </div>
          <q-badge color="primary" class="q-px-sm" outline>
            Selected: {{ selectedOrderIds.length }}
          </q-badge>
        </div>

        <div class="row items-center gap-2">
          <q-input
            v-model="searchFilter"
            dense
            outlined
            placeholder="Search Order #, Tracking, AWB..."
            class="search-input"
            clearable
          >
            <template #prepend>
              <q-icon name="search" size="18px" />
            </template>
          </q-input>

          <q-btn
            v-if="!readOnly"
            flat
            dense
            color="primary"
            icon="content_paste"
            label="Bulk Paste Tracking / AWB"
            class="q-px-sm"
            @click="$emit('openBulkPaste')"
          >
            <q-tooltip>Paste tracking or AWB numbers from Excel/CSV</q-tooltip>
          </q-btn>
        </div>
      </div>
    </q-card-section>

    <q-separator />

    <!-- Quasar Table -->
    <div class="treasury-table-wrap">
      <q-table
        v-model:selected="selectedRows"
        :rows="filteredOrders"
        :columns="columns"
        row-key="id"
        selection="multiple"
        dense
        flat
        :pagination="pagination"
        :loading="loading"
        no-data-label="No unremitted delivered orders found for this courier service"
        class="treasury-table"
      >
        <!-- Header Checkbox Customization -->
        <template #header-selection="scope">
          <q-checkbox
            :model-value="scope.selected"
            dense
            :disable="readOnly"
            @update:model-value="scope.selected = $event"
          />
        </template>

        <!-- Body Selection Checkbox -->
        <template #body-selection="scope">
          <q-checkbox
            :model-value="scope.selected"
            dense
            :disable="readOnly"
            @update:model-value="scope.selected = $event"
          />
        </template>

        <!-- Custom Order No Cell -->
        <template #body-cell-order_no="props">
          <q-td :props="props">
            <div class="text-weight-bold text-primary cursor-pointer" @click="openOrderDetail(props.row.id)">
              {{ props.row.order_no }}
            </div>
            <div v-if="props.row.recipient_name" class="text-caption text-grey-7">
              {{ props.row.recipient_name }}
            </div>
          </q-td>
        </template>

        <!-- Custom Tracking / AWB Cell -->
        <template #body-cell-tracking="props">
          <q-td :props="props">
            <div v-if="props.row.courier_awb_number" class="text-weight-medium">
              AWB: {{ props.row.courier_awb_number }}
            </div>
            <div v-if="props.row.tracking_url" class="text-caption">
              <a :href="props.row.tracking_url" target="_blank" class="text-primary hover-underline">
                Track Package ↗
              </a>
            </div>
            <span v-if="!props.row.courier_awb_number && !props.row.tracking_url" class="text-grey-5">—</span>
          </q-td>
        </template>

        <!-- COD Collected Amount -->
        <template #body-cell-cod_collect_amount="props">
          <q-td :props="props" class="text-right">
            <span class="text-weight-medium">৳ {{ formatAmount(getCodAmount(props.row)) }}</span>
          </q-td>
        </template>

        <!-- Courier Charge Amount -->
        <template #body-cell-courier_charge="props">
          <q-td :props="props" class="text-right">
            <span class="text-negative">৳ {{ formatAmount(getCourierCharge(props.row)) }}</span>
          </q-td>
        </template>

        <!-- Net Amount Cell -->
        <template #body-cell-net_amount="props">
          <q-td :props="props" class="text-right">
            <span class="text-weight-bold text-positive">
              ৳ {{ formatAmount(getNetAmount(props.row)) }}
            </span>
          </q-td>
        </template>
      </q-table>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import type { QTableColumn } from 'quasar';
import type { ShopOrder } from '../types';

const props = defineProps<{
  orders: ShopOrder[];
  selectedOrderIds: number[];
  loading?: boolean;
  readOnly?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:selectedOrderIds', ids: number[]): void;
  (e: 'openBulkPaste'): void;
}>();

const searchFilter = ref('');
const pagination = ref({
  rowsPerPage: 20,
  sortBy: 'id',
  descending: true,
});

const selectedRows = computed<ShopOrder[]>({
  get() {
    return props.orders.filter((o) => props.selectedOrderIds.includes(o.id));
  },
  set(rows: ShopOrder[]) {
    if (props.readOnly) return;
    const ids = rows.map((r) => r.id);
    emit('update:selectedOrderIds', ids);
  },
});

const filteredOrders = computed(() => {
  if (!searchFilter.value.trim()) return props.orders;
  const q = searchFilter.value.toLowerCase().trim();
  return props.orders.filter((o) => {
    return (
      o.order_no.toLowerCase().includes(q) ||
      (o.recipient_name && o.recipient_name.toLowerCase().includes(q)) ||
      (o.courier_awb_number && o.courier_awb_number.toLowerCase().includes(q)) ||
      (o.recipient_phone && o.recipient_phone.includes(q))
    );
  });
});

const columns: QTableColumn<ShopOrder>[] = [
  { name: 'order_no', label: 'Order # / Recipient', field: 'order_no', align: 'left', sortable: true },
  { name: 'tracking', label: 'AWB / Tracking', field: 'courier_awb_number', align: 'left' },
  { name: 'placed_at', label: 'Date Placed', field: (row) => row.placed_at ? row.placed_at.slice(0, 10) : '—', align: 'left', sortable: true },
  { name: 'cod_collect_amount', label: 'COD Collected', field: (row) => getCodAmount(row), align: 'right', sortable: true },
  { name: 'courier_charge', label: 'Courier Fee', field: (row) => getCourierCharge(row), align: 'right', sortable: true },
  { name: 'net_amount', label: 'Calculated Net', field: (row) => getNetAmount(row), align: 'right', sortable: true },
];

function getCodAmount(order: ShopOrder): number {
  return order.cod_collect_amount ?? order.total_amount ?? 0;
}

function getCourierCharge(order: ShopOrder): number {
  return (order.delivery_charge_amount ?? 0) + (order.cod_charge_amount ?? 0);
}

function getNetAmount(order: ShopOrder): number {
  return getCodAmount(order) - getCourierCharge(order);
}

function formatAmount(val: number): string {
  return val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function openOrderDetail(orderId: number) {
  window.open(`/app/shop/staff-orders/${orderId}`, '_blank');
}
</script>

<style scoped lang="scss">
.remittance-table-card {
  border-radius: 12px;
  background: var(--bw-theme-surface);
  border: 1px solid var(--bw-theme-border);
}

.search-input {
  width: 260px;
}

.hover-underline:hover {
  text-decoration: underline;
}
</style>

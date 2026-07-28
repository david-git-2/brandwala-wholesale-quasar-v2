<template>
  <q-card flat bordered class="bg-surface border-base rounded-borders">
    <!-- Toolbar Header -->
    <q-card-section class="q-pa-md border-bottom row items-center justify-between">
      <div class="row items-center q-gutter-x-md">
        <div class="text-subtitle1 text-weight-bold">Courier Unremitted Breakdown</div>
        <q-badge color="grey-3" text-color="dark" class="text-weight-bold">
          {{ summaryList.length }} Courier Partners
        </q-badge>
      </div>
      <q-btn
        color="primary"
        unelevated
        no-caps
        icon="post_add"
        label="Bulk Statement Matcher"
        style="border-radius: 8px"
        :to="getBulkStatementRoute()"
      />
    </q-card-section>

    <!-- Table Content -->
    <q-card-section class="q-pa-none">
      <q-table
        flat
        square
        :rows="summaryList"
        :columns="columns"
        row-key="courier_name"
        hide-pagination
        :pagination="{ rowsPerPage: 0 }"
        class="no-border"
      >
        <!-- Courier Name & Icon -->
        <template #body-cell-courier_name="props">
          <q-td :props="props">
            <div class="row items-center q-gutter-x-sm">
              <q-avatar size="28px" color="primary" text-color="white" class="text-caption text-weight-bold">
                {{ getCourierInitials(props.row.courier_name) }}
              </q-avatar>
              <span class="text-weight-bold text-dark">{{ props.row.courier_name }}</span>
            </div>
          </q-td>
        </template>

        <!-- Unremitted Count -->
        <template #body-cell-unremitted_order_count="props">
          <q-td :props="props">
            <q-badge color="blue-1" text-color="primary" class="text-weight-medium">
              {{ props.row.unremitted_order_count }} orders
            </q-badge>
          </q-td>
        </template>

        <!-- Gross COD Total -->
        <template #body-cell-gross_cod_total="props">
          <q-td :props="props" class="text-weight-bold text-primary">
            ৳{{ formatCurrency(props.row.gross_cod_total) }}
          </q-td>
        </template>

        <!-- Company Wholesale Total -->
        <template #body-cell-company_wholesale_total="props">
          <q-td :props="props" class="text-weight-medium text-positive">
            ৳{{ formatCurrency(props.row.company_wholesale_total) }}
          </q-td>
        </template>

        <!-- Middleman Margin Total -->
        <template #body-cell-middleman_margin_total="props">
          <q-td :props="props" class="text-weight-medium text-warning">
            ৳{{ formatCurrency(props.row.middleman_margin_total) }}
          </q-td>
        </template>

        <!-- Actions -->
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn
              outline
              color="primary"
              size="sm"
              no-caps
              label="Statement Entry"
              style="border-radius: 8px"
              :to="getBulkStatementRoute(props.row.courier_name)"
            />
          </q-td>
        </template>

        <!-- Empty state -->
        <template #no-data>
          <div class="full-width row flex-center q-pa-xl text-grey-6">
            <q-icon name="check_circle_outline" size="48px" class="q-mr-sm text-positive" />
            <span class="text-subtitle1">All courier payments are fully reconciled! No pending holdings.</span>
          </div>
        </template>
      </q-table>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router';
import type { QTableColumn } from 'quasar';
import type { CourierUnremittedFinancialSummary } from '../types';

defineProps<{
  summaryList: CourierUnremittedFinancialSummary[];
}>();

const route = useRoute();

const columns: QTableColumn[] = [
  { name: 'courier_name', label: 'Courier Partner', field: 'courier_name', align: 'left', sortable: true },
  { name: 'unremitted_order_count', label: 'Pending Orders', field: 'unremitted_order_count', align: 'center', sortable: true },
  { name: 'gross_cod_total', label: 'Gross COD Held', field: 'gross_cod_total', align: 'right', sortable: true },
  { name: 'company_wholesale_total', label: 'Wholesale Share', field: 'company_wholesale_total', align: 'right', sortable: true },
  { name: 'middleman_margin_total', label: 'Middleman Locked Margin', field: 'middleman_margin_total', align: 'right', sortable: true },
  { name: 'actions', label: 'Action', field: 'actions', align: 'right' },
];

function formatCurrency(val: number): string {
  return (val || 0).toLocaleString('en-BD', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function getCourierInitials(name: string): string {
  if (!name) return 'C';
  return name.slice(0, 2).toUpperCase();
}

function getBulkStatementRoute(courierName?: string) {
  const tenantSlug = route.params.tenantSlug ? String(route.params.tenantSlug) : '';
  const basePath = tenantSlug ? `/${tenantSlug}/app/shop/dropship/courier-remittances/new` : '/app/shop/dropship/courier-remittances/new';
  return courierName ? `${basePath}?courier=${encodeURIComponent(courierName)}` : basePath;
}
</script>

<style scoped>
.border-base {
  border: 1px solid var(--q-border-color, #e0e0e0);
}
.border-bottom {
  border-bottom: 1px solid var(--q-border-color, #e0e0e0);
}
.rounded-borders {
  border-radius: 8px;
}
</style>

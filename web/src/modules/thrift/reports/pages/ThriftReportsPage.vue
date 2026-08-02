<template>
  <q-page class="q-pa-md thrift-reports-page">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Shipment Reports</h1>
          <div class="text-body2 text-grey-7 q-mt-xs">
            Select a shipment to view sales revenue and profit.
          </div>
        </div>
      </section>

      <q-card flat bordered>
        <q-card-section class="q-pb-none">
          <q-input
            v-model="search"
            dense
            outlined
            clearable
            debounce="200"
            placeholder="Search shipments…"
            class="search-input"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </q-card-section>

        <q-table
          flat
          :rows="filteredRows"
          :columns="columns"
          row-key="id"
          v-model:pagination="tablePagination"
          :rows-per-page-options="[10, 20, 50]"
          :loading="isLoading"
          class="thrift-table cursor-pointer"
          @row-click="onRowClick"
        >
          <template #body-cell-sl="props">
            <q-td :props="props">
              {{ (tablePagination.page - 1) * tablePagination.rowsPerPage + props.rowIndex + 1 }}
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props">
              <router-link
                :to="reportPath(props.row.id)"
                class="text-weight-bold text-primary"
                style="text-decoration: none"
                @click.stop
              >
                {{ props.row.name }}
              </router-link>
            </q-td>
          </template>

          <template #body-cell-created_at="props">
            <q-td :props="props">
              {{ formatDate(props.row.created_at) }}
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn
                flat
                round
                dense
                color="primary"
                icon="ph ph-chart-bar"
                :to="reportPath(props.row.id)"
                @click.stop
              >
                <q-tooltip>View sales &amp; profit</q-tooltip>
              </q-btn>
            </q-td>
          </template>

          <template #no-data>
            <div class="full-width column flex-center q-pa-xl text-grey-6">
              <q-icon name="ph ph-chart-bar" size="48px" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-medium">No shipments yet</div>
              <div class="text-body2">Create a thrift shipment to run sales reports against it.</div>
            </div>
          </template>
        </q-table>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ThriftShipment } from '../../shipment/types';
import { useThriftReportShipmentsQuery } from '../composables/useThriftReportsQuery';

const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const search = ref('');
const tablePagination = ref({ page: 1, rowsPerPage: 20 });

const { data: shipments, isLoading } = useThriftReportShipmentsQuery(tenantId);

const columns: QTableColumn[] = [
  { name: 'sl', label: '#', field: 'id', align: 'left', style: 'width: 48px' },
  { name: 'name', label: 'Shipment', field: 'name', align: 'left', sortable: true },
  {
    name: 'created_at',
    label: 'Created',
    field: 'created_at',
    align: 'left',
    sortable: true,
  },
  { name: 'actions', label: '', field: 'id', align: 'right', style: 'width: 64px' },
];

const filteredRows = computed(() => {
  const q = search.value.trim().toLowerCase();
  const rows = shipments.value || [];
  if (!q) return rows;
  return rows.filter((row) => row.name?.toLowerCase().includes(q) || String(row.id).includes(q));
});

function reportPath(id: number) {
  return `/${tenantSlug.value || 'tenant'}/app/thrift/reports/${id}`;
}

function formatDate(value: string) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleString();
  } catch {
    return value;
  }
}

function onRowClick(_evt: Event, row: ThriftShipment) {
  void router.push(reportPath(row.id));
}
</script>

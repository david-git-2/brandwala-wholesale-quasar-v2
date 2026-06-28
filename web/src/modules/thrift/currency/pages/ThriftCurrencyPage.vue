<template>
  <q-page class="q-pa-md thrift-currency-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="text-h6 text-weight-bold">Thrift Currencies</div>
        <div class="text-caption text-grey-8">Global currency catalog (read-only)</div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="currencyStore.currencies"
        :columns="columns"
        row-key="id"
        v-model:pagination="tablePagination"
        :rows-per-page-options="[10, 20, 50]"
        :loading="currencyStore.loading"
        class="thrift-table"
      >
        <template #body-cell-sl="props">
          <q-td :props="props">
            {{ (tablePagination.page - 1) * tablePagination.rowsPerPage + props.rowIndex + 1 }}
          </q-td>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useThriftCurrencyStore } from '../stores/thriftCurrencyStore';
import type { QTableColumn } from 'quasar';

const currencyStore = useThriftCurrencyStore();

const tablePagination = ref({ page: 1, rowsPerPage: 20 });

const columns: QTableColumn[] = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'center', sortable: false, headerStyle: 'width: 50px' },
  { name: 'id', align: 'left', label: 'ID', field: 'id', sortable: true, headerStyle: 'width: 70px' },
  { name: 'code', align: 'left', label: 'Code', field: 'code', sortable: true, headerStyle: 'width: 80px' },
  { name: 'symbol', align: 'left', label: 'Symbol', field: 'symbol', sortable: true, headerStyle: 'width: 80px' },
  { name: 'name', align: 'left', label: 'Name', field: 'name', sortable: true },
  { name: 'country', align: 'left', label: 'Country', field: 'country', sortable: true },
];

onMounted(async () => {
  await currencyStore.loadCurrencies();
});
</script>

<style scoped>
.thrift-currency-page {
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
</style>

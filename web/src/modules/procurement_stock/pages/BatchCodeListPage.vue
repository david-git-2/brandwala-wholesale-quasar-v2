<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <section class="page-stack">
      <q-banner v-if="error" class="bw-status-banner bg-negative text-white q-mb-xs shrink-0">
        <div class="row items-center justify-between q-gutter-sm full-width">
          <div>{{ error }}</div>
          <q-btn flat dense no-caps color="white" label="Retry" @click="load" />
        </div>
      </q-banner>

      <q-card flat bordered class="q-pa-xs flex-shrink-0 list-toolbar-card">
        <div class="row items-center q-gutter-xs">
          <q-input
            v-model="searchText"
            outlined
            rounded
            dense
            debounce="300"
            clearable
            class="col-grow dense-search-input"
            placeholder="Search name, vendor, or shipment"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="16px" />
            </template>
          </q-input>
          <q-btn
            v-if="filteredRows.length"
            color="primary"
            unelevated
            no-caps
            dense
            icon="ph ph-plus"
            label="Add batch file"
            class="rounded-sq-btn"
            style="border-radius: 8px"
            @click="createDialogOpen = true"
          />
        </div>
      </q-card>

      <PageInitialLoader v-if="loading && !filteredRows.length" />

      <div v-else class="table-fixed-wrap">
        <q-card flat bordered class="q-pa-none overflow-hidden full-height table-card">
          <div
            v-if="!loading && filteredRows.length === 0"
            class="column items-center justify-center text-grey-7 q-pa-xl full-height"
          >
            <q-icon name="ph ph-barcode" size="48px" class="q-mb-sm text-grey-4" />
            <div class="text-subtitle1 text-weight-medium">No batch files yet</div>
            <div class="text-body2 q-mt-xs text-center" style="max-width: 360px">
              Add a batch file with a name, or open one from shipment gear → More → Batch Code.
            </div>
            <q-btn
              class="q-mt-md"
              color="primary"
              unelevated
              no-caps
              icon="ph ph-plus"
              label="Add batch file"
              style="border-radius: 8px"
              @click="createDialogOpen = true"
            />
          </div>

          <q-table
            v-else
            flat
            class="full-height-table"
            :rows="filteredRows"
            :columns="columns"
            row-key="id"
            :loading="loading"
            hide-pagination
            :pagination="{ rowsPerPage: 0 }"
            @row-click="(_, row) => openDetails(row.id)"
          >
            <template #body-cell-name="props">
              <q-td :props="props" class="cursor-pointer text-weight-medium text-grey-9">
                {{ props.row.name }}
              </q-td>
            </template>
            <template #body-cell-vendor="props">
              <q-td :props="props" class="cursor-pointer">
                {{ props.row.vendor?.name ?? '—' }}
              </q-td>
            </template>
            <template #body-cell-shipment="props">
              <q-td :props="props" class="cursor-pointer">
                <span v-if="props.row.shipment">
                  {{ props.row.shipment.name }}
                  <span v-if="props.row.shipment.tenant_shipment_id" class="text-grey-6">
                    (#{{ props.row.shipment.tenant_shipment_id }})
                  </span>
                </span>
                <span v-else class="text-grey-5">—</span>
              </q-td>
            </template>
            <template #body-cell-lines="props">
              <q-td :props="props" class="text-center font-mono cursor-pointer">
                {{ itemCountFor(props.row) }}
              </q-td>
            </template>
            <template #body-cell-updated="props">
              <q-td :props="props" class="text-grey-7 cursor-pointer">
                {{ formatDate(props.row.updated_at) }}
              </q-td>
            </template>
          </q-table>
        </q-card>
      </div>
    </section>

    <BatchCodeCreateDialog
      v-if="parentTenantId"
      v-model="createDialogOpen"
      :parent-tenant-id="parentTenantId"
      :shipment-ids-with-list="shipmentIdsWithList"
      @created="onBatchFileCreated"
    />
  </q-page>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar';
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import BatchCodeCreateDialog from '../components/BatchCodeCreateDialog.vue';
import { useBatchCodeListPage } from '../composables/useBatchCodeListPage';

const route = useRoute();
const router = useRouter();
const createDialogOpen = ref(false);

const {
  loading,
  error,
  searchText,
  filteredRows,
  load,
  itemCountFor,
  shipmentIdsWithList,
  parentTenantId,
} = useBatchCodeListPage();

const columns: QTableColumn[] = [
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'vendor', label: 'Vendor', field: 'vendor_id', align: 'left', sortable: true },
  { name: 'shipment', label: 'Shipment', field: 'shipment_id', align: 'left', sortable: true },
  { name: 'lines', label: 'Lines', field: 'id', align: 'center' },
  { name: 'updated', label: 'Updated', field: 'updated_at', align: 'left', sortable: true },
];

const formatDate = (value: string) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString();
};

const openDetails = (listId: number, fromCreate = false) => {
  const tenantSlug = route.params.tenantSlug;
  const query = fromCreate ? undefined : { from: 'list' };
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-batch-code-details',
      params: { tenantSlug, listId },
      query,
    });
    return;
  }
  void router.push({
    name: 'app-procurement-batch-code-details',
    params: { listId },
    query,
  });
};

const onBatchFileCreated = (listId: number) => {
  openDetails(listId, true);
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.page-stack {
  min-width: 0;
  flex: 1 1 0%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  height: 100%;
}

.table-fixed-wrap {
  flex: 1 1 0%;
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}

.table-card {
  min-width: 0;
  display: flex;
  flex-direction: column;
  height: 100%;
}

:deep(.full-height-table .q-table__card) {
  display: flex;
  flex-direction: column;
  height: 100%;
}

:deep(.full-height-table .q-table__container) {
  display: flex;
  flex-direction: column;
  height: 100%;
}

:deep(.full-height-table .q-table__middle) {
  flex: 1 1 0%;
  overflow-y: auto;
}

:deep(.full-height-table thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #f8fafc !important;
}
</style>

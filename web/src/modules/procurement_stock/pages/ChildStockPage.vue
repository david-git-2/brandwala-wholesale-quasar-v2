<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <div class="row items-center justify-between">
        <div>
          <div class="text-overline text-primary">Procurement & Stock</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Shop stock</h1>
          <div class="text-body2 text-grey-7 q-mt-xs">
            Stock this shop can sell from received shipments.
          </div>
        </div>
      </div>

      <q-card flat bordered>
        <q-card-section class="row items-center q-pb-none">
          <q-input
            v-model="search"
            dense
            outlined
            placeholder="Search assigned shipments..."
            class="col-12 col-sm-4"
            clearable
            @update:model-value="onSearch"
          >
            <template #append>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </q-card-section>

        <q-card-section>
          <q-table
            flat
            :rows="rows"
            :columns="columns"
            row-key="shipment_id"
            :loading="loading"
            no-data-label="No shipments assigned to this shop yet."
          >
            <template #body-cell-status="props">
              <q-td :props="props">
                <q-chip dense square color="green-1" text-color="green-9" label="Received" />
              </q-td>
            </template>
            <template #body-cell-atp_qty="props">
              <q-td :props="props" class="text-weight-bold text-primary">
                {{ props.row.atp_qty }} pcs
              </q-td>
            </template>
          </q-table>
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  childStockRepository,
  type ChildStockAtpRow,
} from '../repositories/childStockRepository';
import { showErrorNotification } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const loading = ref(false);
const search = ref('');
const rows = ref<ChildStockAtpRow[]>([]);

const columns = [
  { name: 'shipment_id', label: 'ID', field: 'shipment_id', align: 'left' as const },
  { name: 'shipment_name', label: 'Shipment Name', field: 'shipment_name', align: 'left' as const },
  { name: 'received_date', label: 'Received Date', field: 'received_date', align: 'left' as const },
  { name: 'status', label: 'Status', field: 'status', align: 'center' as const },
  { name: 'total_ordered_qty', label: 'Total Ordered', field: 'total_ordered_qty', align: 'right' as const },
  { name: 'atp_qty', label: 'Available to sell', field: 'atp_qty', align: 'right' as const },
];

const fetchChildStock = async () => {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const result = await childStockRepository.listChildStockAtp(
      authStore.tenantId,
      search.value || null,
      50,
      0,
    );
    rows.value = result.data;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to load shop stock');
  } finally {
    loading.value = false;
  }
};

const onSearch = () => {
  void fetchChildStock();
};

onMounted(() => {
  void fetchChildStock();
});
</script>

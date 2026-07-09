<template>
  <q-page class="q-pa-md thrift-stock-tag-print-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="text-h6 text-weight-bold">Marketing Tag Printing</div>
        <div class="text-caption text-grey-8">
          Select a shipment to configure and print marketing stickers for available stock.
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="printRows"
        :columns="columns"
        row-key="shipmentId"
        :loading="loading"
        :class="['thrift-table', { 'thrift-table--loading': loading }]"
        :pagination="{ rowsPerPage: 10 }"
      >
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right q-gutter-x-xs">
            <q-btn flat round dense icon="settings" color="grey-7" @click="openConfig(props.row)">
              <q-tooltip>Configure tag layout</q-tooltip>
            </q-btn>
            <q-btn
              unelevated
              color="primary"
              icon="print"
              label="Print Tags"
              class="pill-btn"
              size="sm"
              no-caps
              :disabled="props.row.stickerCount === 0"
              @click="goToPreview(props.row.shipmentId)"
            />
          </q-td>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { QTableColumn } from 'quasar';
import { thriftShipmentRepository } from '../../shipment/repositories/thriftShipmentRepository';
import { thriftStockRepository } from '../repositories/thriftStockRepository';
import ShipmentMarketingTagConfigDialog from '../../shipment/components/ShipmentMarketingTagConfigDialog.vue';
import type { ThriftShipment } from '../../shipment/types';
import type { PrintableTagCounts, ShipmentTagPrintRow } from '../types/marketingTag';

const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

const loading = ref(false);
const shipments = ref<ThriftShipment[]>([]);
const countsMap = ref<Map<number, PrintableTagCounts>>(new Map());

const columns: QTableColumn[] = [
  {
    name: 'shipmentName',
    label: 'Shipment Name',
    field: 'shipmentName',
    align: 'left',
    sortable: true,
  },
  {
    name: 'itemCount',
    label: 'Eligible Items',
    field: 'itemCount',
    align: 'right',
    sortable: true,
  },
  {
    name: 'stickerCount',
    label: 'Sticker Copies',
    field: 'stickerCount',
    align: 'right',
    sortable: true,
  },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
];

const printRows = computed<ShipmentTagPrintRow[]>(() => {
  return shipments.value.map((shipment) => {
    const counts = countsMap.value.get(shipment.id) ?? { itemCount: 0, stickerCount: 0 };
    return {
      shipmentId: shipment.id,
      shipmentName: shipment.name || `Shipment #${shipment.id}`,
      itemCount: counts.itemCount,
      stickerCount: counts.stickerCount,
    };
  });
});

function shipmentById(id: number): ThriftShipment | undefined {
  return shipments.value.find((s) => s.id === id);
}

async function loadData() {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const [shipmentList, counts] = await Promise.all([
      thriftShipmentRepository.fetchShipments(authStore.tenantId),
      thriftStockRepository.fetchPrintableTagCountsByShipment(authStore.tenantId),
    ]);
    shipments.value = shipmentList;
    countsMap.value = counts;
  } catch (err) {
    console.error('Failed to load tag print page data:', err);
  } finally {
    loading.value = false;
  }
}

function openConfig(row: ShipmentTagPrintRow) {
  const shipment = shipmentById(row.shipmentId);
  if (!shipment) return;
  $q.dialog({
    component: ShipmentMarketingTagConfigDialog,
    componentProps: {
      shipmentId: shipment.id,
      shipmentName: shipment.name,
      initialConfig: shipment.marketing_tag_config,
    },
  }).onOk((updated: ThriftShipment) => {
    const idx = shipments.value.findIndex((s) => s.id === updated.id);
    if (idx !== -1) {
      shipments.value[idx] = updated;
      shipments.value = [...shipments.value];
    }
  });
}

function goToPreview(shipmentId: number) {
  void router.push({
    name: 'thrift-stock-tag-print-preview',
    params: { shipmentId },
  });
}

onMounted(() => {
  void loadData();
});
</script>

<style scoped>
.hero-surface {
  border-radius: 16px;
}
.pill-btn {
  border-radius: 999px;
}

.thrift-table--loading {
  opacity: 0.6;
  pointer-events: none;
}
</style>

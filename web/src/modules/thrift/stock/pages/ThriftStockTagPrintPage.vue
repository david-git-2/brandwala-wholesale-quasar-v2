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
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useQuery } from '@tanstack/vue-query';
import type { QTableColumn } from 'quasar';
import { useThriftShipmentsQuery } from '../../shipment/composables/useThriftShipmentQuery';
import { thriftStockRepository } from '../repositories/thriftStockRepository';
import ShipmentMarketingTagConfigDialog from '../../shipment/components/ShipmentMarketingTagConfigDialog.vue';
import type { ThriftShipment } from '../../shipment/types';
import type { ShipmentTagPrintRow } from '../types/marketingTag';

const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

const tenantIdRef = computed(() => authStore.tenantId ?? 0);
const { data: shipmentsData, isLoading: shipmentsLoading } = useThriftShipmentsQuery(tenantIdRef);
const shipments = computed(() => shipmentsData.value ?? []);

const { data: countsMapData, isLoading: countsLoading } = useQuery({
  queryKey: computed(() => ['thrift', 'printable-tag-counts', { tenantId: tenantIdRef.value }]),
  queryFn: () => thriftStockRepository.fetchPrintableTagCountsByShipment(tenantIdRef.value),
  enabled: computed(() => !!tenantIdRef.value),
  staleTime: 2 * 60 * 1000,
});
const countsMap = computed(() => countsMapData.value ?? new Map());

const loading = computed(() => shipmentsLoading.value || countsLoading.value);

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
  });
}

function goToPreview(shipmentId: number) {
  void router.push({
    name: 'thrift-stock-tag-print-preview',
    params: { shipmentId },
  });
}
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

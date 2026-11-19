<template>
  <q-card flat bordered class="q-pa-md report-section">
    <div class="row items-center no-wrap q-gutter-sm">
      <div class="col">
        <div class="row items-center no-wrap q-gutter-x-sm q-mb-xs">
          <span class="text-subtitle2 text-weight-bold ellipsis">{{ header.shipment_name || 'Shipment' }}</span>
          <TfStatusBadge v-if="header.shipment_status" :status="header.shipment_status" />
        </div>
        <div class="text-caption shipment-header-meta row q-gutter-x-md wrap">
          <span v-if="header.shipment_no" class="font-mono">{{ header.shipment_no }}</span>
          <span v-if="header.shipment_type">{{ formatType(header.shipment_type) }}</span>
          <span v-if="header.vendor_name">{{ header.vendor_name }}</span>
          <span v-if="header.received_date">Received {{ header.received_date }}</span>
        </div>
      </div>
      <TfBtn
        v-if="procurementRoute"
        flat
        dense
        no-caps
        size="sm"
        icon="ph ph-package"
        label="Open shipment"
        :to="procurementRoute"
      />
    </div>
  </q-card>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import type { ShipmentReportDetailHeader } from '../../types/shipmentReportDetailTypes';

defineProps<{
  header: ShipmentReportDetailHeader;
  procurementRoute?: string | null;
}>();

function formatType(type: string) {
  const t = type.trim().toLowerCase();
  if (t === 'international') return 'International';
  if (t === 'local') return 'Local';
  if (t === 'transfer') return 'Transfer';
  return type;
}
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}

.shipment-header-meta {
  color: var(--tf-neutral-chrome-text);
}
</style>
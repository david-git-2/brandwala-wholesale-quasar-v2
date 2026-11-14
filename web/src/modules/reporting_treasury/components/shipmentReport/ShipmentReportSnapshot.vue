<template>
  <ShipmentReportSectionShell title="Shipment">
    <div class="row items-center no-wrap q-gutter-x-sm q-mb-xs">
      <span class="text-body2 text-weight-bold">{{ header.shipment_name || 'Shipment' }}</span>
      <TfStatusBadge v-if="header.shipment_status" :status="header.shipment_status" />
    </div>
    <div class="text-caption shipment-snapshot-meta row q-gutter-x-md wrap">
      <span v-if="header.shipment_no" class="font-mono">{{ header.shipment_no }}</span>
      <span v-if="header.shipment_type">{{ formatType(header.shipment_type) }}</span>
      <span v-if="header.vendor_name">{{ header.vendor_name }}</span>
      <span v-if="header.received_date">Received {{ header.received_date }}</span>
    </div>
  </ShipmentReportSectionShell>
</template>

<script setup lang="ts">
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import type { ShipmentReportDetailHeader } from '../../types/shipmentReportDetailTypes';
import ShipmentReportSectionShell from './ShipmentReportSectionShell.vue';

defineProps<{
  header: ShipmentReportDetailHeader;
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
.shipment-snapshot-meta {
  color: var(--tf-neutral-chrome-text);
}
</style>
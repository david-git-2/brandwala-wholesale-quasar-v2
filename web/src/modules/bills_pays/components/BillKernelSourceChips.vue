<template>
  <div v-if="show" class="row items-center q-gutter-xs wrap">
    <span class="text-caption text-grey-7 text-uppercase text-weight-bold" style="letter-spacing: 0.04em">
      Source
    </span>
    <q-chip
      v-for="(chip, idx) in displayChips"
      :key="idx"
      dense
      outline
      class="bill-kernel-source-chip"
    >
      <span class="text-weight-medium">{{ chip }}</span>
    </q-chip>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useBillSourceShipmentName } from '../composables/useBillSourceShipmentName';
import {
  formatBillKernelSourceEntityFallback,
  formatBillKernelSourceKey,
  formatBillKernelSourceType,
} from '../utils/formatBillKernelSource';

const props = defineProps<{
  sourceType?: string | null;
  sourceId?: string | null;
  sourceKey?: string | null;
  apKind?: string | null;
  /** Resolved inbound shipment id (preferred over parsing `source_id`). */
  shipmentId?: number | null;
}>();

const show = computed(
  () => Boolean(props.sourceType?.trim() || props.sourceId?.trim() || props.sourceKey?.trim()),
);

const shipmentId = computed(() => {
  if (props.sourceType !== 'shipment_cost') return null;
  if (props.shipmentId != null && Number(props.shipmentId) > 0) return Number(props.shipmentId);
  const id = Number(props.sourceId);
  return Number.isFinite(id) && id > 0 ? id : null;
});

const { shipmentName } = useBillSourceShipmentName(shipmentId);

const displayChips = computed(() => {
  const chips: string[] = [];
  const typeLabel = formatBillKernelSourceType(props.sourceType);
  if (typeLabel) chips.push(typeLabel);

  if (props.sourceType === 'shipment_cost') {
    const name = shipmentName.value?.trim();
    if (name) chips.push(name);
    const bucket = formatBillKernelSourceKey(props.sourceType, props.sourceKey, props.apKind);
    if (bucket) chips.push(bucket);
    return chips;
  }

  const entity = formatBillKernelSourceEntityFallback(props.sourceType, props.sourceId);
  if (entity) chips.push(entity);

  const keyLabel = formatBillKernelSourceKey(props.sourceType, props.sourceKey, props.apKind);
  if (keyLabel) chips.push(keyLabel);

  return chips;
});
</script>

<style scoped>
.bill-kernel-source-chip {
  font-size: 11px;
  font-weight: 600;
  border-radius: 6px;
  background: var(--tf-neutral-surface, #fff) !important;
  color: var(--tf-neutral-ink, #171412) !important;
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
}

body.body--dark .bill-kernel-source-chip {
  background: var(--tf-neutral-surface, #1c1917) !important;
  color: var(--tf-neutral-ink, #f5f5f4) !important;
  border-color: var(--tf-neutral-border, #2a2622);
}
</style>

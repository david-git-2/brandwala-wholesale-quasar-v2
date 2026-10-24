<template>
  <div v-if="show" class="row items-center q-gutter-xs wrap">
    <span class="text-caption text-grey-7 text-uppercase text-weight-bold" style="letter-spacing: 0.04em">
      Source
    </span>
    <q-chip v-if="sourceType" dense outline class="bill-kernel-source-chip">
      <span class="text-weight-medium">{{ sourceTypeLabel }}</span>
    </q-chip>
    <q-chip v-if="sourceId" dense outline class="bill-kernel-source-chip">
      ID {{ sourceId }}
    </q-chip>
    <q-chip v-if="sourceKey" dense outline class="bill-kernel-source-chip">
      {{ sourceKeyLabel }}
    </q-chip>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { shipmentApKindLabel } from 'src/modules/procurement_stock/constants/shipmentApBuckets';

const props = defineProps<{
  sourceType?: string | null;
  sourceId?: string | null;
  sourceKey?: string | null;
}>();

const show = computed(
  () => Boolean(props.sourceType?.trim() || props.sourceId?.trim() || props.sourceKey?.trim()),
);

const sourceTypeLabel = computed(() => {
  const t = props.sourceType?.trim();
  if (t === 'shipment_cost') return 'Shipment cost';
  if (t === 'shop_order') return 'Shop order';
  if (t === 'compose') return 'Compose';
  return t ?? '—';
});

const sourceKeyLabel = computed(() => {
  const key = props.sourceKey?.trim();
  if (!key) return '';
  if (props.sourceType === 'shipment_cost') return shipmentApKindLabel(key);
  return key;
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

<template>
  <div v-if="show" class="row items-center q-gutter-xs wrap">
    <span class="text-caption text-grey-7 text-uppercase text-weight-bold" style="letter-spacing: 0.04em">
      Source
    </span>
    <q-chip v-if="sourceType" dense outline color="grey-3" text-color="grey-9" class="bill-kernel-source-chip">
      <span class="text-weight-medium">{{ sourceTypeLabel }}</span>
    </q-chip>
    <q-chip v-if="sourceId" dense outline color="grey-3" text-color="grey-9" class="bill-kernel-source-chip">
      ID {{ sourceId }}
    </q-chip>
    <q-chip v-if="sourceKey" dense outline color="grey-3" text-color="grey-9" class="bill-kernel-source-chip">
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
}
</style>

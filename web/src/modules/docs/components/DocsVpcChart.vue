<template>
  <TfValuePropositionCanvas v-bind="canvas" :show-header="showHeader" />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfValuePropositionCanvas from 'src/components/ui/TfValuePropositionCanvas.vue';
import type { PlatformVpcData } from '../utils/parsePlatformVpcMd';
import { mapPlatformVpcToCanvas } from '../utils/mapPlatformVpcToCanvas';

const props = withDefaults(
  defineProps<PlatformVpcData & { showHeader?: boolean }>(),
  { showHeader: true },
);

const canvas = computed(() =>
  mapPlatformVpcToCanvas({
    labels: props.labels,
    jobs: props.jobs,
    pains: props.pains,
    gains: props.gains,
    products: props.products,
    painRelievers: props.painRelievers,
    gainCreators: props.gainCreators,
    fit: props.fit,
  }),
);
</script>

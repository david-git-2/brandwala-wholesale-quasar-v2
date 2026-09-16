<template>
  <div class="dashboard-sparkline">
    <div v-if="!values || values.length < 2" class="dashboard-sparkline__placeholder" />
    <div v-else class="dashboard-sparkline__canvas">
      <VueApexCharts
        type="area"
        height="42"
        width="100%"
        :options="chartOptions"
        :series="series"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import VueApexCharts from 'vue3-apexcharts';
import { createSparklineOptions } from '../utils/apexChartTheme';

const props = withDefaults(
  defineProps<{
    values: number[];
    color?: string;
    gradientColor?: string;
  }>(),
  {
    color: '#0d6b5c',
    gradientColor: undefined,
  },
);

const series = computed(() => [
  {
    name: 'Value',
    data: props.values,
  },
]);

const chartOptions = computed(() =>
  createSparklineOptions(props.color, props.gradientColor),
);
</script>

<style scoped>
.dashboard-sparkline {
  width: 100%;
  height: 42px;
  position: relative;
  overflow: hidden;
  margin-top: 0.25rem;
}

.dashboard-sparkline__canvas {
  width: 100%;
  height: 100%;
}

.dashboard-sparkline__canvas :deep(.apexcharts-canvas) {
  width: 100% !important;
}

.dashboard-sparkline__placeholder {
  width: 100%;
  height: 100%;
  border-bottom: 1px dashed var(--bw-theme-border, #e7e1d8);
  opacity: 0.3;
}
</style>

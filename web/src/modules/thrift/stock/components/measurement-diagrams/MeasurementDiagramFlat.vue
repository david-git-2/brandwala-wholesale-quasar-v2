<template>
  <svg
    class="measurement-diagram-flat"
    viewBox="0 0 200 280"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-label="Garment measurement diagram"
  >
    <!-- Garment outline -->
    <path
      :d="outlinePath"
      class="garment-outline"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
    />

    <!-- Measurement guides -->
    <g class="measure-lines">
      <line
        x1="52" y1="72" x2="148" y2="72"
        :class="lineClass('bust_in')"
      />
      <line
        x1="58" y1="108" x2="142" y2="108"
        :class="lineClass('waist_in')"
      />
      <line
        x1="50" y1="148" x2="150" y2="148"
        :class="lineClass('hips_in')"
      />
      <line
        x1="100" y1="48" x2="100" :y2="hemY"
        :class="lineClass('length_in')"
      />
      <line
        x1="48" y1="56" x2="152" y2="56"
        :class="lineClass('shoulder_width_in')"
      />
      <line
        x1="48" y1="56" x2="38" :y2="sleeveEndY"
        :class="lineClass('sleeve_length_in')"
      />
      <ellipse
        cx="38" :cy="sleeveEndY - 4"
        rx="10" ry="6"
        :class="lineClass('arm_circumference_in')"
        fill="none"
        stroke-width="2"
      />
      <line
        x1="55" :y1="hemY" x2="145" :y2="hemY"
        :class="lineClass('hem_width_in')"
      />
      <line
        x1="78" y1="48" x2="122" y2="48"
        :class="lineClass('neck_opening_in')"
      />
    </g>

    <!-- Labels for active highlight only -->
    <text
      v-if="highlight"
      x="100"
      y="16"
      text-anchor="middle"
      class="diagram-label"
    >
      {{ highlightLabel }}
    </text>
  </svg>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { MeasurementHighlight } from '../../../shared/constants/thriftMeasurementGuide';

const props = withDefaults(
  defineProps<{
    highlight?: MeasurementHighlight | '';
    variant?: 'dress' | 'top';
  }>(),
  {
    highlight: '',
    variant: 'dress',
  },
);

const hemY = computed(() => (props.variant === 'dress' ? 230 : 175));
const sleeveEndY = computed(() => (props.variant === 'dress' ? 118 : 108));

const outlinePath = computed(() => {
  const hem = hemY.value;
  // Simple flat-lay dress/top silhouette
  return [
    'M 100 42',
    'L 78 48 L 48 56 L 38 70 L 32 95',
    `L 38 ${sleeveEndY.value} L 48 ${sleeveEndY.value + 8}`,
    `L 55 ${hem - 20} L 52 ${hem}`,
    `L 148 ${hem}`,
    `L 145 ${hem - 20} L 152 ${sleeveEndY.value + 8}`,
    `L 162 ${sleeveEndY.value} L 168 95 L 162 70`,
    'L 152 56 L 122 48 Z',
  ].join(' ');
});

const HIGHLIGHT_LABELS: Record<MeasurementHighlight, string> = {
  bust_in: 'Bust — pit to pit',
  waist_in: 'Waist — narrowest width',
  hips_in: 'Hips — fullest width',
  length_in: 'Length — shoulder to hem',
  shoulder_width_in: 'Shoulder — seam to seam',
  sleeve_length_in: 'Sleeve — shoulder to cuff',
  arm_circumference_in: 'Arm — around opening',
  hem_width_in: 'Hem — side to side',
  neck_opening_in: 'Neck — across opening',
};

const highlightLabel = computed(() => {
  if (!props.highlight) return '';
  return HIGHLIGHT_LABELS[props.highlight as MeasurementHighlight] || '';
});

function lineClass(key: MeasurementHighlight): string {
  const active = props.highlight === key;
  return active ? 'measure-line measure-line--active' : 'measure-line measure-line--muted';
}
</script>

<style scoped>
.measurement-diagram-flat {
  width: 100%;
  max-width: 200px;
  height: auto;
  color: var(--q-primary);
  display: block;
  margin: 0 auto;
}

.garment-outline {
  color: rgba(0, 0, 0, 0.35);
}

.measure-line {
  stroke-width: 2;
  stroke-dasharray: 4 3;
}

.measure-line--active {
  stroke: var(--q-primary);
  stroke-width: 2.5;
  opacity: 1;
}

.measure-line--muted {
  stroke: rgba(0, 0, 0, 0.15);
  opacity: 0.5;
}

.diagram-label {
  font-size: 11px;
  fill: var(--q-primary);
  font-weight: 600;
}
</style>

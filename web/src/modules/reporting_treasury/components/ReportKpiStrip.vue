<template>
  <div class="row items-baseline q-gutter-x-xs">
    <span class="text-caption text-grey-7 text-uppercase font-bold" style="font-size: 11px">{{ label }}:</span>
    <span
      class="text-subtitle2 text-weight-bolder bw-tabular"
      :class="highlight ? 'text-negative' : 'text-primary'"
    >
      {{ displayValue }}
    </span>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';

const props = defineProps<{
  label: string;
  value?: number | null;
  highlight?: boolean;
  number?: boolean;
}>();

const displayValue = computed(() =>
  props.number ? String(props.value ?? 0) : formatAmountBdt(Number(props.value || 0)),
);
</script>

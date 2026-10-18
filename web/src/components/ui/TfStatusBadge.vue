<template>
  <span class="tf-status-badge" :class="uniqueClass || `tf-status-badge--${group}`">
    <i :class="icon" aria-hidden="true" />
    <span :class="{ 'tf-status-badge__strike': group === 'bad' && strike }">{{ label }}</span>
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import { normalizeStatus, statusGroup, statusIcon } from 'src/utils/statusMap';

const props = defineProps<{
  /** Raw status string from any module (see utils/statusMap.ts). */
  status: string | null | undefined;
  label: string;
  strike?: boolean;
  /** Own hue per status (product-based costing) instead of the shared group hue. */
  unique?: 'pbc';
}>();

const group = computed(() => statusGroup(props.status));
const uniqueClass = computed(() =>
  props.unique ? `tf-status-badge--${props.unique}-${normalizeStatus(props.status)}` : '',
);
const icon = computed(() => statusIcon(props.status));
</script>

<style scoped>
.tf-status-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 1px 6px;
  line-height: 18px;
  font-size: 12px;
  font-weight: 600;
  white-space: nowrap;
  border-radius: var(--tf-radius-sm);
  color: var(--tf-status-ink);
  background: var(--tf-status-soft);
}
.tf-status-badge i {
  font-size: 14px;
  color: var(--tf-status-color);
}
.tf-status-badge__strike {
  text-decoration: line-through;
}
.tf-status-badge--wait { --tf-status-color: var(--tf-status-wait); --tf-status-soft: var(--tf-status-wait-soft); --tf-status-ink: var(--tf-neutral-muted); }
.tf-status-badge--attention { --tf-status-color: var(--tf-status-attention); --tf-status-soft: var(--tf-status-attention-soft); --tf-status-ink: var(--tf-neutral-ink); }
.tf-status-badge--progress { --tf-status-color: var(--tf-status-progress); --tf-status-soft: var(--tf-status-progress-soft); --tf-status-ink: var(--tf-neutral-ink); }
.tf-status-badge--done { --tf-status-color: var(--tf-status-done); --tf-status-soft: var(--tf-status-done-soft); --tf-status-ink: var(--tf-neutral-ink); }
.tf-status-badge--bad { --tf-status-color: var(--tf-status-bad); --tf-status-soft: var(--tf-status-bad-soft); --tf-status-ink: var(--tf-neutral-ink); }
.tf-status-badge--pbc-pending { --tf-status-color: var(--tf-pbc-pending); }
.tf-status-badge--pbc-offered { --tf-status-color: var(--tf-pbc-offered); }
.tf-status-badge--pbc-confirmed { --tf-status-color: var(--tf-pbc-confirmed); }
.tf-status-badge--pbc-procuring { --tf-status-color: var(--tf-pbc-procuring); }
.tf-status-badge--pbc-packed { --tf-status-color: var(--tf-pbc-packed); }
.tf-status-badge--pbc-delivered { --tf-status-color: var(--tf-pbc-delivered); }
.tf-status-badge--pbc-cancelled { --tf-status-color: var(--tf-pbc-cancelled); }
[class*='tf-status-badge--pbc-'] {
  --tf-status-soft: color-mix(in srgb, var(--tf-status-color) 14%, var(--tf-neutral-surface));
  --tf-status-ink: var(--tf-neutral-ink);
}
</style>

<template>
  <div class="row items-center justify-between q-px-md q-py-xs shrink-0 today-plan-header">
    <div class="row items-center q-gutter-sm">
      <div>
        <div class="text-body2 text-weight-bold">Today&apos;s plan</div>
        <div class="text-caption text-grey-7">Shift board — orders, delivery, inbound</div>
      </div>
      <span
        v-if="statusLabel"
        class="today-plan-header__pill"
        :class="statusPillClass"
      >
        {{ statusLabel }}
      </span>
    </div>
    <div class="row items-center q-gutter-sm">
      <span v-if="lastRefreshedLabel" class="text-caption text-grey-7">{{ lastRefreshedLabel }}</span>
      <q-btn
        flat
        dense
        no-caps
        :ripple="false"
        :loading="loading"
        icon="ph ph-arrow-clockwise"
        label="Refresh"
        @click="$emit('refresh')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  loading?: boolean;
  lastRefreshedAt?: string | null;
  statusLabel?: string;
}>();

defineEmits<{
  refresh: [];
}>();

const lastRefreshedLabel = computed(() => {
  if (!props.lastRefreshedAt) return '';
  const d = new Date(props.lastRefreshedAt);
  if (Number.isNaN(d.getTime())) return '';
  return `Updated ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
});

const statusPillClass = computed(() => {
  if (props.statusLabel === 'Clear') return 'today-plan-header__pill--clear';
  if (props.statusLabel === 'Updating') return 'today-plan-header__pill--neutral';
  return 'today-plan-header__pill--attention';
});
</script>

<style scoped>
.today-plan-header {
  border-bottom: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-surface);
}

.today-plan-header__pill {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
  padding: 2px 8px;
  border-radius: var(--tf-radius-sm, 8px);
  border: 1px solid var(--tf-neutral-border);
}

.today-plan-header__pill--attention {
  background: var(--tf-warning-soft);
  border-color: color-mix(in srgb, var(--tf-warning) 35%, var(--tf-neutral-border));
  color: var(--tf-neutral-ink);
}

.today-plan-header__pill--clear {
  background: var(--tf-success-soft, var(--tf-status-progress-soft));
  color: var(--tf-neutral-ink);
}

.today-plan-header__pill--neutral {
  background: var(--tf-neutral-surface);
  color: var(--tf-neutral-muted);
}
</style>
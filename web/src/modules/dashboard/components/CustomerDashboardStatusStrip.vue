<template>
  <q-card v-if="loading || glance.total > 0" flat bordered class="glance-card q-pa-md">
    <div class="text-caption text-grey-6 text-weight-bold text-uppercase q-mb-sm">
      {{ $t('customer_dashboard.glance_title') }}
    </div>

    <div v-if="loading" class="q-gutter-y-sm">
      <div class="row q-col-gutter-sm">
        <div v-for="n in 3" :key="n" class="col-4">
          <q-skeleton type="text" width="70%" height="14px" class="q-mb-xs" />
          <q-skeleton type="text" width="40%" height="24px" />
        </div>
      </div>
      <q-skeleton type="rect" height="8px" class="rounded-borders" />
    </div>

    <template v-else>
      <div class="row q-col-gutter-sm">
        <button
          type="button"
          class="col-4 glance-cell"
          :class="{ 'glance-cell--hot': glance.needs_you > 0 }"
          data-test="glance-needs-you"
          @click="$emit('select-bucket', 'needs_you')"
        >
          <div class="text-caption text-grey-6">{{ $t('customer_dashboard.glance_needs_you') }}</div>
          <div class="text-h6 text-weight-bold">{{ glance.needs_you }}</div>
        </button>
        <button
          type="button"
          class="col-4 glance-cell"
          data-test="glance-in-progress"
          @click="$emit('select-bucket', 'in_progress')"
        >
          <div class="text-caption text-grey-6">{{ $t('customer_dashboard.glance_in_progress') }}</div>
          <div class="text-h6 text-weight-bold">{{ glance.in_progress }}</div>
        </button>
        <button
          type="button"
          class="col-4 glance-cell"
          data-test="glance-done"
          @click="$emit('select-bucket', 'done')"
        >
          <div class="text-caption text-grey-6">{{ $t('customer_dashboard.glance_done') }}</div>
          <div class="text-h6 text-weight-bold">{{ glance.done }}</div>
        </button>
      </div>

      <div class="glance-bar q-mt-md" aria-hidden="true">
        <span
          v-if="glance.needs_you > 0"
          class="glance-bar__seg glance-bar__seg--wait"
          :style="{ flexGrow: glance.needs_you }"
        />
        <span
          v-if="glance.in_progress > 0"
          class="glance-bar__seg glance-bar__seg--progress"
          :style="{ flexGrow: glance.in_progress }"
        />
        <span
          v-if="glance.done > 0"
          class="glance-bar__seg glance-bar__seg--done"
          :style="{ flexGrow: glance.done }"
        />
      </div>
    </template>
  </q-card>
</template>

<script setup lang="ts">
import type { OrderGlanceBucket } from '../utils/customerDashboardStatus';

defineProps<{
  glance: {
    needs_you: number;
    in_progress: number;
    done: number;
    total: number;
  };
  loading: boolean;
}>();

defineEmits<{
  (e: 'select-bucket', bucket: OrderGlanceBucket): void;
}>();
</script>

<style scoped>
.glance-card {
  border-radius: 14px;
  background: var(--bw-theme-surface);
}

.glance-cell {
  width: 100%;
  margin: 0;
  padding: 8px 4px;
  border: 0;
  background: transparent;
  text-align: left;
  cursor: pointer;
  border-radius: 8px;
  color: inherit;
}

.glance-cell:hover,
.glance-cell:focus-visible {
  background: var(--bw-theme-primary-soft);
  outline: none;
}

.glance-cell--hot .text-h6 {
  color: var(--q-warning);
}

.glance-bar {
  display: flex;
  height: 8px;
  border-radius: 999px;
  overflow: hidden;
  background: var(--bw-theme-border);
}

.glance-bar__seg {
  min-width: 0;
}

.glance-bar__seg--wait {
  background: var(--q-warning);
}

.glance-bar__seg--progress {
  background: var(--q-primary);
}

.glance-bar__seg--done {
  background: var(--q-positive);
}
</style>

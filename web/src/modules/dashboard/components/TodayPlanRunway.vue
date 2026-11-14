<template>
  <q-card flat bordered class="today-plan-card">
    <q-card-section class="q-pa-sm q-pb-xs">
      <div class="text-overline text-grey-7">{{ title }}</div>
      <div v-if="caption" class="text-caption text-grey-7">{{ caption }}</div>
    </q-card-section>
    <q-card-section v-if="loading" class="q-pa-sm q-pt-none">
      <div class="row q-col-gutter-xs">
        <div v-for="n in 3" :key="n" class="col">
          <q-skeleton type="rect" height="72px" />
        </div>
      </div>
    </q-card-section>
    <div v-else class="today-plan-runway q-pa-sm q-pt-none">
      <router-link
        v-for="step in steps"
        :key="step.id"
        :to="step.to"
        class="today-plan-runway__cell"
        :class="step.count > 0 ? 'today-plan-runway__cell--active' : 'today-plan-runway__cell--idle'"
      >
        <span class="today-plan-runway__count tf-num">{{ step.count }}</span>
        <span class="today-plan-runway__title">{{ step.title }}</span>
        <span class="today-plan-runway__caption">{{ step.caption }}</span>
      </router-link>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import type { TodayPlanStep } from '../composables/useTodayPlan';

defineProps<{
  title: string;
  caption?: string;
  steps: TodayPlanStep[];
  loading?: boolean;
}>();
</script>

<style scoped>
.today-plan-card {
  border-radius: var(--tf-radius-md, 12px);
}

.today-plan-runway {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(7.5rem, 1fr));
  gap: 0.5rem;
}

.today-plan-runway__cell {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 0.5rem 0.65rem;
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
  text-decoration: none;
  color: var(--tf-neutral-ink);
  min-height: 4.5rem;
}

.today-plan-runway__cell--active {
  background: var(--tf-status-progress-soft, var(--tf-info-soft));
  border-color: color-mix(in srgb, var(--tf-info) 25%, var(--tf-neutral-border));
}

.today-plan-runway__cell--idle {
  opacity: 0.55;
  background: var(--tf-neutral-surface);
}

.today-plan-runway__count {
  font-size: 1.25rem;
  font-weight: 600;
  line-height: 1.2;
}

.today-plan-runway__title {
  font-size: 12px;
  font-weight: 600;
  line-height: 1.3;
}

.today-plan-runway__caption {
  font-size: 11px;
  line-height: 1.25;
  color: var(--tf-neutral-muted);
}
</style>
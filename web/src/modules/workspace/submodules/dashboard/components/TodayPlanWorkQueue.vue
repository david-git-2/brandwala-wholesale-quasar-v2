<template>
  <q-card flat bordered class="today-plan-card">
    <q-card-section class="q-pa-sm q-pb-xs">
      <div class="row items-center justify-between">
        <div class="text-overline text-grey-7">Do first</div>
        <span v-if="openWorkCount > 0" class="text-caption text-weight-medium tf-num">
          {{ openWorkCount }} open
        </span>
      </div>
    </q-card-section>

    <q-card-section v-if="loading" class="q-pa-sm q-pt-none">
      <q-skeleton type="rect" height="88px" class="q-mb-sm" />
      <q-skeleton type="text" />
    </q-card-section>

    <q-card-section v-else-if="!nextAction" class="q-pa-sm q-pt-none">
      <TfEmptyState
        title="Clear for now"
        message="Nothing needs you from live counts. Check the runways below or refresh later."
        icon="ph ph-check-circle"
      />
    </q-card-section>

    <template v-else>
      <q-card-section class="q-pa-sm q-pt-none">
        <div
          class="today-plan-next"
          :class="nextAction.tone === 'warn' ? 'today-plan-next--warn' : 'today-plan-next--info'"
        >
          <div class="today-plan-next__meta">
            <span class="text-caption text-grey-7">Next action</span>
            <span class="today-plan-next__count tf-num">{{ nextAction.count }}</span>
          </div>
          <p class="today-plan-next__label q-mb-sm">{{ nextAction.label }}</p>
          <TfBtn variant="primary" label="Open" icon="ph ph-arrow-square-out" :to="nextAction.to" />
        </div>
      </q-card-section>

      <q-list
        v-if="remainingItems.length"
        dense
        bordered
        separator
        class="rounded-borders q-mx-sm q-mb-sm"
      >
        <q-item
          v-for="item in remainingItems"
          :key="item.id"
          :to="item.to"
          clickable
          :ripple="false"
          dense
        >
          <q-item-section avatar class="min-width-none q-pr-xs">
            <q-icon
              :name="item.tone === 'warn' ? 'ph ph-warning-circle' : 'ph ph-list-checks'"
              size="18px"
              :class="item.tone === 'warn' ? 'text-warning' : 'text-grey-7'"
            />
          </q-item-section>
          <q-item-section class="q-pl-none">
            <q-item-label class="text-body2">{{ item.label }}</q-item-label>
          </q-item-section>
          <q-item-section side>
            <span class="text-weight-medium tf-num">{{ item.count }}</span>
          </q-item-section>
        </q-item>
      </q-list>
    </template>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import type { TodayPlanWorkItem } from '../composables/useTodayPlan';

const props = defineProps<{
  items: TodayPlanWorkItem[];
  nextAction: TodayPlanWorkItem | null;
  openWorkCount: number;
  loading?: boolean;
}>();

const remainingItems = computed(() =>
  props.nextAction ? props.items.filter((item) => item.id !== props.nextAction?.id) : props.items,
);
</script>

<style scoped>
.today-plan-card {
  border-radius: var(--tf-radius-md, 12px);
}

.today-plan-next {
  padding: 0.75rem;
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
}

.today-plan-next--warn {
  background: var(--tf-warning-soft);
  border-color: color-mix(in srgb, var(--tf-warning) 30%, var(--tf-neutral-border));
}

.today-plan-next--info {
  background: var(--tf-status-progress-soft, var(--tf-info-soft));
}

.today-plan-next__meta {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
}

.today-plan-next__count {
  font-size: 1.75rem;
  font-weight: 600;
  line-height: 1;
}

.today-plan-next__label {
  margin: 0.35rem 0 0;
  font-size: 14px;
  font-weight: 500;
  line-height: 1.35;
  color: var(--tf-neutral-ink);
}
</style>
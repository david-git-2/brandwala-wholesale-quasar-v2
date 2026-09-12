<template>
  <DashboardHeroScene
    :image-url="heroImage"
    layout="tr-bl"
    aria-label="Tasks and checklist operations illustration"
  >
    <template #snapshot>
      <div
        class="glass-panel glass-panel--top glass-panel--interactive"
        role="button"
        tabindex="0"
        @click="showDetail = true"
        @keydown.enter="showDetail = true"
      >
        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--primary" />
            <span class="stat-item__label">Assigned to me</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">{{ assignedLabel }}</span>
            <span class="stat-item__badge">Mine</span>
          </div>
        </div>
        <div class="glass-divider" />
        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--warn" />
            <span class="stat-item__label">Overdue</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">{{ overdueLabel }}</span>
            <span class="stat-item__unit">Tasks</span>
          </div>
        </div>
        <i class="ph ph-chart-donut glass-panel__action-icon" />
      </div>
    </template>

    <template #queue>
      <div
        class="glass-panel glass-panel--bottom glass-panel--interactive"
        role="button"
        tabindex="0"
        @click="goToTasks"
        @keydown.enter="goToTasks"
      >
        <div class="pill-stat pill-stat--warn">
          <div class="pill-stat__icon">
            <i class="ph ph-calendar-blank" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Due today</span>
            <span class="pill-stat__value">{{ dueTodayLabel }}</span>
          </div>
        </div>
        <div class="pill-stat pill-stat--info">
          <div class="pill-stat__icon">
            <i class="ph ph-user-minus" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Unassigned</span>
            <span class="pill-stat__value">{{ unassignedLabel }}</span>
          </div>
        </div>
        <i class="ph ph-arrow-up-right glass-panel__action-icon" />
      </div>
    </template>
  </DashboardHeroScene>

  <TasksDetailDialog v-model="showDetail" :metrics="metrics" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import DashboardHeroScene from 'src/modules/dashboard/components/DashboardHeroScene.vue';
import { formatDashboardCount } from 'src/modules/dashboard/utils/formatDashboardMetric';
import heroImage from 'src/assets/tasks-dashboard-bg.jpg';
import { useTasksDashboardQuery } from '../composables/useTasksDashboardQuery';
import TasksDetailDialog from './TasksDetailDialog.vue';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const showDetail = ref(false);
const { data: metrics } = useTasksDashboardQuery(tenantId);

const assignedLabel = computed(() => formatDashboardCount(metrics.value?.assignedToMe ?? 0));
const overdueLabel = computed(() => formatDashboardCount(metrics.value?.overdueCount ?? 0));
const dueTodayLabel = computed(
  () => `${formatDashboardCount(metrics.value?.dueTodayCount ?? 0)} Tasks`,
);
const unassignedLabel = computed(
  () => `${formatDashboardCount(metrics.value?.unassignedCount ?? 0)} Tasks`,
);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const goToTasks = () => {
  void router.push({
    name: 'tasks-page',
    params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
  });
};
</script>

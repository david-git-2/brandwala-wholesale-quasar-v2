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
            <span class="stat-item__number">14</span>
            <span class="stat-item__badge">Stub</span>
          </div>
        </div>
        <div class="glass-divider" />
        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--warn" />
            <span class="stat-item__label">Overdue</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">3</span>
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
            <span class="pill-stat__value">6 Tasks</span>
          </div>
        </div>
        <div class="pill-stat pill-stat--info">
          <div class="pill-stat__icon">
            <i class="ph ph-user-minus" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Unassigned</span>
            <span class="pill-stat__value">4 Tasks</span>
          </div>
        </div>
        <i class="ph ph-arrow-up-right glass-panel__action-icon" />
      </div>
    </template>
  </DashboardHeroScene>

  <TasksDetailDialog v-model="showDetail" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import DashboardHeroScene from 'src/modules/dashboard/components/DashboardHeroScene.vue';
import heroImage from 'src/assets/tasks-dashboard-bg.jpg';
import TasksDetailDialog from './TasksDetailDialog.vue';

const router = useRouter();
const route = useRoute();
const showDetail = ref(false);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const goToTasks = () => {
  void router.push({
    name: 'tasks-page',
    params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
  });
};
</script>

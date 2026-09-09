<template>
  <DashboardHeroScene
    :image-url="heroImage"
    aria-label="After sales service and returns operations illustration"
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
            <span class="stat-item__label">Open cases</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">27</span>
            <span class="stat-item__badge">Stub</span>
          </div>
        </div>
        <div class="glass-divider" />
        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--warn" />
            <span class="stat-item__label">Pending my approval</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">8</span>
            <span class="stat-item__unit">Cases</span>
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
        @click="goToApprovalQueue"
        @keydown.enter="goToApprovalQueue"
      >
        <div class="pill-stat pill-stat--info">
          <div class="pill-stat__icon">
            <i class="ph ph-package" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Awaiting receipt</span>
            <span class="pill-stat__value">9 Cases</span>
          </div>
        </div>
        <div class="pill-stat pill-stat--accent">
          <div class="pill-stat__icon">
            <i class="ph ph-chat-circle-dots" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Dropship complaints</span>
            <span class="pill-stat__value">5 Open</span>
          </div>
        </div>
        <i class="ph ph-arrow-up-right glass-panel__action-icon" />
      </div>
    </template>
  </DashboardHeroScene>

  <AfterSalesDetailDialog v-model="showDetail" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import DashboardHeroScene from 'src/modules/dashboard/components/DashboardHeroScene.vue';
import heroImage from 'src/assets/after-sales-dashboard-bg.jpg';
import AfterSalesDetailDialog from './AfterSalesDetailDialog.vue';

const router = useRouter();
const route = useRoute();
const showDetail = ref(false);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const goToApprovalQueue = () => {
  void router.push({
    name: 'app-after-sales-cases',
    params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
    query: { status: 'pending_approval' },
  });
};
</script>

<template>
  <DashboardHeroScene
    :image-url="heroImage"
    aria-label="Investor capital operations illustration"
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
            <span class="pulse-dot pulse-dot--success" />
            <span class="stat-item__label">Active pool</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">৳12.4M</span>
            <span class="stat-item__badge">Stub</span>
          </div>
        </div>
        <div class="glass-divider" />
        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--primary" />
            <span class="stat-item__label">Deployed this month</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">৳1.8M</span>
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
        @click="goToLedger"
        @keydown.enter="goToLedger"
      >
        <div class="pill-stat pill-stat--warn">
          <div class="pill-stat__icon">
            <i class="ph ph-hand-coins" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Due to investors</span>
            <span class="pill-stat__value">৳420K</span>
          </div>
        </div>
        <div
          class="pill-stat pill-stat--info"
          role="link"
          tabindex="0"
          @click.stop="goToShipments"
          @keydown.enter.stop="goToShipments"
        >
          <div class="pill-stat__icon">
            <i class="ph ph-package" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Open containers</span>
            <span class="pill-stat__value">3 Batches</span>
          </div>
        </div>
        <i class="ph ph-arrow-up-right glass-panel__action-icon" />
      </div>
    </template>
  </DashboardHeroScene>

  <InvestorCapitalDetailDialog v-model="showDetail" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import DashboardHeroScene from 'src/modules/dashboard/components/DashboardHeroScene.vue';
import heroImage from 'src/assets/investor-capital-dashboard-bg.jpg';
import InvestorCapitalDetailDialog from './InvestorCapitalDetailDialog.vue';

const router = useRouter();
const route = useRoute();
const showDetail = ref(false);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const withSlug = () => (tenantSlug.value ? { tenantSlug: tenantSlug.value } : {});

const goToLedger = () => {
  void router.push({ name: 'app-capital-ledger-page', params: withSlug() });
};

const goToShipments = () => {
  void router.push({ name: 'app-capital-shipments-page', params: withSlug() });
};
</script>

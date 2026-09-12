<template>
  <DashboardHeroScene
    :image-url="heroImage"
    aria-label="Treasury and wallet operations illustration"
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
            <span class="stat-item__label">Company cash</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">{{ cashLabel }}</span>
            <span class="stat-item__badge">Live</span>
          </div>
        </div>
        <div class="glass-divider" />
        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--primary" />
            <span class="stat-item__label">Customer prepayments</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">{{ depositsLabel }}</span>
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
        @click="goToWallet"
        @keydown.enter="goToWallet"
      >
        <div class="pill-stat pill-stat--warn">
          <div class="pill-stat__icon">
            <i class="ph ph-truck" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">COD to collect</span>
            <span class="pill-stat__value">{{ codLabel }}</span>
          </div>
        </div>
        <div class="pill-stat pill-stat--info">
          <div class="pill-stat__icon">
            <i class="ph ph-arrow-circle-up" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Pending payouts</span>
            <span class="pill-stat__value">{{ payoutLabel }}</span>
          </div>
        </div>
        <i class="ph ph-arrow-up-right glass-panel__action-icon" />
      </div>
    </template>
  </DashboardHeroScene>

  <WalletTreasuryDetailDialog v-model="showDetail" :summary="dashboardSummary" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import DashboardHeroScene from 'src/modules/dashboard/components/DashboardHeroScene.vue';
import { formatDashboardMoney } from 'src/modules/dashboard/utils/formatDashboardMetric';
import heroImage from 'src/assets/wallet-dashboard-bg.jpg';
import { useWalletAccounts } from '../composables/useWalletAccounts';
import WalletTreasuryDetailDialog from './WalletTreasuryDetailDialog.vue';

const router = useRouter();
const route = useRoute();
const showDetail = ref(false);
const { dashboardSummary } = useWalletAccounts();

const cashLabel = computed(() => formatDashboardMoney(dashboardSummary.value?.tenant_cash_total ?? 0));
const depositsLabel = computed(() =>
  formatDashboardMoney(dashboardSummary.value?.customer_deposits_total ?? 0),
);
const codLabel = computed(() =>
  formatDashboardMoney(dashboardSummary.value?.courier_cod_holding_total ?? 0),
);
const payoutLabel = computed(() =>
  formatDashboardMoney(dashboardSummary.value?.merchant_pending_total ?? 0),
);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const goToWallet = () => {
  void router.push({
    name: 'app-wallet-home-page',
    params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
  });
};
</script>

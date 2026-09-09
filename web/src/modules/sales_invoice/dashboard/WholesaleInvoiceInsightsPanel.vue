<template>
  <DashboardHeroScene
    :image-url="heroImage"
    image-position="center"
    aria-label="Sales and invoicing operations illustration"
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
            <span class="stat-item__label">Today billed</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">৳1.28M</span>
            <span class="stat-item__badge">Stub</span>
          </div>
        </div>
        <div class="glass-divider" />
        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--primary" />
            <span class="stat-item__label">Unpaid invoices</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">42</span>
            <span class="stat-item__unit">Open</span>
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
        @click="goToInvoiceList"
        @keydown.enter="goToInvoiceList"
      >
        <div class="pill-stat pill-stat--warn">
          <div class="pill-stat__icon">
            <i class="ph ph-warning-circle" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Overdue</span>
            <span class="pill-stat__value">11 Invoices</span>
          </div>
        </div>
        <div class="pill-stat pill-stat--info">
          <div class="pill-stat__icon">
            <i class="ph ph-note-blank" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Drafts</span>
            <span class="pill-stat__value">6 Invoices</span>
          </div>
        </div>
        <i class="ph ph-arrow-up-right glass-panel__action-icon" />
      </div>
    </template>
  </DashboardHeroScene>

  <WholesaleInvoiceDetailDialog v-model="showDetail" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import DashboardHeroScene from 'src/modules/dashboard/components/DashboardHeroScene.vue';
import heroImage from 'src/assets/sales-invoice-dashboard-bg.jpg';
import WholesaleInvoiceDetailDialog from './WholesaleInvoiceDetailDialog.vue';

const router = useRouter();
const route = useRoute();
const showDetail = ref(false);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const goToInvoiceList = () => {
  void router.push({
    name: 'app-global-invoices-page',
    params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
  });
};
</script>

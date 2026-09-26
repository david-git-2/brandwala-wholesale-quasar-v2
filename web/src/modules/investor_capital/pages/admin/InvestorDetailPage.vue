<template>
  <q-page class="investor-detail-page q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-card flat bordered class="q-pa-sm flex-shrink-0">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-auto">
            <q-btn flat round dense icon="ph ph-arrow-left" @click="goBackToList" />
          </div>
          <div class="col-grow">
            <div class="text-subtitle1 text-weight-bold">
              {{ investor?.name ?? (loadingInvestors ? 'Loading…' : 'Investor') }}
            </div>
            <div v-if="investor" class="text-caption text-grey-7">
              #{{ investor.investor_id }}
              <span v-if="investor.email"> · {{ investor.email }}</span>
            </div>
          </div>
        </div>

        <div class="drawer-tabs q-mt-sm">
          <div class="drawer-tabs__track">
            <button
              v-for="tab in detailTabs"
              :key="tab.name"
              type="button"
              class="drawer-tabs__item"
              :class="{ 'drawer-tabs__item--active': activeTab === tab.name }"
              @click="onTabChange(tab.name)"
            >
              <q-icon :name="tab.icon" size="14px" />
              <span>{{ tab.label }}</span>
            </button>
          </div>
        </div>
      </q-card>

      <q-banner v-if="error" class="bw-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ error }}
      </q-banner>

      <div class="col overflow-hidden">
        <router-view />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useInvestorDetailContext } from '../../composables/useInvestorDetailContext';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { investor, loadingInvestors, error, goBackToList } = useInvestorDetailContext();

type DetailTab = 'general' | 'investment' | 'shipments';

const routeTabByName: Record<string, DetailTab> = {
  'app-capital-investor-general': 'general',
  'app-capital-investor-investment': 'investment',
  'app-capital-investor-shipments': 'shipments',
};

const tabRouteByName: Record<DetailTab, string> = {
  general: 'app-capital-investor-general',
  investment: 'app-capital-investor-investment',
  shipments: 'app-capital-investor-shipments',
};

const detailTabs: { name: DetailTab; label: string; icon: string }[] = [
  { name: 'general', label: 'General', icon: 'ph ph-user' },
  { name: 'investment', label: 'Investment', icon: 'ph ph-wallet' },
  { name: 'shipments', label: 'Allocated shipments', icon: 'ph ph-package' },
];

const activeTab = computed<DetailTab>(() => {
  const name = String(route.name ?? '');
  return routeTabByName[name] ?? 'general';
});

const onTabChange = (tab: DetailTab) => {
  const routeName = tabRouteByName[tab];
  void router.push({
    name: routeName,
    params: {
      tenantSlug: authStore.tenantSlug || undefined,
      id: route.params.id,
    },
  });
};
</script>

<style scoped>
.drawer-tabs__track {
  display: flex;
  gap: 4px;
  padding: 4px;
  border-radius: var(--bw-radius-sm, 8px);
  background: var(--bw-neutral-muted-bg, #f1f5f9);
}

.drawer-tabs__item {
  flex: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-width: 0;
  border: none;
  background: transparent;
  color: var(--bw-neutral-chrome, #64748b);
  font-size: 13px;
  font-weight: 500;
  line-height: 1.2;
  padding: 8px 10px;
  border-radius: 6px;
  cursor: pointer;
  transition:
    background-color 0.15s ease,
    color 0.15s ease,
    box-shadow 0.15s ease;
}

.drawer-tabs__item:hover {
  color: var(--bw-neutral-ink, #0f172a);
}

.drawer-tabs__item--active {
  background: var(--bw-neutral-surface, #ffffff);
  color: var(--bw-neutral-ink, #0f172a);
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06);
}

.drawer-tabs__item span {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

@media (max-width: 599px) {
  .drawer-tabs__item span {
    font-size: 12px;
  }
}
</style>

<style>
body.body--dark .investor-detail-page .drawer-tabs__track {
  background: #262626;
}

body.body--dark .investor-detail-page .drawer-tabs__item {
  color: #94a3b8;
}

body.body--dark .investor-detail-page .drawer-tabs__item--active {
  background: #1c1c1c;
  color: #f8fafc;
}
</style>

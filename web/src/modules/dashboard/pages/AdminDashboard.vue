<template>
  <q-page class="dashboard-page theme-app q-pa-md">
    <header class="dashboard-hero">
      <div class="text-overline text-primary">Workspace</div>
      <h1>{{ selectedTenantName || 'Dashboard' }}</h1>
      <p>What do you want to do?</p>
    </header>

    <template v-if="!isEmpty">
      <section v-if="primaries.length" class="dashboard-block">
        <p class="dashboard-block__label">Primary actions</p>
        <div class="dashboard-primary-grid">
          <DashboardSlotHost
            v-for="slot in primaries"
            :key="slot.id"
            :item="slot"
            v-bind="tenantSlug ? { tenantSlug } : {}"
            emphasis="primary"
          />
        </div>
      </section>

      <DashboardGroup
        v-for="group in groups"
        :key="group.parentGroupKey"
        :title="group.title"
        :icon="group.icon"
        :slots="group.slots"
        v-bind="tenantSlug ? { tenantSlug } : {}"
      />
    </template>

    <section v-else class="dashboard-block">
      <p class="dashboard-block__label">Dashboard</p>
      <h2>No widgets for your access</h2>
      <p>Open the sidebar or ask an admin to enable modules and permissions for this tenant.</p>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import DashboardGroup from '../components/DashboardGroup.vue';
import DashboardSlotHost from '../components/DashboardSlotHost.vue';
import { useDashboardSlots } from '../composables/useDashboardSlots';

const tenantStore = useTenantStore();
const selectedTenantName = computed(() => tenantStore.selectedTenant?.name ?? '');

const { primaries, groups, isEmpty, tenantSlug } = useDashboardSlots();
</script>

<style scoped>
.dashboard-page {
  --dashboard-border: var(--bw-theme-border);
  --dashboard-surface: var(--bw-theme-surface);
  --dashboard-ink: var(--bw-theme-ink);
  --dashboard-muted: var(--bw-theme-muted);
  display: grid;
  gap: 1.5rem;
  max-width: 52rem;
}

.dashboard-hero h1 {
  margin: 0.15rem 0 0;
  font-size: clamp(1.75rem, 3vw, 2.15rem);
  font-weight: 700;
  line-height: 1.15;
  letter-spacing: -0.02em;
  color: var(--dashboard-ink);
}

.dashboard-hero p {
  margin: 0.4rem 0 0;
  color: var(--dashboard-muted);
  font-size: 0.95rem;
  line-height: 1.5;
}

.dashboard-block {
  border: 1px solid var(--dashboard-border);
  border-radius: 14px;
  background: var(--dashboard-surface);
  padding: 1.1rem 1.15rem;
}

.dashboard-block__label {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--dashboard-muted);
}

.dashboard-block h2 {
  margin: 0.4rem 0 0;
  font-size: 1.15rem;
  color: var(--dashboard-ink);
}

.dashboard-block p {
  margin: 0.45rem 0 0;
  color: var(--dashboard-muted);
  line-height: 1.55;
}

.dashboard-primary-grid {
  display: grid;
  gap: 0.65rem;
  margin-top: 0.85rem;
  grid-template-columns: 1fr;
}
</style>

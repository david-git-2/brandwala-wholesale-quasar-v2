<template>
  <q-page class="dashboard-page theme-app q-pa-md">
    <!-- Parent Workspace: Supply Chain, Procurement & Physical Stock -->
    <ProcurementStockCard v-if="isParentTenant" />

    <!-- Child Workspace / Sister Concern: Storefront Shop, Orders & Dropship Hub -->
    <ShopOrderCard v-else-if="isChildTenant" />

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
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import ProcurementStockCard from 'src/modules/procurement_stock/dashboard/ProcurementStockCard.vue';
import ShopOrderCard from 'src/modules/shop_order/dashboard/ShopOrderCard.vue';
import DashboardGroup from '../components/DashboardGroup.vue';
import DashboardSlotHost from '../components/DashboardSlotHost.vue';
import { useDashboardSlots } from '../composables/useDashboardSlots';

const tenantStore = useTenantStore();
const { primaries, groups, tenantSlug } = useDashboardSlots();

const isChildTenant = computed(() => Boolean(tenantStore.selectedTenant?.parent_id));
const isParentTenant = computed(() => !isChildTenant.value);
</script>

<style scoped>
.dashboard-page {
  --dashboard-border: var(--bw-theme-border);
  --dashboard-surface: var(--bw-theme-surface);
  --dashboard-ink: var(--bw-theme-ink);
  --dashboard-muted: var(--bw-theme-muted);
  display: grid;
  gap: 1.5rem;
  max-width: 68rem;
  margin: 0 auto;
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
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--dashboard-muted);
}

.dashboard-primary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 0.75rem;
  margin-top: 0.85rem;
}
</style>

<template>
  <q-page class="q-pa-md admin-tenant-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Tenants</div>
            <div class="text-caption text-grey-8">
              Browse the workspaces connected to your access.
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <PageInitialLoader v-if="loading" />

    <template v-else>
      <div v-if="visibleTenants.length" class="admin-tenant-page__tree-container">
        <TenantTreeList :tenants="visibleTenants" @click-tenant="goToTenantDetails" />
      </div>

      <q-card v-else flat class="floating-surface shadow-1">
        <q-card-section class="text-center q-pa-xl">
          <div class="text-subtitle1 text-grey-9 text-weight-bold">No tenants found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">
            When tenant access is assigned, workspaces will appear here.
          </div>
        </q-card-section>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { storeToRefs } from 'pinia';
import { useRoute } from 'vue-router';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { getTenantSlugFromRoute } from 'src/modules/tenant/utils/tenantRouteContext';
import { useAdminTenantSelection } from '../composables/useAdminTenantSelection';
import { useTenantStore } from '../stores/tenantStore';
import TenantTreeList from '../components/TenantTreeList.vue';

const route = useRoute();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const { items, loading, error } = storeToRefs(tenantStore);
const { selectTenantWorkspace } = useAdminTenantSelection();

const visibleTenants = computed(() => {
  const routeTenantSlug = getTenantSlugFromRoute(route);

  if (!routeTenantSlug) {
    return items.value;
  }

  return items.value.filter((tenant) => tenant.slug === routeTenantSlug);
});

const refreshTenants = () =>
  tenantStore.fetchTenantsByMembership({
    email: authStore.user?.email ?? null,
  });

const goToTenantDetails = (tenantId?: number) => {
  if (!tenantId) return;
  const tenant = items.value.find((item) => item.id === tenantId) ?? null;

  if (tenant) {
    void selectTenantWorkspace(tenant);
  }
};

onMounted(() => {
  void refreshTenants();
});
</script>

<style scoped>
.admin-tenant-list-page {
  background: transparent;
}
.hero-surface {
  border-radius: 16px;
}

.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.admin-tenant-page__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.admin-tenant-page__card {
  width: 100%;
  transition:
    transform 0.2s ease,
    box-shadow 0.2s ease;
}

.admin-tenant-page__card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(25, 35, 47, 0.12) !important;
}

.admin-tenant-page__card-section {
  padding: 1rem;
}

@media (max-width: 599px) {
  .admin-tenant-page__grid {
    grid-template-columns: 1fr;
  }
}
</style>

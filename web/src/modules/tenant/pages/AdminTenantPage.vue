<template>
  <q-page class="q-pa-md admin-tenant-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Tenants</div>
            <div class="text-caption text-grey-8">Browse the workspaces connected to your access.</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <PageInitialLoader v-if="loading" />

    <template v-else>
      <section v-if="visibleTenants.length" class="admin-tenant-page__grid">
        <q-card
          v-for="tenant in visibleTenants"
          :key="tenant.id"
          flat
          class="admin-tenant-page__card floating-surface shadow-1 cursor-pointer"
          @click="goToTenantDetails(tenant.id)"
        >
          <q-card-section class="admin-tenant-page__card-section">
            <div class="row justify-between items-center q-mb-xs">
              <div class="text-overline text-primary text-weight-bold">Tenant #{{ tenant.id }}</div>
              <q-chip
                dense
                square
                class="costing-status-chip"
                :style="tenant.is_active ? activeStatusStyle : inactiveStatusStyle"
              >
                <span class="status-dot" :style="{ backgroundColor: tenant.is_active ? '#2f8b5d' : '#66758c' }" />
                {{ selectingTenantId === tenant.id ? 'Opening' : tenant.is_active ? 'Active' : 'Inactive' }}
              </q-chip>
            </div>
            <div class="text-subtitle1 text-weight-bold text-grey-9">{{ tenant.name }}</div>
            <div class="text-body2 text-grey-7 q-mt-xs">{{ tenant.slug }}</div>
          </q-card-section>
        </q-card>
      </section>

      <q-card v-else flat class="floating-surface shadow-1">
        <q-card-section class="text-center q-pa-xl">
          <div class="text-subtitle1 text-grey-9 text-weight-bold">No tenants found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">When tenant access is assigned, workspaces will appear here.</div>
        </q-card-section>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute } from 'vue-router'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { getTenantSlugFromRoute } from 'src/modules/tenant/utils/tenantRouteContext'
import { useAdminTenantSelection } from '../composables/useAdminTenantSelection'
import { useTenantStore } from '../stores/tenantStore'

const route = useRoute()
const authStore = useAuthStore()
const tenantStore = useTenantStore()
const { items, loading, error } = storeToRefs(tenantStore)
const { selectTenantWorkspace, selectingTenantId } = useAdminTenantSelection()

const activeStatusStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
  boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
}

const inactiveStatusStyle = {
  backgroundColor: '#dbe5f3',
  color: '#3b4b66',
  border: '1px solid #b9c8dd',
  boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
}

const visibleTenants = computed(() => {
  const routeTenantSlug = getTenantSlugFromRoute(route)

  if (!routeTenantSlug) {
    return items.value
  }

  return items.value.filter((tenant) => tenant.slug === routeTenantSlug)
})

const refreshTenants = () =>
  tenantStore.fetchTenantsByMembership({
    email: authStore.user?.email ?? null,
  })

const goToTenantDetails = (tenantId?: number) => {
  if (!tenantId) return
  const tenant = items.value.find((item) => item.id === tenantId) ?? null

  if (tenant) {
    void selectTenantWorkspace(tenant)
  }
}

onMounted(() => {
  void refreshTenants()
})
</script>

<style scoped>
.admin-tenant-list-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
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
  transition: transform 0.2s ease, box-shadow 0.2s ease;
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

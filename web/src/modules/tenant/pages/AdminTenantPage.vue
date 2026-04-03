<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section>
        <div class="text-overline">Operations</div>
        <h1 class="text-h5 q-my-none">Tenants</h1>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">Browse the workspaces connected to your admin access.</p>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <section v-if="visibleTenants.length" class="admin-tenant-page__grid">
        <q-card
          v-for="tenant in visibleTenants"
          :key="tenant.id"
          flat
          bordered
          class="admin-tenant-page__card cursor-pointer"
          @click="goToTenantDetails(tenant.id)"
        >
          <q-card-section class="admin-tenant-page__card-section">
            <div class="text-overline">Tenant #{{ tenant.id }}</div>
            <div class="text-subtitle2">{{ tenant.name }}</div>
            <div class="text-body2 text-grey-7">{{ tenant.slug }}</div>
            <div class="text-caption q-mt-xs">
              {{ selectingTenantId === tenant.id ? 'Opening' : tenant.is_active ? 'Active' : 'Inactive' }}
            </div>
          </q-card-section>
        </q-card>
      </section>

      <q-card v-else-if="!loading" flat bordered>
        <q-card-section class="text-center">
          <div class="text-subtitle1">No tenants found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">When tenant access is assigned, workspaces will appear here.</div>
        </q-card-section>
      </q-card>

      <q-card v-else flat bordered>
        <q-card-section class="text-grey-7">Loading tenants...</q-card-section>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { getTenantSlugFromRoute } from 'src/modules/tenant/utils/tenantRouteContext'
import { useAdminTenantSelection } from '../composables/useAdminTenantSelection'
import { useTenantStore } from '../stores/tenantStore'

const route = useRoute()
const authStore = useAuthStore()
const tenantStore = useTenantStore()
const { items, loading, error } = storeToRefs(tenantStore)
const { selectTenantWorkspace, selectingTenantId } = useAdminTenantSelection()

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
.admin-tenant-page__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 260px));
  gap: 0.75rem;
}

.admin-tenant-page__card {
  width: 100%;
}

.admin-tenant-page__card-section {
  padding: 0.75rem;
}

@media (max-width: 599px) {
  .admin-tenant-page__grid {
    grid-template-columns: 1fr;
  }
}
</style>

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

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Tenant Directory</div>
        </q-card-section>

        <q-card-section v-if="items.length">
          <div class="bw-entity-grid">
            <q-card
              v-for="tenant in items"
              :key="tenant.id"
              flat
              bordered
              class="cursor-pointer"
              @click="goToTenantDetails(tenant.id)"
            >
              <q-card-section>
                <div class="text-overline">Tenant #{{ tenant.id }}</div>
                <div class="text-subtitle1">{{ tenant.name }}</div>
                <div class="text-body2 text-grey-7">{{ tenant.slug }}</div>
                <div class="text-caption q-mt-sm">{{ selectingTenantId === tenant.id ? 'Opening' : tenant.is_active ? 'Active' : 'Inactive' }}</div>
              </q-card-section>
            </q-card>
          </div>
        </q-card-section>

        <q-card-section v-else-if="!loading" class="text-center">
          <div class="text-subtitle1">No tenants found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">When tenant access is assigned, workspaces will appear here.</div>
        </q-card-section>

        <q-card-section v-else class="text-grey-7">Loading tenants...</q-card-section>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { storeToRefs } from 'pinia'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useAdminTenantSelection } from '../composables/useAdminTenantSelection'
import { useTenantStore } from '../stores/tenantStore'

const authStore = useAuthStore()
const tenantStore = useTenantStore()
const { items, loading, error } = storeToRefs(tenantStore)
const { selectTenantWorkspace, selectingTenantId } = useAdminTenantSelection()

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

<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <AppPageHeader
        eyebrow="Operations"
        title="Tenants"
        subtitle="Browse the workspaces connected to your admin access using the same card layout used across the app."
      />

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <AppSectionCard
        title="Tenant Directory"
        caption="Each card uses the shared entity shell so future list pages stay visually aligned."
      >
        <div v-if="items.length" class="bw-entity-grid">
          <AppEntityCard
            v-for="tenant in items"
            :key="tenant.id"
            clickable
            :eyebrow="`Tenant #${tenant.id}`"
            :title="tenant.name"
            :meta="tenant.slug"
            :status-label="tenant.is_active ? 'Active' : 'Inactive'"
            :status-tone="tenant.is_active ? 'positive' : 'neutral'"
            @click="goToTenantDetails(tenant.id)"
          />
        </div>

        <AppEmptyState
          v-else-if="!loading"
          icon="domain"
          title="No tenants found"
          message="When tenant access is assigned to this admin account, those workspaces will appear here."
        />

        <div v-else class="bw-text-muted">Loading tenants...</div>
      </AppSectionCard>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import AppEmptyState from 'src/components/ui/AppEmptyState.vue'
import AppEntityCard from 'src/components/ui/AppEntityCard.vue'
import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import AppSectionCard from 'src/components/ui/AppSectionCard.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from '../stores/tenantStore'

const router = useRouter()
const authStore = useAuthStore()
const tenantStore = useTenantStore()
const { items, loading, error } = storeToRefs(tenantStore)

const refreshTenants = () =>
  tenantStore.fetchTenantsByMembership({
    email: authStore.user?.email ?? null,
  })

const goToTenantDetails = (tenantId?: number) => {
  if (!tenantId) return
  const tenant = items.value.find((item) => item.id === tenantId) ?? null

  if (tenant) {
    tenantStore.setSelectedTenant({
      id: tenant.id,
      slug: tenant.slug,
    })
  }

  void router.push(`/app/tenants/${tenantId}`)
}

onMounted(() => {
  void refreshTenants()
})
</script>

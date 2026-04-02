<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <AppPageHeader
        eyebrow="Platform"
        title="Tenants"
        subtitle="Manage tenant workspaces with the shared page header, action area, and entity-card pattern."
      >
        <template #actions>
          <div class="bw-inline-actions">
            <q-btn
              color="primary"
              unelevated
              icon="add"
              label="Add Tenant"
              @click="onClickAddTenant"
            />
          </div>
        </template>
      </AppPageHeader>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <AppSectionCard
        title="Tenant Directory"
        caption="Use this shared card layout for master lists throughout the app, including modules and future admin resources."
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
          icon="apartment"
          title="No tenants available"
          message="Create your first tenant to start assigning modules, staff access, and customer groups."
        >
          <template #actions>
            <q-btn color="primary" unelevated icon="add" label="Create Tenant" @click="onClickAddTenant" />
          </template>
        </AppEmptyState>

        <div v-else class="bw-text-muted">Loading tenants...</div>
      </AppSectionCard>

      <AddTenantDialog
        v-model="openAddDialog"
        :initial-data="selectedTenant"
        @save="handleSaveTenant"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import AppEmptyState from 'src/components/ui/AppEmptyState.vue'
import AppEntityCard from 'src/components/ui/AppEntityCard.vue'
import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import AppSectionCard from 'src/components/ui/AppSectionCard.vue'
import { useTenantStore } from '../stores/tenantStore'
import AddTenantDialog from '../components/AddTenantDialog.vue'
import type { TenantCreateInput, TenantUpdateInput } from '../types'

type TenantForm = {
  id?: number
  name: string
  slug: string
  is_active: boolean
  created_at?: string
  updated_at?: string
}

const router = useRouter()
const tenantStore = useTenantStore()
const { items, loading, error } = storeToRefs(tenantStore)

const openAddDialog = ref(false)
const selectedTenant = ref<TenantForm | null>(null)

const refreshTenants = () => tenantStore.fetchTenants()

const onClickAddTenant = () => {
  selectedTenant.value = null
  openAddDialog.value = true
}

const handleSaveTenant = async (payload: TenantForm) => {
  if (payload.id) {
    const updatePayload: TenantUpdateInput = {
      id: payload.id,
      name: payload.name,
      slug: payload.slug,
      is_active: payload.is_active,
    }

    await tenantStore.updateTenant(updatePayload)
  } else {
    const createPayload: TenantCreateInput = {
      name: payload.name,
      slug: payload.slug,
      is_active: payload.is_active,
    }

    await tenantStore.createTenant(createPayload)
  }
}

const goToTenantDetails = (tenantId?: number) => {
  if (!tenantId) return
  void router.push(`/platform/tenants/${tenantId}`)
}

onMounted(() => {
  void refreshTenants()
})
</script>

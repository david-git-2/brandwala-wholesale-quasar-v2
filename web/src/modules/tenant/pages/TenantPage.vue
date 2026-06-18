<template>
  <q-page class="q-pa-md tenant-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Tenants</div>
            <div class="text-caption text-grey-8">Platform Management</div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Add Tenant"
              @click="onClickAddTenant"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <PageInitialLoader v-if="loading" />

    <template v-else>
      <div v-if="items.length" class="tenant-page__tree-container">
        <TenantTreeList :tenants="items" @click-tenant="goToTenantDetails" />
      </div>

      <q-card v-else flat class="floating-surface shadow-1">
        <q-card-section class="text-center q-pa-xl">
          <div class="text-subtitle1 text-grey-9 text-weight-bold">No tenants available</div>
          <div class="text-body2 text-grey-7 q-mt-sm">Create your first tenant to get started.</div>
          <q-btn
            class="q-mt-md pill-btn slim-btn"
            color="primary"
            no-caps
            size="sm"
            icon="add"
            label="Create Tenant"
            @click="onClickAddTenant"
          />
        </q-card-section>
      </q-card>
    </template>

    <AddTenantDialog
      v-model="openAddDialog"
      :initial-data="selectedTenant"
      @save="handleSaveTenant"
    />
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useTenantStore } from '../stores/tenantStore'
import AddTenantDialog from '../components/AddTenantDialog.vue'
import TenantTreeList from '../components/TenantTreeList.vue'
import type { TenantCreateInput, TenantUpdateInput } from '../types'

type TenantForm = {
  id?: number
  name: string
  slug: string
  public_domain: string | null
  is_active: boolean
  parent_id: number | null
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
      public_domain: payload.public_domain,
      is_active: payload.is_active,
      parent_id: payload.parent_id,
    }

    await tenantStore.updateTenant(updatePayload)
  } else {
    const createPayload: TenantCreateInput = {
      name: payload.name,
      slug: payload.slug,
      public_domain: payload.public_domain,
      is_active: payload.is_active,
      parent_id: payload.parent_id,
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

<style scoped>
.tenant-list-page {
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

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
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

.tenant-page__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.tenant-page__card {
  width: 100%;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.tenant-page__card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(25, 35, 47, 0.12) !important;
}

@media (max-width: 599px) {
  .tenant-page__grid {
    grid-template-columns: 1fr;
  }
}
</style>

<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Platform</div>
          <h1 class="text-h5 q-my-none">Tenants</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">Manage tenant workspaces.</p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" unelevated icon="add" label="Add Tenant" @click="onClickAddTenant" />
        </div>
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
                <div class="text-body2 text-grey-7">{{ tenant.public_domain ? `${tenant.slug} | ${tenant.public_domain}` : tenant.slug }}</div>
              </q-card-section>
            </q-card>
          </div>
        </q-card-section>

        <q-card-section v-else-if="!loading" class="text-center">
          <div class="text-subtitle1">No tenants available</div>
          <div class="text-body2 text-grey-7 q-mt-sm">Create your first tenant to get started.</div>
          <q-btn class="q-mt-md" color="primary" unelevated icon="add" label="Create Tenant" @click="onClickAddTenant" />
        </q-card-section>

        <q-card-section v-else class="text-grey-7">Loading tenants...</q-card-section>
      </q-card>

      <AddTenantDialog
        v-model="openAddDialog"
        :initial-data="selectedTenant"
        @save="handleSaveTenant"
      />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import { useTenantStore } from '../stores/tenantStore'
import AddTenantDialog from '../components/AddTenantDialog.vue'
import type { TenantCreateInput, TenantUpdateInput } from '../types'

type TenantForm = {
  id?: number
  name: string
  slug: string
  public_domain: string | null
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
      public_domain: payload.public_domain,
      is_active: payload.is_active,
    }

    await tenantStore.updateTenant(updatePayload)
  } else {
    const createPayload: TenantCreateInput = {
      name: payload.name,
      slug: payload.slug,
      public_domain: payload.public_domain,
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

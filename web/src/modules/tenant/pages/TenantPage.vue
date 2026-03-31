<template>
  <q-page class="q-pa-lg">
    <div class="q-mb-md text-h5 text-weight-bold">Tenants</div>



    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <q-card flat bordered>
      <q-card-section class="row items-center justify-between">
        <div class="text-subtitle1 text-weight-medium">Tenant records</div>
        <q-btn
          color="primary"
          outline
          :loading="loading"
          label="Refresh"
          @click="refreshTenants"
        />
      </q-card-section>

      <q-separator />

      <q-card-section v-if="loading" class="text-grey-7">
        Loading tenants...
      </q-card-section>

      <q-card-section v-else-if="items.length === 0" class="text-grey-7">
        No tenants found.
      </q-card-section>

      <q-list v-else separator>
        <q-item v-for="tenant in items" :key="tenant.id">
          <q-item-section>
            <q-item-label>{{ tenant.name }}</q-item-label>
            <q-item-label caption>
              {{ tenant.slug }} · {{ tenant.is_active ? 'Active' : 'Inactive' }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-badge :color="tenant.is_active ? 'positive' : 'grey-6'">
              #{{ tenant.id }}
            </q-badge>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card>


<q-page-sticky position="bottom-right" :offset="[18, 18]">
  <q-fab color="primary" icon="add" @click="onClickAddTenant">
  </q-fab>
</q-page-sticky>

<AddTenantDialog
  v-model="openAddDialog"
  @save="onSaveTenant"
/>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'

import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from '../stores/tenantStore'
import AddTenantDialog from '../components/AddTenantDialog.vue'
import type { TenantCreateInput } from '../types'

const tenantStore = useTenantStore()
const { items, loading, error } = storeToRefs(tenantStore)
const refreshTenants = () => tenantStore.fetchTenants()
const authStore = useAuthStore()

const debugSessionEmail = ref('unknown')
const debugMemberRole = ref('unknown')
const debugScope = ref('unknown')
const openAddDialog = ref(false)

const loadDebugState = async () => {
  const { data } = await supabase.auth.getSession()
  debugSessionEmail.value = data.session?.user?.email ?? 'no-session'
  debugMemberRole.value = authStore.member?.role ?? 'no-store-role'
  debugScope.value = authStore.scope ?? 'no-store-scope'
}

const onClickAddTenant = () => {
  openAddDialog.value = true
}

const onSaveTenant = async (tenantData: TenantCreateInput) => {
  try {
    await tenantStore.createTenant(tenantData)
    openAddDialog.value = false
  } catch (err) {
    console.error('Error creating tenant:', err)
  }
}


onMounted(() => {
  void loadDebugState()
  void refreshTenants()
})
</script>

<template>
  <q-page class="q-pa-lg">
    <div class="q-mb-md text-h5 text-weight-bold">Tenants</div>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <div class="row q-col-gutter-md">
      <div
        v-for="tenant in items"
        :key="tenant.id"
        class="col-6 col-sm-4 col-md-3 col-lg-2"
      >
        <q-card
          class="tenant-card cursor-pointer"
          @click="goToTenantDetails(tenant.id)"
        >
          <q-card-section class="column items-center justify-center">
            <div class="text-caption text-grey-6 q-mb-xs">
              #{{ tenant.id }}
            </div>

            <div class="text-subtitle2 text-weight-medium text-center ellipsis">
              {{ tenant.name }}
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <div v-if="!loading && items.length === 0" class="text-grey-7 q-mt-lg">
      No tenants found.
    </div>

    <q-page-sticky position="top-right" :offset="[18, 18]">
      <q-btn
        color="primary"
        outline
        :loading="loading"
        label="Refresh"
        @click="refreshTenants"
      />
    </q-page-sticky>

    <q-page-sticky position="bottom-right" :offset="[18, 18]">
      <q-fab color="primary" icon="add" @click="onClickAddTenant" />
    </q-page-sticky>

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

import { useTenantStore } from '../stores/tenantStore'
import AddTenantDialog from '../components/AddTenantDialog.vue'

type TenantForm = {
  id?: number
  name: string
  slug: string
  is_active: boolean
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
    await tenantStore.updateTenant(payload)
  } else {
    await tenantStore.createTenant(payload)
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
.tenant-card {
  min-height: 100px;
}

.ellipsis {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>

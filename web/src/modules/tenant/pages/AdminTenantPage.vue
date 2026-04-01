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




  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import { useTenantStore } from '../stores/tenantStore'

const router = useRouter()
const tenantStore = useTenantStore()
const { items, loading, error } = storeToRefs(tenantStore)

const refreshTenants = () => tenantStore.fetchAdminTenantsByEmail()


const goToTenantDetails = (tenantId?: number) => {
  if (!tenantId) return
  void router.push(`/app/tenants/${tenantId}`)
}

onMounted(() => {
  void refreshTenants()
  console.log('Tenant list refreshed on mounted')
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

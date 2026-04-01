<template>
  <q-select
    v-model="selectedTenantId"
    :options="tenantOptions"
    label="Tenant"
    outlined
    emit-value
    map-options
    dense
    class="tenant-selector"
  />
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'

const tenantStore = useTenantStore()
const selectedTenantId = ref<number | null>(null)

const tenantOptions = computed(() =>
  tenantStore.items.map((tenant) => ({
    label: tenant.name,
    value: tenant.id,
  }))
)

onMounted(() => {
  void tenantStore.fetchTenantsByMembership()
})
</script>

<style scoped>
.tenant-selector {
  min-width: 180px;
}

@media (max-width: 599px) {
  .tenant-selector {
    min-width: 132px;
  }
}
</style>

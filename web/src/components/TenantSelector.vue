<template>
  <q-select
    v-model="selectedTenantId"
    :options="tenantOptions"
    label="Standard"
    filled
    emit-value
    map-options
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
  console.log('Tenants fetched in TenantSelector', tenantStore.items)
})
</script>

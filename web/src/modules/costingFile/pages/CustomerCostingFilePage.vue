<template>
  <q-page class="bw-page theme-shop">
    <section class="bw-page__stack costing-page">
      <section>
        <div class="text-overline">Shop Costing File</div>
        <h1 class="text-h5 q-my-none">Customer costing files</h1>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
      </section>

      <q-card v-if="loadingFiles" flat bordered>
        <q-card-section class="text-grey-7">Loading costing files...</q-card-section>
      </q-card>
      <q-card v-else-if="!files.length" flat bordered>
        <q-card-section class="text-grey-7">No costing files yet.</q-card-section>
      </q-card>
      <section v-else class="costing-page__card-grid">
        <q-card
          v-for="file in files"
          :key="file.id"
          flat
          bordered
          class="costing-page__card cursor-pointer"
          :style="{ '--costing-card-accent': cardAccentColor }"
          @click="openFile(file.id)"
        >
          <q-card-section>
            <div class="text-overline">Costing file</div>
            <div class="text-subtitle1">{{ file.name }}</div>
            <div class="text-body2 text-grey-7">Market: {{ file.market }}</div>
            <div class="text-body2 text-grey-7">Status: {{ file.status }}</div>
          </q-card-section>
        </q-card>
      </section>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'

const router = useRouter()
const authStore = useAuthStore()
const costingFileStore = useCostingFileStore()
const { items: files, listLoading: loadingFiles } = storeToRefs(costingFileStore)

const cardAccentColor = computed(
  () => authStore.customerGroup?.accentColor?.trim() || 'var(--bw-theme-primary)',
)

const subtitle = computed(() =>
  authStore.customerGroup?.name
    ? `${authStore.customerGroup.name} can open costing files here.`
    : 'Customer group access is required.',
)

const loadFiles = async () => {
  const customerGroupId = authStore.customerGroupId
  const tenantId = authStore.tenantId

  if (!customerGroupId || !tenantId) {
    costingFileStore.items = []
    return
  }

  await costingFileStore.fetchCostingFilesByCustomerGroup(customerGroupId, tenantId)
}

const openFile = async (id: number) => {
  await router.push({
    name: 'customer-costing-file-details-page',
    params: { id: String(id) },
  })
}

onMounted(async () => {
  await loadFiles()
})
</script>

<style scoped>
.costing-page { display: grid; gap: 1.25rem; }
.costing-page__card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 260px));
  gap: 0.75rem;
}
.costing-page__card {
  width: 100%;
  border-left: 4px solid var(--costing-card-accent, var(--bw-theme-primary));
}
.costing-page__empty { color: var(--bw-theme-muted); }
@media (max-width: 900px) {
  .costing-page__card-grid { grid-template-columns: 1fr; }
}
</style>

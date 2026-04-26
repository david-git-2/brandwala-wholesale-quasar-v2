<template>
  <q-page class="bw-page theme-app">
    <PageInitialLoader v-if="initialLoading" />
    <section v-else class="bw-page__stack costing-page">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Viewer Access</div>
          <h1 class="text-h5 q-my-none">PO placed costing files</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
        </div>
      </section>

      <q-card v-if="loadingFiles" flat bordered>
        <q-card-section class="text-grey-7">Loading assigned costing files...</q-card-section>
      </q-card>
      <q-card v-else-if="!files.length" flat bordered>
        <q-card-section class="text-grey-7">
          No PO placed costing files are available for your viewer access yet.
        </q-card-section>
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
            <div class="row justify-end">
              <q-chip
                dense
                square
                :color="statusChipColor(file.status)"
                text-color="white"
                class="costing-page__status-chip"
              >
                {{ formatStatusLabel(file.status) }}
              </q-chip>
            </div>
            <div class="text-overline q-mt-xs">Costing file</div>
            <div class="text-subtitle1">#{{ file.id }} {{ file.name }}</div>
            <div class="text-body2 text-grey-7">Market: {{ file.market || 'Not set' }}</div>
          </q-card-section>
        </q-card>
      </section>

      <div v-if="totalPages > 1" class="costing-page__pagination">
        <q-pagination
          v-model="page"
          :max="totalPages"
          boundary-links
          direction-links
          color="primary"
          :max-pages="7"
          @update:model-value="handlePageChange"
        />
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'

const router = useRouter()
const authStore = useAuthStore()
const costingFileStore = useCostingFileStore()
const { items: files, listLoading: loadingFiles, totalItems } = storeToRefs(costingFileStore)
const initialLoading = ref(true)
const page = ref(1)
const pageSize = 20

const cardAccentColor = computed(() => 'var(--bw-theme-primary)')
const statusChipColor = (status: string) => {
  if (status === 'draft') return 'grey-7'
  if (status === 'customer_submitted') return 'indigo'
  if (status === 'in_review') return 'amber-8'
  if (status === 'offered') return 'positive'
  if (status === 'po_placed') return 'primary'
  return 'secondary'
}
const formatStatusLabel = (status: string) =>
  status
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
const totalPages = computed(() => Math.max(1, Math.ceil((totalItems.value || 0) / pageSize)))

const subtitle = computed(() =>
  authStore.selectedTenant?.name
    ? `Viewer access for ${authStore.selectedTenant.name}.`
    : 'Viewer access is required to open assigned costing files.',
)

const loadFiles = async () => {
  const tenantId = authStore.tenantId

  if (!tenantId) {
    costingFileStore.items = []
    costingFileStore.totalItems = 0
    return
  }

  await costingFileStore.fetchCostingFilesByTenant(tenantId, {
    page: page.value,
    pageSize,
  })
}

const handlePageChange = async () => {
  await loadFiles()
}

const openFile = async (id: number) => {
  await router.push({
    name: 'viewer-costing-file-details-page',
    params: { id: String(id) },
  })
}

onMounted(async () => {
  try {
    await loadFiles()
  } finally {
    initialLoading.value = false
  }
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
.costing-page__pagination {
  display: flex;
  justify-content: center;
  padding-top: 0.5rem;
}
</style>

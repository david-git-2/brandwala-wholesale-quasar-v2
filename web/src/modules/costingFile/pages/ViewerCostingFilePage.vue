<template>
  <q-page class="q-pa-md costing-list-page theme-app">
    <PageInitialLoader v-if="initialLoading" />
    <section v-else class="bw-page__stack costing-page">
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col">
              <div class="text-h6 text-weight-bold">PO placed costing files</div>
              <div class="text-caption text-grey-8">{{ subtitle }}</div>
            </div>
          </div>
        </q-card-section>
      </q-card>

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
                :style="statusChipStyle(file.status)"
                class="costing-status-chip"
              >
                <span class="status-dot" :style="{ backgroundColor: statusDotColor(file.status) }" />
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
const statusChipStyle = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending'
  if (value === 'draft') {
    return {
      backgroundColor: '#f1f5f9',
      color: '#475569',
      border: '1px solid #cbd5e1',
    }
  }
  if (value === 'customer_submitted') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
    }
  }
  if (value === 'in_review') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
    }
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
    }
  }
  if (value === 'accepted') {
    return {
      backgroundColor: '#d1fae5',
      color: '#065f46',
      border: '1px solid #a7f3d0',
    }
  }
  if (value === 'po_placed') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
    }
  }
  return {
    backgroundColor: '#f1f5f9',
    color: '#475569',
    border: '1px solid #cbd5e1',
  }
}
const statusDotColor = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending'
  if (value === 'draft') return '#64748b'
  if (value === 'customer_submitted') return '#3f51b5'
  if (value === 'in_review') return '#9a6a24'
  if (value === 'offered') return '#3f67b3'
  if (value === 'accepted') return '#059669'
  if (value === 'po_placed') return '#2f8b5d'
  if (value === 'cancelled') return '#a64c62'
  return '#64748b'
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

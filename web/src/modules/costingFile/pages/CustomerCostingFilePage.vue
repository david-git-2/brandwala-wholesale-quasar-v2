<template>
  <q-page class="bw-page theme-shop">
    <section class="bw-page__stack costing-page">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Shop Costing File</div>
          <h1 class="text-h5 q-my-none">Customer costing files</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            label="Create costing file"
            :disable="!canCreate"
            :loading="creating"
            @click="createDialog = true"
          />
        </div>
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
            <div class="row items-start justify-between no-wrap">
              <div class="text-overline">Costing file</div>
              <q-chip
                dense
                square
                :color="statusChipColor(file.status)"
                text-color="white"
                class="costing-page__status-chip"
              >
                {{ file.status }}
              </q-chip>
            </div>
            <div class="text-subtitle1">{{ file.name }}</div>
            <div class="text-body2 text-grey-7">Market: {{ file.market || 'Not set' }}</div>
          </q-card-section>
          <q-card-actions v-if="file.status === 'draft'" align="right">
            <q-btn
              flat
              dense
              round
              color="negative"
              icon="delete"
              aria-label="Delete costing file"
              :loading="deletingFileId === file.id"
              @click.stop="handleDelete(file.id)"
            />
          </q-card-actions>
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

      <q-dialog v-model="createDialog" persistent>
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Create costing file</div>
          </q-card-section>

          <q-card-section class="text-body2">
            A draft file will be created for
            <strong>{{ customerGroupName }}</strong>
            with an auto-generated name.
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="createDialog = false" />
            <q-btn
              color="primary"
              unelevated
              label="Create"
              :loading="creating"
              :disable="!canCreate"
              @click="handleCreate"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import { handleApiFailure } from 'src/utils/appFeedback'

const router = useRouter()
const authStore = useAuthStore()
const costingFileStore = useCostingFileStore()
const { items: files, listLoading: loadingFiles, totalItems } = storeToRefs(costingFileStore)
const createDialog = ref(false)
const creating = ref(false)
const deletingFileId = ref<number | null>(null)
const page = ref(1)
const pageSize = 20

const cardAccentColor = computed(
  () => authStore.customerGroup?.accentColor?.trim() || 'var(--bw-theme-primary)',
)
const statusChipColor = (status: string) => {
  if (status === 'draft') return 'grey-7'
  if (status === 'customer_submitted') return 'indigo'
  if (status === 'in_review') return 'amber-8'
  if (status === 'offered') return 'positive'
  return 'primary'
}
const customerGroupName = computed(() => authStore.customerGroup?.name?.trim() || 'Customer group')
const canCreate = computed(() => Boolean(authStore.customerGroupId && authStore.tenantId))
const totalPages = computed(() => Math.max(1, Math.ceil((totalItems.value || 0) / pageSize)))

const subtitle = computed(() =>
  authStore.customerGroup?.name
    ? `${authStore.customerGroup.name} can open costing files here.`
    : 'Customer group access is required.',
)

const formatFileDate = () => {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const buildCustomerFileName = () => `${customerGroupName.value} ${formatFileDate()}`

const loadFiles = async () => {
  const customerGroupId = authStore.customerGroupId
  const tenantId = authStore.tenantId

  if (!customerGroupId || !tenantId) {
    costingFileStore.items = []
    costingFileStore.totalItems = 0
    return
  }

  await costingFileStore.fetchCostingFilesByCustomerGroup(customerGroupId, tenantId, {
    page: page.value,
    pageSize,
  })
}

const handlePageChange = async () => {
  await loadFiles()
}

const handleCreate = async () => {
  const customerGroupId = authStore.customerGroupId
  const tenantId = authStore.tenantId

  if (!customerGroupId || !tenantId) {
    return
  }

  creating.value = true
  try {
    const result = await costingFileStore.createCostingFile({
      tenantId,
      customerGroupId,
      name: buildCustomerFileName(),
      market: '',
    })

    if (!result.success || !result.data) {
      handleApiFailure(result, 'Failed to create costing file.')
      return
    }

    createDialog.value = false
    await loadFiles()
    await openFile(result.data.id)
  } finally {
    creating.value = false
  }
}

const handleDelete = async (id: number) => {
  deletingFileId.value = id
  try {
    const result = await costingFileStore.deleteCostingFile({ id })

    if (!result.success) {
      handleApiFailure(result, 'Failed to delete costing file.')
      return
    }

    await loadFiles()
  } finally {
    deletingFileId.value = null
  }
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
.costing-page__dialog {
  width: min(440px, 92vw);
}
.costing-page__pagination {
  display: flex;
  justify-content: center;
  padding-top: 0.5rem;
}
.costing-page__empty { color: var(--bw-theme-muted); }
@media (max-width: 900px) {
  .costing-page__card-grid { grid-template-columns: 1fr; }
}
</style>

<template>
  <q-page class="bw-page theme-app">
    <section class="bw-page__stack viewer-page">
      <section class="viewer-page__header">
        <div>
          <div class="text-overline">Costing File</div>
          <h1 class="text-h5 q-my-none">Manage viewers</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ subtitle }}
          </p>
        </div>

        <q-btn
          outline
          color="primary"
          icon="arrow_back"
          label="Back to file"
          :disable="!selectedFile"
          @click="goBackToFile"
        />
      </section>

      <q-card v-if="pageLoading" flat bordered>
        <q-card-section class="text-grey-7">Loading viewer access...</q-card-section>
      </q-card>

      <template v-else-if="selectedFile">
        <q-card flat bordered class="viewer-page__summary-card">
          <q-card-section class="viewer-page__summary-grid">
            <div>
              <div class="text-caption text-grey-7">File</div>
              <div class="text-body1">#{{ selectedFile.id }} {{ selectedFile.name }}</div>
            </div>
            <div>
              <div class="text-caption text-grey-7">Market</div>
              <div class="text-body1">{{ selectedFile.market || 'Not set' }}</div>
            </div>
            <div>
              <div class="text-caption text-grey-7">Status</div>
              <div class="text-body1">{{ formatStatusLabel(selectedFile.status) }}</div>
            </div>
            <div>
              <div class="text-caption text-grey-7">Viewers assigned</div>
              <div class="text-body1">{{ assignedCount }}</div>
            </div>
          </q-card-section>
        </q-card>

        <q-card flat bordered>
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-h6">Tenant viewers</div>
              <div class="text-caption text-grey-7">
                Add or remove viewer access for this costing file.
              </div>
            </div>
          </q-card-section>

          <q-separator />

          <q-card-section v-if="viewerRows.length === 0" class="text-grey-7">
            No viewers found for this tenant.
          </q-card-section>

          <q-table
            v-else
            flat
            bordered
            row-key="membership_id"
            :rows="viewerRows"
            :columns="viewerColumns"
            :loading="viewerLoading"
            :pagination="{ rowsPerPage: 0 }"
            hide-bottom
            class="viewer-page__table"
          >
            <template #body-cell-name="props">
              <q-td :props="props">
                <div class="text-weight-medium">{{ props.row.name }}</div>
                <div class="text-caption text-grey-7">{{ props.row.email }}</div>
              </q-td>
            </template>

            <template #body-cell-role="props">
              <q-td :props="props">
                <q-badge color="blue-1" text-color="blue-10" outline>
                  {{ props.row.role }}
                </q-badge>
              </q-td>
            </template>

            <template #body-cell-active="props">
              <q-td :props="props">
                <q-badge :color="props.row.is_active ? 'positive' : 'grey-6'">
                  {{ props.row.is_active ? 'Active' : 'Inactive' }}
                </q-badge>
              </q-td>
            </template>

            <template #body-cell-assigned="props">
              <q-td :props="props">
                <q-badge :color="props.row.isAssigned ? 'positive' : 'grey-6'">
                  {{ props.row.isAssigned ? 'Assigned' : 'Not assigned' }}
                </q-badge>
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props">
                <q-btn
                  v-if="props.row.isAssigned"
                  flat
                  dense
                  color="negative"
                  icon="remove_circle"
                  label="Remove"
                  :loading="savingMembershipId === props.row.membership_id"
                  :disable="savingMembershipId !== null"
                  @click="handleRemoveViewer(props.row.membership_id)"
                />
                <q-btn
                  v-else
                  flat
                  dense
                  color="primary"
                  icon="person_add"
                  label="Add"
                  :loading="savingMembershipId === props.row.membership_id"
                  :disable="savingMembershipId !== null || !props.row.is_active"
                  @click="handleAddViewer(props.row.membership_id)"
                />
              </q-td>
            </template>
          </q-table>
        </q-card>
      </template>

      <q-card v-else flat bordered>
        <q-card-section class="text-grey-7">Costing file not found.</q-card-section>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute, useRouter } from 'vue-router'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { TenantViewer } from 'src/modules/costingFile/types'

type ViewerRow = TenantViewer & {
  isAssigned: boolean
}

const route = useRoute()
const router = useRouter()
const costingFileStore = useCostingFileStore()
const { selectedItem: selectedFile, costingFileViewers, tenantViewers, viewerLoading } =
  storeToRefs(costingFileStore)

const pageLoading = ref(false)
const savingMembershipId = ref<number | null>(null)

const subtitle = computed(() =>
  selectedFile.value
    ? `Assign viewers who can see ${selectedFile.value.name}.`
    : 'Loading costing file viewer access.',
)

const assignedMembershipIds = computed(
  () => new Set(costingFileViewers.value.map((viewer) => viewer.membership_id)),
)

const assignedCount = computed(() => assignedMembershipIds.value.size)

const viewerRows = computed<ViewerRow[]>(() =>
  tenantViewers.value.map((viewer) => ({
    ...viewer,
    isAssigned: assignedMembershipIds.value.has(viewer.membership_id),
  })),
)

const viewerColumns = [
  { name: 'name', label: 'Viewer', field: 'name', align: 'left' as const },
  { name: 'role', label: 'Role', field: 'role', align: 'left' as const },
  { name: 'active', label: 'Status', field: 'is_active', align: 'left' as const },
  { name: 'assigned', label: 'Access', field: 'isAssigned', align: 'left' as const },
  { name: 'actions', label: 'Actions', field: 'membership_id', align: 'right' as const },
]

const formatStatusLabel = (status: string) =>
  status
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())

const loadPage = async () => {
  const fileId = Number(route.params.id)

  if (!Number.isFinite(fileId) || fileId <= 0) {
    await router.replace({ name: 'admin-costing-file-page' })
    return
  }

  pageLoading.value = true
  try {
    const fileResult = await costingFileStore.fetchCostingFileById(fileId)

    if (!fileResult.success || !fileResult.data) {
      await router.replace({ name: 'admin-costing-file-page' })
      return
    }

    await Promise.all([
      costingFileStore.fetchCostingFileViewers(fileId),
      costingFileStore.fetchTenantViewers(fileResult.data.tenant_id),
    ])
  } finally {
    pageLoading.value = false
  }
}

const refreshViewers = async () => {
  if (!selectedFile.value) {
    return
  }

  await Promise.all([
    costingFileStore.fetchCostingFileViewers(selectedFile.value.id),
    costingFileStore.fetchTenantViewers(selectedFile.value.tenant_id),
  ])
}

const handleAddViewer = async (membershipId: number) => {
  if (!selectedFile.value) {
    return
  }

  savingMembershipId.value = membershipId
  try {
    const result = await costingFileStore.grantCostingFileViewer({
      costingFileId: selectedFile.value.id,
      membershipId,
    })

    if (result.success) {
      await refreshViewers()
    }
  } finally {
    savingMembershipId.value = null
  }
}

const handleRemoveViewer = async (membershipId: number) => {
  if (!selectedFile.value) {
    return
  }

  savingMembershipId.value = membershipId
  try {
    const result = await costingFileStore.revokeCostingFileViewer({
      costingFileId: selectedFile.value.id,
      membershipId,
    })

    if (result.success) {
      await refreshViewers()
    }
  } finally {
    savingMembershipId.value = null
  }
}

const goBackToFile = async () => {
  if (!selectedFile.value) {
    await router.replace({ name: 'admin-costing-file-page' })
    return
  }

  await router.push({
    name: 'admin-costing-file-details-page',
    params: { id: String(selectedFile.value.id) },
  })
}

onMounted(async () => {
  await loadPage()
})
</script>

<style scoped>
.viewer-page {
  display: grid;
  gap: 1rem;
}

.viewer-page__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.viewer-page__summary-card {
  border-left: 4px solid var(--bw-theme-primary);
}

.viewer-page__summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 1rem;
}

.viewer-page__table {
  min-width: 0;
}
</style>

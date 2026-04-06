<template>
  <q-page class="bw-page theme-app">
    <section class="bw-page__stack costing-page">
      <section class="row items-start justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Costing File</div>
          <h1 class="text-h5 q-my-none">Staff costing files</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            label="Create costing file"
            :disable="!tenantStore.selectedTenant?.id"
            @click="createDialog = true"
          />
        </div>
      </section>

      <section class="row items-end q-col-gutter-md">
        <div class="col-12 col-sm-5 col-md-4">
          <q-select
            v-model="selectedCustomerGroupId"
            label="Customer group"
            outlined
            dense
            emit-value
            map-options
            :options="customerGroupFilterOptions"
            @update:model-value="handleFilterChange"
          />
        </div>
        <div class="col-auto text-body2 text-grey-7">
          Showing {{ files.length }} of {{ totalItems }} files
        </div>
      </section>

      <template v-if="files.length">
        <section class="costing-page__grid">
          <q-card
            v-for="file in files"
            :key="file.id"
            flat
            bordered
            class="costing-page__card"
            :class="{ 'cursor-pointer': canOpenFile(file.status) }"
            :style="{ '--costing-card-accent': customerGroupAccentColorById(file.customer_group_id) }"
            @click="canOpenFile(file.status) && openFile(file.id)"
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
              <div class="text-overline q-mt-xs">Costing file #{{ file.id }}</div>
              <div class="text-subtitle1">#{{ file.id }} {{ file.name }}</div>
              <div class="text-body2 text-grey-7">{{ file.market || 'Not set' }}</div>
              <div class="text-caption q-mt-xs text-grey-7">
                {{ customerGroupNameById(file.customer_group_id) }}
              </div>
              <div class="text-caption q-mt-xs text-grey-7">
                Created by: {{ file.created_by_label || file.created_by_email || 'Unknown' }}
              </div>
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
      </template>

      <q-card v-else-if="loadingFiles" flat bordered>
        <q-card-section class="text-grey-7">Loading costing files...</q-card-section>
      </q-card>

      <q-card v-else flat bordered>
        <q-card-section class="text-center">
          <div class="text-subtitle1">No costing files found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">
            Select another customer group or create a new costing file.
          </div>
        </q-card-section>
      </q-card>

      <q-dialog v-model="createDialog" persistent>
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Create costing file</div>
          </q-card-section>

          <q-card-section class="costing-page__dialog-body">
            <q-input v-model="createForm.name" label="Name" outlined dense />
            <q-input v-model="createForm.market" label="Market" outlined dense />
            <q-select
              v-model="createForm.customerGroupId"
              label="Customer group"
              outlined
              dense
              emit-value
              map-options
              :options="customerGroupOptions"
            />
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="createDialog = false" />
            <q-btn color="primary" unelevated label="Create" :loading="creating" :disable="!canCreate" @click="handleCreate" />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import { customerGroupService } from 'src/modules/tenant/services/customerGroupService'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'

const router = useRouter()
const tenantStore = useTenantStore()
const costingFileStore = useCostingFileStore()
const { items: files, totalItems, listLoading: loadingFiles } = storeToRefs(costingFileStore)

const selectedCustomerGroupId = ref<number | null>(null)
const page = ref(1)
const pageSize = 20
const createDialog = ref(false)
const creating = ref(false)

const customerGroupOptions = ref<{ label: string; value: number; accentColor: string | null }[]>([])
const createForm = reactive({
  name: '',
  market: '',
  customerGroupId: null as number | null,
})

const subtitle = computed(() =>
  tenantStore.selectedTenant?.name
    ? `${tenantStore.selectedTenant.name} staff can create costing files and send them to review here.`
    : 'Select a tenant to browse costing files.',
)

const totalPages = computed(() => Math.max(1, Math.ceil((totalItems.value || 0) / pageSize)))
const customerGroupFilterOptions = computed(() => [
  { label: 'All customer groups', value: null },
  ...customerGroupOptions.value,
])

const canCreate = computed(
  () =>
    Boolean(tenantStore.selectedTenant?.id) &&
    Boolean(createForm.customerGroupId) &&
    createForm.name.trim().length > 0 &&
    createForm.market.trim().length > 0,
)

const customerGroupNameById = (customerGroupId: number) =>
  customerGroupOptions.value.find((option) => option.value === customerGroupId)?.label ?? `#${customerGroupId}`
const customerGroupAccentColorById = (customerGroupId: number) =>
  customerGroupOptions.value.find((option) => option.value === customerGroupId)?.accentColor?.trim() ||
  'var(--bw-theme-primary)'
const statusChipColor = (status: string) => {
  if (status === 'draft') return 'grey-7'
  if (status === 'customer_submitted') return 'indigo'
  if (status === 'in_review') return 'amber-8'
  if (status === 'offered') return 'positive'
  return 'primary'
}
const formatStatusLabel = (status: string) =>
  status
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())

const loadFiles = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    costingFileStore.items = []
    costingFileStore.totalItems = 0
    return
  }

  await costingFileStore.fetchCostingFilesByTenant(tenantId, {
    customerGroupId: selectedCustomerGroupId.value,
    page: page.value,
    pageSize,
  })
}

const getStaffListStateKey = (tenantId: number) =>
  `costingFile.staff.listState.v1.tenant.${tenantId}`

const saveStaffListState = () => {
  const tenantId = tenantStore.selectedTenant?.id
  if (!tenantId || typeof window === 'undefined') {
    return
  }

  window.localStorage.setItem(
    getStaffListStateKey(tenantId),
    JSON.stringify({
      selectedCustomerGroupId: selectedCustomerGroupId.value,
      page: page.value,
    }),
  )
}

const loadStaffListState = () => {
  const tenantId = tenantStore.selectedTenant?.id
  if (!tenantId || typeof window === 'undefined') {
    selectedCustomerGroupId.value = null
    page.value = 1
    return
  }

  const raw = window.localStorage.getItem(getStaffListStateKey(tenantId))
  if (!raw) {
    selectedCustomerGroupId.value = null
    page.value = 1
    return
  }

  try {
    const parsed = JSON.parse(raw) as {
      selectedCustomerGroupId?: number | null
      page?: number
    }
    selectedCustomerGroupId.value =
      typeof parsed.selectedCustomerGroupId === 'number'
        ? parsed.selectedCustomerGroupId
        : null
    page.value = Number.isFinite(parsed.page) && Number(parsed.page) > 0 ? Number(parsed.page) : 1
  } catch {
    selectedCustomerGroupId.value = null
    page.value = 1
  }
}

const loadCustomerGroups = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    customerGroupOptions.value = []
    createForm.customerGroupId = null
    return
  }

  const result = await customerGroupService.listCustomerGroupsByTenant(tenantId)

  if (!result.success) {
    customerGroupOptions.value = []
    createForm.customerGroupId = null
    return
  }

  customerGroupOptions.value = (result.data ?? []).map((group) => ({
    label: group.name,
    value: group.id,
    accentColor: group.accent_color ?? null,
  }))

  if (!createForm.customerGroupId) {
    createForm.customerGroupId = customerGroupOptions.value[0]?.value ?? null
  }
}

const resetCreateForm = () => {
  createForm.name = ''
  createForm.market = ''
  createForm.customerGroupId = customerGroupOptions.value[0]?.value ?? null
}

const handleCreate = async () => {
  const tenantId = tenantStore.selectedTenant?.id
  const customerGroupId = createForm.customerGroupId

  if (!tenantId || !customerGroupId) {
    return
  }

  creating.value = true
  try {
    const result = await costingFileStore.createCostingFile({
      tenantId,
      customerGroupId,
      name: createForm.name.trim(),
      market: createForm.market.trim(),
      status: 'customer_submitted',
    })

    if (result.success && result.data) {
      resetCreateForm()
      createDialog.value = false
      await router.push({
        name: 'staff-costing-file-details-page',
        params: { id: String(result.data.id) },
      })
    }
  } finally {
    creating.value = false
  }
}

const canOpenFile = (status: string) => status === 'customer_submitted'

const openFile = async (id: number) => {
  await router.push({
    name: 'staff-costing-file-details-page',
    params: { id: String(id) },
  })
}

const handleFilterChange = async () => {
  page.value = 1
  saveStaffListState()
  await loadFiles()
}

const handlePageChange = async () => {
  saveStaffListState()
  await loadFiles()
}

watch(createDialog, (isOpen) => {
  if (!isOpen) {
    resetCreateForm()
  }
})

watch(
  () => tenantStore.selectedTenant?.id ?? null,
  async () => {
    loadStaffListState()
    await loadCustomerGroups()
    await loadFiles()
    createDialog.value = false
  },
)

onMounted(async () => {
  loadStaffListState()
  await loadCustomerGroups()
  await loadFiles()
})
</script>

<style scoped>
.costing-page {
  display: grid;
  gap: 1.25rem;
}

.costing-page__grid {
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
}

.costing-page__dialog {
  min-width: min(520px, 92vw);
}

.costing-page__dialog-body {
  display: grid;
  gap: 1rem;
}

@media (max-width: 599px) {
  .costing-page__grid {
    grid-template-columns: 1fr;
  }
}
</style>

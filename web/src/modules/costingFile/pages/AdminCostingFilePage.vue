<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Operations</div>
          <h1 class="text-h5 q-my-none">Costing files</h1>
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

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <q-card v-if="!tenantStore.selectedTenant" flat bordered>
        <q-card-section class="text-grey-7">
          Select a tenant to load costing files.
        </q-card-section>
      </q-card>

      <section v-else-if="files.length" class="costing-page__grid">
        <q-card
          v-for="file in files"
          :key="file.id"
          flat
          bordered
          class="costing-page__card cursor-pointer"
          :style="{ '--costing-card-accent': customerGroupAccentColorById(file.customer_group_id) }"
          @click="openFile(file.id)"
        >
          <q-card-section>
            <div class="text-overline">Costing file #{{ file.id }}</div>
            <div class="text-subtitle1">{{ file.name }}</div>
            <div class="text-body2 text-grey-7">{{ file.market }}</div>
            <div class="text-caption q-mt-xs text-grey-7">
              {{ customerGroupNameById(file.customer_group_id) }}
            </div>
          </q-card-section>
          <q-card-actions align="right">
            <q-btn flat round dense icon="edit" aria-label="Edit costing file" @click.stop="openEditDialog(file.id)" />
            <q-btn flat round dense color="negative" icon="delete" aria-label="Delete costing file" @click.stop="openDeleteDialog(file.id)" />
          </q-card-actions>
        </q-card>
      </section>

      <q-card v-else-if="!loadingFiles" flat bordered>
        <q-card-section class="text-center">
          <div class="text-subtitle1">No costing files found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">
            Create a costing file to get started.
          </div>
        </q-card-section>
      </q-card>

      <q-card v-else flat bordered>
        <q-card-section class="text-grey-7">Loading costing files...</q-card-section>
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

      <q-dialog v-model="editDialog" persistent @hide="closeEditDialog">
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Edit costing file</div>
          </q-card-section>

          <q-card-section class="costing-page__dialog-body">
            <q-input v-model="editForm.name" label="Name" outlined dense />
            <q-input v-model="editForm.market" label="Market" outlined dense />
            <q-select
              v-model="editForm.customerGroupId"
              label="Customer group"
              outlined
              dense
              emit-value
              map-options
              :options="customerGroupOptions"
            />
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="closeEditDialog" />
            <q-btn color="primary" unelevated label="Save" :loading="editing" :disable="!canEdit" @click="handleEdit" />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <q-dialog v-model="deleteDialog" persistent @hide="closeDeleteDialog">
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Delete costing file</div>
          </q-card-section>

          <q-card-section>
            <div class="text-body2">
              Delete
              <strong>{{ filePendingDelete?.name ?? 'this costing file' }}</strong>
              ?
            </div>
            <div class="text-body2 text-grey-7 q-mt-sm">
              This will also delete all related costing file items.
            </div>
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="closeDeleteDialog" />
            <q-btn color="negative" unelevated label="Delete" :loading="deleting" @click="handleDelete" />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import { customerGroupService } from 'src/modules/tenant/services/customerGroupService'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { handleApiFailure } from 'src/utils/appFeedback'

const router = useRouter()
const tenantStore = useTenantStore()
const costingFileStore = useCostingFileStore()
const { items: files, listLoading: loadingFiles, error } = storeToRefs(costingFileStore)

const creating = ref(false)
const editing = ref(false)
const deleting = ref(false)
const createDialog = ref(false)
const editDialog = ref(false)
const deleteDialog = ref(false)
const editingFileId = ref<number | null>(null)
const deletingFileId = ref<number | null>(null)

const customerGroupOptions = ref<{ label: string; value: number; accentColor: string | null }[]>([])

const createForm = reactive({
  name: '',
  market: '',
  customerGroupId: null as number | null,
})

const editForm = reactive({
  name: '',
  market: '',
  customerGroupId: null as number | null,
})

const canCreate = computed(
  () =>
    Boolean(tenantStore.selectedTenant?.id) &&
    Boolean(createForm.customerGroupId) &&
    createForm.name.trim().length > 0 &&
    createForm.market.trim().length > 0,
)

const canEdit = computed(
  () =>
    Boolean(editingFileId.value) &&
    Boolean(editForm.customerGroupId) &&
    editForm.name.trim().length > 0 &&
    editForm.market.trim().length > 0,
)

const customerGroupNameById = (customerGroupId: number) =>
  customerGroupOptions.value.find((option) => option.value === customerGroupId)?.label ?? `#${customerGroupId}`
const customerGroupAccentColorById = (customerGroupId: number) =>
  customerGroupOptions.value.find((option) => option.value === customerGroupId)?.accentColor?.trim() ||
  'var(--bw-theme-primary)'

const filePendingDelete = computed(
  () => files.value.find((file) => file.id === deletingFileId.value) ?? null,
)

const resetCreateForm = () => {
  createForm.name = ''
  createForm.market = ''
  createForm.customerGroupId = customerGroupOptions.value[0]?.value ?? null
}

const resetEditForm = () => {
  editForm.name = ''
  editForm.market = ''
  editForm.customerGroupId = customerGroupOptions.value[0]?.value ?? null
}

const loadCustomerGroupContext = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    customerGroupOptions.value = []
    resetCreateForm()
    return
  }

  const result = await customerGroupService.listCustomerGroupsByTenant(tenantId)

  if (!result.success) {
    handleApiFailure(result, 'Failed to load customer groups for costing file creation.')
    customerGroupOptions.value = []
    resetCreateForm()
    return
  }

  customerGroupOptions.value = (result.data ?? []).map((group) => ({
    label: group.name,
    value: group.id,
    accentColor: group.accent_color ?? null,
  }))
  resetCreateForm()
  resetEditForm()
}

const loadFiles = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    costingFileStore.items = []
    return
  }

  await costingFileStore.fetchCostingFilesByTenant(tenantId)
}

const loadPageData = async () => {
  await loadCustomerGroupContext()
  await loadFiles()
}

const openFile = async (id: number) => {
  await router.push({
    name: 'admin-costing-file-details-page',
    params: { id: String(id) },
  })
}

const openEditDialog = (id: number) => {
  const file = files.value.find((item) => item.id === id)

  if (!file) {
    return
  }

  editingFileId.value = file.id
  editForm.name = file.name
  editForm.market = file.market
  editForm.customerGroupId = file.customer_group_id
  editDialog.value = true
}

const closeEditDialog = () => {
  editDialog.value = false
  editingFileId.value = null
  resetEditForm()
}

const openDeleteDialog = (id: number) => {
  deletingFileId.value = id
  deleteDialog.value = true
}

const closeDeleteDialog = () => {
  deleteDialog.value = false
  deletingFileId.value = null
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
    })

    if (!result.success || !result.data) {
      handleApiFailure(result, 'Failed to create costing file.')
      return
    }

    resetCreateForm()
    createDialog.value = false
    await loadFiles()
    await openFile(result.data.id)
  } finally {
    creating.value = false
  }
}

const handleEdit = async () => {
  const id = editingFileId.value
  const customerGroupId = editForm.customerGroupId

  if (!id || !customerGroupId) {
    return
  }

  editing.value = true
  try {
    const result = await costingFileStore.updateCostingFile({
      id,
      name: editForm.name.trim(),
      market: editForm.market.trim(),
      customerGroupId,
    })

    if (!result.success) {
      handleApiFailure(result, 'Failed to update costing file.')
      return
    }

    closeEditDialog()
    await loadFiles()
  } finally {
    editing.value = false
  }
}

const handleDelete = async () => {
  const id = deletingFileId.value

  if (!id) {
    return
  }

  deleting.value = true
  try {
    const result = await costingFileStore.deleteCostingFile({ id })

    if (!result.success) {
      handleApiFailure(result, 'Failed to delete costing file.')
      return
    }

    closeDeleteDialog()
    await loadFiles()
  } finally {
    deleting.value = false
  }
}

watch(
  () => tenantStore.selectedTenant?.id ?? null,
  async () => {
    createDialog.value = false
    closeEditDialog()
    closeDeleteDialog()
    await loadPageData()
  },
  { immediate: true },
)
</script>

<style scoped>
.costing-page__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 260px));
  gap: 0.75rem;
}

.costing-page__card {
  width: 100%;
  border-left: 4px solid var(--costing-card-accent, var(--bw-theme-primary));
}

.costing-page__dialog {
  min-width: min(520px, 92vw);
}

.costing-page__dialog-body { display: grid; gap: 1rem; }

@media (max-width: 599px) {
  .costing-page__grid {
    grid-template-columns: 1fr;
  }
}
</style>

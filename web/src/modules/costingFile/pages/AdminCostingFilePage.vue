<template>
  <q-page class="bw-page theme-app">
    <section class="bw-page__stack costing-page">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Costing File</div>
          <h1 class="text-h5 q-my-none">Admin costing files</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" unelevated label="Create costing file" @click="createDialog = true" />
        </div>
      </section>

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Costing file list</div>
          <div class="text-body2 text-grey-7">{{ createCaption }}</div>
        </q-card-section>

        <q-card-section v-if="loadingFiles" class="text-grey-7">Loading costing files...</q-card-section>
        <q-card-section v-else-if="!files.length" class="text-grey-7">No costing files yet.</q-card-section>
        <q-card-section v-else>
          <div class="costing-page__card-grid">
            <q-card
              v-for="file in files"
              :key="file.id"
              flat
              bordered
              class="cursor-pointer"
              @click="openFile(file.id)"
            >
              <q-card-section>
                <div class="text-overline">Costing file</div>
                <div class="text-subtitle1">{{ file.name }}</div>
                <div class="text-body2 text-grey-7">Market: {{ file.market }}</div>
                <div class="text-body2 text-grey-7">Customer group: {{ customerGroupNameById(file.customer_group_id) }}</div>
              </q-card-section>
            </q-card>
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
import { computed, onMounted, reactive, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import { customerGroupService } from 'src/modules/tenant/services/customerGroupService'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { handleApiFailure } from 'src/utils/appFeedback'

const router = useRouter()
const tenantStore = useTenantStore()
const costingFileStore = useCostingFileStore()
const { items: files, listLoading: loadingFiles } = storeToRefs(costingFileStore)

const creating = ref(false)
const createDialog = ref(false)

const customerGroupOptions = ref<{ label: string; value: number }[]>([])

const createForm = reactive({
  name: '',
  market: '',
  customerGroupId: null as number | null,
})

const subtitle = computed(() =>
  tenantStore.selectedTenant?.name
    ? `${tenantStore.selectedTenant.name} admin can create and manage costing files here.`
    : 'Select a tenant to manage costing files.',
)

const createCaption = computed(() => {
  if (!tenantStore.selectedTenant) {
    return 'Select a tenant first.'
  }

  if (!customerGroupOptions.value.length) {
    return 'Create a customer group first before creating costing files.'
  }

  return 'Click a costing file card to open its details page.'
})

const canCreate = computed(
  () =>
    Boolean(tenantStore.selectedTenant?.id) &&
    Boolean(createForm.customerGroupId) &&
    createForm.name.trim().length > 0 &&
    createForm.market.trim().length > 0,
)

const customerGroupNameById = (customerGroupId: number) =>
  customerGroupOptions.value.find((option) => option.value === customerGroupId)?.label ?? `#${customerGroupId}`

const loadCustomerGroupContext = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    customerGroupOptions.value = []
    createForm.customerGroupId = null
    return
  }

  const result = await customerGroupService.listCustomerGroupsByTenant(tenantId)

  if (!result.success) {
    handleApiFailure(result, 'Failed to load customer groups for costing file creation.')
    customerGroupOptions.value = []
    createForm.customerGroupId = null
    return
  }

  customerGroupOptions.value = (result.data ?? []).map((group) => ({
    label: group.name,
    value: group.id,
  }))
  createForm.customerGroupId = customerGroupOptions.value[0]?.value ?? null
}

const loadFiles = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    costingFileStore.items = []
    return
  }

  await costingFileStore.fetchCostingFilesByTenant(tenantId)
}

const openFile = async (id: number) => {
  await router.push({
    name: 'admin-costing-file-details-page',
    params: { id: String(id) },
  })
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

    createForm.name = ''
    createForm.market = ''
    createForm.customerGroupId = customerGroupOptions.value[0]?.value ?? null
    createDialog.value = false
    await loadFiles()
    await openFile(result.data.id)
  } finally {
    creating.value = false
  }
}

onMounted(async () => {
  await loadCustomerGroupContext()
  await loadFiles()
})
</script>

<style scoped>
.costing-page { display: grid; gap: 1.25rem; }
.costing-page__card-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; }
.costing-page__empty { color: var(--bw-theme-muted); }
.costing-page__dialog { min-width: min(520px, 92vw); }
.costing-page__dialog-body { display: grid; gap: 1rem; }
@media (max-width: 900px) {
  .costing-page__card-grid { grid-template-columns: 1fr; }
}
</style>

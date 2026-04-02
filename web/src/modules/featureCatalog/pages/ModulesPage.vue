<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Catalog</div>
          <h1 class="text-h5 q-my-none">Modules</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">Manage the module catalog.</p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" unelevated icon="add" label="Add Module" @click="onClickAddModule" />
        </div>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <q-banner
        v-if="missingSeededModules.length"
        class="bg-warning text-dark"
        rounded
      >
        Missing seeded modules:
        {{ missingSeededModules.map((module) => module.name).join(', ') }}.
        Push the Step 3 seed migration if this environment should already have the full master catalog.
      </q-banner>

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Module Catalog</div>
        </q-card-section>

        <q-card-section v-if="items.length">
          <div class="bw-entity-grid">
            <q-card v-for="module in items" :key="module.id" flat bordered>
              <q-card-section>
                <div class="text-overline">{{ module.key }}</div>
                <div class="text-subtitle1">{{ module.name }}</div>
                <div class="text-body2 text-grey-7">{{ buildModuleMeta(module) }}</div>
                <div class="text-body2 q-mt-sm">{{ module.description || 'No description provided yet.' }}</div>
                <div class="row justify-end q-gutter-sm q-mt-md">
                  <q-btn flat round icon="edit" @click.stop="onClickEditModule(module)" />
                  <q-btn
                    flat
                    round
                    icon="delete"
                    color="negative"
                    :disable="isSeededModule(module.key)"
                    @click.stop="onClickDeleteModule(module)"
                  />
                </div>
              </q-card-section>
            </q-card>
          </div>
        </q-card-section>

        <q-card-section v-else-if="!loading" class="text-center">
          <div class="text-subtitle1">No modules found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">Create the first module to define features.</div>
          <q-btn class="q-mt-md" color="primary" unelevated icon="add" label="Create Module" @click="onClickAddModule" />
        </q-card-section>

        <q-card-section v-else class="text-grey-7">Loading modules...</q-card-section>
      </q-card>
    </section>

    <AddModuleDialog
      v-model="openAddDialog"
      :initial-data="selectedModule"
      :existing-modules="items"
      @save="handleSaveModule"
    />

    <q-dialog v-model="openDeleteDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete
          <strong>{{ moduleToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteModule" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'

import { showWarningDialog } from 'src/utils/appFeedback'
import AddModuleDialog from '../components/AddModuleDialog.vue'
import {
  SEEDED_MODULE_DEFINITIONS,
  getSeededModuleDefinition,
  isSeededModuleKey,
} from '../catalogContract'
import { useModuleStore } from '../stores/moduleStore'
import type { Module, ModuleCreateInput, ModuleDeleteInput, ModuleUpdateInput } from '../types'

type ModuleForm = {
  id?: number
  key: string
  name: string
  description: string
  is_active: boolean
}

const moduleStore = useModuleStore()
const { items, loading, error } = storeToRefs(moduleStore)

const openAddDialog = ref(false)
const openDeleteDialog = ref(false)

const selectedModule = ref<ModuleForm | null>(null)
const moduleToDelete = ref<Module | null>(null)
const missingSeededModules = computed(() =>
  SEEDED_MODULE_DEFINITIONS.filter(
    (definition) => !items.value.some((module) => module.key === definition.key),
  ),
)

const onClickAddModule = () => {
  selectedModule.value = null
  openAddDialog.value = true
}

const onClickEditModule = (module: Module) => {
  selectedModule.value = { ...module }
  openAddDialog.value = true
}

const onClickDeleteModule = (module: Module) => {
  if (isSeededModuleKey(module.key)) {
    showWarningDialog(
      'Seeded catalog modules stay protected because their keys are part of the shared module contract. Deactivate the module instead of deleting it.',
      'Seeded module protected',
    )
    return
  }

  moduleToDelete.value = module
  openDeleteDialog.value = true
}

const refreshModules = () => moduleStore.fetchModules()

const isSeededModule = (moduleKey: string) => isSeededModuleKey(moduleKey)

const buildModuleMeta = (module: Module) => {
  const seededDefinition = getSeededModuleDefinition(module.key)

  if (seededDefinition) {
    return `Seeded catalog item | Module #${module.id}`
  }

  return `Custom module | Module #${module.id}`
}

const handleSaveModule = async (payload: ModuleForm) => {
  if (payload.id !== undefined) {
    const updatePayload: ModuleUpdateInput = {
      id: payload.id,
      key: payload.key,
      name: payload.name,
      description: payload.description,
      is_active: payload.is_active,
    }

    await moduleStore.updateModule(updatePayload)
  } else {
    const createPayload: ModuleCreateInput = {
      key: payload.key,
      name: payload.name,
      description: payload.description,
      is_active: payload.is_active,
    }

    await moduleStore.createModule(createPayload)
  }
}

const confirmDeleteModule = async () => {
  if (moduleToDelete.value) {
    const deletePayload: ModuleDeleteInput = {
      id: moduleToDelete.value.id,
    }

    await moduleStore.deleteModule(deletePayload)
  }
  openDeleteDialog.value = false
}

onMounted(() => {
  void refreshModules()
})
</script>

<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <AppPageHeader
        eyebrow="Catalog"
        title="Modules"
        subtitle="Keep module management on the same page flow as tenants with shared actions, cards, and empty-state patterns."
      >
        <template #actions>
          <div class="bw-inline-actions">
            <q-btn
              color="primary"
              unelevated
              icon="add"
              label="Add Module"
              @click="onClickAddModule"
            />
          </div>
        </template>
      </AppPageHeader>

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

      <AppSectionCard
        title="Module Catalog"
        caption="The same entity-card shell is used here so cards, actions, and metadata feel consistent across the workspace."
      >
        <div v-if="items.length" class="bw-entity-grid">
          <AppEntityCard
            v-for="module in items"
            :key="module.id"
            :eyebrow="module.key"
            :title="module.name"
            :meta="buildModuleMeta(module)"
            :description="module.description || 'No description provided yet.'"
            :status-label="module.is_active ? 'Active' : 'Inactive'"
            :status-tone="module.is_active ? 'positive' : isSeededModule(module.key) ? 'warning' : 'neutral'"
          >
            <template #actions>
              <q-btn flat round icon="edit" @click.stop="onClickEditModule(module)" />
              <q-btn
                flat
                round
                icon="delete"
                color="negative"
                :disable="isSeededModule(module.key)"
                @click.stop="onClickDeleteModule(module)"
              />
            </template>
          </AppEntityCard>
        </div>

        <AppEmptyState
          v-else-if="!loading"
          icon="widgets"
          title="No modules found"
          message="Create the first module to define features that can later be assigned to tenants."
        >
          <template #actions>
            <q-btn color="primary" unelevated icon="add" label="Create Module" @click="onClickAddModule" />
          </template>
        </AppEmptyState>

        <div v-else class="bw-text-muted">Loading modules...</div>
      </AppSectionCard>
    </div>

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

import AppEmptyState from 'src/components/ui/AppEmptyState.vue'
import AppEntityCard from 'src/components/ui/AppEntityCard.vue'
import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import AppSectionCard from 'src/components/ui/AppSectionCard.vue'
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

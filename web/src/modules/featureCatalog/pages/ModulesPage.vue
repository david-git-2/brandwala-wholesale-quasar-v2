<template>
  <q-page class="q-pa-lg">
    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <div class="row q-col-gutter-md">
      <div
        v-for="module in items"
        :key="module.id"
        class="col-12 col-sm-6 col-md-4 col-lg-3"
      >
        <q-card class="module-card">
          <q-card-section class="q-pa-md">

            <!-- Name -->
            <div class="text-subtitle1 text-weight-bold q-mb-xs ellipsis-2">
              {{ module.name }}
            </div>

            <!-- Key -->
            <div class="text-caption text-grey-7 q-mb-sm">
              <span class="text-weight-medium">Key:</span>
              {{ module.key }}
            </div>

            <!-- Description -->
            <div class="text-body2 text-grey-8 description-text ellipsis-3">
              {{ module.description || 'No description provided.' }}
            </div>

          </q-card-section>

          <q-space />

          <q-separator />

          <!-- Actions -->
          <q-card-actions align="between" class="q-px-md q-py-sm">
            <q-btn
              flat
              round
              icon="edit"
              @click.stop="onClickEditModule(module)"
            />
            <q-btn
              flat
              round
              icon="delete"
              color="negative"
              @click.stop="onClickDeleteModule(module)"
            />
          </q-card-actions>
        </q-card>
      </div>
    </div>

    <div v-if="!loading && items.length === 0" class="text-grey-7 q-mt-lg">
      No modules found.
    </div>

    <q-page-sticky position="bottom-right" :offset="[18, 18]">
      <q-btn round color="primary" icon="add" @click="onClickAddModule" />
    </q-page-sticky>

    <AddModuleDialog
      v-model="openAddDialog"
      :initial-data="selectedModule"
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
import { onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'

import AddModuleDialog from '../components/AddModuleDialog.vue'
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

const onClickAddModule = () => {
  selectedModule.value = null
  openAddDialog.value = true
}

const onClickEditModule = (module: Module) => {
  selectedModule.value = { ...module }
  openAddDialog.value = true
}

const onClickDeleteModule = (module: Module) => {
  moduleToDelete.value = module
  openDeleteDialog.value = true
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
  void moduleStore.fetchModules()
})
</script>

<style scoped>
.module-card {
  min-height: 220px;
  display: flex;
  flex-direction: column;
}

.description-text {
  min-height: 60px;
}

.ellipsis-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.ellipsis-3 {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>

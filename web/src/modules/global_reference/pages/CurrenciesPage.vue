<template>
  <ReferenceCatalogPage
    title="Currencies"
    description="Manage global currencies. System rows are protected."
    entity-label="Currency"
    :columns="columns"
    :rows="items"
    :loading="loading"
    :error="error"
    @add="openCreate"
    @edit="(row) => openEdit(row as GlobalCurrency)"
    @delete="(row) => openDelete(row as GlobalCurrency)"
    @refresh="load"
  />

  <AddCurrencyDialog v-model="dialogOpen" :initial-data="selected" @save="handleSave" />

  <q-dialog v-model="deleteOpen" persistent>
    <q-card style="min-width: 350px">
      <q-card-section><div class="text-h6">Confirm Delete</div></q-card-section>
      <q-card-section>Delete <strong>{{ selected?.name }}</strong>?</q-card-section>
      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="deleteOpen = false" />
        <q-btn color="negative" label="Delete" @click="confirmDelete" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { QTableColumn } from 'quasar'
import { handleApiFailure, showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'
import ReferenceCatalogPage from '../components/ReferenceCatalogPage.vue'
import AddCurrencyDialog from '../components/AddCurrencyDialog.vue'
import { globalReferenceRepository } from '../repositories/globalReferenceRepository'
import type { GlobalCurrency, GlobalCurrencyCreateInput, GlobalCurrencyUpdateInput } from '../types'

const items = ref<GlobalCurrency[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const dialogOpen = ref(false)
const deleteOpen = ref(false)
const selected = ref<GlobalCurrency | null>(null)

const columns: QTableColumn[] = [
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'symbol', label: 'Symbol', field: 'symbol', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'country', label: 'Country', field: 'country', align: 'left', sortable: true },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'left', sortable: true },
  { name: 'is_system', label: 'Type', field: 'is_system', align: 'left', sortable: true },
  { name: 'actions', label: 'Actions', field: 'id', align: 'right' },
]

const load = async () => {
  loading.value = true
  error.value = null
  try {
    items.value = await globalReferenceRepository.listCurrencies()
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to load currencies.'
    handleApiFailure({ success: false, error: error.value }, error.value)
  } finally {
    loading.value = false
  }
}

const openCreate = () => {
  selected.value = null
  dialogOpen.value = true
}

const openEdit = (row: GlobalCurrency) => {
  if (row.is_system) {
    showWarningDialog('System currencies cannot be edited.', 'Protected row')
    return
  }
  selected.value = { ...row }
  dialogOpen.value = true
}

const openDelete = (row: GlobalCurrency) => {
  if (row.is_system) {
    showWarningDialog('System currencies cannot be deleted.', 'Protected row')
    return
  }
  selected.value = row
  deleteOpen.value = true
}

const handleSave = async (payload: GlobalCurrencyCreateInput & { id?: number }) => {
  try {
    if (payload.id !== undefined) {
      await globalReferenceRepository.updateCurrency(payload as GlobalCurrencyUpdateInput)
      showSuccessNotification('Currency updated.')
    } else {
      await globalReferenceRepository.createCurrency(payload)
      showSuccessNotification('Currency created.')
    }
    dialogOpen.value = false
    await load()
  } catch (err: unknown) {
    handleApiFailure({ success: false, error: (err as Error).message }, 'Save failed')
  }
}

const confirmDelete = async () => {
  if (!selected.value) return
  try {
    await globalReferenceRepository.deleteCurrency(selected.value.id)
    showSuccessNotification('Currency deleted.')
    deleteOpen.value = false
    await load()
  } catch (err: unknown) {
    handleApiFailure({ success: false, error: (err as Error).message }, 'Delete failed')
  }
}

onMounted(() => void load())
</script>

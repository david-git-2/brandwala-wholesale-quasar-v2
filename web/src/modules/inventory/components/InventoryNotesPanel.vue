<template>
  <q-card flat bordered class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-subtitle1 font-bold row items-center gap-sm">
        <q-icon name="description" color="primary" size="sm" />
        <span>Inventory Notes & History</span>
      </div>
      <q-btn
        flat
        round
        dense
        icon="refresh"
        color="primary"
        :loading="loading"
        @click="loadNotes"
      />
    </div>

    <!-- Notes Timeline -->
    <div v-if="notes.length > 0" class="q-mb-lg">
      <q-timeline color="primary">
        <q-timeline-entry
          v-for="note in notes"
          :key="note.id"
          :title="getCategoryLabel(note.category)"
          :subtitle="formatDate(note.created_at)"
          :color="getCategoryColor(note.category)"
          :icon="getCategoryIcon(note.category)"
        >
          <div class="text-body2 text-weight-medium q-mb-xs" style="white-space: pre-wrap;">
            {{ note.content }}
          </div>
          <div class="text-caption text-grey-7">
            Logged by User
          </div>
        </q-timeline-entry>
      </q-timeline>
    </div>
    <div v-else class="text-center q-py-lg text-grey-6 text-body2">
      <q-icon name="info_outline" size="md" class="q-mb-sm block" style="margin: 0 auto;" />
      No notes recorded for this item.
    </div>

    <!-- Add Note Form -->
    <q-separator class="q-my-md" />
    <q-form ref="formRef" class="q-gutter-sm">
      <div class="row q-col-gutter-sm">
        <div class="col-12 col-sm-6">
          <q-select
            v-model="newNote.category"
            :options="categoryOptions"
            label="Category"
            outlined
            dense
            emit-value
            map-options
          />
        </div>
      </div>
      <q-input
        v-model="newNote.content"
        type="textarea"
        label="Write a note..."
        outlined
        dense
        rows="3"
        :rules="[(v) => !!v?.trim() || 'Note content is required']"
        lazy-rules
      />
      <div class="row justify-end">
        <q-btn
          color="primary"
          label="Add Note"
          icon="add"
          :loading="saving"
          @click="onAddNote"
        />
      </div>
    </q-form>
  </q-card>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import type { QForm } from 'quasar'

import { useInventoryStore } from '../stores/inventoryStore'
import type { InventoryNote, InventoryNoteCategory } from '../types'

const props = defineProps<{
  productId?: number | null | undefined
  inventoryItemId?: number | null | undefined
  movementId?: number | null | undefined
  tenantId?: number | null | undefined
}>()

const inventoryStore = useInventoryStore()
const formRef = ref<QForm | null>(null)

const loading = ref(false)
const saving = ref(false)

const newNote = reactive({
  category: 'general' as InventoryNoteCategory,
  content: '',
})

const notes = computed(() => {
  return [...inventoryStore.notes].sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  )
})

const categoryOptions = [
  { label: 'General Info', value: 'general' },
  { label: 'Packaging Defect', value: 'packaging_defect' },
  { label: 'Product Defect', value: 'product_defect' },
  { label: 'Warehouse Instruction', value: 'warehouse_instruction' },
  { label: 'Transit Loss (Missing/Stolen)', value: 'transit_loss' },
]

const getCategoryLabel = (cat: InventoryNoteCategory) => {
  return categoryOptions.find((o) => o.value === cat)?.label ?? cat
}

const getCategoryColor = (cat: InventoryNoteCategory) => {
  switch (cat) {
    case 'product_defect':
      return 'negative'
    case 'packaging_defect':
      return 'orange'
    case 'transit_loss':
      return 'deep-orange-10'
    case 'warehouse_instruction':
      return 'info'
    default:
      return 'primary'
  }
}

const getCategoryIcon = (cat: InventoryNoteCategory) => {
  switch (cat) {
    case 'product_defect':
      return 'warning'
    case 'packaging_defect':
      return 'all_inbox'
    case 'transit_loss':
      return 'report_off'
    case 'warehouse_instruction':
      return 'assignment'
    default:
      return 'info'
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  return date.toLocaleString()
}

const loadNotes = async () => {
  const tenantId = props.tenantId
  if (!tenantId) return

  loading.value = true
  try {
    const filters: Record<string, unknown> = {}
    const operators: Record<string, 'eq'> = {}

    if (props.productId) {
      filters.product_id = props.productId
      operators.product_id = 'eq'
    } else if (props.inventoryItemId) {
      filters.inventory_item_id = props.inventoryItemId
      operators.inventory_item_id = 'eq'
    } else if (props.movementId) {
      filters.movement_id = props.movementId
      operators.movement_id = 'eq'
    } else {
      // If no ID is passed, don't query
      inventoryStore.notes = []
      return
    }

    await inventoryStore.fetchInventoryNotes({
      tenant_id: tenantId,
      filters,
      operators,
      sortBy: 'id',
      sortOrder: 'desc',
    })
  } finally {
    loading.value = false
  }
}

const onAddNote = async () => {
  const tenantId = props.tenantId
  if (!tenantId) return

  const isValid = await formRef.value?.validate()
  if (!isValid) return

  saving.value = true
  try {
    const payload = {
      tenant_id: tenantId,
      product_id: props.productId ?? null,
      inventory_item_id: props.inventoryItemId ?? null,
      movement_id: props.movementId ?? null,
      category: newNote.category,
      content: newNote.content.trim(),
      created_by: null,
    }

    const result = await inventoryStore.createInventoryNote(payload)
    if (result.success) {
      newNote.content = ''
      formRef.value?.resetValidation()
    }
  } finally {
    saving.value = false
  }
}

watch(
  () => [props.productId, props.inventoryItemId, props.movementId, props.tenantId],
  () => {
    loadNotes()
  },
  { immediate: true }
)
</script>

<template>
  <q-dialog v-model="localModelValue" max-width="800px" style="min-width: 600px;">
    <q-card style="width: 750px; max-width: 95vw; border-radius: 16px;">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">Inventory Batch Details</div>
        <q-space />
        <q-btn
          v-if="item"
          icon="o_delete"
          color="negative"
          flat
          round
          dense
          :disable="!canDeleteBatch"
          class="q-mr-sm"
          @click="onDeleteBatch"
        >
          <q-tooltip v-if="!canDeleteBatch" anchor="top middle" self="bottom middle">
            All quantities must be 0 to delete this batch.
          </q-tooltip>
          <q-tooltip v-else anchor="top middle" self="bottom middle">
            Delete this batch
          </q-tooltip>
        </q-btn>
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section v-if="item" class="q-pt-sm">
        <div class="row q-col-gutter-md">
          <!-- Item image and key details -->
          <div class="col-12 col-sm-4 text-center">
            <q-avatar rounded size="120px" class="bg-grey-2 q-mb-sm shadow-1">
              <img
                :src="item.image_url || 'https://placehold.co/120x120?text=No+Image'"
                alt="Product Image"
                style="object-fit: contain;"
              />
            </q-avatar>
            <div class="text-subtitle1 text-weight-bold">{{ item.name }}</div>
            <div class="text-caption text-grey-7">ID: {{ item.id }}</div>
            <div class="text-caption text-grey-8 q-mt-xs">
              <span class="text-weight-bold">Cost:</span> BDT {{ item.cost ?? '-' }}
            </div>
          </div>

          <!-- Product meta & quantities -->
          <div class="col-12 col-sm-8">
            <q-list dense>
              <q-item>
                <q-item-section>
                  <q-item-label caption>Barcode</q-item-label>
                  <q-item-label class="text-weight-medium">{{ item.barcode ?? '-' }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-item-label caption>Product Code</q-item-label>
                  <q-item-label class="text-weight-medium">{{ item.product_code ?? '-' }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-item-label caption>Shipment Source</q-item-label>
                  <q-item-label class="text-weight-medium">
                    {{ item.shipment?.shipment?.name ? `#${item.shipment.shipment.id} ${item.shipment.shipment.name}` : 'Manual Entry' }}
                  </q-item-label>
                </q-item-section>
              </q-item>
            </q-list>

            <div class="text-subtitle2 q-mt-md q-mb-sm row items-center justify-between">
              <span>Quantities Status</span>
              <q-btn
                v-if="item && draftStock"
                flat
                dense
                no-caps
                color="primary"
                :icon="isEditingQuantities ? 'close' : 'edit'"
                :label="isEditingQuantities ? 'Cancel Edit' : 'Edit Quantities'"
                @click="isEditingQuantities = !isEditingQuantities"
              />
            </div>

            <!-- Read-only View -->
            <div v-if="!isEditingQuantities" class="row q-col-gutter-xs">
              <div v-for="(qty, label) in formattedQuantities" :key="label" class="col-4 text-center">
                <div class="q-pa-xs rounded text-weight-bold border column items-center justify-center" :class="qty.bg" style="min-height: 60px;">
                  <div class="text-caption text-grey-9 text-uppercase" style="font-size: 0.7rem;">{{ label }}</div>
                  <div class="text-subtitle1 font-bold">{{ qty.val }}</div>
                </div>
              </div>
            </div>

            <!-- Edit View -->
            <div v-else-if="draftStock" class="row q-col-gutter-sm bg-grey-1 q-pa-md rounded border">
              <div class="col-12 text-caption text-grey-7 q-mb-xs">
                Modify stock counts directly. Click "Save Quantities" at the bottom to apply.
              </div>
              
              <div class="col-6 col-sm-4">
                <q-input
                  v-model.number="draftStock.available_quantity"
                  type="number"
                  outlined
                  dense
                  bg-color="white"
                  label="Available (Usable) *"
                  min="0"
                />
              </div>
              <div class="col-6 col-sm-4">
                <q-input
                  v-model.number="draftStock.open_box_quantity"
                  type="number"
                  outlined
                  dense
                  bg-color="white"
                  label="Open Box (Usable) *"
                  min="0"
                />
              </div>
              <div class="col-6 col-sm-4">
                <q-input
                  v-model.number="draftStock.reserved_quantity"
                  type="number"
                  outlined
                  dense
                  bg-color="white"
                  label="Reserved"
                  min="0"
                />
              </div>
              <div class="col-6 col-sm-4">
                <q-input
                  v-model.number="draftStock.damaged_quantity"
                  type="number"
                  outlined
                  dense
                  bg-color="white"
                  label="Damaged"
                  min="0"
                />
              </div>
              <div class="col-6 col-sm-4">
                <q-input
                  v-model.number="draftStock.stolen_quantity"
                  type="number"
                  outlined
                  dense
                  bg-color="white"
                  label="Stolen"
                  min="0"
                />
              </div>
              <div class="col-6 col-sm-4">
                <q-input
                  v-model.number="draftStock.expired_quantity"
                  type="number"
                  outlined
                  dense
                  bg-color="white"
                  label="Expired"
                  min="0"
                />
              </div>

              <div class="col-12 row justify-end q-mt-md q-gutter-sm">
                <q-btn flat label="Discard" no-caps color="grey-7" @click="discardStockChanges" />
                <q-btn
                  color="positive"
                  label="Save Quantities"
                  no-caps
                  icon="save"
                  :loading="isSubmitting"
                  :disable="!hasStockChanges"
                  @click="() => void saveStockChanges()"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Stock Actions Button -->
        <q-btn
          flat
          no-caps
          color="primary"
          icon="swap_horiz"
          label="Stock Movement & Split Actions"
          class="full-width q-my-md text-weight-bold pill-btn"
          style="background: rgba(63, 103, 179, 0.06); border-radius: 8px;"
          @click="showMovementForm = !showMovementForm"
        />

        <!-- Stock Action Form Panel -->
        <q-slide-transition>
          <div v-if="showMovementForm" class="q-mb-md q-pa-md border rounded bg-grey-1" style="border-radius: 12px;">
            <div class="text-subtitle2 q-mb-md text-weight-bold row items-center">
              <q-icon name="edit_note" color="primary" size="20px" class="q-mr-sm" />
              Perform Manual Stock Action
            </div>

            <q-select
              v-model="movementAction"
              :options="movementActionOptions"
              emit-value
              map-options
              outlined
              dense
              class="q-mb-md bg-white"
              label="Action Type"
            />

            <!-- Form: Split to New Batch -->
            <div v-if="movementAction === 'split'" class="row q-col-gutter-sm">
              <div class="col-12">
                <q-input
                  :model-value="`#${item.id} - ${item.name} (Available: ${item.quantities.available})`"
                  label="Move From"
                  outlined
                  dense
                  readonly
                  class="q-mb-md bg-grey-2"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="movementForm.condition"
                  :options="conditionOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  class="bg-white"
                  label="Target Split Condition"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="movementForm.nameSuffix"
                  outlined
                  dense
                  class="bg-white"
                  label="Name Suffix"
                />
              </div>
              <div class="col-12 class q-mt-sm text-caption text-grey-8 text-right">
                Available standard stock: <strong>{{ item.quantities.available }}</strong> units
              </div>
            </div>

            <!-- Form: Transfer to Batch -->
            <div v-if="movementAction === 'transfer'" class="row q-col-gutter-sm">
              <div class="col-12">
                <q-input
                  :model-value="`#${item.id} - ${item.name} (Available: ${item.quantities.available})`"
                  label="Move From"
                  outlined
                  dense
                  readonly
                  class="q-mb-md bg-grey-2"
                />
              </div>
              <div class="col-12">
                <q-select
                  v-model="movementForm.targetItem"
                  :options="targetBatchOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  class="bg-white"
                  label="Move To (Target Batch)"
                  no-data-label="No other active batches found for this product"
                />
              </div>
              <div class="col-12 class q-mt-sm text-caption text-grey-8 text-right">
                Available standard stock: <strong>{{ item.quantities.available }}</strong> units
              </div>
            </div>

            <div class="row q-col-gutter-sm q-mt-sm">
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="movementForm.quantity"
                  type="number"
                  outlined
                  dense
                  class="bg-white"
                  label="Quantity"
                  min="1"
                  :max="item.quantities.available"
                />
              </div>
              <div class="col-12 col-sm-8">
                <q-input
                  v-model="movementForm.note"
                  outlined
                  dense
                  class="bg-white"
                  :label="movementAction === 'split' ? 'Movement Note (Required) *' : 'Movement Note (Optional)'"
                  :placeholder="movementAction === 'split' ? 'Describe the reason for the split' : 'Why is this stock moving?'"
                />
              </div>
            </div>

            <div class="row justify-end q-mt-md q-gutter-sm">
              <q-btn flat label="Cancel" no-caps @click="showMovementForm = false" />
              <q-btn
                color="primary"
                label="Apply Action"
                no-caps
                :loading="isSubmitting"
                @click="onSubmitMovement"
              />
            </div>
          </div>
        </q-slide-transition>

        <!-- Polymorphic Notes System -->
        <div class="q-mt-lg">
          <InventoryNotesPanel
            :inventory-item-id="item.id"
            :product-id="item.product_id ?? null"
            :tenant-id="item.tenant_id"
          />
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useInventoryStore } from '../stores/inventoryStore'
import type { InventoryItemWithStock, InventoryStock } from '../types'
import InventoryNotesPanel from './InventoryNotesPanel.vue'

const props = defineProps<{
  modelValue: boolean
  item: InventoryItemWithStock | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'refresh'): void
}>()

const $q = useQuasar()
const inventoryStore = useInventoryStore()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const draftStock = ref<InventoryStock | null>(null)
const isEditingQuantities = ref(false)

const formattedQuantities = computed<Record<string, { val: number; bg: string }>>(() => {
  if (!props.item) return {}
  const stock = draftStock.value || props.item.stock
  const quantities = stock ? {
    available: stock.available_quantity,
    open_box: stock.open_box_quantity,
    reserved: stock.reserved_quantity,
    damaged: stock.damaged_quantity,
    stolen: stock.stolen_quantity,
    expired: stock.expired_quantity,
  } : props.item.quantities

  return {
    available: { val: quantities.available, bg: 'bg-green-1' },
    'open box': { val: quantities.open_box ?? 0, bg: 'bg-blue-1' },
    reserved: { val: quantities.reserved, bg: 'bg-indigo-1' },
    damaged: { val: quantities.damaged, bg: 'bg-red-1' },
    stolen: { val: quantities.stolen, bg: 'bg-orange-1' },
    expired: { val: quantities.expired, bg: 'bg-purple-1' },
  }
})

// Movement Form States
const showMovementForm = ref(false)
const movementAction = ref<'split' | 'transfer'>('transfer')
const isSubmitting = ref(false)
const otherBatches = ref<Array<{ id: number; name: string; cost: number | null; stock: InventoryStock | null }>>([])

const movementForm = ref({
  quantity: 1,
  condition: 'box_damage' as 'standard' | 'box_damage' | 'expired' | 'boxless' | 'stolen',
  nameSuffix: ' (Box Damage)',
  targetItem: null as { id: number; name: string; cost: number | null; stock: InventoryStock | null } | null,
  note: '',
})

const movementActionOptions = [
  { label: 'Transfer Stock to Existing Batch', value: 'transfer' },
  { label: 'Split Off to a New Batch', value: 'split' },
]

const conditionOptions = [
  { label: 'Standard Split', value: 'standard' },
  { label: 'Box Damage Suffix', value: 'box_damage' },
  { label: 'Expired Suffix', value: 'expired' },
  { label: 'Boxless Suffix', value: 'boxless' },
  { label: 'Stolen Suffix', value: 'stolen' },
]

const conditionSuffixes = {
  standard: ' (Split)',
  box_damage: ' (Box Damage)',
  expired: ' (Expired)',
  boxless: ' (Boxless)',
  stolen: ' (Stolen/Missing)',
} as const

const targetBatchOptions = computed(() => {
  return otherBatches.value.map((batch) => ({
    label: `#${batch.id} ${batch.name} (Available: ${batch.stock?.available_quantity || 0})`,
    value: batch,
  }))
})

// Auto-fill suffix when condition changes
watch(() => movementForm.value.condition, (newVal) => {
  if (newVal) {
    movementForm.value.nameSuffix = conditionSuffixes[newVal] || ''
  }
})

// Fetch other batches for transfers
const fetchOtherBatches = async () => {
  if (!props.item || !props.item.product_id) return
  otherBatches.value = []

  try {
    const { data, error } = await supabase
      .from('inventory_items')
      .select('id, name, cost, stock:inventory_stocks(id, available_quantity, reserved_quantity, damaged_quantity, stolen_quantity, expired_quantity, open_box_quantity)')
      .eq('product_id', props.item.product_id)
      .eq('status', 'active')
      .neq('id', props.item.id)

    if (error) throw error

    if (data) {
      otherBatches.value = data.map((row) => {
        const stockArr = row.stock as unknown as InventoryStock[] | InventoryStock | null
        const stockObj = Array.isArray(stockArr) ? stockArr[0] : stockArr
        return {
          id: row.id,
          name: row.name,
          cost: row.cost == null ? null : Number(row.cost),
          stock: stockObj || null,
        }
      })
    }
  } catch (err) {
    console.error('Error fetching other batches:', err)
  }
}

const resetForm = () => {
  movementForm.value = {
    quantity: 1,
    condition: 'box_damage',
    nameSuffix: ' (Box Damage)',
    targetItem: null,
    note: '',
  }
}

watch(() => props.item, (newItem) => {
  if (newItem) {
    resetForm()
    void fetchOtherBatches()
    draftStock.value = newItem.stock ? { ...newItem.stock } : null
    isEditingQuantities.value = false
  }
}, { immediate: true })

const onSubmitMovement = async () => {
  if (!props.item) return
  if (movementForm.value.quantity <= 0) {
    $q.notify({ type: 'negative', message: 'Quantity must be greater than 0.' })
    return
  }
  if (movementAction.value === 'split' && !movementForm.value.note.trim()) {
    $q.notify({ type: 'negative', message: 'Movement note is required for splits.' })
    return
  }

  isSubmitting.value = true

  try {
    let result
    if (movementAction.value === 'split') {
      if (movementForm.value.quantity > props.item.quantities.available) {
        $q.notify({ type: 'negative', message: 'Insufficient standard available stock to split.' })
        isSubmitting.value = false
        return
      }

      result = await inventoryStore.splitInventoryBatch({
        sourceItem: props.item,
        quantity: movementForm.value.quantity,
        condition: movementForm.value.condition,
        nameSuffix: movementForm.value.nameSuffix,
        note: movementForm.value.note,
      })
    } else if (movementAction.value === 'transfer') {
      if (!movementForm.value.targetItem) {
        $q.notify({ type: 'negative', message: 'Please select a target batch to transfer units to.' })
        isSubmitting.value = false
        return
      }
      if (movementForm.value.quantity > props.item.quantities.available) {
        $q.notify({ type: 'negative', message: 'Insufficient standard available stock to transfer.' })
        isSubmitting.value = false
        return
      }

      // Re-map target batch types to fit InventoryItemWithStock minimal details
      const targetItemMapped: InventoryItemWithStock = {
        id: movementForm.value.targetItem.id,
        name: movementForm.value.targetItem.name,
        tenant_id: props.item.tenant_id,
        source_type: 'manual',
        source_id: null,
        product_id: props.item.product_id,
        image_url: props.item.image_url,
        cost: movementForm.value.targetItem.cost,
        stock: movementForm.value.targetItem.stock,
        barcode: null,
        product_code: null,
        manufacturing_date: null,
        expire_date: null,
        status: 'active',
        created_at: '',
        updated_at: '',
        shipment: null,
        quantities: {
          available: movementForm.value.targetItem.stock?.available_quantity || 0,
          usable: movementForm.value.targetItem.stock?.available_quantity || 0,
          reserved: 0,
          damaged: 0,
          stolen: 0,
          expired: 0,
          open_box: 0,
        },
      }

      result = await inventoryStore.transferInventoryStock({
        sourceItem: props.item,
        targetItem: targetItemMapped,
        quantity: movementForm.value.quantity,
        note: movementForm.value.note,
      })
    }

    if (result && result.success) {
      emit('refresh')
      showMovementForm.value = false
      localModelValue.value = false
    } else {
      $q.notify({ type: 'negative', message: result?.error || 'Failed to apply movement.' })
    }
  } catch (error) {
    console.error('Movement operation failed:', error)
    $q.notify({ type: 'negative', message: 'An unexpected error occurred.' })
  } finally {
    isSubmitting.value = false
  }
}

const canDeleteBatch = computed(() => {
  if (!props.item) return false
  const stock = draftStock.value || props.item.stock
  if (!stock) return false
  return (
    (stock.available_quantity || 0) +
    (stock.reserved_quantity || 0) +
    (stock.damaged_quantity || 0) +
    (stock.stolen_quantity || 0) +
    (stock.expired_quantity || 0) +
    (stock.open_box_quantity || 0)
  ) === 0
})

const executeDelete = async () => {
  if (!props.item) return
  isSubmitting.value = true
  try {
    const result = await inventoryStore.deleteInventoryItem({ id: props.item.id })
    if (result.success) {
      emit('refresh')
      localModelValue.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error || 'Failed to delete batch.' })
    }
  } catch (err) {
    console.error(err)
    $q.notify({ type: 'negative', message: 'An unexpected error occurred.' })
  } finally {
    isSubmitting.value = false
  }
}

const onDeleteBatch = () => {
  if (!canDeleteBatch.value || !props.item) return

  $q.dialog({
    title: 'Confirm Deletion',
    message: `Are you sure you want to delete this inventory batch: "${props.item.name}"? This action cannot be undone.`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void executeDelete()
  })
}

const hasStockChanges = computed(() => {
  if (!props.item?.stock || !draftStock.value) return false
  const original = props.item.stock
  const draft = draftStock.value
  return (
    original.available_quantity !== draft.available_quantity ||
    original.reserved_quantity !== draft.reserved_quantity ||
    original.damaged_quantity !== draft.damaged_quantity ||
    original.stolen_quantity !== draft.stolen_quantity ||
    original.expired_quantity !== draft.expired_quantity ||
    original.open_box_quantity !== draft.open_box_quantity
  )
})

const discardStockChanges = () => {
  if (props.item?.stock) {
    draftStock.value = { ...props.item.stock }
  }
  isEditingQuantities.value = false
}

const saveStockChanges = async () => {
  if (!props.item?.stock || !draftStock.value) return

  isSubmitting.value = true
  try {
    const original = props.item.stock
    const draft = draftStock.value

    const patchPayload: Partial<
      Pick<
        InventoryStock,
        | 'available_quantity'
        | 'reserved_quantity'
        | 'damaged_quantity'
        | 'stolen_quantity'
        | 'expired_quantity'
        | 'open_box_quantity'
      >
    > = {
      available_quantity: draft.available_quantity,
      reserved_quantity: draft.reserved_quantity,
      damaged_quantity: draft.damaged_quantity,
      stolen_quantity: draft.stolen_quantity,
      expired_quantity: draft.expired_quantity,
      open_box_quantity: draft.open_box_quantity,
    }

    const updateResult = await inventoryStore.updateInventoryStock({
      id: props.item.stock.id,
      patch: patchPayload,
    })

    if (!updateResult.success) {
      throw new Error(updateResult.error || 'Failed to update stock quantities.')
    }

    const changes: string[] = []
    if (original.available_quantity !== draft.available_quantity) {
      changes.push(`available: ${original.available_quantity} -> ${draft.available_quantity}`)
    }
    if (original.reserved_quantity !== draft.reserved_quantity) {
      changes.push(`reserved: ${original.reserved_quantity} -> ${draft.reserved_quantity}`)
    }
    if (original.damaged_quantity !== draft.damaged_quantity) {
      changes.push(`damaged: ${original.damaged_quantity} -> ${draft.damaged_quantity}`)
    }
    if (original.stolen_quantity !== draft.stolen_quantity) {
      changes.push(`stolen: ${original.stolen_quantity} -> ${draft.stolen_quantity}`)
    }
    if (original.expired_quantity !== draft.expired_quantity) {
      changes.push(`expired: ${original.expired_quantity} -> ${draft.expired_quantity}`)
    }
    if (original.open_box_quantity !== draft.open_box_quantity) {
      changes.push(`open box: ${original.open_box_quantity} -> ${draft.open_box_quantity}`)
    }

    if (changes.length > 0) {
      await inventoryStore.createInventoryMovement({
        inventory_item_id: props.item.id,
        type: 'adjustment',
        quantity: 1,
        previous_quantity: original.available_quantity,
        new_quantity: draft.available_quantity,
        note: `Manual batch quantities adjustment: ${changes.join(', ')}.`,
        created_by: null,
      })
    }

    $q.notify({ type: 'positive', message: 'Quantities saved successfully.' })
    isEditingQuantities.value = false
    emit('refresh')
  } catch (err) {
    console.error(err)
    $q.notify({
      type: 'negative',
      message: err instanceof Error ? err.message : 'Failed to save quantity changes.',
    })
  } finally {
    isSubmitting.value = false
  }
}
</script>

<style scoped>
.border {
  border: 1px solid rgba(0, 0, 0, 0.08);
}
.pill-btn {
  border-radius: 999px;
}
</style>

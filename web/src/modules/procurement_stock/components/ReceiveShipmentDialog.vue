<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin" style="width: 800px; max-width: 95vw;">
      <q-card-section class="row items-center q-pb-none">
        <div>
          <div class="text-h6 text-primary text-weight-bold">Receive Shipment to Warehouse Stock</div>
          <div class="text-caption text-grey-7">Assign item quantities to stock types. Sum of splits must equal ordered quantity.</div>
        </div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md scroll" style="max-height: 70vh;">
        <!-- Error banner -->
        <q-banner v-if="error" class="bg-negative text-white rounded-borders q-mb-md q-py-sm">
          {{ error }}
        </q-banner>

        <div v-if="loadingStockTypes" class="text-center q-py-xl">
          <q-spinner color="primary" size="2em" />
          <div class="text-grey-6 q-mt-sm">Loading stock types...</div>
        </div>

        <div v-else class="q-gutter-y-lg">
          <div v-for="(item, lineIndex) in lines" :key="item.id" class="q-pa-md border rounded-borders">
            <!-- Line Item Header -->
            <div class="row items-center justify-between q-mb-md">
              <div class="row items-center q-col-gutter-sm">
                <q-avatar rounded size="36px" class="bg-grey-2">
                  <img :src="item.image_url || 'https://placehold.co/36x36?text=No+Image'" />
                </q-avatar>
                <div>
                  <div class="text-weight-bold text-grey-9">{{ item.name }}</div>
                  <div class="text-caption text-grey-6">Code: {{ item.product_code || '-' }} | Barcode: {{ item.barcode || '-' }}</div>
                </div>
              </div>
              <div class="text-right">
                <div class="text-caption text-grey-7">Ordered Quantity</div>
                <div class="text-subtitle1 text-weight-bolder text-primary">{{ item.ordered_quantity }} pcs</div>
              </div>
            </div>

            <!-- Splits List -->
            <div class="q-gutter-y-sm">
              <div v-for="(split, splitIndex) in item.splits" :key="splitIndex" class="row q-col-gutter-sm items-center">
                <div class="col-12 col-sm-4">
                  <q-select
                    v-model="split.stock_type_id"
                    :options="stockTypeOptions"
                    label="Stock Type *"
                    filled
                    dense
                    emit-value
                    map-options
                    @update:model-value="onStockTypeSelected(split)"
                  />
                </div>
                <div class="col-6 col-sm-3">
                  <q-input
                    v-model.number="split.quantity"
                    type="number"
                    label="Quantity *"
                    filled
                    dense
                    :rules="[val => val >= 0 || 'Must be >= 0']"
                  />
                </div>
                <div class="col-4 col-sm-3">
                  <q-checkbox v-model="split.is_usable" label="Usable Pool" />
                </div>
                <div class="col-2 col-sm-2 text-right">
                  <q-btn
                    v-if="item.splits.length > 1"
                    flat
                    round
                    dense
                    color="negative"
                    icon="remove_circle"
                    @click="removeSplit(lineIndex, splitIndex)"
                  />
                </div>
              </div>

              <div class="row items-center justify-between q-mt-sm">
                <q-btn
                  flat
                  color="primary"
                  icon="add"
                  label="Add Split Row"
                  no-caps
                  dense
                  @click="addSplit(lineIndex)"
                />
                <div class="text-caption text-weight-bold" :class="getSplitValidationClass(item)">
                  Assigned: {{ getSumOfSplits(item) }} / {{ item.ordered_quantity }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1">
        <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          label="Commit & Receive"
          :loading="saving"
          :disable="!isValid"
          no-caps
          @click="onCommit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useDialogPluginComponent, useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import { useGlobalStockTypeStore } from '../stores/globalStockTypeStore'
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository'

const props = defineProps<{
  shipmentId: number
}>()

defineEmits([
  ...useDialogPluginComponent.emits
])

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent()

const $q = useQuasar()
const authStore = useAuthStore()
const shipmentStore = useGlobalShipmentStore()
const stockTypeStore = useGlobalStockTypeStore()

const loadingStockTypes = ref(false)
const saving = ref(false)
const error = ref<string | null>(null)

interface ReceiveSplit {
  stock_type_id: number
  quantity: number
  is_usable: boolean
}

interface ReceiveLineItem extends GlobalShipmentItem {
  splits: ReceiveSplit[]
}

const lines = ref<ReceiveLineItem[]>([])

const stockTypeOptions = computed(() => {
  return stockTypeStore.items.map((t) => ({
    label: `${t.description} ${t.is_sellable ? '(Sellable)' : '(Non-Sellable)'}`,
    value: t.id,
    is_sellable: t.is_sellable,
  }))
})

onMounted(async () => {
  loadingStockTypes.value = true
  try {
    await stockTypeStore.fetchStockTypes(authStore.tenantId)
    
    // Find the standard sellable stock type ID to default
    const standardType = stockTypeStore.items.find((t) => t.description === 'Standard Sellable')
    const defaultTypeId = standardType?.id || stockTypeStore.items[0]?.id || 0
    const defaultIsUsable = standardType?.is_sellable ?? true

    // Map shipment items
    lines.value = shipmentStore.currentShipmentItems.map((item) => ({
      ...item,
      splits: [
        {
          stock_type_id: defaultTypeId,
          quantity: item.ordered_quantity,
          is_usable: defaultIsUsable,
        },
      ],
    }))
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to initialize receive dialog'
  } finally {
    loadingStockTypes.value = false
  }
})

const onStockTypeSelected = (split: ReceiveSplit) => {
  const stockType = stockTypeStore.items.find((t) => t.id === split.stock_type_id)
  if (stockType) {
    split.is_usable = stockType.is_sellable
  }
}

const addSplit = (lineIndex: number) => {
  const item = lines.value[lineIndex]
  if (!item) return
  const defaultTypeId = stockTypeStore.items[0]?.id || 0
  const defaultIsUsable = stockTypeStore.items[0]?.is_sellable ?? true
  item.splits.push({
    stock_type_id: defaultTypeId,
    quantity: 0,
    is_usable: defaultIsUsable,
  })
}

const removeSplit = (lineIndex: number, splitIndex: number) => {
  const item = lines.value[lineIndex]
  if (item) {
    item.splits.splice(splitIndex, 1)
  }
}

const getSumOfSplits = (item: ReceiveLineItem): number => {
  return item.splits.reduce((sum, s) => sum + (s.quantity || 0), 0)
}

const getSplitValidationClass = (item: ReceiveLineItem): string => {
  const sum = getSumOfSplits(item)
  if (sum === item.ordered_quantity) return 'text-positive'
  return 'text-negative'
}

const isValid = computed(() => {
  if (lines.value.length === 0) return false
  return lines.value.every((item) => getSumOfSplits(item) === item.ordered_quantity)
})

const onCommit = async () => {
  if (!isValid.value || !authStore.tenantId) return
  saving.value = true
  error.value = null

  try {
    // 1. Prepare global_stocks insert payload
    const stockRows: any[] = []
    for (const line of lines.value) {
      for (const split of line.splits) {
        if (split.quantity > 0) {
          stockRows.push({
            parent_tenant_id: authStore.tenantId,
            shipment_item_id: line.id,
            stock_type_id: split.stock_type_id,
            quantity: split.quantity,
            is_usable: split.is_usable,
          })
        }
      }
    }

    if (stockRows.length === 0) {
      throw new Error('No quantities received to stock.')
    }

    // 2. Perform direct insert
    // Since direct client RLS matches policy global_stocks_all, parent can insert.
    // Let's run a bulk upsert / insert. To satisfy uniqueness, we use upsert on conflict (shipment_item_id, stock_type_id, is_usable).
    const { error: insertError } = await supabase
      .from('global_stocks')
      .upsert(stockRows, { onConflict: 'shipment_item_id,stock_type_id,is_usable' })

    if (insertError) throw insertError

    // 3. Promote shipment status to 'Ready Stock'
    await shipmentStore.updateShipment(props.shipmentId, {
      status: 'Ready Stock',
      stock_ready: true,
    })

    $q.notify({
      type: 'positive',
      message: 'Shipment received successfully. Stock pools created.',
    })

    onDialogOK()
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to receive stock.'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.border {
  border: 1px solid var(--q-grey-4, #e0e0e0);
}
.scroll-x {
  overflow-x: auto;
}
</style>

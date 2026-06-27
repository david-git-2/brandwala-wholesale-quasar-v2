<template>
  <div class="shipment-line-items">
    <q-card-section class="q-pa-none shipment-table-scroll-wrap">
      <q-inner-loading :showing="loading" />
      <q-markup-table flat class="shipment-details-table" :class="{ 'is-editable': isEditable }">
        <thead>
          <tr>
            <th class="text-right shipment-sl-col">SL</th>
            <th class="text-left shipment-image-col">Image</th>
            <th v-if="isColumnVisible('name')" class="text-left shipment-name-col">Name</th>
            <th v-if="isColumnVisible('product_id') && props.shipment?.status === 'Warehouse Received'" class="text-center shipment-split-col" style="width: 80px; min-width: 80px; max-width: 80px;">Split Qty</th>
            <th v-if="isColumnVisible('product_id')" class="text-center shipment-product-id-col">Product ID</th>
            <th v-if="isColumnVisible('barcode')" class="text-left shipment-barcode-col">Barcode</th>
            <th v-if="isColumnVisible('product_code')" class="text-left shipment-product-code-col">Product Code</th>
            <th v-if="isColumnVisible('add_method')" class="text-left shipment-method-col">Method</th>
            <th v-if="isColumnVisible('purchase_price')" class="text-center shipment-price-col">Price {{ purchaseCurrencySymbol }}</th>
            <th v-if="isColumnVisible('cost_bdt')" class="text-center shipment-cost-col">Cost {{ costCurrencySymbol }}</th>
            <th v-if="isColumnVisible('ordered_quantity')" class="text-center shipment-qty-col shipment-qty-col--quantity">Quantity</th>
            <th v-if="isColumnVisible('product_weight')" class="text-center shipment-product-weight-col">Product Wt</th>
            <th v-if="isColumnVisible('package_weight')" class="text-center shipment-package-weight-col">Package Wt</th>
            <th v-if="isColumnVisible('actions')" class="text-right shipment-actions-col">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, index) in items" :key="item.id">
            <td class="text-right shipment-sl-col">
              <div class="row items-center justify-end no-wrap">
                <span :class="{ 'cursor-pointer': isEditable, 'text-underline-dashed': isEditable }">{{ index + 1 }}</span>
                <q-popup-edit
                  v-if="isEditable"
                  :model-value="index + 1"
                  buttons
                  persistent
                  label-set="Move"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(val) => moveItemToPosition(index, val)"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    type="number"
                    dense
                    outlined
                    autofocus
                    min="1"
                    :max="items.length"
                    label="New SL Position"
                    @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                    @keyup.enter="scope.set"
                  />
                </q-popup-edit>
                <div v-if="isEditable" class="column items-center justify-center q-ml-xs">
                  <q-btn
                    flat
                    round
                    dense
                    size="xs"
                    icon="keyboard_arrow_up"
                    :disable="index === 0"
                    class="q-my-none"
                    style="height: 14px; min-height: 14px;"
                    @click="moveItem(index, 'up')"
                  >
                    <q-tooltip>Move Up</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    dense
                    size="xs"
                    icon="keyboard_arrow_down"
                    :disable="index === items.length - 1"
                    class="q-my-none"
                    style="height: 14px; min-height: 14px;"
                    @click="moveItem(index, 'down')"
                  >
                    <q-tooltip>Move Down</q-tooltip>
                  </q-btn>
                </div>
              </div>
            </td>
            <td class="shipment-image-col">
              <div class="shipment-item-image-box">
                <SmartImage
                  :src="item.image_url"
                  alt="shipment item"
                  img-class="shipment-item-image"
                  fallback-class="shipment-item-image-fallback"
                  :enable-edit="false"
                />
              </div>
            </td>
            <td
              v-if="isColumnVisible('name')"
              class="shipment-item-name-cell shipment-name-col"
              :class="{ 'cursor-pointer': isEditable }"
              @click="isEditable && emit('edit-details', item)"
            >
              {{ item.name ?? '-' }}
            </td>
            <td v-if="isColumnVisible('product_id') && props.shipment?.status === 'Warehouse Received'" class="text-center shipment-split-col">
              <div class="column items-center q-gutter-y-xs q-py-xs">
                <q-btn
                  flat
                  round
                  dense
                  icon="call_split"
                  :color="isItemSplitsCompleteInDb(item) ? 'green-7' : 'orange-7'"
                  size="sm"
                  @click="openSplitDialog(item)"
                >
                  <q-tooltip>
                    {{ isItemSplitsCompleteInDb(item) ? 'Quantity splits complete.' : 'Configure quantity splits.' }}
                  </q-tooltip>
                </q-btn>
                <span
                  class="text-weight-bold"
                  style="font-size: 11px; line-height: 1;"
                  :class="isItemSplitsCompleteInDb(item) ? 'text-green-7' : 'text-orange-7'"
                >
                  {{ isItemSplitsCompleteInDb(item) ? 'Done' : 'Pending' }}
                </span>
              </div>
            </td>
            <td v-if="isColumnVisible('product_id')" class="shipment-product-id-col">{{ item.product_id ?? '-' }}</td>
            <td v-if="isColumnVisible('barcode')" class="shipment-barcode-col">{{ item.barcode ?? '-' }}</td>
            <td v-if="isColumnVisible('product_code')" class="shipment-product-code-col">{{ item.product_code ?? '-' }}</td>
            <td v-if="isColumnVisible('add_method')" class="text-uppercase shipment-method-col">{{ item.add_method ?? '-' }}</td>
            <td v-if="isColumnVisible('purchase_price')" class="text-center shipment-price-col">
              <div>
                <span :class="{ 'cursor-pointer': isEditable }">{{ formatFixed2(item.purchase_price) }}</span>
                <q-popup-edit
                  v-if="isEditable"
                  :model-value="item.purchase_price"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericSave(item, 'purchase_price', value, { decimals: 2 })"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    type="number"
                    step="0.01"
                    dense
                    outlined
                    autofocus
                    @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                    @keyup.enter="scope.set"
                  />
                </q-popup-edit>
              </div>
              <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px;">
                T: {{ formatFixed2((item.purchase_price || 0) * (item.ordered_quantity || 0)) }}
              </div>
            </td>
            <td v-if="isColumnVisible('cost_bdt')" class="text-center shipment-cost-col">
              <div>{{ formatFixed2(lineCostBdt(item)) }}</div>
              <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px;">
                T: {{ formatFixed2(lineCostBdt(item) * (item.ordered_quantity || 0)) }}
              </div>
            </td>
            <td
              v-if="isColumnVisible('ordered_quantity')"
              class="text-center shipment-qty-col shipment-qty-col--quantity"
            >
              <span :class="{ 'cursor-pointer': isEditable }">{{ item.ordered_quantity }}</span>
              <q-popup-edit
                v-if="isEditable"
                :model-value="item.ordered_quantity"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                v-slot="scope"
                @save="(value) => onNumericSave(item, 'ordered_quantity', value)"
              >
                <q-input
                  :model-value="scope.value ?? ''"
                  type="number"
                  dense
                  outlined
                  autofocus
                  min="1"
                  @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </td>
            <td v-if="isColumnVisible('product_weight')" class="text-center shipment-product-weight-col">
              <div>
                <span :class="{ 'cursor-pointer': isEditable }">{{ formatDecimal(item.product_weight) }}</span>
                <q-popup-edit
                  v-if="isEditable"
                  :model-value="item.product_weight"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericSave(item, 'product_weight', value, { decimals: 3 })"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    type="number"
                    step="0.001"
                    dense
                    outlined
                    autofocus
                    @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                    @keyup.enter="scope.set"
                  />
                </q-popup-edit>
              </div>
              <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px;">
                T: {{ formatFixed2((item.product_weight || 0) * (item.ordered_quantity || 0)) }} gm
              </div>
            </td>
            <td v-if="isColumnVisible('package_weight')" class="text-center shipment-package-weight-col">
              <div>
                <span :class="{ 'cursor-pointer': isEditable }">{{ formatDecimal(item.package_weight) }}</span>
                <q-popup-edit
                  v-if="isEditable"
                  :model-value="item.package_weight"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(value) => onNumericSave(item, 'package_weight', value, { decimals: 3 })"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    type="number"
                    step="0.001"
                    dense
                    outlined
                    autofocus
                    @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                    @keyup.enter="scope.set"
                  />
                </q-popup-edit>
              </div>
              <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px;">
                T: {{ formatFixed2((item.package_weight || 0) * (item.ordered_quantity || 0)) }} gm
              </div>
            </td>
            <td v-if="isColumnVisible('actions')" class="text-right shipment-actions-col">
              <q-btn v-if="isEditable" flat round dense icon="more_vert">
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable @click="emit('edit-details', item)">
                      <q-item-section>Edit details</q-item-section>
                    </q-item>
                    <q-item clickable class="text-negative" @click="emit('delete', item.id)">
                      <q-item-section>Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </td>
          </tr>

          <tr v-if="items.length" class="shipment-total-row">
            <td class="shipment-sl-col" />
            <td class="shipment-image-col" />
            <td v-if="isColumnVisible('name')" class="shipment-name-col" />
            <td v-if="isColumnVisible('product_id') && props.shipment?.status === 'Warehouse Received'" class="shipment-split-col" />
            <td v-if="isColumnVisible('product_id')" />
            <td v-if="isColumnVisible('barcode')" />
            <td v-if="isColumnVisible('product_code')" />
            <td v-if="isColumnVisible('add_method')" />
            <td v-if="isColumnVisible('purchase_price')" class="text-center text-weight-bold shipment-price-col">
              {{ formatFixed2(tableTotals.price_gbp) }}
            </td>
            <td v-if="isColumnVisible('cost_bdt')" class="text-center text-weight-bold shipment-cost-col">
              {{ formatFixed2(tableTotals.cost_bdt) }}
            </td>
            <td
              v-if="isColumnVisible('ordered_quantity')"
              class="text-center shipment-qty-col shipment-qty-col--quantity text-weight-bold"
            >
              {{ tableTotals.quantity }}
            </td>
            <td v-if="isColumnVisible('product_weight')" class="text-center text-weight-bold shipment-product-weight-col">
              {{ formatFixed2(tableTotals.product_weight) }} gm
            </td>
            <td v-if="isColumnVisible('package_weight')" class="text-center text-weight-bold shipment-package-weight-col">
              {{ formatFixed2(tableTotals.package_weight) }} gm
            </td>
            <td v-if="isColumnVisible('actions')" />
          </tr>

          <tr v-if="!items.length && !loading">
            <td :colspan="tableColspan" class="text-center text-grey-6 q-pa-md">
              No shipment items yet. Use Add Items to get started.
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card-section>
  </div>

  <!-- Centered Quantity Split Dialog -->
  <q-dialog v-model="splitDialogActive" persistent>
    <q-card v-if="activeSplitItem" style="width: 450px; max-width: 95vw;" class="q-pa-md rounded-borders">
      <q-card-section class="row items-start no-wrap q-pb-none q-mb-sm">
        <q-avatar rounded size="48px" class="bg-grey-2 q-mr-md shadow-1 flex-shrink-0">
          <img
            v-if="activeSplitItem.image_url"
            :src="activeSplitItem.image_url"
            style="object-fit: cover; width: 100%; height: 100%;"
          />
          <q-icon v-else name="image" color="grey-6" />
        </q-avatar>
        <div class="col column justify-center text-left">
          <div class="text-subtitle1 text-weight-bold text-grey-9 text-wrap" style="line-height: 1.2; word-break: break-word;">
            {{ activeSplitItem.name }}
          </div>
          <div class="text-caption text-grey-6 text-weight-medium q-mt-xs" style="font-size: 11px;">
            Qty: {{ activeSplitItem.ordered_quantity }} pcs | Code: {{ activeSplitItem.product_code || '-' }}
          </div>
        </div>
        <q-btn icon="close" flat round dense v-close-popup class="q-ml-md self-start" />
      </q-card-section>

      <q-separator class="q-mx-md q-my-sm" />

      <q-card-section class="q-py-sm">
        <!-- Stock Type Splits Inputs -->
        <div class="q-gutter-y-md">
          <div
            v-for="t in stockTypeStore.items"
            :key="t.id"
            class="row items-center justify-between no-wrap q-py-xs"
          >
            <div class="column text-left">
              <span class="text-weight-bold text-grey-9 text-subtitle2" style="line-height: 1.1;">{{ t.description }}</span>
              <span class="text-caption text-grey-6" style="font-size: 11px;">
                {{ t.is_sellable ? 'Sellable Pool' : 'Non-Sellable Pool' }}
              </span>
            </div>
            <q-input
              v-model.number="localSplits[activeSplitItem.id][t.id]"
              type="number"
              dense
              outlined
              style="width: 130px;"
              min="0"
              class="text-right"
              :rules="[val => val >= 0 || 'Must be >= 0']"
              hide-bottom-space
            />
          </div>
        </div>
      </q-card-section>

      <q-separator class="q-my-sm" />

      <q-card-actions align="between" class="q-pt-sm">
        <!-- Sum validation message -->
        <div
          class="text-subtitle2 text-weight-bolder"
          :class="isItemSplitsCompleteLocal(activeSplitItem) ? 'text-positive' : 'text-negative'"
        >
          Allocated: {{ getSumOfSplits(activeSplitItem.id) }} / {{ activeSplitItem.ordered_quantity }}
        </div>
        
        <div class="row q-gutter-sm">
          <q-btn label="Cancel" color="grey-7" flat v-close-popup no-caps />
          <q-btn
            label="Save"
            color="primary"
            unelevated
            no-caps
            :disable="!isItemSplitsCompleteLocal(activeSplitItem)"
            :loading="savingSplits[activeSplitItem.id]"
            @click="saveItemSplits"
          />
        </div>
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, watch } from 'vue'
import { useQuasar } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import type { GlobalShipment, GlobalShipmentItem } from '../repositories/globalShipmentRepository'
import { calculateLineLandedCostBdt } from '../utils/landedCost'
import { syncShipmentWeightToProduct } from '../utils/syncShipmentWeightToProduct'
import { useGlobalStockTypeStore } from '../stores/globalStockTypeStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { supabase } from 'src/boot/supabase'

const props = withDefaults(
  defineProps<{
    items: GlobalShipmentItem[]
    shipment: GlobalShipment | null
    loading?: boolean
    visibleColumns?: ColumnKey[]
    purchaseCurrencySymbol?: string
    costCurrencySymbol?: string
  }>(),
  {
    purchaseCurrencySymbol: '£',
    costCurrencySymbol: '৳',
  },
)

const emit = defineEmits<{
  'edit-details': [item: GlobalShipmentItem]
  delete: [id: number]
}>()

const $q = useQuasar()
const shipmentStore = useGlobalShipmentStore()

const baseColumnOptions = [
  { label: 'Name', value: 'name' },
  { label: 'Product ID', value: 'product_id' },
  { label: 'Barcode', value: 'barcode' },
  { label: 'Product Code', value: 'product_code' },
  { label: 'Method', value: 'add_method' },
  { label: 'Price GBP', value: 'purchase_price' },
  { label: 'Cost BDT', value: 'cost_bdt' },
  { label: 'Quantity', value: 'ordered_quantity' },
  { label: 'Product Wt', value: 'product_weight' },
  { label: 'Package Wt', value: 'package_weight' },
  { label: 'Actions', value: 'actions' },
] as const

export type ColumnKey = (typeof baseColumnOptions)[number]['value']

const internalVisibleColumns = ref<ColumnKey[]>([
  'name',
  'product_id',
  'barcode',
  'product_code',
  'add_method',
  'purchase_price',
  'cost_bdt',
  'ordered_quantity',
  'product_weight',
  'package_weight',
  'actions',
])

const activeVisibleColumns = computed(() => props.visibleColumns ?? internalVisibleColumns.value)

const isInternational = computed(() => props.shipment?.type === 'international')

const columnOptions = computed(() =>
  baseColumnOptions
    .filter((opt) => {
      if (!isInternational.value) {
        return !['purchase_price', 'product_weight', 'package_weight'].includes(opt.value)
      }
      return true
    })
    .map((opt) => {
      if (opt.value === 'purchase_price') {
        return { label: `Price ${props.purchaseCurrencySymbol}`, value: 'purchase_price' as ColumnKey }
      }
      if (opt.value === 'cost_bdt') {
        return { label: `Cost ${props.costCurrencySymbol}`, value: 'cost_bdt' as ColumnKey }
      }
      return opt
    }),
)

const isEditable = computed(() => {
  if (!props.shipment) return false
  return !props.shipment.stock_ready && props.shipment.status !== 'Ready Stock'
})

const isColumnVisible = (column: ColumnKey) => activeVisibleColumns.value.includes(column)

const tableColspan = computed(() => {
  let count = 2
  for (const opt of columnOptions.value) {
    if (isColumnVisible(opt.value)) count++
  }
  if (isColumnVisible('product_id') && props.shipment?.status === 'Warehouse Received') count++
  return count
})

const stockTypeStore = useGlobalStockTypeStore()
const authStore = useAuthStore()

const localSplits = ref<Record<number, Record<number, number>>>({})
const savingSplits = ref<Record<number, boolean>>({})

const splitDialogActive = ref(false)
const activeSplitItem = ref<GlobalShipmentItem | null>(null)

const openSplitDialog = (item: GlobalShipmentItem) => {
  activeSplitItem.value = item
  splitDialogActive.value = true
}

onMounted(async () => {
  if (stockTypeStore.items.length === 0 && authStore.tenantId) {
    await stockTypeStore.fetchStockTypes(authStore.tenantId)
  }
})

const initLocalSplits = () => {
  const stocks = shipmentStore.currentShipmentStocks || []
  const items = props.items || []
  const defaultType = stockTypeStore.items.find(t => t.description === 'Standard Sellable') || stockTypeStore.items[0]
  const defaultTypeId = defaultType?.id || 0

  const newSplits: Record<number, Record<number, number>> = {}
  for (const item of items) {
    const itemStocks = stocks.filter(s => s.shipment_item_id === item.id)
    newSplits[item.id] = {}
    
    for (const t of stockTypeStore.items) {
      newSplits[item.id][t.id] = 0
    }

    if (itemStocks.length > 0) {
      for (const s of itemStocks) {
        newSplits[item.id][s.stock_type_id] = s.quantity || 0
      }
    } else {
      if (defaultTypeId > 0) {
        newSplits[item.id][defaultTypeId] = item.ordered_quantity
      }
    }
  }
  localSplits.value = newSplits
}

watch(
  [() => shipmentStore.currentShipmentStocks, () => props.items, () => stockTypeStore.items],
  () => {
    initLocalSplits()
  },
  { immediate: true }
)

const getSumOfSplits = (itemId: number): number => {
  const itemSplits = localSplits.value[itemId] || {}
  return Object.values(itemSplits).reduce((sum, qty) => sum + (qty || 0), 0)
}

const isItemSplitsCompleteInDb = (item: GlobalShipmentItem): boolean => {
  const stocks = shipmentStore.currentShipmentStocks || []
  const itemStocks = stocks.filter((s) => s.shipment_item_id === item.id)
  if (itemStocks.length === 0) return false
  const sum = itemStocks.reduce((acc, s) => acc + (s.quantity || 0), 0)
  return sum === item.ordered_quantity
}

const isItemSplitsCompleteLocal = (item: GlobalShipmentItem): boolean => {
  return getSumOfSplits(item.id) === item.ordered_quantity
}

const saveItemSplits = async () => {
  const item = activeSplitItem.value
  if (!item || !isItemSplitsComplete(item) || !authStore.tenantId) return
  
  savingSplits.value[item.id] = true
  try {
    const itemSplits = localSplits.value[item.id] || {}
    const stockRows = Object.entries(itemSplits)
      .map(([stockTypeIdStr, qty]) => {
        const stockTypeId = Number(stockTypeIdStr)
        const stockType = stockTypeStore.items.find(t => t.id === stockTypeId)
        return {
          parent_tenant_id: authStore.tenantId,
          shipment_item_id: item.id,
          stock_type_id: stockTypeId,
          quantity: qty,
          is_usable: stockType?.is_sellable ?? true,
        }
      })
      .filter(row => row.quantity > 0)

    const { error: deleteError } = await supabase
      .from('global_stocks')
      .delete()
      .eq('shipment_item_id', item.id)
    if (deleteError) throw deleteError

    if (stockRows.length > 0) {
      const { error: insertError } = await supabase
        .from('global_stocks')
        .insert(stockRows)
      if (insertError) throw insertError
    }

    $q.notify({
      type: 'positive',
      message: `Stock splits saved successfully for ${item.name}.`,
      timeout: 1000,
    })

    splitDialogActive.value = false
    await shipmentStore.fetchShipmentDetails(props.shipment!.id)
  } catch (error: any) {
    $q.notify({
      type: 'negative',
      message: error.message || 'Failed to save splits.',
    })
  } finally {
    savingSplits.value[item.id] = false
  }
}

const formatDecimal = (value: number | null | undefined) =>
  value == null ? '-' : String(Number(value))

const formatFixed2 = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const lineCostBdt = (item: GlobalShipmentItem) => {
  if (!props.shipment) return 0
  return calculateLineLandedCostBdt(item, props.shipment, props.items)
}

const tableTotals = computed(() =>
  props.items.reduce(
    (acc, item) => {
      const qty = Number(item.ordered_quantity ?? 0)
      const unitCost = lineCostBdt(item)
      acc.price_gbp += Number(item.purchase_price ?? 0) * qty
      acc.cost_bdt += unitCost * qty
      acc.quantity += qty
      acc.product_weight += Number(item.product_weight ?? 0) * qty
      acc.package_weight += Number(item.package_weight ?? 0) * qty
      return acc
    },
    { price_gbp: 0, cost_bdt: 0, quantity: 0, product_weight: 0, package_weight: 0 },
  ),
)

type EditableField = 'purchase_price' | 'ordered_quantity' | 'product_weight' | 'package_weight'

const roundTo = (value: number, decimals = 0) => {
  const factor = 10 ** decimals
  return Math.round(value * factor) / factor
}

const onNumericSave = async (
  item: GlobalShipmentItem,
  field: EditableField,
  value: string | number | null,
  options?: { decimals?: number },
) => {
  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed < 0) {
    $q.notify({ type: 'warning', message: 'Value must be 0 or greater.' })
    return
  }

  let normalized = options?.decimals != null ? roundTo(parsed, options.decimals) : Math.floor(parsed)
  if (field === 'ordered_quantity') {
    normalized = Math.max(1, Math.floor(parsed))
  }

  try {
    await shipmentStore.updateShipmentItem(item.id, { [field]: normalized })
    if ((field === 'product_weight' || field === 'package_weight') && item.product_id != null) {
      await syncShipmentWeightToProduct(item.product_id, field, normalized)
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to update item.'
    $q.notify({ type: 'negative', message: msg })
  }
}

const moveItem = async (index: number, direction: 'up' | 'down') => {
  const targetIndex = direction === 'up' ? index - 1 : index + 1
  if (targetIndex < 0 || targetIndex >= props.items.length) return

  const updatedItems = [...props.items]
  const temp = updatedItems[index]
  const targetItem = updatedItems[targetIndex]
  if (!temp || !targetItem) return

  updatedItems[index] = targetItem
  updatedItems[targetIndex] = temp

  const itemsOrder = updatedItems.map((item, idx) => ({
    id: item.id,
    sort_order: idx * 10,
  }))

  try {
    if (props.shipment) {
      await shipmentStore.reorderShipmentItems(props.shipment.id, itemsOrder)
      $q.notify({
        type: 'positive',
        message: 'Items reordered successfully.',
        timeout: 1000,
      })
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to reorder items.'
    $q.notify({
      type: 'negative',
      message: msg,
    })
  }
}

const moveItemToPosition = async (currentIndex: number, newPosition: string | number | null) => {
  const parsed = Number(newPosition)
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > props.items.length) {
    $q.notify({
      type: 'warning',
      message: `Position must be between 1 and ${props.items.length}.`,
    })
    return
  }

  const targetIndex = parsed - 1
  if (currentIndex === targetIndex) return

  const updatedItems = [...props.items]
  const [removedItem] = updatedItems.splice(currentIndex, 1)
  if (!removedItem) return

  updatedItems.splice(targetIndex, 0, removedItem)

  const itemsOrder = updatedItems.map((item, idx) => ({
    id: item.id,
    sort_order: idx * 10,
  }))

  try {
    if (props.shipment) {
      await shipmentStore.reorderShipmentItems(props.shipment.id, itemsOrder)
      $q.notify({
        type: 'positive',
        message: `Item moved to position ${parsed} successfully.`,
        timeout: 1000,
      })
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to move item.'
    $q.notify({
      type: 'negative',
      message: msg,
    })
  }
}

defineExpose({
  columnOptions,
  internalVisibleColumns,
})
</script>

<style scoped>
.text-underline-dashed {
  text-decoration: underline dashed;
}

.shipment-table-scroll-wrap {
  overflow: visible;
  position: relative;
}

.shipment-details-table {
  min-width: 0;
  max-width: 100%;
  height: clamp(400px, calc(100vh - 320px), 80vh);
  background: var(--bw-theme-base, #eef2f5);
  overflow: auto;
  --sl-col-width: 60px;
}

.shipment-details-table.is-editable {
  --sl-col-width: 90px;
}

.shipment-details-table :deep(table) {
  table-layout: fixed;
  border-collapse: separate;
  border-spacing: 0;
  min-width: max-content;
  width: max-content;
}

.shipment-details-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
  box-shadow: inset 0 -1px 0 rgba(148, 163, 184, 0.25);
}

.shipment-item-image-box {
  width: 1in;
  height: 1in;
  display: flex;
  align-items: center;
  justify-content: center;
}

.shipment-details-table :deep(.shipment-item-image) {
  max-width: 1in;
  max-height: 1in;
  object-fit: contain;
}

.shipment-item-name-cell {
  white-space: normal;
  word-break: break-word;
  line-height: 1.25;
}

.shipment-sl-col {
  width: var(--sl-col-width);
  min-width: var(--sl-col-width);
  max-width: var(--sl-col-width);
}

.shipment-image-col {
  width: 1.2in;
  min-width: 1.2in;
  max-width: 1.2in;
}

.shipment-name-col {
  width: 220px;
  min-width: 220px;
  max-width: 220px;
}

.shipment-product-id-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-barcode-col,
.shipment-product-code-col {
  width: 170px;
  min-width: 170px;
  max-width: 170px;
}

.shipment-method-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-price-col,
.shipment-product-weight-col,
.shipment-package-weight-col {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
}

.shipment-cost-col {
  width: 120px;
  min-width: 120px;
  max-width: 120px;
}

.shipment-actions-col {
  width: 80px;
  min-width: 80px;
  max-width: 80px;
}

.shipment-qty-col--quantity {
  width: 110px;
  min-width: 110px;
  max-width: 110px;
  background: #d0e6ff;
}

.shipment-details-table :deep(td.shipment-qty-col--quantity) {
  background: #d0e6ff;
}

.shipment-details-table :deep(thead tr th.shipment-qty-col--quantity) {
  background: #d0e6ff;
}

/* Package Weight Column - Light Purple */
.shipment-package-weight-col {
  background: #e8d7f7;
}
.shipment-details-table :deep(td.shipment-package-weight-col) {
  background: #e8d7f7;
}
.shipment-details-table :deep(thead tr th.shipment-package-weight-col) {
  background: #e8d7f7;
}

/* Price Column - Light Green */
.shipment-price-col {
  background: #daf3e4;
}
.shipment-details-table :deep(td.shipment-price-col) {
  background: #daf3e4;
}
.shipment-details-table :deep(thead tr th.shipment-price-col) {
  background: #daf3e4;
}

/* Cost Column - Light Orange */
.shipment-cost-col {
  background: #ffe8d1;
}
.shipment-details-table :deep(td.shipment-cost-col) {
  background: #ffe8d1;
}
.shipment-details-table :deep(thead tr th.shipment-cost-col) {
  background: #ffe8d1;
}

.shipment-details-table :deep(td:first-child),
.shipment-details-table :deep(th:first-child) {
  position: sticky;
  left: 0;
}

.shipment-details-table :deep(td:nth-child(2)),
.shipment-details-table :deep(th:nth-child(2)) {
  position: sticky;
  left: var(--sl-col-width);
}

.shipment-details-table :deep(td:nth-child(3)),
.shipment-details-table :deep(th:nth-child(3)) {
  position: sticky;
  left: calc(var(--sl-col-width) + 1.2in);
}

.shipment-details-table :deep(td:first-child) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.shipment-details-table :deep(td:nth-child(2)),
.shipment-details-table :deep(td:nth-child(3)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-details-table :deep(tr:first-child th:first-child),
.shipment-details-table :deep(tr:first-child th:nth-child(2)),
.shipment-details-table :deep(tr:first-child th:nth-child(3)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.shipment-total-row td {
  background: rgba(255, 255, 255, 0.85);
  font-weight: 600;
}

.shipment-total-row td.shipment-qty-col--quantity {
  background: #d0e6ff;
}

.shipment-total-row td.shipment-package-weight-col {
  background: #e8d7f7;
}

.shipment-total-row td.shipment-price-col {
  background: #daf3e4;
}

.shipment-total-row td.shipment-cost-col {
  background: #ffe8d1;
}

@media (max-width: 1023px) {
  .shipment-details-table {
    height: clamp(320px, calc(100vh - 260px), 65vh);
  }
}

:deep(input[type="number"]::-webkit-outer-spin-button),
:deep(input[type="number"]::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(input[type="number"]) {
  -moz-appearance: textfield;
}
</style>

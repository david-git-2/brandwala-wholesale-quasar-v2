<template>
  <div class="shipment-item-card-list q-pa-md">
    <q-inner-loading :showing="loading" />

    <div v-if="!items || items.length === 0" class="text-center q-pa-xl text-grey-6">
      <q-icon name="ph ph-package" size="48px" class="q-mb-sm" />
      <div class="text-subtitle1">No line items in this shipment yet.</div>
    </div>

    <!-- Full Width List Cards with Inline Editable Fields -->
    <div v-else class="column q-gutter-y-sm">
      <q-card
        v-for="(item, index) in items"
        :key="item.id || index"
        flat
        bordered
        class="full-width-item-card shadow-1-hover transition-all"
      >
        <q-card-section class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            
            <!-- 1. SL & Image -->
            <div class="col-auto row items-center q-gutter-x-xs">
              <q-badge color="grey-8" class="text-weight-bold font-mono q-px-xs">
                {{ index + 1 }}
              </q-badge>

              <q-img
                :src="item.image_url || (item as any).image || (item as any).product?.image_url || 'https://cdn.quasar.dev/img/placeholder.png'"
                style="height: 54px; width: 54px; border-radius: 6px; flex-shrink: 0;"
                fit="contain"
                class="bg-white border-grey"
              >
                <template v-slot:error>
                  <div class="absolute-full flex flex-center bg-grey-3 text-grey-6 text-caption">
                    No Img
                  </div>
                </template>
              </q-img>
            </div>

            <!-- 2. Separate Product Name Cell -->
            <div class="col-12 col-md-3">
              <div
                class="text-subtitle2 text-weight-bold text-dark cursor-pointer hover-teal multiline-name"
                :title="item.name || (item as any).product_name"
                @click="$emit('edit-details', item)"
              >
                {{ item.name || (item as any).product_name || 'Unnamed Product' }}
              </div>
              <div v-if="item.add_method" class="q-mt-xs">
                <span class="text-uppercase text-weight-medium bg-grey-3 text-grey-8 q-px-xs rounded-borders" style="font-size: 10px">
                  {{ item.add_method }}
                </span>
                <span v-if="shipment?.status === 'in_transit'" class="text-caption text-weight-bold q-ml-xs" :class="isItemSplitsComplete(item) ? 'text-green-7' : 'text-orange-7'">
                  • Split: {{ isItemSplitsComplete(item) ? 'Done' : 'Pending' }}
                </span>
              </div>
            </div>

            <!-- 3. Product Codes Cell (with Copy Buttons) -->
            <div class="col-12 col-md-2 font-mono text-caption bg-grey-1 q-pa-xs rounded-borders border-grey">
              <div class="row items-center justify-between no-wrap q-mb-xs" v-if="item.product_code">
                <div class="ellipsis">
                  <span class="text-grey-6 text-uppercase" style="font-size: 9px">Code: </span>
                  <b class="text-dark">{{ item.product_code }}</b>
                </div>
                <q-btn
                  flat
                  dense
                  round
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  @click.stop="copyToClipboard(item.product_code, 'Product Code')"
                >
                  <q-tooltip>Copy Product Code</q-tooltip>
                </q-btn>
              </div>

              <div class="row items-center justify-between no-wrap q-mb-xs" v-if="item.barcode">
                <div class="ellipsis">
                  <span class="text-grey-6 text-uppercase" style="font-size: 9px">Barcode: </span>
                  <span class="text-grey-9">{{ item.barcode }}</span>
                </div>
                <q-btn
                  flat
                  dense
                  round
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  @click.stop="copyToClipboard(item.barcode, 'Barcode')"
                >
                  <q-tooltip>Copy Barcode</q-tooltip>
                </q-btn>
              </div>

              <div class="row items-center justify-between no-wrap" v-if="item.product_id">
                <div class="ellipsis">
                  <span class="text-grey-6 text-uppercase" style="font-size: 9px">ID: </span>
                  <span class="text-grey-9">{{ item.product_id }}</span>
                </div>
                <q-btn
                  flat
                  dense
                  round
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  @click.stop="copyToClipboard(String(item.product_id), 'Product ID')"
                >
                  <q-tooltip>Copy Product ID</q-tooltip>
                </q-btn>
              </div>
            </div>

            <!-- 4. EDITABLE Financials & Cost (Price, Cost, Quantity) -->
            <div class="col-12 col-sm-6 col-md-4 row items-center justify-around text-caption bg-teal-1 text-teal-10 q-pa-xs rounded-borders">
              <!-- Purchase Price (Editable Input) -->
              <div class="text-center" style="max-width: 90px;">
                <div class="text-uppercase text-grey-7" style="font-size: 9px">Price {{ purchaseCurrencySymbol }}</div>
                <q-input
                  v-if="isEditable"
                  :model-value="getDraftValue(item, 'purchase_price')"
                  type="number"
                  step="0.01"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-card-input"
                  input-class="text-center text-weight-bold text-teal-9"
                  @update:model-value="(val) => setDraftValue(item, 'purchase_price', val)"
                  @blur="saveDraftValue(item, 'purchase_price', { decimals: 2 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
                <div v-else class="text-weight-bolder">
                  {{ purchaseCurrencySymbol }} {{ formatPrice(item.purchase_price) }}
                </div>
                <div class="text-grey-7 q-mt-xs" style="font-size: 10px">
                  T: {{ formatPrice((item.purchase_price || 0) * (item.ordered_quantity || 0)) }}
                </div>
              </div>

              <q-separator vertical class="q-mx-xs" />

              <!-- Calculated Cost BDT -->
              <div class="text-center" style="max-width: 95px;">
                <div class="text-uppercase text-grey-7" style="font-size: 9px">Cost {{ costCurrencySymbol }}</div>
                <div class="text-weight-bolder text-amber-10">
                  {{ costCurrencySymbol }} {{ formatPrice(lineCostBdt(item)) }}
                </div>
                <div class="text-grey-7 q-mt-xs" style="font-size: 10px">
                  T: {{ formatPrice(lineCostBdt(item) * (item.ordered_quantity || 0)) }}
                </div>
              </div>

              <q-separator vertical class="q-mx-xs" />

              <!-- Ordered Quantity (Editable Input) -->
              <div class="text-center" style="max-width: 75px;">
                <div class="text-uppercase text-grey-7" style="font-size: 9px">Quantity</div>
                <q-input
                  v-if="isEditable"
                  :model-value="getDraftValue(item, 'ordered_quantity')"
                  type="number"
                  min="1"
                  step="1"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-card-input"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'ordered_quantity', val)"
                  @blur="saveDraftValue(item, 'ordered_quantity')"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
                <div v-else class="text-weight-bolder text-dark">
                  {{ item.ordered_quantity || (item as any).quantity || 0 }} pcs
                </div>
                <div class="text-grey-7 q-mt-xs" style="font-size: 10px; user-select: none;">
                  &nbsp;
                </div>
              </div>
            </div>

            <!-- 5. EDITABLE Weights (Product Weight & Package Weight) -->
            <div class="col-12 col-sm-6 col-md-3 row items-center justify-around text-caption bg-grey-2 text-grey-9 q-pa-xs rounded-borders">
              <!-- Product Weight (Editable Input) -->
              <div class="text-center" style="max-width: 95px;">
                <div class="text-uppercase text-grey-7" style="font-size: 9px">Product Wt</div>
                <q-input
                  v-if="isEditable"
                  :model-value="getDraftValue(item, 'product_weight')"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-card-input"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'product_weight', val)"
                  @blur="saveDraftValue(item, 'product_weight', { decimals: 3 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
                <div v-else class="text-weight-bold">
                  {{ formatDecimal(item.product_weight) }} kg
                </div>
                <div class="text-grey-7 q-mt-xs" style="font-size: 10px">
                  T: {{ formatPrice((item.product_weight || 0) * (item.ordered_quantity || 0)) }} kg
                </div>
              </div>

              <q-separator vertical class="q-mx-xs" />

              <!-- Package Weight (Editable Input) -->
              <div class="text-center" style="max-width: 95px;">
                <div class="text-uppercase text-grey-7" style="font-size: 9px">Package Wt</div>
                <q-input
                  v-if="isEditable"
                  :model-value="getDraftValue(item, 'package_weight')"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-card-input"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'package_weight', val)"
                  @blur="saveDraftValue(item, 'package_weight', { decimals: 3 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
                <div v-else class="text-weight-bold">
                  {{ formatDecimal(item.package_weight) }} kg
                </div>
                <div class="text-grey-7 q-mt-xs" style="font-size: 10px">
                  T: {{ formatPrice((item.package_weight || 0) * (item.ordered_quantity || 0)) }} kg
                </div>
              </div>

              <!-- Actions Menu -->
              <div class="col-auto">
                <q-btn flat round dense icon="ph ph-dots-three-vertical" color="grey-7">
                  <q-menu auto-close>
                    <q-list style="min-width: 140px">
                      <q-item clickable @click="$emit('edit-details', item)">
                        <q-item-section avatar>
                          <q-icon name="ph ph-pencil-simple" color="primary" size="18px" />
                        </q-item-section>
                        <q-item-section>Edit Details</q-item-section>
                      </q-item>
                      <q-item clickable @click="$emit('delete', item)">
                        <q-item-section avatar>
                          <q-icon name="ph ph-trash" color="negative" size="18px" />
                        </q-item-section>
                        <q-item-section class="text-negative">Delete Item</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </div>
            </div>

          </div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, type PropType } from 'vue'
import { useQuasar } from 'quasar'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import type { GlobalShipment, GlobalShipmentItem } from '../repositories/globalShipmentRepository'
import { calculateLineLandedCostBdt } from 'src/shared/shipment-engine'

const $q = useQuasar()
const shipmentStore = useGlobalShipmentStore()

const props = withDefaults(
  defineProps<{
    items?: GlobalShipmentItem[];
    shipment?: GlobalShipment | Record<string, any> | null;
    loading?: boolean;
    purchaseCurrencySymbol?: string;
    costCurrencySymbol?: string;
  }>(),
  {
    items: () => [],
    shipment: null,
    loading: false,
    purchaseCurrencySymbol: '£',
    costCurrencySymbol: '৳',
  }
)

defineEmits(['edit-details', 'delete'])

const isEditable = computed(() => {
  if (!props.shipment) return true
  const status = props.shipment.status?.toLowerCase()
  return status !== 'received' && status !== 'cancelled' && status !== 'closed'
})

const lineCostBdt = (item: any) => {
  if (item.landed_cost_bdt != null && Number.isFinite(Number(item.landed_cost_bdt))) {
    return Number(item.landed_cost_bdt)
  }
  if (item.cost_bdt != null && Number.isFinite(Number(item.cost_bdt))) {
    return Number(item.cost_bdt)
  }
  if (!props.shipment) return 0
  return calculateLineLandedCostBdt(item, props.shipment as any, props.items as any)
}

const formatPrice = (val: any) => {
  if (val === undefined || val === null || val === '') return '0.00'
  const num = Number(val)
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

const formatDecimal = (val: any) => {
  if (val === undefined || val === null || val === '') return '-'
  const num = Number(val)
  return isNaN(num) ? '-' : num.toString()
}

const roundTo = (value: number, decimals: number) => {
  const factor = Math.pow(10, decimals)
  return Math.round(value * factor) / factor
}

const isItemSplitsComplete = (item: any) => {
  return item && (item.splits_complete === true || item.split_status === 'complete')
}

const copyToClipboard = (text: any, label: string) => {
  if (!text) return
  navigator.clipboard.writeText(String(text))
  $q.notify({
    type: 'positive',
    message: `Copied ${label} to clipboard!`,
    icon: 'ph ph-check',
    timeout: 1200,
    position: 'top'
  })
}

const activeSaves = new Set()
const draftValues = ref<Record<string, any>>({})

const getDraftValue = (item: any, field: string) => {
  const key = `${item.id}:${field}`
  if (key in draftValues.value) {
    return draftValues.value[key]
  }
  return item[field] ?? ''
}

const setDraftValue = (item: any, field: string, val: any) => {
  const key = `${item.id}:${field}`
  draftValues.value[key] = val
}

const saveDraftValue = async (item: any, field: string, options?: any) => {
  const key = `${item.id}:${field}`
  const rawValue = key in draftValues.value ? draftValues.value[key] : item[field]
  delete draftValues.value[key]

  if (rawValue === null || rawValue === undefined || rawValue === '') return
  const parsed = Number(rawValue)
  if (isNaN(parsed) || !Number.isFinite(parsed) || parsed < 0) {
    $q.notify({
      type: 'warning',
      message: 'Value must be 0 or greater.',
      position: 'top'
    })
    return
  }

  let normalized = options?.decimals != null ? roundTo(parsed, options.decimals) : Math.floor(parsed)
  if (field === 'ordered_quantity') {
    normalized = Math.max(1, Math.floor(parsed))
  }

  const currentValue = Number(item[field] ?? 0)
  if (currentValue === normalized) return

  if (activeSaves.has(key)) return
  activeSaves.add(key)

  try {
    await shipmentStore.updateShipmentItem(item.id, { [field]: normalized })
    $q.notify({
      type: 'positive',
      message: `Updated ${field.replace('_', ' ')}`,
      icon: 'ph ph-check',
      timeout: 1000,
      position: 'top'
    })
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to update item.'
    $q.notify({
      type: 'negative',
      message: msg,
      position: 'top'
    })
  } finally {
    activeSaves.delete(key)
  }
}
</script>

<style scoped>
.full-width-item-card {
  width: 100%;
  border-radius: 8px;
  background-color: #ffffff;
  border: 1px solid #e2e8f0;
  transition: all 0.2s ease-in-out;
}
.full-width-item-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.05);
}
.multiline-name {
  white-space: normal;
  word-break: break-word;
  line-height: 1.3;
}
.inline-card-input :deep(.q-field__native) {
  padding: 2px 4px;
}
.hover-teal:hover {
  color: #0d9488 !important;
}
.border-grey {
  border: 1px solid #e2e8f0;
}
</style>

<template>
  <q-card flat bordered class="q-pa-md shipment-weight-balance-card bg-white">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-subtitle1 text-weight-bold text-primary row items-center q-gutter-xs">
        <q-icon name="scale" size="22px" />
        <span>Shipment Weight Balance</span>
      </div>
      <q-badge
        v-if="hasDelta"
        :color="deltaColor"
        class="q-py-xs q-px-sm text-weight-bold"
      >
        Delta: {{ deltaKg.toFixed(2) }} kg
      </q-badge>
    </div>

    <!-- 1. Manage Boxes Section -->
    <div class="bg-grey-1 q-pa-sm rounded-borders border-light q-mb-md">
      <div class="text-caption text-weight-bold text-grey-9 q-mb-xs">Manage Box Weights</div>
      <div class="row q-col-gutter-xs items-center">
        <div class="col-5">
          <q-input
            v-model="newBoxNumber"
            label="Box #"
            placeholder="e.g. A-1"
            outlined
            dense
            stack-label
            bg-color="white"
            class="soft-input"
            @keyup.enter="addBox"
          />
        </div>
        <div class="col-5">
          <q-input
            v-model.number="newBoxWeight"
            type="number"
            label="Weight (kg)"
            placeholder="e.g. 15.5"
            outlined
            dense
            stack-label
            bg-color="white"
            class="soft-input"
            step="0.01"
            @keyup.enter="addBox"
          />
        </div>
        <div class="col-2 text-center">
          <q-btn
            color="primary"
            icon="add"
            dense
            flat
            round
            :disable="!newBoxNumber.trim() || newBoxWeight === null || newBoxWeight <= 0"
            @click="addBox"
          >
            <q-tooltip>Add Box</q-tooltip>
          </q-btn>
        </div>
      </div>

      <!-- Scrollable list of boxes -->
      <div v-if="boxes.length" class="q-mt-sm q-gutter-y-xs scroll" style="max-height: 150px;">
        <div
          v-for="box in boxes"
          :key="box.id"
          class="row items-center justify-between q-px-sm q-py-xs bg-white rounded-borders shadow-1 border-light box-row"
        >
          <div class="text-caption text-black">
            Box <strong>{{ box.box_number }}</strong>: {{ box.weight_kg }} kg
          </div>
          <q-btn
            flat
            round
            dense
            color="negative"
            icon="close"
            size="xs"
            @click="deleteBox(box.id)"
          >
            <q-tooltip>Delete Box</q-tooltip>
          </q-btn>
        </div>
      </div>
      <div v-else class="text-caption text-grey-6 text-center q-py-sm">
        No individual boxes added yet.
      </div>
    </div>

    <!-- 2. Summary Row -->
    <div class="row q-col-gutter-sm q-mb-md text-center">
      <div class="col-4">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7">Estimated</div>
          <div class="text-subtitle2 text-weight-bold text-mono">{{ estimatedKg.toFixed(2) }} kg</div>
        </div>
      </div>
      <div class="col-4">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7">Actual</div>
          <div class="text-subtitle2 text-weight-bold text-mono">{{ actualKg.toFixed(2) }} kg</div>
        </div>
      </div>
      <div class="col-4">
        <div :class="`q-pa-xs rounded-borders ${deltaBg}`">
          <div class="text-caption text-grey-7">Delta</div>
          <div class="text-subtitle2 text-weight-bold text-mono">{{ deltaKg.toFixed(2) }} kg</div>
        </div>
      </div>
    </div>

    <!-- Validation Error Banner -->
    <div v-if="validationError" class="q-mb-md">
      <q-banner dense class="bg-warning text-black rounded-borders" style="font-size: 11px;">
        <q-icon name="warning" class="q-mr-xs" />
        {{ validationError }}
      </q-banner>
    </div>

    <!-- 3. Preview Table (only if there are boxes and no hard errors) -->
    <div v-if="boxes.length && previewItems.length && !validationError" class="q-mb-md">
      <div class="text-caption text-weight-bold text-grey-9 q-mb-xs">Preview Weight Adjustments</div>
      <div style="border: 1px solid rgba(0,0,0,0.08); border-radius: 8px; overflow: hidden;">
        <q-markup-table dense flat class="weight-preview-table bg-grey-1">
          <thead>
            <tr>
              <th class="text-left text-caption">Product</th>
              <th class="text-right text-caption">Qty</th>
              <th class="text-right text-caption">Pkg Wt (g)</th>
              <th class="text-right text-caption">Delta (g)</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in previewItems" :key="item.id">
              <td class="text-left text-caption text-weight-medium ellipsis" style="max-width: 120px;">
                {{ item.name }}
              </td>
              <td class="text-right text-caption text-mono">{{ item.qty }}</td>
              <td class="text-right text-caption text-mono">
                {{ item.weightBefore.toFixed(1) }} &rarr; <strong class="text-primary">{{ item.weightAfter.toFixed(1) }}</strong>
              </td>
              <td class="text-right text-caption text-mono" :class="item.delta >= 0 ? 'text-negative' : 'text-positive'">
                {{ item.delta >= 0 ? '+' : '' }}{{ item.delta.toFixed(1) }}g
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>
    </div>

    <!-- 4. Apply Action -->
    <q-btn
      color="primary"
      label="Apply Weight Balance"
      class="full-width pill-btn shadow-1"
      unelevated
      no-caps
      :disable="applyDisabled"
      :loading="applying"
      @click="confirmApply"
    >
      <q-tooltip v-if="applyDisabled">
        {{ applyDisabledReason }}
      </q-tooltip>
    </q-btn>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { globalShipmentBoxRepository } from '../repositories/globalShipmentBoxRepository'
import { computePackageWeightAdjustments } from '../utils/weightBalance'
import { useQuasar } from 'quasar'

const props = defineProps<{
  shipmentId: number
}>()

const emit = defineEmits<{
  (e: 'applied'): void
}>()

const $q = useQuasar()
const shipmentStore = useGlobalShipmentStore()
const authStore = useAuthStore()

// Local state for box additions
const newBoxNumber = ref('')
const newBoxWeight = ref<number | null>(null)
const applying = ref(false)

const boxes = computed(() => shipmentStore.currentShipmentBoxes)
const items = computed(() => shipmentStore.currentShipmentItems)

// Basic Weight Computations
const estimatedKg = computed(() => {
  let totalGm = 0
  for (const item of items.value) {
    const qty = item.ordered_quantity || 0
    totalGm += ((item.product_weight || 0) + (item.package_weight || 0)) * qty
  }
  return totalGm / 1000
})

const actualKg = computed(() => {
  return boxes.value.reduce((sum, box) => sum + (box.weight_kg || 0), 0)
})

const deltaKg = computed(() => {
  return actualKg.value - estimatedKg.value
})

const hasDelta = computed(() => {
  return boxes.value.length > 0 && Math.abs(deltaKg.value) > 0.001
})

// Delta Colors (red/heavy, green/light)
const deltaColor = computed(() => {
  if (deltaKg.value > 0) return 'negative' // heavy
  if (deltaKg.value < 0) return 'positive' // light
  return 'grey-7'
})

const deltaBg = computed(() => {
  if (deltaKg.value > 0) return 'bg-red-1 text-red-9'
  if (deltaKg.value < 0) return 'bg-green-1 text-green-9'
  return 'bg-grey-2 text-grey-9'
})

// Run adjustments calculation to check for validation errors and drive preview
const adjustments = computed(() => {
  if (boxes.value.length === 0 || items.value.length === 0) return []
  try {
    const inputItems = items.value.map((item) => ({
      id: item.id,
      name: item.name,
      product_weight: item.product_weight || 0,
      package_weight: item.package_weight || 0,
      ordered_quantity: item.ordered_quantity || 0,
    }))
    return computePackageWeightAdjustments(inputItems, actualKg.value)
  } catch (error) {
    return error as Error
  }
})

const validationError = computed(() => {
  if (adjustments.value instanceof Error) {
    return adjustments.value.message
  }
  return null
})

// Preview line items
const previewItems = computed(() => {
  const adjs = adjustments.value
  if (adjs instanceof Error || !adjs.length) return []
  return items.value
    .map((item) => {
      const adj = adjs.find((a) => a.itemId === item.id)
      if (!adj) return null
      return {
        id: item.id,
        name: item.name,
        qty: item.ordered_quantity,
        weightBefore: item.package_weight,
        weightAfter: adj.newPackageWeight,
        delta: adj.perUnitDelta * (item.ordered_quantity || 0),
      }
    })
    .filter(Boolean) as {
    id: number
    name: string
    qty: number
    weightBefore: number
    weightAfter: number
    delta: number
  }[]
})

// Apply Actions disabled states
const applyDisabled = computed(() => {
  if (boxes.value.length === 0) return true
  if (items.value.length === 0) return true
  if (validationError.value !== null) return true
  // If actual and estimated are equal, there's no delta to balance
  if (Math.abs(deltaKg.value) < 0.001) return true
  return false
})

const applyDisabledReason = computed(() => {
  if (boxes.value.length === 0) return 'Add at least one physical box weight to apply'
  if (items.value.length === 0) return 'No line items to distribute weight to'
  if (validationError.value !== null) return validationError.value
  if (Math.abs(deltaKg.value) < 0.001) return 'No weight delta to balance'
  return ''
})

// Box weight CRUD helpers
const addBox = async () => {
  const num = newBoxNumber.value.trim()
  const wt = newBoxWeight.value
  if (!num || wt === null || wt <= 0) return

  try {
    const tenantStore = useTenantStore()
    const currentTenant = tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === authStore.tenantId)
    const parentTenantId = currentTenant?.parent_id ?? authStore.tenantId
    if (!parentTenantId) throw new Error('No tenant found')

    await globalShipmentBoxRepository.create({
      parent_tenant_id: parentTenantId,
      shipment_id: props.shipmentId,
      box_number: num,
      weight_kg: wt,
    })

    newBoxNumber.value = ''
    newBoxWeight.value = null
    $q.notify({ type: 'positive', message: `Added box ${num} successfully.` })
    await shipmentStore.fetchShipmentBoxes(props.shipmentId)
  } catch (error: unknown) {
    $q.notify({ type: 'negative', message: (error as Error).message || 'Failed to add box.' })
  }
}

const deleteBox = async (boxId: number) => {
  try {
    await globalShipmentBoxRepository.delete(boxId)
    $q.notify({ type: 'positive', message: 'Box removed.' })
    await shipmentStore.fetchShipmentBoxes(props.shipmentId)
  } catch (error: unknown) {
    $q.notify({ type: 'negative', message: (error as Error).message || 'Failed to delete box.' })
  }
}

// Confirmation Dialog before running Apply
const confirmApply = () => {
  if (applyDisabled.value) return

  $q.dialog({
    title: 'Apply Weight Balance',
    message: `This will update package weights on ${previewItems.value.length} lines, sync products, and set received weight to ${actualKg.value.toFixed(2)} kg. Continue?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      applying.value = true
      try {
        await shipmentStore.applyWeightBalance(props.shipmentId)
        $q.notify({
          type: 'positive',
          message: 'Weight balance successfully distributed and applied across lines.',
        })
        emit('applied')
      } catch (error: unknown) {
        $q.notify({
          type: 'negative',
          message: (error as Error).message || 'Failed to apply weight balance.',
        })
      } finally {
        applying.value = false
      }
    })()
  })
}

</script>

<style scoped>
.shipment-weight-balance-card {
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}
.border-light {
  border: 1px solid rgba(0, 0, 0, 0.06);
}
.box-row {
  transition: all 0.2s ease;
}
.box-row:hover {
  background-color: #fcfcfc;
}
.weight-preview-table th {
  font-weight: 700;
  color: #555;
  background-color: #f3f3f3;
}
.weight-preview-table td {
  padding: 6px 8px;
}
.soft-input {
  border-radius: 8px;
}
</style>

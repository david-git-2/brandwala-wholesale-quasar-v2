<template>
  <q-card flat bordered class="q-pa-md shipment-weight-balance-card bg-white">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-subtitle1 text-weight-bold text-primary row items-center q-gutter-xs">
        <q-icon name="scale" size="22px" />
        <span>Shipment Weight Balance</span>
      </div>
      <q-badge v-if="hasDelta" :color="deltaColor" class="q-py-xs q-px-sm text-weight-bold">
        Delta: {{ deltaKg.toFixed(2) }} kg
      </q-badge>
    </div>

    <!-- 0. Cargo Invoice Weight Section -->
    <div class="bg-blue-1 border-light rounded-borders q-pa-sm q-mb-md">
      <div class="text-caption text-weight-bold text-blue-9 q-mb-xs">Cargo Invoice Weight (kg)</div>
      <div class="row q-col-gutter-sm items-center">
        <div class="col-8">
          <q-input
            v-model.number="cargoInvoiceWeight"
            type="number"
            placeholder="e.g. 35.5"
            outlined
            dense
            bg-color="white"
            class="soft-input"
            step="0.01"
          >
            <template v-slot:append>
              <q-btn
                flat
                round
                dense
                icon="save"
                color="blue-9"
                size="sm"
                :loading="savingCargoInvoiceWeight"
                @click="saveCargoInvoiceWeight"
              >
                <q-tooltip>Save Weight</q-tooltip>
              </q-btn>
            </template>
          </q-input>
        </div>
        <div class="col-4 text-caption text-grey-7 q-pl-xs leading-tight" style="font-size: 10px">
          The weight you paid the cargo bill on. Click save, then apply weight balance to distribute
          across lines.
        </div>
      </div>
    </div>

    <!-- 1. Manage Boxes Section -->
    <div class="bg-grey-1 q-pa-sm rounded-borders border-light q-mb-md">
      <div
        class="text-caption text-weight-bold text-grey-9 q-mb-xs row items-center justify-between"
      >
        <span>{{
          editingBoxId !== null ? 'Edit Box Weight' : 'Manage Box Weights (Record Only)'
        }}</span>
        <span class="text-grey-6 text-weight-medium">Total: {{ boxTotalKg.toFixed(2) }} kg</span>
      </div>
      <div class="row q-col-gutter-xs items-center">
        <div class="col-4">
          <q-input
            v-model="newBoxNumber"
            label="Box #"
            placeholder="e.g. A-1"
            outlined
            dense
            stack-label
            bg-color="white"
            class="soft-input"
            @keyup.enter="submitBoxForm"
          />
        </div>
        <div class="col-4">
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
            @keyup.enter="submitBoxForm"
          />
        </div>
        <div class="col-4 row items-center justify-center q-gutter-x-xs no-wrap">
          <q-btn
            :color="editingBoxId !== null ? 'green-7' : 'primary'"
            :icon="editingBoxId !== null ? 'check' : 'add'"
            dense
            flat
            round
            :disable="!newBoxNumber.trim() || newBoxWeight === null || newBoxWeight <= 0"
            @click="submitBoxForm"
          >
            <q-tooltip>{{ editingBoxId !== null ? 'Update Box' : 'Add Box' }}</q-tooltip>
          </q-btn>
          <q-btn
            v-if="editingBoxId !== null"
            color="grey-7"
            icon="close"
            dense
            flat
            round
            @click="cancelEditBox"
          >
            <q-tooltip>Cancel Edit</q-tooltip>
          </q-btn>
        </div>
      </div>

      <!-- Scrollable list of boxes -->
      <div v-if="boxes.length" class="q-mt-sm q-gutter-y-xs scroll" style="max-height: 150px">
        <div
          v-for="box in boxes"
          :key="box.id"
          class="row items-center justify-between q-px-sm q-py-xs bg-white rounded-borders shadow-1 border-light box-row"
        >
          <div class="text-caption text-black">
            Box
            <strong class="cursor-pointer text-underline-dashed">
              {{ box.box_number }}
              <q-popup-edit
                :model-value="box.box_number"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                v-slot="scope"
                @save="(val) => updateBox(box.id, { box_number: val })"
              >
                <q-input
                  v-model="scope.value"
                  dense
                  outlined
                  autofocus
                  label="Box #"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit> </strong
            >:
            <span class="cursor-pointer text-underline-dashed">
              {{ box.weight_kg }}
              <q-popup-edit
                :model-value="box.weight_kg"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                v-slot="scope"
                @save="(val) => updateBox(box.id, { weight_kg: Number(val) })"
              >
                <q-input
                  :model-value="scope.value ?? ''"
                  type="number"
                  step="0.01"
                  dense
                  outlined
                  autofocus
                  label="Weight (kg)"
                  @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                  @keyup.enter="scope.set"
                />
              </q-popup-edit>
            </span>
            kg
          </div>
          <div class="row items-center q-gutter-x-xs">
            <q-btn
              flat
              round
              dense
              color="primary"
              icon="edit"
              size="xs"
              @click="startEditBox(box)"
            >
              <q-tooltip>Edit Box (Fill form above)</q-tooltip>
            </q-btn>
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
      </div>
      <div v-else class="text-caption text-grey-6 text-center q-py-sm">
        No individual boxes added yet.
      </div>

      <!-- Box vs invoice verification -->
      <div v-if="boxes.length && savedInvoiceWeightKg > 0" class="q-mt-sm">
        <q-banner
          dense
          :class="boxVerificationMatch ? 'bg-green-1 text-green-9' : 'bg-amber-1 text-amber-10'"
          rounded
          style="font-size: 11px"
        >
          <template v-slot:avatar>
            <q-icon :name="boxVerificationMatch ? 'check_circle' : 'warning'" />
          </template>
          <span v-if="boxVerificationMatch">
            Box total ({{ boxTotalKg.toFixed(2) }} kg) matches cargo invoice weight ({{
              savedInvoiceWeightKg.toFixed(2)
            }}
            kg).
          </span>
          <span v-else>
            Box total ({{ boxTotalKg.toFixed(2) }} kg) differs from cargo invoice ({{
              savedInvoiceWeightKg.toFixed(2)
            }}
            kg) by {{ Math.abs(boxTotalKg - savedInvoiceWeightKg).toFixed(2) }} kg.
          </span>
        </q-banner>
      </div>
    </div>

    <!-- 2. Summary Row -->
    <div class="row q-col-gutter-xs q-mb-md text-center">
      <div class="col-3">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7" style="font-size: 10px">Estimated</div>
          <div class="text-subtitle2 text-weight-bold text-mono" style="font-size: 12px">
            {{ estimatedKg.toFixed(2) }} kg
          </div>
        </div>
      </div>
      <div class="col-3">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7" style="font-size: 10px">Box Total</div>
          <div class="text-subtitle2 text-weight-bold text-mono" style="font-size: 12px">
            {{ boxTotalKg.toFixed(2) }} kg
          </div>
        </div>
      </div>
      <div class="col-3">
        <div class="bg-grey-2 q-pa-xs rounded-borders">
          <div class="text-caption text-grey-7" style="font-size: 10px">Invoice</div>
          <div class="text-subtitle2 text-weight-bold text-mono" style="font-size: 12px">
            {{ actualKg.toFixed(2) }} kg
          </div>
        </div>
      </div>
      <div class="col-3">
        <div :class="`q-pa-xs rounded-borders ${deltaBg}`">
          <div class="text-caption text-grey-7" style="font-size: 10px">Delta</div>
          <div class="text-subtitle2 text-weight-bold text-mono" style="font-size: 12px">
            {{ deltaKg.toFixed(2) }} kg
          </div>
        </div>
      </div>
    </div>

    <!-- Validation Error Banner -->
    <div v-if="validationError || hasUnsavedInvoiceWeight" class="q-mb-md">
      <q-banner
        v-if="hasUnsavedInvoiceWeight"
        dense
        class="bg-amber-1 text-amber-10 rounded-borders q-mb-xs"
        style="font-size: 11px"
      >
        <q-icon name="info" class="q-mr-xs" />
        Unsaved cargo invoice weight — click save before applying weight balance.
      </q-banner>
      <q-banner
        v-if="validationError"
        dense
        class="bg-warning text-black rounded-borders"
        style="font-size: 11px"
      >
        <q-icon name="warning" class="q-mr-xs" />
        {{ validationError }}
      </q-banner>
    </div>

    <!-- 3. Preview Adjustments Trigger -->
    <div v-if="previewItems.length && !validationError" class="q-mb-sm">
      <q-btn
        outline
        color="secondary"
        icon="visibility"
        label="Preview Weight Adjustments"
        class="full-width soft-input"
        no-caps
        dense
        @click="showPreviewDialog = true"
      />

      <!-- Preview Dialog -->
      <q-dialog v-model="showPreviewDialog">
        <q-card style="width: 600px; max-width: 90vw">
          <q-card-section class="row items-center q-pb-none">
            <div class="text-subtitle1 text-weight-bold text-primary row items-center q-gutter-xs">
              <q-icon name="scale" size="20px" />
              <span>Preview Weight Adjustments</span>
            </div>
            <q-space />
            <q-btn icon="close" flat round dense v-close-popup />
          </q-card-section>

          <q-card-section class="q-pa-md">
            <div style="border: 1px solid rgba(0, 0, 0, 0.08); border-radius: 8px; overflow: hidden">
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
                    <td class="text-left text-caption text-weight-medium ellipsis" style="max-width: 250px">
                      {{ item.name }}
                    </td>
                    <td class="text-right text-caption text-mono">{{ item.qty }}</td>
                    <td class="text-right text-caption text-mono">
                      {{ item.weightBefore.toFixed(1) }} &rarr;
                      <strong class="text-primary">{{ item.weightAfter.toFixed(1) }}</strong>
                    </td>
                    <td
                      class="text-right text-caption text-mono"
                      :class="item.delta >= 0 ? 'text-negative' : 'text-positive'"
                    >
                      {{ item.delta >= 0 ? '+' : '' }}{{ item.delta.toFixed(1) }}g
                    </td>
                  </tr>
                </tbody>
              </q-markup-table>
            </div>
          </q-card-section>

          <q-card-actions align="right" class="bg-grey-1 q-pa-sm">
            <q-btn flat label="Close" color="grey-8" v-close-popup no-caps />
          </q-card-actions>
        </q-card>
      </q-dialog>
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
import { ref, computed, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { globalShipmentBoxRepository } from '../repositories/globalShipmentBoxRepository';
import { computePackageWeightAdjustments } from '../utils/weightBalance';
import {
  showSuccessNotification,
  showErrorNotification,
  showWarningNotification,
} from 'src/utils/appFeedback';

const props = defineProps<{
  shipmentId: number;
}>();

const emit = defineEmits<{
  (e: 'applied'): void;
}>();

const $q = useQuasar();
const shipmentStore = useGlobalShipmentStore();
const authStore = useAuthStore();

const showPreviewDialog = ref(false);

// Local state for box additions
const newBoxNumber = ref('');
const newBoxWeight = ref<number | null>(null);
const editingBoxId = ref<number | null>(null);
const applying = ref(false);
const savingCargoInvoiceWeight = ref(false);

const boxes = computed(() => shipmentStore.currentShipmentBoxes);
const items = computed(() => shipmentStore.currentShipmentItems);

// Basic Weight Computations
const estimatedKg = computed(() => {
  let totalGm = 0;
  for (const item of items.value) {
    const qty = item.ordered_quantity || 0;
    totalGm += ((item.product_weight || 0) + (item.package_weight || 0)) * qty;
  }
  return totalGm / 1000;
});

const cargoInvoiceWeight = ref<number | null>(null);

watch(
  () => shipmentStore.currentShipment?.received_weight,
  (newVal) => {
    cargoInvoiceWeight.value = newVal ?? null;
  },
  { immediate: true },
);

const saveCargoInvoiceWeight = async () => {
  const val = cargoInvoiceWeight.value;
  if (val === null || val <= 0) {
    showWarningNotification('Cargo Invoice Weight must be greater than 0.');
    return;
  }
  const roundedKg = Math.round(val * 100) / 100;
  savingCargoInvoiceWeight.value = true;
  try {
    await shipmentStore.updateShipment(props.shipmentId, { received_weight: roundedKg });
    cargoInvoiceWeight.value = roundedKg;
    showSuccessNotification('Cargo Invoice Weight updated successfully.');
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to update Cargo Invoice Weight.');
  } finally {
    savingCargoInvoiceWeight.value = false;
  }
};

const boxTotalKg = computed(() => {
  return boxes.value.reduce((sum, box) => sum + (box.weight_kg || 0), 0);
});

const boxVerificationMatch = computed(() => {
  const invoice = savedInvoiceWeightKg.value;
  if (invoice <= 0 || boxes.value.length === 0) return false;
  return Math.abs(boxTotalKg.value - invoice) <= 0.1;
});

const savedInvoiceWeightKg = computed(() => {
  const rw = shipmentStore.currentShipment?.received_weight;
  return rw != null && rw > 0 ? Math.round(rw * 100) / 100 : 0;
});

const hasUnsavedInvoiceWeight = computed(() => {
  const saved = shipmentStore.currentShipment?.received_weight;
  const draft = cargoInvoiceWeight.value;
  if (draft === null || draft <= 0) return saved != null && saved > 0;
  const roundedDraft = Math.round(draft * 100) / 100;
  const roundedSaved = saved != null ? Math.round(saved * 100) / 100 : null;
  return roundedSaved === null || roundedDraft !== roundedSaved;
});

const actualKg = computed(() => savedInvoiceWeightKg.value);

const deltaKg = computed(() => {
  return actualKg.value - estimatedKg.value;
});

const hasDelta = computed(() => {
  return actualKg.value > 0 && Math.abs(deltaKg.value) > 0.001;
});

// Delta Colors (red/heavy, green/light)
const deltaColor = computed(() => {
  if (deltaKg.value > 0) return 'negative'; // heavy
  if (deltaKg.value < 0) return 'positive'; // light
  return 'grey-7';
});

const deltaBg = computed(() => {
  if (deltaKg.value > 0) return 'bg-red-1 text-red-9';
  if (deltaKg.value < 0) return 'bg-green-1 text-green-9';
  return 'bg-grey-2 text-grey-9';
});

// Run adjustments calculation to check for validation errors and drive preview
const adjustments = computed(() => {
  if (actualKg.value <= 0 || items.value.length === 0) return [];
  try {
    const inputItems = items.value.map((item) => ({
      id: item.id,
      name: item.name,
      product_weight: item.product_weight || 0,
      package_weight: item.package_weight || 0,
      ordered_quantity: item.ordered_quantity || 0,
    }));
    return computePackageWeightAdjustments(inputItems, actualKg.value);
  } catch (error) {
    return error as Error;
  }
});

const validationError = computed(() => {
  if (adjustments.value instanceof Error) {
    return adjustments.value.message;
  }
  return null;
});

// Preview line items
const previewItems = computed(() => {
  const adjs = adjustments.value;
  if (adjs instanceof Error || !adjs.length) return [];
  return items.value
    .map((item) => {
      const adj = adjs.find((a) => a.itemId === item.id);
      if (!adj) return null;
      return {
        id: item.id,
        name: item.name,
        qty: item.ordered_quantity,
        weightBefore: item.package_weight,
        weightAfter: adj.newPackageWeight,
        delta: adj.perUnitDelta * (item.ordered_quantity || 0),
      };
    })
    .filter(Boolean) as {
    id: number;
    name: string;
    qty: number;
    weightBefore: number;
    weightAfter: number;
    delta: number;
  }[];
});

// Apply Actions disabled states
const applyDisabled = computed(() => {
  if (savedInvoiceWeightKg.value <= 0) return true;
  if (hasUnsavedInvoiceWeight.value) return true;
  if (items.value.length === 0) return true;
  if (validationError.value !== null) return true;
  if (Math.abs(deltaKg.value) < 0.001) return true;
  return false;
});

const applyDisabledReason = computed(() => {
  if (savedInvoiceWeightKg.value <= 0)
    return 'Save Cargo Invoice Weight before applying weight balance';
  if (hasUnsavedInvoiceWeight.value) return 'Save Cargo Invoice Weight first — unsaved changes';
  if (items.value.length === 0) return 'No line items to distribute weight to';
  if (validationError.value !== null) return validationError.value;
  if (Math.abs(deltaKg.value) < 0.001) return 'No weight delta to balance';
  return '';
});

// Auto-fill box number calculations
const getNextBoxNumber = (): string => {
  if (!boxes.value || boxes.value.length === 0) {
    return '1';
  }
  const lastBox = boxes.value[boxes.value.length - 1];
  if (!lastBox) return '1';

  const lastNum = lastBox.box_number;
  const match = lastNum.match(/^(.*?)(\d+)$/);
  if (match) {
    const prefix = match[1] ?? '';
    const numStr = match[2] ?? '';
    const num = parseInt(numStr, 10);
    const nextNum = String(num + 1);
    const paddedNum = nextNum.padStart(numStr.length, '0');
    return `${prefix}${paddedNum}`;
  }
  return `${lastNum}-2`;
};

const autoFillNextBoxNumber = () => {
  if (!newBoxNumber.value) {
    newBoxNumber.value = getNextBoxNumber();
  }
};

// Watch boxes to auto-fill if empty
watch(
  boxes,
  () => {
    autoFillNextBoxNumber();
  },
  { immediate: true },
);

// Box weight CRUD helpers
const startEditBox = (box: (typeof boxes.value)[number]) => {
  editingBoxId.value = box.id;
  newBoxNumber.value = box.box_number;
  newBoxWeight.value = box.weight_kg;
};

const cancelEditBox = () => {
  editingBoxId.value = null;
  newBoxNumber.value = '';
  newBoxWeight.value = null;
  autoFillNextBoxNumber();
};

const submitBoxForm = async () => {
  if (editingBoxId.value !== null) {
    await updateBoxFromForm();
  } else {
    await addBox();
  }
};

const addBox = async () => {
  const num = newBoxNumber.value.trim();
  const wt = newBoxWeight.value;
  if (!num || wt === null || wt <= 0) return;

  try {
    const tenantStore = useTenantStore();
    const currentTenant =
      tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === authStore.tenantId);
    const parentTenantId = currentTenant?.parent_id ?? authStore.tenantId;
    if (!parentTenantId) throw new Error('No tenant found');

    await globalShipmentBoxRepository.create({
      parent_tenant_id: parentTenantId,
      shipment_id: props.shipmentId,
      box_number: num,
      weight_kg: wt,
    });

    newBoxWeight.value = null;
    showSuccessNotification(`Added box ${num} successfully.`);
    await shipmentStore.fetchShipmentBoxes(props.shipmentId);
    // Clear and autofill next box number
    newBoxNumber.value = '';
    autoFillNextBoxNumber();
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to add box.');
  }
};

const updateBoxFromForm = async () => {
  const id = editingBoxId.value;
  const num = newBoxNumber.value.trim();
  const wt = newBoxWeight.value;
  if (id === null || !num || wt === null || wt <= 0) return;

  try {
    await globalShipmentBoxRepository.update(id, {
      box_number: num,
      weight_kg: wt,
    });
    showSuccessNotification('Box updated successfully.');
    await shipmentStore.fetchShipmentBoxes(props.shipmentId);
    cancelEditBox();
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to update box.');
  }
};

const updateBox = async (boxId: number, patch: { box_number?: string; weight_kg?: number }) => {
  if (patch.box_number !== undefined && !patch.box_number.trim()) {
    showWarningNotification('Box number cannot be empty.');
    return;
  }
  if (patch.weight_kg !== undefined && (Number.isNaN(patch.weight_kg) || patch.weight_kg <= 0)) {
    showWarningNotification('Weight must be greater than 0.');
    return;
  }

  try {
    await globalShipmentBoxRepository.update(boxId, patch);
    showSuccessNotification('Box updated successfully.');
    await shipmentStore.fetchShipmentBoxes(props.shipmentId);
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to update box.');
  }
};

const deleteBox = async (boxId: number) => {
  try {
    await globalShipmentBoxRepository.delete(boxId);
    showSuccessNotification('Box removed.');
    await shipmentStore.fetchShipmentBoxes(props.shipmentId);
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to delete box.');
  }
};

// Confirmation Dialog before running Apply
const confirmApply = () => {
  if (applyDisabled.value) return;

  $q.dialog({
    title: 'Apply Weight Balance',
    message: `This will update package weights on ${previewItems.value.length} lines and sync products to match the saved invoice weight of ${savedInvoiceWeightKg.value.toFixed(2)} kg. Continue?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      applying.value = true;
      try {
        await shipmentStore.applyWeightBalance(props.shipmentId);
        showSuccessNotification(
          'Weight balance successfully distributed and applied across lines.',
        );
        emit('applied');
      } catch (error: unknown) {
        showErrorNotification((error as Error).message || 'Failed to apply weight balance.');
      } finally {
        applying.value = false;
      }
    })();
  });
};
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
.text-underline-dashed {
  text-decoration: underline dashed;
}
</style>

<template>
  <div class="column col overflow-hidden">
    <div v-if="loading" class="col row justify-center items-center">
      <q-spinner color="primary" size="3em" />
      <div class="text-grey-7 q-ml-md">Loading boxes...</div>
    </div>

    <template v-else>
      <div class="col overflow-auto hide-native-scrollbar">
        <q-markup-table flat class="shipment-items-markup-table bg-white" style="min-width: 720px; width: 100%">
          <thead>
            <tr>
              <th class="text-center" style="width: 48px; min-width: 48px">SL</th>
              <th class="text-left" style="min-width: 120px">Box #</th>
              <th class="text-center bw-ops-col-tint--qty" style="min-width: 100px">Received (kg)</th>
              <th class="text-center bw-ops-col-tint--qty" style="min-width: 100px">Shipping (kg)</th>
              <th class="text-center" style="min-width: 100px">
                <div>Ship − recv</div>
                <div class="text-xxs text-weight-regular text-grey-7">(kg)</div>
              </th>
              <th class="text-center" style="min-width: 100px">Status</th>
              <th class="text-center" style="width: 88px; min-width: 88px" />
            </tr>
          </thead>
          <tbody>
            <tr v-for="(box, index) in savedRows" :key="box.id">
              <td class="text-center text-grey-7 font-mono text-weight-medium">
                {{ index + 1 }}
              </td>
              <td class="q-pa-none" @click.stop>
                <q-input
                  :model-value="getBoxNumber({ kind: 'saved', id: box.id })"
                  dense
                  borderless
                  input-class="text-left font-mono text-weight-bold text-slate-800 excel-cell-input-native"
                  class="excel-cell-input"
                  :loading="isRowSaving({ kind: 'saved', id: box.id })"
                  @update:model-value="(val) => setBoxNumber({ kind: 'saved', id: box.id }, val)"
                  @blur="() => commitSavedRow(box.id)"
                  @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
                />
              </td>
              <td
                v-for="field in weightFields"
                :key="field"
                class="text-center bw-ops-col-tint--qty q-pa-none"
                @click.stop
              >
                <q-input
                  :model-value="getWeight({ kind: 'saved', id: box.id }, field)"
                  type="number"
                  step="0.01"
                  dense
                  borderless
                  input-class="text-center font-mono text-weight-bold text-slate-800 excel-cell-input-native"
                  class="excel-cell-input"
                  :loading="isRowSaving({ kind: 'saved', id: box.id })"
                  @update:model-value="(val) => setWeight({ kind: 'saved', id: box.id }, field, val)"
                  @blur="() => commitSavedRow(box.id)"
                  @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
                />
              </td>
              <td class="text-center font-mono text-weight-medium text-grey-8">
                <template v-if="rowVariance({ kind: 'saved', id: box.id }).diff !== null">
                  {{ formatDiff(rowVariance({ kind: 'saved', id: box.id }).diff!) }}
                </template>
                <span v-else class="text-grey-5">—</span>
              </td>
              <td class="text-center">
                <q-badge
                  v-if="rowVariance({ kind: 'saved', id: box.id }).status"
                  :color="statusBadgeColor(rowVariance({ kind: 'saved', id: box.id }).status!)"
                  class="text-weight-bold"
                >
                  {{ statusLabel(rowVariance({ kind: 'saved', id: box.id }).status!) }}
                </q-badge>
                <span v-else class="text-grey-5">—</span>
              </td>
              <td class="text-center">
                <q-btn
                  flat
                  round
                  dense
                  size="sm"
                  icon="ph ph-trash"
                  color="grey-7"
                  :disable="isRowSaving({ kind: 'saved', id: box.id })"
                  @click="deleteRow(box.id)"
                >
                  <q-tooltip>Delete box</q-tooltip>
                </q-btn>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>

      <div class="shrink-0 bg-white border-top q-px-lg q-py-sm column q-gutter-y-xs">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="text-caption text-grey-7">
            {{ savedRows.length }} box<span v-if="savedRows.length !== 1">es</span>
          </div>
          <div class="text-caption text-weight-bold text-grey-9 font-mono row q-gutter-md">
            <span>Recv: {{ totalReceivedKg.toFixed(2) }} kg</span>
            <span>Ship: {{ totalShippingKg.toFixed(2) }} kg</span>
          </div>
        </div>
        <div v-if="savedRows.length" class="text-caption text-grey-8 column q-gutter-y-2xs">
          <div>
            <span class="text-weight-bold font-mono text-grey-9">
              {{ totalsNetDiff.formulaLabel }} = {{ totalsNetDiff.signedKgLabel }}
            </span>
            <span class="q-ml-xs">{{ totalsNetDiff.explanation }}</span>
          </div>
          <template v-if="invoiceCargoKg > 0">
            <div class="text-xxs text-weight-bold text-grey-6">
              vs invoice cargo ({{ invoiceCargoKg.toFixed(2) }} kg)
            </div>
            <div>
              <span class="text-weight-bold font-mono text-grey-9">
                {{ boxShippingVsInvoice.formulaLabel }} = {{ boxShippingVsInvoice.signedKgLabel }}
              </span>
              <span class="q-ml-xs">{{ boxShippingVsInvoice.explanation }}</span>
            </div>
            <div>
              <span class="text-weight-bold font-mono text-grey-9">
                {{ boxReceivedVsInvoice.formulaLabel }} = {{ boxReceivedVsInvoice.signedKgLabel }}
              </span>
              <span class="q-ml-xs">{{ boxReceivedVsInvoice.explanation }}</span>
            </div>
          </template>
        </div>
      </div>
    </template>

    <q-dialog v-model="showAddDialog" persistent>
      <q-card style="min-width: 360px; max-width: 96vw">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-weight-bold">Add box</div>
          <q-space />
          <q-btn v-close-popup icon="ph ph-x" flat round dense @click="closeAddDialog" />
        </q-card-section>

        <q-card-section class="q-gutter-md q-pt-sm">
          <q-input
            v-model="addForm.box_number"
            label="Box #"
            outlined
            dense
            autofocus
            @keyup.enter="saveAddBox"
          />
          <q-input
            v-model.number="addForm.received_weight"
            type="number"
            label="Received (kg)"
            outlined
            dense
            step="0.01"
            @keyup.enter="saveAddBox"
          />
          <q-input
            v-model.number="addForm.shipping_weight"
            type="number"
            label="Shipping (kg)"
            outlined
            dense
            step="0.01"
            @keyup.enter="saveAddBox"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat no-caps label="Cancel" color="grey-8" @click="closeAddDialog" />
          <q-btn
            unelevated
            no-caps
            color="primary"
            label="Add"
            class="rounded-sq-btn text-weight-bold"
            :loading="savingAdd"
            @click="saveAddBox"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useShipmentBoxWeightGrid } from '../composables/useShipmentBoxWeightGrid';
import {
  BOX_WEIGHT_VARIANCE_LABEL,
  describeBoxTotalsNetDiff,
  type BoxWeightVarianceStatus,
} from '../utils/boxWeightVariance';

const props = defineProps<{
  shipmentId: number;
}>();

const weightFields = ['received_weight', 'shipping_weight'] as const;

const {
  loading,
  showAddDialog,
  savingAdd,
  addForm,
  savedRows,
  totalReceivedKg,
  totalShippingKg,
  invoiceCargoKg,
  boxShippingVsInvoice,
  boxReceivedVsInvoice,
  getBoxNumber,
  getWeight,
  setBoxNumber,
  setWeight,
  rowVariance,
  openAddDialog,
  closeAddDialog,
  saveAddBox,
  commitSavedRow,
  deleteRow,
  isRowSaving,
} = useShipmentBoxWeightGrid(props.shipmentId);

defineExpose({ openAddDialog });

const totalsNetDiff = computed(() =>
  describeBoxTotalsNetDiff(totalReceivedKg.value, totalShippingKg.value),
);

const formatDiff = (diff: number): string => {
  if (diff > 0) return `+${diff.toFixed(2)}`;
  return diff.toFixed(2);
};

const statusLabel = (status: BoxWeightVarianceStatus) => BOX_WEIGHT_VARIANCE_LABEL[status];

const statusBadgeColor = (status: BoxWeightVarianceStatus): string => {
  if (status === 'match') return 'grey-6';
  if (status === 'weight_loss') return 'negative';
  return 'warning';
};
</script>

<style scoped>
.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
}

.shipment-items-markup-table th,
.shipment-items-markup-table td {
  padding: 4px 4px !important;
  height: 48px;
}

.shipment-items-markup-table th.bw-ops-col-tint--qty,
.shipment-items-markup-table td.bw-ops-col-tint--qty {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

.shipment-items-markup-table tr:hover td {
  filter: brightness(0.98);
}

:deep(input[type='number']::-webkit-outer-spin-button),
:deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none !important;
  margin: 0 !important;
}

:deep(input[type='number']) {
  -moz-appearance: textfield !important;
  appearance: textfield !important;
}

:deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
  transition: all 0.1s ease-in-out;
}

:deep(.excel-cell-input .q-field__control:before),
:deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

:deep(.excel-cell-input:hover .q-field__control) {
  background-color: rgba(255, 255, 255, 0.4) !important;
}

:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: #ffffff !important;
  border: 1.5px solid #059669 !important;
  box-shadow: 0 0 0 1px #059669 !important;
}
</style>

<template>
  <div class="column col overflow-hidden">
    <div v-if="loading" class="col row justify-center items-center">
      <q-spinner color="primary" size="3em" />
      <div class="text-grey-7 q-ml-md">Loading boxes...</div>
    </div>

    <template v-else>
      <div class="col overflow-auto hide-native-scrollbar">
        <q-markup-table flat class="shipment-items-markup-table bg-white" style="min-width: 480px; width: 100%">
          <thead>
            <tr>
              <th class="text-center" style="width: 48px; min-width: 48px">SL</th>
              <th class="text-left" style="min-width: 160px">Box #</th>
              <th class="text-center bw-ops-col-tint--qty" style="min-width: 120px; width: 120px">Weight (kg)</th>
              <th class="text-center" style="width: 56px; min-width: 56px" />
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
                  @blur="() => commitRow({ kind: 'saved', id: box.id })"
                  @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
                />
              </td>
              <td class="text-center bw-ops-col-tint--qty q-pa-none" @click.stop>
                <q-input
                  :model-value="getWeightKg({ kind: 'saved', id: box.id })"
                  type="number"
                  step="0.01"
                  min="0"
                  dense
                  borderless
                  input-class="text-center font-mono text-weight-bold text-slate-800 excel-cell-input-native"
                  class="excel-cell-input"
                  :loading="isRowSaving({ kind: 'saved', id: box.id })"
                  @update:model-value="(val) => setWeightKg({ kind: 'saved', id: box.id }, val)"
                  @blur="() => commitRow({ kind: 'saved', id: box.id })"
                  @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
                />
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

            <tr class="box-draft-row">
              <td class="text-center text-grey-5 font-mono">
                {{ savedRows.length + 1 }}
              </td>
              <td class="q-pa-none" @click.stop>
                <q-input
                  :model-value="getBoxNumber({ kind: 'draft' })"
                  dense
                  borderless
                  placeholder="Box #"
                  input-class="text-left font-mono text-weight-bold text-slate-800 excel-cell-input-native"
                  class="excel-cell-input"
                  :loading="isRowSaving({ kind: 'draft' })"
                  @update:model-value="(val) => setBoxNumber({ kind: 'draft' }, val)"
                  @blur="() => commitRow({ kind: 'draft' })"
                  @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
                />
              </td>
              <td class="text-center bw-ops-col-tint--qty q-pa-none" @click.stop>
                <q-input
                  :model-value="getWeightKg({ kind: 'draft' })"
                  type="number"
                  step="0.01"
                  min="0"
                  dense
                  borderless
                  placeholder="0.00"
                  input-class="text-center font-mono text-weight-bold text-slate-800 excel-cell-input-native"
                  class="excel-cell-input"
                  :loading="isRowSaving({ kind: 'draft' })"
                  @update:model-value="(val) => setWeightKg({ kind: 'draft' }, val)"
                  @blur="() => commitRow({ kind: 'draft' })"
                  @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
                />
              </td>
              <td />
            </tr>
          </tbody>
        </q-markup-table>
      </div>

      <div class="shrink-0 bg-white border-top q-px-lg q-py-sm row items-center justify-between">
        <div class="text-caption text-grey-7">
          {{ savedRows.length }} box<span v-if="savedRows.length !== 1">es</span>
        </div>
        <div class="text-subtitle2 text-weight-bold text-grey-9 font-mono">
          Total: {{ totalWeightKg.toFixed(2) }} kg
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { useShipmentBoxWeightGrid } from '../composables/useShipmentBoxWeightGrid';

const props = defineProps<{
  shipmentId: number;
}>();

const {
  loading,
  savedRows,
  totalWeightKg,
  getBoxNumber,
  getWeightKg,
  setBoxNumber,
  setWeightKg,
  commitRow,
  deleteRow,
  isRowSaving,
} = useShipmentBoxWeightGrid(props.shipmentId);
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

.box-draft-row td {
  background-color: color-mix(in srgb, var(--q-primary) 4%, white) !important;
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

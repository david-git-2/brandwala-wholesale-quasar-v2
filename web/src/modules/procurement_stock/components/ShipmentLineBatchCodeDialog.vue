<template>
  <q-dialog
    :model-value="modelValue"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card style="width: 520px; max-width: 92vw; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <q-avatar color="primary" text-color="white" icon="ph ph-barcode" size="32px" />
        <div class="q-ml-sm col">
          <div class="text-subtitle1 text-weight-bold">Batch codes</div>
          <div class="text-caption text-grey-7 ellipsis">{{ productName }}</div>
        </div>
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-sm">
        <q-markup-table flat dense class="batch-detail-table">
          <thead>
            <tr>
              <th class="text-left">Batch ID</th>
              <th class="text-center">Expire date</th>
              <th class="text-right">Expires in</th>
              <th class="text-center">Arrived</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="rows.length === 0">
              <td colspan="4" class="text-grey-6 text-caption text-center">No batch lines yet</td>
            </tr>
            <tr v-for="row in rows" :key="row.itemId">
              <td class="font-mono text-weight-medium">{{ row.batchId }}</td>
              <td class="text-center font-mono text-caption">{{ row.expireDate }}</td>
              <td class="text-right font-mono text-weight-bold" :class="row.toneClass">
                {{ row.expiresIn }}
              </td>
              <td class="text-center" @click.stop>
                <q-checkbox
                  :model-value="row.isArrived"
                  dense
                  color="primary"
                  :disable="togglingItemId === row.itemId"
                  @update:model-value="(val) => emit('toggle-arrived', row.itemId, val)"
                />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card-section>

      <q-separator v-if="canAdd" />

      <q-card-section v-if="canAdd" class="q-pt-md">
        <div class="text-caption text-weight-bold text-grey-8 q-mb-sm">Add missing batch</div>
        <div class="row q-col-gutter-sm items-end">
          <div class="col-12 col-sm-6">
            <q-input
              v-model="addBatchId"
              dense
              outlined
              label="Batch ID"
              class="font-mono"
              :disable="adding"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-input
              v-model="addExpireDate"
              dense
              outlined
              label="Expire date"
              mask="##-##-####"
              placeholder="DD-MM-YYYY"
              class="font-mono"
              :disable="adding"
            />
          </div>
        </div>
        <div class="row justify-end q-mt-sm">
          <q-btn
            unelevated
            no-caps
            color="primary"
            label="Save batch line"
            :loading="adding"
            :disable="!addBatchId.trim()"
            @click="onSaveAdd"
          />
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat no-caps label="Close" v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { BatchCodeMatchTableRow } from '../utils/batchCodeShipmentMatch';

const props = defineProps<{
  modelValue: boolean;
  productName: string;
  rows: BatchCodeMatchTableRow[];
  canAdd?: boolean;
  adding?: boolean;
  togglingItemId?: number | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  add: [payload: { batch_id: string; expire_date: string }];
  'toggle-arrived': [itemId: number, value: boolean];
}>();

const addBatchId = ref('');
const addExpireDate = ref('');

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return;
    addBatchId.value = '';
    addExpireDate.value = '';
  },
);

const onSaveAdd = () => {
  emit('add', {
    batch_id: addBatchId.value.trim(),
    expire_date: addExpireDate.value.trim(),
  });
};
</script>

<style scoped>
.batch-detail-table th {
  font-size: 11px;
  font-weight: 600;
  color: #64748b;
  padding: 6px 8px !important;
}

.batch-detail-table td {
  font-size: 12px;
  padding: 6px 8px !important;
}

.batch-code-tone--warn {
  color: #b42318;
}

.batch-code-tone--ok {
  color: #047857;
}

.batch-code-tone--unset {
  color: #1d4ed8;
}
</style>

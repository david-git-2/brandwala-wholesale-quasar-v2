<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="delivery-paper-reject-dialog">
      <q-card-section class="row items-start q-pb-sm">
        <div class="col">
          <div class="text-h6 text-weight-bold">Return to warehouse</div>
          <div class="text-body2 text-grey-8 q-mt-xs">
            Choose a warehouse grade for each lot being rejected.
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-card-section class="q-pt-none">
        <q-markup-table flat bordered dense>
          <thead>
            <tr>
              <th class="text-left">Product</th>
              <th class="text-left">Lot</th>
              <th class="text-center">Qty</th>
              <th class="text-right">Sell / unit</th>
              <th class="text-left">Grade</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in localRows" :key="row.clientKey">
              <td class="delivery-paper-reject-dialog__product">{{ row.product_name || '—' }}</td>
              <td class="delivery-paper-reject-dialog__lot text-caption text-grey-8">
                {{ row.shipment_name || row.global_stock_id }}
              </td>
              <td class="text-center font-mono delivery-paper-reject-dialog__qty">{{ row.quantity }}</td>
              <td class="text-right font-mono delivery-paper-reject-dialog__sell">{{ formatRowSellPrice(row) }}</td>
              <td class="q-pa-xs delivery-paper-reject-dialog__grade">
                <q-select
                  v-model="row.grade_tag_id"
                  :options="gradeOptions"
                  option-value="id"
                  option-label="name"
                  emit-value
                  map-options
                  dense
                  outlined
                  hide-bottom-space
                  label="Grade"
                  class="delivery-paper-reject-grade-select"
                />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card-section>

      <q-card-actions align="right" class="q-pt-none">
        <q-btn flat no-caps label="Cancel" color="grey-7" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="negative"
          label="Return stock"
          :loading="loading"
          :disable="!canConfirm"
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useTagStore } from 'src/modules/tag/stores/tagStore';
import { showErrorNotification } from 'src/utils/appFeedback';
import type { DeliveryPaperOutcomeAllocationRow } from '../utils/deliveryPaperOutcomeAllocations';
import { formatDeliveryPaperUnitSellPrice } from '../utils/deliveryPaperUnitSellPrice';

type LocalRow = DeliveryPaperOutcomeAllocationRow & {
  grade_tag_id: number | null;
};

const props = defineProps<{
  modelValue: boolean;
  rows: DeliveryPaperOutcomeAllocationRow[];
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (
    e: 'confirm',
    payload: Array<{
      preorder_demand_id: number;
      global_stock_id: number;
      quantity: number;
      grade_tag_id: number;
    }>,
  ): void;
}>();

const gradeOptions = ref<Array<{ id: number; name: string }>>([]);
const localRows = ref<LocalRow[]>([]);
const tagStore = useTagStore();

const canConfirm = computed(() =>
  localRows.value.length > 0 && localRows.value.every((row) => row.grade_tag_id != null),
);

const formatRowSellPrice = (row: LocalRow) =>
  formatDeliveryPaperUnitSellPrice({ unit_sell_price_amount: row.unit_sell_price_amount });

const close = () => emit('update:modelValue', false);

const loadGrades = async () => {
  try {
    const tags = await tagStore.ensureTagsForCategory({
      moduleKey: 'stock_grade',
      code: 'warehouse',
    });
    gradeOptions.value = tags.map((t) => ({ id: t.id, name: t.name }));
  } catch (err: unknown) {
    gradeOptions.value = [];
    showErrorNotification(err instanceof Error ? err.message : 'Failed to load grades');
  }
};

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return;
    await loadGrades();
    const defaultGrade = gradeOptions.value[0]?.id ?? null;
    localRows.value = props.rows.map((row) => ({
      ...row,
      grade_tag_id: defaultGrade,
    }));
  },
);

const onConfirm = () => {
  if (!canConfirm.value) return;
  emit(
    'confirm',
    localRows.value.map((row) => ({
      preorder_demand_id: row.preorder_demand_id,
      global_stock_id: row.global_stock_id,
      quantity: row.quantity,
      grade_tag_id: row.grade_tag_id!,
    })),
  );
};
</script>

<style scoped>
.delivery-paper-reject-dialog {
  width: min(780px, 96vw);
  max-width: 96vw;
}

.delivery-paper-reject-dialog :deep(.q-markup-table) {
  table-layout: auto;
  width: 100%;
}

.delivery-paper-reject-dialog__product {
  min-width: 11rem;
  max-width: 16rem;
  white-space: normal;
  word-break: break-word;
}

.delivery-paper-reject-dialog__lot {
  min-width: 9rem;
  max-width: 14rem;
  white-space: normal;
  word-break: break-word;
}

.delivery-paper-reject-dialog__qty {
  width: 3.5rem;
  white-space: nowrap;
}

.delivery-paper-reject-dialog__sell {
  width: 6.5rem;
  white-space: nowrap;
}

.delivery-paper-reject-dialog__grade {
  min-width: 11rem;
}

.delivery-paper-reject-grade-select {
  min-width: 10rem;
  width: 100%;
}
</style>

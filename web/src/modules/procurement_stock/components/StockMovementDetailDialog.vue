<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card style="width: 720px; max-width: 95vw">
      <!-- Card Header -->
      <q-card-section class="row items-center q-pb-none">
        <div>
          <div class="row items-center q-gutter-x-sm">
            <span class="text-h6 text-weight-bold">{{ movementTitle }}</span>
            <q-chip
              dense
              size="sm"
              :color="isPosted ? 'green-1' : 'grey-3'"
              :text-color="isPosted ? 'green-9' : 'grey-8'"
              class="text-weight-bold"
            >
              {{ isPosted ? 'Posted' : 'Draft' }}
            </q-chip>
          </div>
          <div class="text-caption text-grey-7">{{ movementTypeLabel }}</div>
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-gutter-y-md">
        <!-- Loading Spinner -->
        <div v-if="loading" class="row justify-center q-py-lg">
          <q-spinner color="primary" size="2.5em" />
        </div>

        <template v-else-if="detail">
          <!-- Movement Metadata Grid -->
          <div class="row q-col-gutter-sm bg-grey-1 q-pa-sm rounded-borders text-body2">
            <div class="col-12 col-sm-6">
              <span class="text-grey-7">Created:</span>
              <span class="q-ml-xs text-weight-medium">{{ createdAtLabel }}</span>
            </div>
            <div class="col-12 col-sm-6">
              <span class="text-grey-7">Posted:</span>
              <span class="q-ml-xs text-weight-medium">{{ postedAtLabel }}</span>
            </div>
            <div class="col-12 col-sm-6">
              <span class="text-grey-7">Created by:</span>
              <span class="q-ml-xs text-weight-medium">{{ detail.movement.created_by_email || '—' }}</span>
            </div>
            <div class="col-12 col-sm-6">
              <span class="text-grey-7">Notes:</span>
              <span class="q-ml-xs text-weight-medium">{{ detail.movement.notes || '—' }}</span>
            </div>
          </div>

          <!-- Lines Table Section -->
          <div>
            <div class="text-subtitle2 text-weight-bold q-mb-xs">Movement Lines</div>
            <q-table
              flat
              bordered
              dense
              :rows="detail.lines"
              :columns="lineColumns"
              row-key="id"
              :pagination="{ rowsPerPage: 0 }"
              hide-pagination
            >
              <!-- Stock column -->
              <template #body-cell-stock="props">
                <q-td :props="props">
                  {{ props.row.stock_label || '—' }}
                </q-td>
              </template>

              <!-- From availability -->
              <template #body-cell-from_availability="props">
                <q-td :props="props">
                  <template v-if="props.row.from_availability">
                    <q-chip
                      dense
                      size="sm"
                      :color="availabilityChipColor(props.row.from_availability).color"
                      :text-color="availabilityChipColor(props.row.from_availability).textColor"
                    >
                      {{ formatStockAvailability(props.row.from_availability) }}
                    </q-chip>
                  </template>
                  <template v-else>—</template>
                </q-td>
              </template>

              <!-- To availability -->
              <template #body-cell-to_availability="props">
                <q-td :props="props">
                  <template v-if="props.row.to_availability">
                    <q-chip
                      dense
                      size="sm"
                      :color="availabilityChipColor(props.row.to_availability).color"
                      :text-color="availabilityChipColor(props.row.to_availability).textColor"
                    >
                      {{ formatStockAvailability(props.row.to_availability) }}
                    </q-chip>
                  </template>
                  <template v-else>—</template>
                </q-td>
              </template>
            </q-table>
          </div>
        </template>
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat no-caps label="Close" color="grey-7" v-close-popup />
        <q-btn
          v-if="detail && !isPosted"
          color="primary"
          unelevated
          no-caps
          label="Post movement"
          :loading="posting"
          @click="confirmPost"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { date, type QTableColumn } from 'quasar';
import type { StockMovementDetail } from '../repositories/stockMovementRepository';
import { stockMovementRepository } from '../repositories/stockMovementRepository';
import {
  availabilityChipColor,
  formatStockAvailability,
} from '../constants/stockAvailability';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  movementId: number | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  posted: [];
}>();

const loading = ref(false);
const posting = ref(false);
const detail = ref<StockMovementDetail | null>(null);

watch(
  [() => props.modelValue, () => props.movementId],
  async ([open, id]) => {
    if (!open || !id) {
      detail.value = null;
      return;
    }
    loading.value = true;
    try {
      detail.value = await stockMovementRepository.getMovementDetail(id);
    } catch (err) {
      showErrorNotification(err instanceof Error ? err.message : 'Failed to load movement');
    } finally {
      loading.value = false;
    }
  },
  { immediate: true },
);

const movementTitle = computed(() => detail.value?.movement.movement_no ?? 'Movement detail');

const movementTypeLabel = computed(() => {
  if (!detail.value) return '';
  return detail.value.movement.movement_type.replace(/_/g, ' ').toUpperCase();
});

const isPosted = computed(() => Boolean(detail.value?.movement.is_posted));

const createdAtLabel = computed(() => {
  if (!detail.value?.movement.created_at) return '—';
  return date.formatDate(detail.value.movement.created_at, 'DD MMM YYYY HH:mm');
});

const postedAtLabel = computed(() => {
  if (!detail.value?.movement.posted_at) return '—';
  return date.formatDate(detail.value.movement.posted_at, 'DD MMM YYYY HH:mm');
});

const lineColumns: QTableColumn[] = [
  { name: 'stock', label: 'Stock', field: 'stock_label', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right' },
  {
    name: 'from_location',
    label: 'From location',
    field: (r) => r.from_location_label || '—',
    align: 'left',
  },
  {
    name: 'to_location',
    label: 'To location',
    field: (r) => r.to_location_label || '—',
    align: 'left',
  },
  { name: 'from_availability', label: 'From avail.', field: 'from_availability', align: 'left' },
  { name: 'to_availability', label: 'To avail.', field: 'to_availability', align: 'left' },
];

const confirmPost = async () => {
  if (!detail.value || detail.value.movement.is_posted) return;

  const ok = await requestConfirmation(
    'Apply this movement to stock quantities and locations?',
    'Post movement',
    'Post',
  );
  if (!ok) return;

  posting.value = true;
  try {
    await stockMovementRepository.postMovement(detail.value.movement.id);
    showSuccessNotification('Movement posted');
    emit('posted');
    detail.value = await stockMovementRepository.getMovementDetail(detail.value.movement.id);
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to post movement');
  } finally {
    posting.value = false;
  }
};
</script>

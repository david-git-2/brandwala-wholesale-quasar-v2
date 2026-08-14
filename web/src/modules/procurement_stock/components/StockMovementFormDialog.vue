<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card style="width: 540px; max-width: 90vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">
          {{ lockFields ? dialogTitle : 'Create stock movement' }}
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>
      <q-card-section class="q-pt-none">
        <div class="text-caption text-grey-7">
          Move quantity to another shelf or change sellable / held / unsellable.
        </div>
      </q-card-section>

      <q-form @submit.prevent="onSubmit">
        <q-card-section class="q-gutter-y-md">
          <div v-if="loading" class="row justify-center q-py-md">
            <q-spinner color="primary" size="2em" />
          </div>

          <template v-else>
            <!-- Lock fields stock summary header -->
            <div v-if="lockFields && targetStock" class="bg-grey-2 q-pa-sm rounded-borders">
              <div class="text-weight-bold text-grey-9">{{ targetStock.item_name }}</div>
              <div class="text-caption text-grey-7">
                Shipment: {{ targetStock.shipment_name }} | Current Qty: {{ targetStock.quantity }} pcs | Location: {{ targetStock.location_name || 'No location' }}
              </div>
            </div>

            <!-- Movement Type (hidden when locked) -->
            <q-select
              v-if="!lockFields"
              v-model="form.movement_type"
              :options="movementTypeOptions"
              label="Movement type *"
              dense
              outlined
              emit-value
              map-options
              class="soft-input"
            />

            <!-- Notes -->
            <q-input
              v-model="form.notes"
              label="Notes"
              dense
              outlined
              class="soft-input"
              placeholder="Reason or reference notes..."
            />

            <q-separator class="q-my-sm" />
            <div class="text-subtitle2 text-weight-bold">Line</div>

            <!-- Stock Picker (hidden when locked) -->
            <q-select
              v-if="!lockFields"
              v-model="form.stock_id"
              :options="stockOptions"
              label="Select stock *"
              dense
              outlined
              emit-value
              map-options
              class="soft-input"
              :rules="[(v) => !!v || 'Stock selection is required']"
            >
              <template #no-option>
                <q-item>
                  <q-item-section class="text-grey">No active stock available</q-item-section>
                </q-item>
              </template>
            </q-select>

            <!-- Quantity -->
            <q-input
              v-model.number="form.quantity"
              type="number"
              label="Quantity *"
              dense
              outlined
              class="soft-input"
              :rules="[
                (v) => (v != null && v > 0) || 'Quantity must be > 0',
                (v) =>
                  !targetStock || v <= targetStock.quantity || `Max available: ${targetStock.quantity}`,
              ]"
            />

            <!-- From / To Location Fields -->
            <div class="row q-col-gutter-md">
              <div v-if="showFromLocation" class="col-12 col-sm-6">
                <q-input
                  :model-value="fromLocationLabel"
                  label="From location"
                  dense
                  outlined
                  disable
                  class="soft-input"
                  hint="Source location from selected stock"
                />
              </div>

              <div v-if="showToLocation" class="col-12 col-sm-6">
                <q-select
                  v-model="form.to_location_id"
                  :options="toLocationOptions"
                  label="To location *"
                  dense
                  outlined
                  emit-value
                  map-options
                  class="soft-input"
                  :rules="[(v) => !!v || 'Destination location is required']"
                  :hint="returnsHint"
                />
              </div>
            </div>

            <!-- From / To Availability Fields -->
            <div class="row q-col-gutter-md">
              <div v-if="showFromAvailability" class="col-12 col-sm-6">
                <q-input
                  :model-value="formatStockAvailability(form.from_availability)"
                  label="From availability"
                  dense
                  outlined
                  disable
                  class="soft-input"
                  hint="Source availability state"
                />
              </div>

              <div v-if="showToAvailability" class="col-12 col-sm-6">
                <q-select
                  v-model="form.to_availability"
                  :options="STOCK_AVAILABILITY_OPTIONS"
                  label="To availability *"
                  dense
                  outlined
                  emit-value
                  map-options
                  class="soft-input"
                  :rules="[(v) => !!v || 'Target availability is required']"
                />
              </div>
            </div>
          </template>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md bg-grey-1">
          <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
          <q-btn
            color="primary"
            unelevated
            label="Create draft"
            type="submit"
            no-caps
            :loading="creating"
            :disable="!canCreate || loading"
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import type { Database } from 'src/types/database.types';
import type { GlobalStock } from '../repositories/globalStockRepository';
import { globalStockRepository } from '../repositories/globalStockRepository';
import type { StockLocation } from '../repositories/stockLocationRepository';
import { stockLocationRepository } from '../repositories/stockLocationRepository';
import { stockMovementRepository } from '../repositories/stockMovementRepository';
import { getLeafLocations } from '../utils/stockLocationOptions';
import {
  STOCK_AVAILABILITY_OPTIONS,
  formatStockAvailability,
  type StockAvailability,
} from '../constants/stockAvailability';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

type StockMovementType = Database['public']['Enums']['stock_movement_type'];

const props = defineProps<{
  modelValue: boolean;
  tenantId: number | null;
  initialStock?: GlobalStock | null;
  presetMovementType?: StockMovementType;
  lockFields?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  created: [movementId: number];
}>();

const movementTypeOptions: Array<{ label: string; value: StockMovementType }> = [
  { label: 'Location transfer', value: 'location_transfer' },
  { label: 'Availability transfer', value: 'availability_transfer' },
  { label: 'Adjustment', value: 'adjustment' },
  { label: 'Return inbound', value: 'return_inbound' },
];

const loading = ref(false);
const creating = ref(false);
const stockRows = ref<GlobalStock[]>([]);
const locations = ref<StockLocation[]>([]);

const form = reactive({
  movement_type: 'location_transfer' as StockMovementType,
  notes: '',
  stock_id: null as number | null,
  quantity: 1,
  from_location_id: null as number | null,
  to_location_id: null as number | null,
  from_availability: null as StockAvailability | null,
  to_availability: null as StockAvailability | null,
});

const dialogTitle = computed(() => {
  if (form.movement_type === 'location_transfer') return 'Transfer stock location';
  if (form.movement_type === 'availability_transfer') return 'Change stock availability';
  return 'Create stock movement';
});

const resetForm = () => {
  form.movement_type = props.presetMovementType ?? 'location_transfer';
  form.notes = '';
  form.to_location_id = null;
  form.to_availability = null;

  if (props.initialStock) {
    form.stock_id = props.initialStock.id;
    form.quantity = props.initialStock.quantity;
    form.from_location_id = props.initialStock.location_id ?? null;
    form.from_availability = (props.initialStock.availability as StockAvailability) ?? 'sellable';
  } else {
    form.stock_id = null;
    form.quantity = 1;
    form.from_location_id = null;
    form.from_availability = null;
  }
};

const loadData = async () => {
  if (!props.tenantId) return;
  loading.value = true;
  try {
    const [stockRes, locRes] = await Promise.all([
      props.lockFields
        ? Promise.resolve({ data: [] })
        : globalStockRepository.listPaginated(
            props.tenantId,
            1,
            100,
            undefined,
            undefined,
            undefined,
            undefined,
            true,
          ),
      stockLocationRepository.listStockLocations(props.tenantId),
    ]);
    stockRows.value = stockRes.data;
    locations.value = locRes;
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to load options');
  } finally {
    loading.value = false;
  }
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      resetForm();
      loadData();
    }
  },
);

const stockOptions = computed(() =>
  stockRows.value.map((s) => ({
    label: `${s.item_name} · ${s.quantity} pcs · ${formatStockAvailability(s.availability)} · ${
      s.location_name ?? 'No location'
    } · ${s.shipment_name}`,
    value: s.id,
  })),
);

const selectedStock = computed(() => stockRows.value.find((s) => s.id === form.stock_id));
const targetStock = computed(() => props.initialStock || selectedStock.value);

watch(
  () => form.stock_id,
  (id) => {
    if (props.lockFields) return;
    const stock = stockRows.value.find((s) => s.id === id);
    if (!stock) return;
    form.from_location_id = stock.location_id ?? null;
    form.from_availability = (stock.availability as StockAvailability) ?? 'sellable';
    form.to_location_id = null;
    form.to_availability = null;
  },
);

watch(
  () => form.movement_type,
  (type) => {
    if (type === 'return_inbound') {
      form.to_availability = 'held';
    }
  },
);

const showFromLocation = computed(() =>
  ['location_transfer', 'availability_transfer'].includes(form.movement_type),
);

const showToLocation = computed(() =>
  ['location_transfer', 'return_inbound', 'adjustment'].includes(form.movement_type),
);

const showFromAvailability = computed(() =>
  ['location_transfer', 'availability_transfer', 'adjustment'].includes(form.movement_type),
);

const showToAvailability = computed(() =>
  ['availability_transfer', 'return_inbound', 'adjustment'].includes(form.movement_type),
);

const fromLocationLabel = computed(() => {
  if (!form.from_location_id) return 'No location';
  const loc = locations.value.find((l) => l.id === form.from_location_id);
  return loc ? `${loc.code} — ${loc.name}` : `#${form.from_location_id}`;
});

const returnLocations = computed(() =>
  locations.value.filter(
    (l) => l.is_active && (l.kind === 'returns' || l.code.toLowerCase().includes('return')),
  ),
);

const returnsHint = computed(() => {
  if (form.movement_type === 'return_inbound' && returnLocations.value.length === 0) {
    return 'No returns area configured; showing all active locations';
  }
  return undefined;
});

const toLocationOptions = computed(() => {
  let list = getLeafLocations(locations.value);
  if (form.movement_type === 'return_inbound' && returnLocations.value.length > 0) {
    list = returnLocations.value;
  }
  if (form.movement_type === 'location_transfer' && form.from_location_id) {
    list = list.filter((l) => l.id !== form.from_location_id);
  }
  return list.map((l) => ({
    label: `${l.code} — ${l.name}`,
    value: l.id,
  }));
});

const canCreate = computed(() => {
  if (!props.tenantId || !form.stock_id || form.quantity <= 0) return false;
  const stock = targetStock.value;
  if (!stock) return false;

  switch (form.movement_type) {
    case 'location_transfer':
      return (
        !!form.to_location_id &&
        form.to_location_id !== form.from_location_id &&
        form.quantity <= stock.quantity
      );
    case 'availability_transfer':
      return (
        !!form.to_availability &&
        form.to_availability !== form.from_availability &&
        form.quantity <= stock.quantity
      );
    case 'return_inbound':
      return !!form.to_location_id && form.quantity <= stock.quantity;
    case 'adjustment':
      return form.quantity > 0;
    default:
      return false;
  }
});

const onSubmit = async () => {
  if (!canCreate.value || !props.tenantId) return;

  creating.value = true;
  try {
    const movement = await stockMovementRepository.createMovement({
      tenant_id: props.tenantId,
      movement_type: form.movement_type,
      notes: form.notes || null,
      lines: [
        {
          stock_id: form.stock_id!,
          quantity: form.quantity,
          from_location_id: form.from_location_id,
          to_location_id: form.to_location_id,
          from_availability: form.from_availability,
          to_availability: form.to_availability,
        },
      ],
    });
    showSuccessNotification('Movement draft created');
    emit('created', movement.id);
    emit('update:modelValue', false);
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to create movement');
  } finally {
    creating.value = false;
  }
};
</script>

<style scoped>
.soft-input {
  border-radius: 8px;
}
</style>

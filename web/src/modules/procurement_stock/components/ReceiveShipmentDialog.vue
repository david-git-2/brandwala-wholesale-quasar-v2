<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin" style="width: 900px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div>
          <div class="text-h6 text-primary text-weight-bold">
            Receive Shipment to Warehouse Stock
          </div>
          <div class="text-caption text-grey-7">
            Assign quantities to stock types and put-away locations. Sum of splits must equal ordered quantity.
          </div>
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md scroll" style="max-height: 70vh">
        <!-- Error banner -->
        <q-banner v-if="error" class="bg-negative text-white rounded-borders q-mb-md q-py-sm">
          {{ error }}
        </q-banner>

        <div v-if="loading" class="text-center q-py-xl">
          <q-spinner color="primary" size="2em" />
          <div class="text-grey-6 q-mt-sm">Loading options...</div>
        </div>

        <div v-else class="q-gutter-y-lg">
          <!-- Shipment-level default location shortcut -->
          <div class="row items-center q-col-gutter-sm bg-grey-2 q-pa-sm rounded-borders">
            <div class="col-12 col-sm-6">
              <q-select
                v-model="globalDefaultLocationId"
                :options="locationOptions"
                label="Shipment Default Location (Apply to all splits)"
                outlined
                dense
                emit-value
                map-options
                class="bg-white"
                @update:model-value="applyGlobalLocationToAll"
              />
            </div>
            <div class="col-12 col-sm-6 text-caption text-grey-7">
              Select a location above to set the default put-away bin for all stock rows.
            </div>
          </div>

          <div
            v-for="(item, lineIndex) in lines"
            :key="item.id"
            class="q-pa-md border rounded-borders"
          >
            <!-- Line Item Header -->
            <div class="row items-center justify-between q-mb-md">
              <div class="row items-center q-col-gutter-sm">
                <q-avatar rounded size="36px" class="bg-grey-2">
                  <img :src="item.image_url || 'https://placehold.co/36x36?text=No+Image'" />
                </q-avatar>
                <div>
                  <div class="text-weight-bold text-grey-9">{{ item.name }}</div>
                  <div class="text-caption text-grey-6">
                    Code: {{ item.product_code || '-' }} | Barcode: {{ item.barcode || '-' }}
                  </div>
                </div>
              </div>
              <div class="text-right">
                <div class="text-caption text-grey-7">Ordered Quantity</div>
                <div class="text-subtitle1 text-weight-bolder text-primary">
                  {{ item.ordered_quantity }} pcs
                </div>
              </div>
            </div>

            <!-- Splits List -->
            <div class="q-gutter-y-sm">
              <div
                v-for="(split, splitIndex) in item.splits"
                :key="splitIndex"
                class="row q-col-gutter-sm items-center"
              >
                <div class="col-12 col-sm-3">
                  <q-select
                    v-model="split.availability"
                    :options="availabilityOptions"
                    label="Availability *"
                    filled
                    dense
                    emit-value
                    map-options
                  />
                </div>
                <div class="col-12 col-sm-4">
                  <q-select
                    v-model="split.location_id"
                    :options="locationOptions"
                    label="Put-away location *"
                    filled
                    dense
                    emit-value
                    map-options
                    :rules="[(val) => !!val || 'Location required']"
                  />
                </div>
                <div class="col-6 col-sm-2">
                  <q-input
                    v-model.number="split.quantity"
                    type="number"
                    label="Quantity *"
                    filled
                    dense
                    :rules="[(val) => val >= 0 || 'Must be >= 0']"
                  />
                </div>
                <div class="col-4 col-sm-2">
                  <q-checkbox v-model="split.is_usable" label="Usable Pool" />
                </div>
                <div class="col-2 col-sm-1 text-right">
                  <q-btn
                    v-if="item.splits.length > 1"
                    flat
                    round
                    dense
                    color="negative"
                    icon="ph ph-minus-circle"
                    @click="removeSplit(lineIndex, splitIndex)"
                  />
                </div>
              </div>

              <div class="row items-center justify-between q-mt-sm">
                <q-btn
                  flat
                  color="primary"
                  icon="ph ph-plus"
                  label="Add Split Row"
                  no-caps
                  dense
                  @click="addSplit(lineIndex)"
                />
                <div class="text-caption text-weight-bold" :class="getSplitValidationClass(item)">
                  Assigned: {{ getSumOfSplits(item) }} / {{ item.ordered_quantity }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1">
        <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          label="Commit & Receive"
          :loading="saving"
          :disable="!isValid"
          no-caps
          @click="onCommit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useDialogPluginComponent, useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { useStockLocationStore } from '../stores/stockLocationStore';
import {
  getLeafLocations,
  getDefaultPutawayLocationId,
  toLocationSelectOptions,
} from '../utils/stockLocationOptions';
import type {
  FinalizeShipmentStockRow,
  GlobalShipmentItem,
} from '../repositories/globalShipmentRepository';

type StockAvailability = 'sellable' | 'held' | 'unsellable';

const props = defineProps<{
  shipmentId: number;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const $q = useQuasar();
const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();
const locationStore = useStockLocationStore();

const loading = ref(false);
const saving = ref(false);
const error = ref<string | null>(null);
const globalDefaultLocationId = ref<number | null>(null);

interface ReceiveSplit {
  availability: StockAvailability;
  quantity: number;
  is_usable: boolean;
  location_id: number | null;
}

interface ReceiveLineItem extends GlobalShipmentItem {
  splits: ReceiveSplit[];
}

const lines = ref<ReceiveLineItem[]>([]);

const availabilityOptions = [
  { label: 'Sellable', value: 'sellable' },
  { label: 'Held', value: 'held' },
  { label: 'Unsellable', value: 'unsellable' },
];

const leafLocations = computed(() => getLeafLocations(locationStore.items));
const locationOptions = computed(() => toLocationSelectOptions(leafLocations.value));

onMounted(async () => {
  loading.value = true;
  error.value = null;
  try {
    const tenantId = authStore.tenantId;
    if (!tenantId) return;

    await locationStore.fetchLocations(tenantId);

    const defaultLocationId = getDefaultPutawayLocationId(locationStore.items);
    globalDefaultLocationId.value = defaultLocationId;

    const stagingStocks = shipmentStore.currentShipmentStocks || [];

    lines.value = shipmentStore.currentShipmentItems.map((item) => {
      const itemStaging = stagingStocks.filter(
        (s) => s.shipment_item_id === item.id && (s.quantity || 0) > 0,
      );

      if (itemStaging.length > 0) {
        return {
          ...item,
          splits: itemStaging.map((st) => ({
            availability: (st.availability as StockAvailability) || 'sellable',
            quantity: st.quantity,
            is_usable: st.is_usable ?? true,
            location_id: st.location_id || defaultLocationId,
          })),
        };
      }

      return {
        ...item,
        splits: [
          {
            availability: 'sellable',
            quantity: item.ordered_quantity,
            is_usable: true,
            location_id: defaultLocationId,
          },
        ],
      };
    });
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to initialize receive dialog';
  } finally {
    loading.value = false;
  }
});

const applyGlobalLocationToAll = (locationId: number | null) => {
  if (!locationId) return;
  for (const line of lines.value) {
    for (const split of line.splits) {
      split.location_id = locationId;
    }
  }
};

const addSplit = (lineIndex: number) => {
  const item = lines.value[lineIndex];
  if (!item) return;
  item.splits.push({
    availability: 'sellable',
    quantity: 0,
    is_usable: true,
    location_id: globalDefaultLocationId.value || getDefaultPutawayLocationId(locationStore.items),
  });
};

const removeSplit = (lineIndex: number, splitIndex: number) => {
  const item = lines.value[lineIndex];
  if (item) {
    item.splits.splice(splitIndex, 1);
  }
};

const getSumOfSplits = (item: ReceiveLineItem): number => {
  return item.splits.reduce((sum, s) => sum + (s.quantity || 0), 0);
};

const getSplitValidationClass = (item: ReceiveLineItem): string => {
  const sum = getSumOfSplits(item);
  if (sum === item.ordered_quantity) return 'text-positive';
  return 'text-negative';
};

const isValid = computed(() => {
  if (lines.value.length === 0) return false;
  return lines.value.every((item) => {
    const sumValid = getSumOfSplits(item) === item.ordered_quantity;
    const locationsValid = item.splits.every(
      (s) => s.quantity <= 0 || (s.location_id != null && s.location_id > 0),
    );
    return sumValid && locationsValid;
  });
});

const onCommit = async () => {
  if (!isValid.value || !authStore.tenantId) return;
  saving.value = true;
  error.value = null;

  try {
    const stockRows: FinalizeShipmentStockRow[] = [];
    for (const line of lines.value) {
      for (const split of line.splits) {
        if (split.quantity > 0) {
          stockRows.push({
            shipment_item_id: line.id,
            availability: split.availability,
            quantity: split.quantity,
            is_usable: split.is_usable,
            location_id: split.location_id,
          });
        }
      }
    }

    const result = await shipmentStore.finalizeShipment(props.shipmentId, stockRows);

    $q.notify({
      type: 'positive',
      message: `Shipment received. Stamped ${result.items_stamped} items, posted ${result.stock_rows_posted} stock rows.`,
    });

    onDialogOK();
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to receive stock.';
  } finally {
    saving.value = false;
  }
};
</script>

<style scoped>
.border {
  border: 1px solid var(--q-grey-4, #e0e0e0);
}
</style>

<template>
  <q-page class="receive-shipment-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Header -->
    <div class="receive-top-section bg-white border-bottom q-px-lg q-py-md shrink-0 shadow-xs">
      <div class="row items-center justify-between wrap q-gutter-y-sm">
        <div class="row items-center q-gutter-sm col-grow" style="min-width: 0">
          <q-btn
            icon="ph ph-arrow-left"
            flat
            round
            dense
            color="grey-8"
            @click="goBack"
          >
            <q-tooltip>Back to shipment</q-tooltip>
          </q-btn>
          <div class="ellipsis">
            <div class="text-subtitle1 text-weight-bolder text-grey-9 ellipsis">
              Receive Shipment Stock Checklist
            </div>
            <div class="text-caption text-grey-7 ellipsis">
              {{ shipmentName }}
              <span v-if="items.length"> · {{ items.length }} line<span v-if="items.length !== 1">s</span></span>
            </div>
          </div>
        </div>

        <div class="row items-center q-gutter-md no-wrap">
          <div class="row items-center q-gutter-md text-caption text-grey-7">
            <span>
              Ordered:
              <span class="text-weight-bold text-grey-9">{{ totalOrderedQty }}</span>
            </span>
            <span>
              Received:
              <span
                class="text-weight-bold"
                :class="totalReceivedQty === totalOrderedQty ? 'text-positive' : 'text-primary'"
              >
                {{ totalReceivedQty }}
              </span>
            </span>
          </div>
          <q-btn
            flat
            label="Cancel"
            color="grey-8"
            no-caps
            dense
            class="rounded-sq-btn"
            style="border-radius: 8px"
            @click="goBack"
          />
          <q-btn
            color="primary"
            unelevated
            icon="ph ph-check-circle"
            label="Confirm & Post Stock"
            no-caps
            dense
            class="rounded-sq-btn text-weight-bold"
            style="border-radius: 8px"
            :loading="submitting"
            :disable="!isValid || submitting"
            @click="onConfirmReceive"
          />
        </div>
      </div>

      <q-banner v-if="error" class="bg-negative text-white rounded-borders q-mt-sm q-py-xs">
        <template #avatar>
          <q-icon name="ph ph-warning-circle" size="20px" />
        </template>
        {{ error }}
      </q-banner>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="col row justify-center items-center bg-white">
      <q-spinner color="primary" size="3em" />
      <div class="text-grey-7 q-ml-md">Loading shipment lines...</div>
    </div>

    <!-- Table -->
    <div
      v-else
      class="receive-table-section col overflow-auto q-pa-none bg-white hide-native-scrollbar"
      style="overflow-x: auto; overflow-y: auto"
    >
      <q-markup-table flat class="shipment-items-markup-table bg-white" style="min-width: 960px; width: 100%">
        <thead>
          <tr>
            <th class="text-center q-pa-none" style="width: 36px; min-width: 36px; max-width: 36px">SL</th>
            <th class="text-left" style="width: 82px; min-width: 82px">Image</th>
            <th class="text-left" style="min-width: 120px; width: 120px; max-width: 120px; white-space: normal">Name</th>
            <th class="text-left" style="min-width: 105px; width: 115px">Codes</th>
            <th class="text-center bw-ops-col-tint--qty" style="min-width: 56px; width: 56px">Ordered</th>
            <th class="text-center bw-ops-col-tint--received" style="min-width: 72px; width: 72px">Received</th>
            <th class="text-center" style="min-width: 88px; width: 88px">Variance</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(item, index) in items"
            :key="item.id"
            class="shipment-item-row"
            :class="{ 'row-variance': (item.received_quantity ?? 0) !== item.ordered_quantity }"
          >
            <td class="text-center text-weight-medium text-grey-7 q-pa-none" style="width: 36px; min-width: 36px">
              {{ index + 1 }}
            </td>

            <td class="shipment-image-col">
              <q-avatar square size="82px" class="avatar-soft-sq bg-grey-2 border-grey overflow-hidden" style="width: 0.85in; height: 0.85in">
                <SmartImage
                  :src="item.image_url"
                  :alt="item.name"
                  style="object-fit: cover; width: 100%; height: 100%"
                />
              </q-avatar>
            </td>

            <td style="width: 120px; min-width: 120px; max-width: 120px; white-space: normal !important; word-break: break-word">
              <div class="text-weight-bold text-grey-9" style="font-size: 13px; line-height: 1.35; word-break: break-word; white-space: normal">
                {{ item.name }}
              </div>
            </td>

            <td class="font-mono text-caption">
              <div class="column q-gutter-y-2xs" style="line-height: 1.1">
                <div v-if="item.product_code" class="row items-center justify-between no-wrap">
                  <div class="ellipsis">
                    <span class="text-grey-6 text-uppercase" style="font-size: 8px">C: </span>
                    <b class="text-dark" style="font-size: 10px">{{ item.product_code }}</b>
                  </div>
                  <q-btn
                    flat
                    dense
                    round
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-7"
                    style="font-size: 9px; padding: 0"
                    @click.stop="copyToClipboard(item.product_code, 'Product Code')"
                  >
                    <q-tooltip>Copy Code</q-tooltip>
                  </q-btn>
                </div>
                <div v-if="item.barcode" class="row items-center justify-between no-wrap">
                  <div class="ellipsis">
                    <span class="text-grey-6 text-uppercase" style="font-size: 8px">B: </span>
                    <span class="text-grey-9" style="font-size: 10px">{{ item.barcode }}</span>
                  </div>
                  <q-btn
                    flat
                    dense
                    round
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-7"
                    style="font-size: 9px; padding: 0"
                    @click.stop="copyToClipboard(item.barcode, 'Barcode')"
                  >
                    <q-tooltip>Copy Barcode</q-tooltip>
                  </q-btn>
                </div>
                <span v-if="!item.product_code && !item.barcode" class="text-grey-5">—</span>
              </div>
            </td>

            <td class="text-center bw-ops-col-tint--qty font-mono text-weight-bold text-grey-9" style="width: 56px; min-width: 56px">
              {{ item.ordered_quantity }}
            </td>

            <td class="text-center bw-ops-col-tint--received" style="width: 72px; min-width: 72px">
              <div class="row justify-center">
                <q-input
                  v-model.number="item.received_quantity"
                  type="number"
                  min="0"
                  dense
                  outlined
                  hide-bottom-space
                  class="inline-edit-input excel-cell-input"
                  style="max-width: 56px"
                  input-class="text-center text-weight-bold"
                  :rules="[
                    (val) => val !== null && val !== undefined && val !== '' || 'Required',
                    (val) => Number(val) >= 0 || 'Must be >= 0',
                  ]"
                />
              </div>
            </td>

            <td class="text-center">
              <q-badge
                v-if="(item.received_quantity ?? 0) === item.ordered_quantity"
                color="positive"
                text-color="white"
                class="text-weight-bold text-xxs q-px-sm"
              >
                Exact
              </q-badge>
              <q-badge
                v-else-if="(item.received_quantity ?? 0) < item.ordered_quantity"
                color="orange-8"
                text-color="white"
                class="text-weight-bold text-xxs q-px-sm"
              >
                -{{ item.ordered_quantity - (item.received_quantity ?? 0) }}
              </q-badge>
              <q-badge
                v-else
                color="blue-8"
                text-color="white"
                class="text-weight-bold text-xxs q-px-sm"
              >
                +{{ (item.received_quantity ?? 0) - item.ordered_quantity }}
              </q-badge>
            </td>
          </tr>

          <tr v-if="items.length === 0">
            <td colspan="7" class="text-center text-grey-6 q-py-xl">
              No line items to receive.
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { showSuccessNotification, showErrorNotification, requestConfirmation } from 'src/utils/appFeedback';

interface ReceiveItemDraft {
  id: number;
  name: string;
  image_url: string | null;
  product_code: string | null;
  barcode: string | null;
  ordered_quantity: number;
  received_quantity: number;
}

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const shipmentStore = useGlobalShipmentStore();

const shipmentId = computed(() => Number(route.params.id));
const loading = ref(false);
const submitting = ref(false);
const error = ref<string | null>(null);

const items = ref<ReceiveItemDraft[]>([]);

const shipmentName = computed(() => shipmentStore.currentShipment?.name || `#${shipmentId.value}`);

const totalOrderedQty = computed(() =>
  items.value.reduce((sum, item) => sum + (item.ordered_quantity || 0), 0),
);

const totalReceivedQty = computed(() =>
  items.value.reduce((sum, item) => sum + (Number(item.received_quantity) || 0), 0),
);

const isValid = computed(() => {
  if (items.value.length === 0) return false;
  const allNonNegative = items.value.every(
    (item) =>
      item.received_quantity !== null &&
      item.received_quantity !== undefined &&
      !isNaN(Number(item.received_quantity)) &&
      Number(item.received_quantity) >= 0,
  );
  return allNonNegative && totalReceivedQty.value > 0;
});

const copyToClipboard = (text: string | null, label: string) => {
  if (!text) return;
  void navigator.clipboard.writeText(String(text));
  $q.notify({
    message: `Copied ${label} to clipboard`,
    color: 'positive',
    icon: 'ph ph-copy',
    timeout: 1000,
  });
};

onMounted(async () => {
  if (!shipmentId.value || isNaN(shipmentId.value)) {
    error.value = 'Invalid shipment ID';
    return;
  }

  loading.value = true;
  error.value = null;
  try {
    await shipmentStore.fetchShipmentDetails(shipmentId.value);
    const shipment = shipmentStore.currentShipment;

    if (!shipment) {
      error.value = 'Shipment not found.';
      return;
    }

    if (shipment.status === 'received' || shipment.stock_ready === true) {
      error.value = 'Shipment already received. Stock has been posted.';
      showErrorNotification(error.value);
      goBack();
      return;
    }

    if (shipment.status !== 'in_transit') {
      error.value = 'Shipment must be in transit before receiving stock.';
      showErrorNotification(error.value);
      goBack();
      return;
    }

    const loadedItems = shipmentStore.currentShipmentItems || [];

    if (loadedItems.length === 0) {
      error.value = 'Shipment has no line items to receive.';
      return;
    }

    items.value = loadedItems.map((item) => ({
      id: item.id,
      name: item.name,
      image_url: item.image_url,
      product_code: item.product_code,
      barcode: item.barcode,
      ordered_quantity: item.ordered_quantity,
      received_quantity: item.received_quantity ?? item.ordered_quantity,
    }));
  } catch (err: unknown) {
    error.value = err instanceof Error ? err.message : 'Failed to load shipment details';
  } finally {
    loading.value = false;
  }
});

const goBack = () => {
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { tenantSlug, id: shipmentId.value },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { id: shipmentId.value },
    });
  }
};

const onConfirmReceive = async () => {
  if (!isValid.value || submitting.value) return;

  const confirmed = await requestConfirmation(
    `Are you sure you want to receive and post stock for ${shipmentName.value}? Total received quantity: ${totalReceivedQty.value} pcs across ${items.value.length} item(s).`,
    'Confirm Receive Stock',
    'Confirm & Post',
  );

  if (!confirmed) return;

  submitting.value = true;
  error.value = null;

  try {
    const stockRows = items.value.map((item) => ({
      shipment_item_id: item.id,
      quantity: Number(item.received_quantity),
      availability: 'sellable' as const,
      location_id: null,
    }));

    const result = await shipmentStore.finalizeShipment(shipmentId.value, stockRows);

    showSuccessNotification(
      `Shipment received! Stamped ${result.items_stamped} items, posted ${result.stock_rows_posted} stock rows.`,
    );

    goBack();
  } catch (err: unknown) {
    error.value = err instanceof Error ? err.message : 'Failed to confirm receive stock';
  } finally {
    submitting.value = false;
  }
};
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-grey {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.shrink-0 {
  flex-shrink: 0;
}
.avatar-soft-sq {
  border-radius: 6px;
}
.text-xxs {
  font-size: 11px;
}
.font-mono {
  font-family: monospace;
}
.rounded-sq-btn {
  border-radius: 8px;
}
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

.shipment-items-markup-table th.bw-ops-col-tint--received,
.shipment-items-markup-table td.bw-ops-col-tint--received {
  background-color: #daf3e4 !important;
  box-shadow: inset 2px 0 0 #059669;
}

.shipment-items-markup-table tr.row-variance td {
  background-color: #fff7ed !important;
}

.shipment-items-markup-table tr:hover td {
  filter: brightness(0.98);
}

:deep(.inline-edit-input input[type='number']::-webkit-outer-spin-button),
:deep(.inline-edit-input input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(.inline-edit-input input[type='number']) {
  -moz-appearance: textfield;
  appearance: textfield;
}

:deep(.inline-edit-input .q-field__control) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 4px !important;
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

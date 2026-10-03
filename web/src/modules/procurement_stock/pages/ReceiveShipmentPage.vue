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
              Receive &amp; post to stock
            </div>
            <div class="text-caption text-grey-7 ellipsis">
              {{ shipmentName }}
              <span v-if="extras.length">
                · {{ totalExtraQty }} unit<span v-if="totalExtraQty !== 1">s</span> on
                {{ extras.length }} sellable split<span v-if="extras.length !== 1">s</span>
              </span>
            </div>
          </div>
        </div>

        <div class="row items-center q-gutter-md no-wrap">
          <q-banner
            v-if="extras.length"
            dense
            rounded
            class="bg-blue-1 text-blue-10 q-py-xs q-px-sm"
            style="max-width: 420px"
          >
            Posting marks the shipment <strong>Received</strong> and puts units in the default bin.
          </q-banner>
          <div class="row items-center q-gutter-md text-caption text-grey-7">
            <span>
              Extra qty:
              <span class="text-weight-bold text-primary">{{ totalExtraQty }}</span>
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
            label="Post to Stock"
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
            <th class="text-left" style="min-width: 120px">Line</th>
            <th class="text-center" style="min-width: 56px">Qty</th>
            <th class="text-center" style="min-width: 88px">Stock impact</th>
            <th class="text-center" style="min-width: 88px">Land reason</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(row, index) in extras"
            :key="row.id"
            class="shipment-item-row"
          >
            <td class="text-center text-weight-medium text-grey-7 q-pa-none" style="width: 36px; min-width: 36px">
              {{ index + 1 }}
            </td>

            <td class="shipment-image-col">
              <q-avatar square size="82px" class="avatar-soft-sq bg-grey-2 border-grey overflow-hidden" style="width: 0.85in; height: 0.85in">
                <SmartImage
                  :src="row.image_url"
                  :alt="row.item_name"
                  style="object-fit: cover; width: 100%; height: 100%"
                />
              </q-avatar>
            </td>

            <td style="width: 120px; min-width: 120px; max-width: 120px; white-space: normal !important; word-break: break-word">
              <div class="text-weight-bold text-grey-9" style="font-size: 13px; line-height: 1.35; word-break: break-word; white-space: normal">
                {{ row.item_name }}
              </div>
            </td>

            <td class="font-mono text-caption">
              <span v-if="row.product_code" class="text-grey-9">{{ row.product_code }}</span>
              <span v-else class="text-grey-5">—</span>
            </td>

            <td class="text-center font-mono text-weight-bold">{{ row.quantity }}</td>
            <td class="text-center text-caption">{{ formatOutcomeKind(row.kind) }}</td>
            <td class="text-center text-caption">{{ formatOutcomeReason(row.reason) }}</td>
          </tr>

          <tr v-if="extras.length === 0">
            <td colspan="7" class="text-center text-grey-6 q-py-xl">
              Add receive extras on the shipment line page first (not ordered paper rows).
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
import {
  globalShipmentRepository,
  type ShipmentItemOutcome,
} from '../repositories/globalShipmentRepository';
import { showSuccessNotification, showErrorNotification, requestConfirmation } from 'src/utils/appFeedback';
import { formatOutcomeKind, formatOutcomeReason } from '../constants/shipmentOutcomeLabels';

interface PutawayExtraRow extends ShipmentItemOutcome {
  item_name: string;
  product_code: string | null;
  image_url: string | null;
}

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const shipmentStore = useGlobalShipmentStore();

const shipmentId = computed(() => Number(route.params.id));
const loading = ref(false);
const submitting = ref(false);
const error = ref<string | null>(null);

const extras = ref<PutawayExtraRow[]>([]);

const shipmentName = computed(() => shipmentStore.currentShipment?.name || `#${shipmentId.value}`);

const totalExtraQty = computed(() =>
  extras.value.reduce((sum, row) => sum + (Number(row.quantity) || 0), 0),
);

const isValid = computed(() => extras.value.some((row) => row.kind === 'sellable' && row.quantity > 0));

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

    if (shipment.status === 'cancelled') {
      error.value = 'Cancelled shipments cannot post stock.';
      showErrorNotification(error.value);
      goBack();
      return;
    }

    const loadedItems = shipmentStore.currentShipmentItems || [];

    if (loadedItems.length === 0) {
      error.value = 'Shipment has no line items.';
      return;
    }

    const outcomes = await globalShipmentRepository.listShipmentItemOutcomes(
      loadedItems.map((item) => item.id),
    );
    const itemById = new Map(loadedItems.map((item) => [item.id, item]));
    extras.value = outcomes
      .filter((row) => row.reason !== 'ordered' && row.kind === 'sellable' && row.quantity > 0)
      .map((row) => {
        const line = itemById.get(row.shipment_item_id);
        return {
          ...row,
          item_name: line?.name ?? 'Line',
          product_code: line?.product_code ?? null,
          image_url: line?.image_url ?? null,
        };
      });
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
    `Post unposted sellable extras to the default put-away bin for ${shipmentName.value}? (${totalExtraQty.value} pcs on ${extras.value.length} row(s))`,
    'Post to stock',
    'Post',
  );

  if (!confirmed) return;

  submitting.value = true;
  error.value = null;

  try {
    const stockRows = extras.value.map((row) => ({
      outcome_id: row.id,
      location_id: null,
    }));

    const result = await shipmentStore.postOutcomeStock(shipmentId.value, stockRows);

    if (result.stock_rows_posted === 0) {
      showErrorNotification('Nothing new to post. Extras may already be on the shelf.');
      return;
    }

    showSuccessNotification(
      `Posted ${result.stock_rows_posted} lot row(s). Shipment is Received. Stamped ${result.items_stamped} line cost(s).`,
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

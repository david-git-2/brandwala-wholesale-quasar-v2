<template>
  <q-page class="receive-shipment-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Header bar -->
    <div class="bg-white border-bottom q-px-md q-py-sm row items-center justify-between shadow-1">
      <div class="row items-center q-gutter-sm">
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
        <div>
          <div class="row items-center q-gutter-xs">
            <span class="text-h6 text-weight-bold text-grey-9">Receive Shipment Stock Checklist</span>
            <q-badge color="primary" outline rounded class="q-ml-xs">
              {{ shipmentName }}
            </q-badge>
          </div>
          <div class="text-caption text-grey-7">
            Enter received quantities per line item to post sellable stock into the warehouse.
          </div>
        </div>
      </div>

      <div class="row items-center q-gutter-sm">
        <q-btn
          flat
          label="Cancel"
          color="grey-8"
          no-caps
          style="border-radius: 8px"
          @click="goBack"
        />
        <q-btn
          color="primary"
          unelevated
          icon="ph ph-check-circle"
          label="Confirm & Post Stock"
          no-caps
          style="border-radius: 8px"
          :loading="submitting"
          :disable="!isValid || submitting"
          @click="onConfirmReceive"
        />
      </div>
    </div>

    <!-- Main Content Area -->
    <div class="col scroll q-pa-md">
      <div class="max-width-container">
        <!-- Error Banner -->
        <q-banner v-if="error" class="bg-negative text-white rounded-borders q-mb-md q-py-sm shadow-1">
          <template #avatar>
            <q-icon name="ph ph-warning-circle" size="24px" />
          </template>
          {{ error }}
        </q-banner>

        <!-- Loading State -->
        <div v-if="loading" class="row justify-center items-center q-py-xl">
          <q-spinner color="primary" size="3em" />
          <div class="text-grey-7 q-ml-md font-medium">Loading shipment lines...</div>
        </div>

        <!-- Checklist List/Table -->
        <q-card v-else flat bordered class="bg-white rounded-borders shadow-1">
          <q-card-section class="q-pa-none">
            <div class="row items-center justify-between q-pa-md border-bottom bg-grey-1">
              <div class="text-subtitle1 text-weight-bold text-grey-9">
                Line Items ({{ items.length }})
              </div>
              <div class="row items-center q-gutter-md text-caption text-grey-7">
                <div>
                  Total Ordered:
                  <span class="text-weight-bold text-grey-9">{{ totalOrderedQty }} pcs</span>
                </div>
                <div>
                  Total Received:
                  <span
                    class="text-weight-bold"
                    :class="totalReceivedQty === totalOrderedQty ? 'text-positive' : 'text-primary'"
                  >
                    {{ totalReceivedQty }} pcs
                  </span>
                </div>
              </div>
            </div>

            <!-- Items table -->
            <q-markup-table flat borderless class="checklist-table">
              <thead>
                <tr class="text-left text-grey-8 bg-grey-2">
                  <th style="width: 60px">#</th>
                  <th style="width: 80px">Image</th>
                  <th>Product Details</th>
                  <th class="text-right" style="width: 140px">Ordered quantity</th>
                  <th class="text-right" style="width: 180px">Received quantity</th>
                  <th class="text-center" style="width: 120px">Variance</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(item, index) in items"
                  :key="item.id"
                  class="items-row"
                  :class="{ 'bg-orange-1': (item.received_quantity ?? 0) !== item.ordered_quantity }"
                >
                  <td class="text-grey-6">{{ index + 1 }}</td>
                  <td>
                    <div class="q-pa-xs border rounded-borders bg-white inline-block">
                      <SmartImage
                        :src="item.image_url"
                        :alt="item.name"
                        style="width: 48px; height: 48px; object-fit: cover; border-radius: 4px"
                      />
                    </div>
                  </td>
                  <td>
                    <div class="text-weight-bold text-grey-9">{{ item.name }}</div>
                    <div class="text-caption text-grey-6 row items-center q-gutter-x-sm">
                      <span v-if="item.product_code">Code: {{ item.product_code }}</span>
                      <span v-if="item.barcode">Barcode: {{ item.barcode }}</span>
                    </div>
                  </td>
                  <td class="text-right font-medium text-grey-9 text-subtitle2">
                    {{ item.ordered_quantity }} pcs
                  </td>
                  <td class="text-right">
                    <q-input
                      v-model.number="item.received_quantity"
                      type="number"
                      outlined
                      dense
                      min="0"
                      class="bg-white"
                      style="max-width: 160px; margin-left: auto"
                      :rules="[
                        (val) => val !== null && val !== undefined && val !== '' || 'Required',
                        (val) => Number(val) >= 0 || 'Must be >= 0',
                      ]"
                      hide-bottom-space
                    />
                  </td>
                  <td class="text-center">
                    <q-chip
                      v-if="(item.received_quantity ?? 0) === item.ordered_quantity"
                      color="positive"
                      text-color="white"
                      dense
                      size="sm"
                    >
                      Exact
                    </q-chip>
                    <q-chip
                      v-else-if="(item.received_quantity ?? 0) < item.ordered_quantity"
                      color="orange-8"
                      text-color="white"
                      dense
                      size="sm"
                    >
                      Short (-{{ item.ordered_quantity - (item.received_quantity ?? 0) }})
                    </q-chip>
                    <q-chip
                      v-else
                      color="blue-8"
                      text-color="white"
                      dense
                      size="sm"
                    >
                      Over (+{{ (item.received_quantity ?? 0) - item.ordered_quantity }})
                    </q-chip>
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card-section>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import SmartImage from 'src/components/SmartImage.vue';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

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
.receive-shipment-page {
  font-family: inherit;
}
.border-bottom {
  border-bottom: 1px solid var(--q-grey-4, #e0e0e0);
}
.border {
  border: 1px solid var(--q-grey-4, #e0e0e0);
}
.max-width-container {
  max-width: 1200px;
  margin: 0 auto;
}
.checklist-table th {
  font-weight: 600;
  font-size: 0.85rem;
}
.checklist-table td {
  vertical-align: middle;
}
</style>

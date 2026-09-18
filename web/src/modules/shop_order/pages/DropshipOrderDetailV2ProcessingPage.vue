<script setup lang="ts">
import { computed, nextTick, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import DropshipOrderConfirmedInvoicePaper from '../components/DropshipOrderConfirmedInvoicePaper.vue';
import DropshipOrderItemStockPickDialog from '../components/DropshipOrderItemStockPickDialog.vue';
import DropshipOrderCancelDialog from '../components/DropshipOrderCancelDialog.vue';
import { useDropshipOrderDetailV2Query } from '../composables/useDropshipOrderDetailV2Query';
import { useDropshipCourierOptions } from '../composables/useDropshipCourierOptions';
import { useDropshipOrderProcessingDesk } from '../composables/useDropshipOrderProcessingDesk';
import { useDropshipOrderStatusRedirect } from '../composables/useDropshipOrderStatusRedirect';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import {
  createEmptyDropshipInvoiceSummary,
  type DropshipInvoiceSummaryState,
} from '../utils/dropshipInvoiceSummary';
import type {
  DropshipInvoiceCourierState,
  DropshipInvoicePickupState,
} from '../utils/dropshipInvoiceFulfillment';
import type { ShopOrderItem } from '../types';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
} from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);
const orderId = computed(() => Number(route.params.id || 0));

const orderDetailQuery = useDropshipOrderDetailV2Query({ tenantSlug, orderId });

const order = computed(() => orderDetailQuery.data.value?.order ?? null);
const orderItems = computed(() => orderDetailQuery.data.value?.items ?? []);

const summaryForm = ref<DropshipInvoiceSummaryState>(createEmptyDropshipInvoiceSummary());

const { couriers, courierOptions } = useDropshipCourierOptions({
  tenantSlug,
  orderTenantId: computed(() => order.value?.tenant_id),
});

const pickupForm = reactive<DropshipInvoicePickupState>({
  pickup_location_id: null,
  sender_name: '',
  pickup_phone: '',
  pickup_address: '',
});

const courierForm = reactive<DropshipInvoiceCourierState>({
  courier_service_id: null,
  courier_awb_number: '',
  tracking_url: '',
  allow_open_box: false,
  cod_charge: 0,
});

const formReady = ref(false);
const pickDialogOpen = ref(false);
const cancelDialogOpen = ref(false);
const pickTargetItem = ref<ShopOrderItem | null>(null);
const actionLoading = ref(false);

const canMarkReadyForPickup = computed(
  () => orderDetailQuery.data.value?.permissions.can_mark_ready_for_pickup ?? false,
);
const canCancelOrder = computed(
  () => orderDetailQuery.data.value?.permissions.can_cancel_order ?? false,
);
const allLinesResolved = computed(
  () => orderDetailQuery.data.value?.computed.all_lines_resolved ?? false,
);
const totalDeliveredQty = computed(
  () => orderDetailQuery.data.value?.computed.total_delivered_qty ?? 0,
);

watch(
  () => orderDetailQuery.data.value,
  async (detail) => {
    if (!detail) {
      formReady.value = false;
      return;
    }

    formReady.value = false;
    summaryForm.value = { ...detail.summary };
    Object.assign(pickupForm, detail.fulfillment.pickup);
    Object.assign(courierForm, detail.fulfillment.courier);
    await nextTick();
    formReady.value = true;
  },
  { immediate: true },
);

const isLoading = computed(() => orderDetailQuery.isLoading.value);
const loadError = computed(() => orderDetailQuery.error.value);

const processingDesk = useDropshipOrderProcessingDesk({
  tenantSlug,
  orderId,
  order,
  orderItems,
  summaryForm,
  pickupForm,
  courierForm,
  couriers,
  canMarkReadyForPickup,
  allLinesResolved,
  totalDeliveredQty,
  formReady,
  refetchOrderDetail: () => orderDetailQuery.refetch(),
});

const {
  saving,
  advancingStatus,
  autoSaveState,
  pickupLocationOptions,
  pendingLineNames,
  hasCourier,
  hasPickupLocation,
  allLinesResolvedLocal,
  canAdvanceToReadyForPickup,
  readyForPickupBlockReason,
  showNothingToShipBanner,
  advanceToReadyForPickup,
  onPickupLocationSelect,
  invalidateDetail,
} = processingDesk;

useDropshipOrderStatusRedirect({
  expectedView: 'processing',
  status: computed(() => order.value?.status ?? null),
  orderId,
  tenantSlug,
  enabled: computed(() => !isLoading.value && !!order.value),
});

const selectedCourier = computed(() =>
  couriers.value.find((courier) => courier.id === courierForm.courier_service_id),
);

const deliveryZoneLabel = computed(
  () =>
    orderDetailQuery.data.value?.computed.delivery_zone_label ??
    (order.value?.shipping_district?.trim().toLowerCase() === 'dhaka' ? 'Inside Dhaka' : 'Outside Dhaka'),
);

const autoSaveLabel = computed(() => {
  if (autoSaveState.value === 'pending' || saving.value) return 'Saving…';
  if (autoSaveState.value === 'error') return 'Save failed';
  if (autoSaveState.value === 'saved') return 'All changes saved';
  return '';
});

const onCourierChange = () => {
  const courier = selectedCourier.value;
  if (!courier) return;

  courierForm.allow_open_box = courier.open_box_default_allowed;

  if (courier.tracking_url_template && courierForm.courier_awb_number.trim()) {
    courierForm.tracking_url = courier.tracking_url_template.replace(
      '{awb}',
      courierForm.courier_awb_number.trim(),
    );
  }
};

const openPickDialog = (itemId: number) => {
  pickTargetItem.value = orderItems.value.find((item) => item.id === itemId) ?? null;
  pickDialogOpen.value = true;
};

const markUnavailable = async (itemId: number) => {
  const confirmed = await requestConfirmation(
    'Mark this line unavailable? Delivered qty will be 0. A demand bucket entry will be created by default.',
    'Mark unavailable',
    'Mark unavailable',
  );
  if (!confirmed) return;

  actionLoading.value = true;
  try {
    await shopOrderRepository.markShopOrderItemUnavailable(itemId, null, true);
    showSuccessNotification('Line marked unavailable.');
    await invalidateDetail();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to mark unavailable'));
  } finally {
    actionLoading.value = false;
  }
};

const clearUnavailable = async (itemId: number) => {
  actionLoading.value = true;
  try {
    await shopOrderRepository.clearShopOrderItemUnavailable(itemId);
    showSuccessNotification('Line is pending again — you can pick stock.');
    await invalidateDetail();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to clear unavailable'));
  } finally {
    actionLoading.value = false;
  }
};

const removePick = async (pickId: number) => {
  actionLoading.value = true;
  try {
    await shopOrderRepository.removeShopOrderItemStockPick(pickId);
    showSuccessNotification('Pick removed and hold released.');
    await invalidateDetail();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to remove pick'));
  } finally {
    actionLoading.value = false;
  }
};

const onOrderCancelled = () => {
  void router.push({ name: 'app-shop-dropship-orders-page' });
};
</script>

<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <q-banner
        v-if="showNothingToShipBanner"
        dense
        rounded
        class="bg-red-1 text-red-10"
      >
        Nothing to ship on this order. Cancel the order or go back and pick stock on at least one line.
        <template #action>
          <q-btn
            v-if="canCancelOrder"
            flat
            no-caps
            color="negative"
            label="Cancel order"
            @click="cancelDialogOpen = true"
          />
        </template>
      </q-banner>

      <section v-if="isLoading" class="dropship-order-detail-v2__loading">
        <q-skeleton type="rect" height="520px" class="dropship-order-detail-v2__paper-skeleton" />
      </section>

      <section v-else-if="loadError" class="text-caption text-negative">
        {{ loadError instanceof Error ? loadError.message : 'Failed to load order.' }}
      </section>

      <template v-else-if="order">
        <div class="dropship-order-detail-v2__status-actions row items-center justify-between">
          <div class="row items-center q-gutter-x-sm">
            <q-chip
              dense
              :color="allLinesResolvedLocal ? 'positive' : 'orange-9'"
              text-color="white"
              icon="ph ph-package"
              class="text-weight-bold"
            >
              {{ allLinesResolvedLocal ? 'All lines picked or cancelled' : `${pendingLineNames.length} line(s) pending` }}
            </q-chip>
            <q-chip
              dense
              :color="hasPickupLocation ? 'positive' : 'grey-6'"
              text-color="white"
              icon="ph ph-map-pin"
              class="text-weight-bold"
            >
              {{ hasPickupLocation ? 'Pickup location set' : 'Pickup location needed' }}
            </q-chip>
            <q-chip
              dense
              :color="hasCourier ? 'positive' : 'grey-6'"
              text-color="white"
              icon="ph ph-truck"
              class="text-weight-bold"
            >
              {{ hasCourier ? (courierForm.courier_awb_number ? `AWB: ${courierForm.courier_awb_number}` : 'Courier selected') : 'Courier needed' }}
            </q-chip>
            <span
              v-if="autoSaveLabel"
              class="text-caption text-weight-medium q-ml-xs"
              :class="autoSaveState === 'error' ? 'text-negative' : 'text-grey-6'"
            >
              {{ autoSaveLabel }}
            </span>
          </div>

          <div class="row items-center q-gutter-x-sm">
            <q-btn
              v-if="canCancelOrder"
              outline
              color="negative"
              no-caps
              icon="ph ph-x-circle"
              label="Cancel order"
              @click="cancelDialogOpen = true"
            />
            <q-btn
              v-if="canMarkReadyForPickup"
              color="primary"
              unelevated
              no-caps
              icon="ph ph-check-circle"
              label="Ready for pickup"
              class="text-weight-bold"
              style="border-radius: 8px; min-width: 200px"
              :loading="advancingStatus"
              :disable="!canAdvanceToReadyForPickup || advancingStatus"
              @click="advanceToReadyForPickup()"
            >
              <q-tooltip v-if="readyForPickupBlockReason">
                {{ readyForPickupBlockReason }}
              </q-tooltip>
            </q-btn>
          </div>
        </div>

        <DropshipOrderConfirmedInvoicePaper
          :order="order"
          :order-items="orderItems"
          editable-summary
          show-delivered-quantities
          show-stock-pick-actions
          show-fulfillment-blocks
          v-model:summary="summaryForm"
          v-model:pickup="pickupForm"
          v-model:courier="courierForm"
          :pickup-location-options="pickupLocationOptions"
          :courier-options="courierOptions"
          :delivery-zone-label="deliveryZoneLabel"
          @pickup-select="onPickupLocationSelect"
          @courier-change="onCourierChange"
          @pick-stock="openPickDialog"
          @mark-unavailable="markUnavailable"
          @clear-unavailable="clearUnavailable"
          @remove-pick="removePick"
        />
      </template>
    </div>

    <DropshipOrderItemStockPickDialog
      v-model="pickDialogOpen"
      :order-item="pickTargetItem"
      @picked="invalidateDetail"
    />

    <DropshipOrderCancelDialog
      v-if="order"
      v-model="cancelDialogOpen"
      :order-id="order.id"
      :order-no="order.order_no"
      :has-invoice="!!order.global_invoice_id"
      @cancelled="onOrderCancelled"
    />
  </q-page>
</template>

<style scoped>
.dropship-order-detail-v2 {
  min-height: 100%;
}

.dropship-order-detail-v2__info-banner {
  border: 1px solid rgba(249, 115, 22, 0.25);
  max-width: 1100px;
  margin: 0 auto;
  width: 100%;
}

.dropship-order-detail-v2__paper-skeleton {
  max-width: 1100px;
  margin: 0 auto;
  border-radius: 12px;
}

.dropship-order-detail-v2__status-actions {
  max-width: 1100px;
  margin: 0 auto;
  width: 100%;
  display: flex;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 0.5rem;
}
</style>

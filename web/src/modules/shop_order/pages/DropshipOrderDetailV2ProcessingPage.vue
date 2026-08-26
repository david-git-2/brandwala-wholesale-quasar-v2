<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import DropshipOrderConfirmedInvoicePaper from '../components/DropshipOrderConfirmedInvoicePaper.vue';
import DropshipOrderDialogs from '../components/DropshipOrderDialogs.vue';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import {
  createEmptyDropshipInvoiceSummary,
  type DropshipInvoiceSummaryState,
} from '../utils/dropshipInvoiceSummary';
import type {
  DropshipInvoiceCourierState,
  DropshipInvoiceDeliveredQuantitiesState,
  DropshipInvoicePickupState,
} from '../utils/dropshipInvoiceFulfillment';
import { useDropshipOrderDetailV2Query } from '../composables/useDropshipOrderDetailV2Query';
import { useDropshipOrderProcessingDesk } from '../composables/useDropshipOrderProcessingDesk';
import { useDropshipOrderStatusRedirect } from '../composables/useDropshipOrderStatusRedirect';

const route = useRoute();

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);
const orderId = computed(() => Number(route.params.id || 0));

const orderDetailQuery = useDropshipOrderDetailV2Query({ tenantSlug, orderId });

const order = computed(() => orderDetailQuery.data.value?.order ?? null);
const orderItems = computed(() => orderDetailQuery.data.value?.items ?? []);

const summaryForm = ref<DropshipInvoiceSummaryState>(createEmptyDropshipInvoiceSummary());
const deliveredQuantitiesForm = ref<DropshipInvoiceDeliveredQuantitiesState>({});
const couriers = ref<CourierServiceRow[]>([]);

const pickupForm = reactive<DropshipInvoicePickupState>({
  merchant_id: null,
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

watch(
  () => orderDetailQuery.data.value,
  (detail) => {
    if (!detail) return;

    summaryForm.value = { ...detail.summary };
    Object.assign(pickupForm, detail.fulfillment.pickup);
    Object.assign(courierForm, detail.fulfillment.courier);
    deliveredQuantitiesForm.value = Object.fromEntries(
      detail.items.map((item) => [
        item.id,
        item.confirmed_quantity != null ? item.confirmed_quantity : item.quantity,
      ]),
    );
    couriers.value = detail.lookups.courier_services;
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
  deliveredQuantitiesForm,
  couriers,
  refetchOrderDetail: () => orderDetailQuery.refetch(),
});

const {
  saving,
  advancingStatus,
  confirmB2bInvoiceDialogOpen,
  merchantOptions,
  finance,
  formatBdt,
  saveProcessingDesk,
  onReadyForPickupClick,
  executeAdvanceToReadyForPickup,
  onMerchantSelect,
} = processingDesk;

useDropshipOrderStatusRedirect({
  expectedView: 'processing',
  status: computed(() => order.value?.status ?? null),
  orderId,
  tenantSlug,
  enabled: computed(() => !isLoading.value && !!order.value),
});

const courierOptions = computed(() =>
  couriers.value.map((courier) => ({ label: courier.name, value: courier.id })),
);

const selectedCourier = computed(() =>
  couriers.value.find((courier) => courier.id === courierForm.courier_service_id),
);

const deliveryZoneLabel = computed(
  () =>
    orderDetailQuery.data.value?.computed.delivery_zone_label ??
    (order.value?.shipping_district?.trim().toLowerCase() === 'dhaka' ? 'Inside Dhaka' : 'Outside Dhaka'),
);

const suggestedDeliveryFee = computed(() => {
  const courier = selectedCourier.value;
  if (!courier) return 0;
  return deliveryZoneLabel.value === 'Inside Dhaka'
    ? courier.inside_dhaka_fee
    : courier.outside_dhaka_fee;
});

const codRateLabel = computed(() => {
  const courier = selectedCourier.value;
  if (!courier) return '—';
  if (courier.cod_fee_mode === 'percent_of_collect') {
    return `${courier.cod_fee_percent}% of collect`;
  }
  if (courier.cod_fee_mode === 'flat') {
    return `Flat ৳${courier.cod_fee_flat_amount.toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })}`;
  }
  return courier.cod_fee_mode.replace(/_/g, ' ');
});

const canMarkReadyForPickup = computed(
  () => orderDetailQuery.data.value?.permissions.can_mark_ready_for_pickup ?? false,
);

const onCourierChange = () => {
  const courier = selectedCourier.value;
  if (!courier) return;

  courierForm.allow_open_box = courier.open_box_default_allowed;
  if (courier.cod_fee_mode === 'flat') {
    courierForm.cod_charge = courier.cod_fee_flat_amount;
  } else if (courier.cod_fee_mode === 'percent_of_collect') {
    courierForm.cod_charge = Math.round(
      summaryForm.value.cod_collect_amount * (courier.cod_fee_percent / 100),
    );
  }

  if (courier.tracking_url_template && courierForm.courier_awb_number.trim()) {
    courierForm.tracking_url = courier.tracking_url_template.replace(
      '{awb}',
      courierForm.courier_awb_number.trim(),
    );
  }
};
</script>

<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <q-banner dense rounded class="bg-orange-1 text-orange-10 dropship-order-detail-v2__info-banner">
        <template #avatar>
          <q-icon name="ph ph-package" color="orange-9" />
        </template>
        <span class="text-caption">
          Processing desk — edit charges, pickup location, and courier before packing.
        </span>
      </q-banner>

      <section v-if="isLoading" class="dropship-order-detail-v2__loading">
        <q-skeleton type="rect" height="520px" class="dropship-order-detail-v2__paper-skeleton" />
      </section>

      <section v-else-if="loadError" class="text-caption text-negative">
        {{ loadError instanceof Error ? loadError.message : 'Failed to load order.' }}
      </section>

      <template v-else-if="order">
        <div class="dropship-order-detail-v2__status-actions">
          <q-btn
            outline
            color="primary"
            unelevated
            no-caps
            icon="ph ph-floppy-disk"
            label="Save changes"
            class="text-weight-bold"
            style="border-radius: 8px; min-width: 180px"
            :loading="saving"
            @click="saveProcessingDesk()"
          />
          <q-btn
            v-if="canMarkReadyForPickup"
            color="primary"
            unelevated
            no-caps
            icon="ph ph-check-circle"
            label="Ready for pickup"
            class="text-weight-bold"
            style="border-radius: 8px; min-width: 220px"
            :loading="advancingStatus || saving"
            @click="onReadyForPickupClick()"
          />
        </div>

        <DropshipOrderConfirmedInvoicePaper
          :order="order"
          :order-items="orderItems"
          editable-summary
          show-delivered-quantities
          show-fulfillment-blocks
          v-model:summary="summaryForm"
          v-model:pickup="pickupForm"
          v-model:courier="courierForm"
          v-model:delivered-quantities="deliveredQuantitiesForm"
          :merchant-options="merchantOptions"
          :courier-options="courierOptions"
          :delivery-zone-label="deliveryZoneLabel"
          :suggested-delivery-fee="suggestedDeliveryFee"
          :cod-rate-label="codRateLabel"
          @merchant-select="onMerchantSelect"
          @courier-change="onCourierChange"
        />

        <DropshipOrderDialogs
          :order="order"
          :dual-invoice-dialog-open="false"
          :creating-invoice="false"
          :confirm-b2b-invoice-dialog-open="confirmB2bInvoiceDialogOpen"
          :confirm-delete-invoice-dialog-open="false"
          :updating-status="advancingStatus"
          :recipient-grand-total="finance.recipientGrandTotal"
          :delivery-charge-val="finance.deliveryChargeVal"
          :cod-charge-val="finance.codChargeVal"
          :accounting-subtotal="finance.accountingSubtotal"
          :print-charge-val="finance.printChargeVal"
          :packing-charge-val="finance.packingChargeVal"
          :estimated-profit="finance.estimatedProfit"
          :cod-collect-amount="summaryForm.cod_collect_amount"
          :format-bdt="formatBdt"
          @update:confirm-b2b-invoice-dialog-open="(val) => (confirmB2bInvoiceDialogOpen = val)"
          @execute-status-update="executeAdvanceToReadyForPickup()"
        />
      </template>
    </div>
  </q-page>
</template>

<style scoped>
.dropship-order-detail-v2 {
  background: #eef1f4;
}

.dropship-order-detail-v2__info-banner {
  border: 1px solid rgba(249, 115, 22, 0.25);
}

.dropship-order-detail-v2__paper-skeleton {
  max-width: 920px;
  margin: 0 auto;
  border-radius: 2px;
}

.dropship-order-detail-v2__status-actions {
  max-width: 920px;
  margin: 0 auto;
  width: 100%;
  display: flex;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 0.5rem;
}
</style>

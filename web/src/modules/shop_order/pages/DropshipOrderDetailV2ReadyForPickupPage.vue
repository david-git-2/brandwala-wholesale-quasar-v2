<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import DropshipOrderDetailUiToggle from '../components/DropshipOrderDetailUiToggle.vue';
import DropshipOrderConfirmedInvoicePaper from '../components/DropshipOrderConfirmedInvoicePaper.vue';
import { DROPSHIP_ORDER_DETAIL_V2_DUMMY } from '../fixtures/dropshipOrderDetailV2Dummy';
import {
  createDropshipInvoiceSummaryFromOrder,
  type DropshipInvoiceSummaryState,
} from '../utils/dropshipInvoiceSummary';
import type {
  DropshipInvoiceCourierState,
  DropshipInvoiceDeliveredQuantitiesState,
  DropshipInvoicePickupState,
} from '../utils/dropshipInvoiceFulfillment';
import { createDeliveredQuantitiesFromItems } from '../utils/dropshipInvoiceFulfillment';
import { DROPSHIP_ORDER_DETAIL_V2_CUSTOMER_INVOICE_PREVIEW_ROUTE } from '../composables/useDropshipOrderDetailUiToggle';
import { saveDropshipV2CustomerInvoiceSnapshot } from '../utils/dropshipV2CustomerInvoiceStorage';
import { supabase } from 'src/boot/supabase';
import {
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
} from 'src/utils/appFeedback';
import type { ShopOrderStatus } from '../types';

const route = useRoute();
const router = useRouter();
const useDummyData = ref(true);
const advancingStatus = ref(false);
const orderStatus = ref<Extract<ShopOrderStatus, 'ready_for_pickup' | 'shipped'>>('ready_for_pickup');

const order = computed(() => {
  if (!useDummyData.value) return null;
  return {
    ...DROPSHIP_ORDER_DETAIL_V2_DUMMY.order,
    status: orderStatus.value,
  };
});

const canMarkShipped = computed(() => orderStatus.value === 'ready_for_pickup');

const orderItems = computed(() =>
  useDummyData.value ? DROPSHIP_ORDER_DETAIL_V2_DUMMY.items : [],
);

const summaryForm = ref<DropshipInvoiceSummaryState>(
  createDropshipInvoiceSummaryFromOrder(DROPSHIP_ORDER_DETAIL_V2_DUMMY.order),
);

const deliveredQuantitiesForm = ref<DropshipInvoiceDeliveredQuantitiesState>(
  createDeliveredQuantitiesFromItems(DROPSHIP_ORDER_DETAIL_V2_DUMMY.items),
);

const pickupForm = reactive<DropshipInvoicePickupState>({
  merchant_id: DROPSHIP_ORDER_DETAIL_V2_DUMMY.pickup.merchant_id,
  sender_name: DROPSHIP_ORDER_DETAIL_V2_DUMMY.pickup.sender_name,
  pickup_phone: DROPSHIP_ORDER_DETAIL_V2_DUMMY.pickup.pickup_phone,
  pickup_address: DROPSHIP_ORDER_DETAIL_V2_DUMMY.pickup.pickup_address,
});

const courierForm = reactive<DropshipInvoiceCourierState>({
  courier_service_id: DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierForm.courier_service_id,
  courier_awb_number: 'PA-2026-0842-001',
  tracking_url: 'https://merchant.pathao.com/tracking?consignment_id=PA-2026-0842-001',
  allow_open_box: DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierForm.allow_open_box,
  cod_charge: DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierForm.cod_charge,
});

const merchantOptions = DROPSHIP_ORDER_DETAIL_V2_DUMMY.merchantOptions;
const courierOptions = computed(() =>
  DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierServices.map((courier) => ({
    label: courier.name,
    value: courier.id,
  })),
);

const selectedCourier = computed(() =>
  DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierServices.find(
    (courier) => courier.id === courierForm.courier_service_id,
  ),
);

const deliveryZoneLabel = computed(() =>
  order.value?.shipping_district?.trim().toLowerCase() === 'dhaka' ? 'Inside Dhaka' : 'Outside Dhaka',
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

const openCustomerInvoicePreview = () => {
  if (!order.value) return;

  saveDropshipV2CustomerInvoiceSnapshot(order.value.id, {
    summary: summaryForm.value,
    deliveredQuantities: deliveredQuantitiesForm.value,
  });

  const routeData = router.resolve({
    name: DROPSHIP_ORDER_DETAIL_V2_CUSTOMER_INVOICE_PREVIEW_ROUTE,
    params: {
      id: order.value.id,
      tenantSlug: route.params.tenantSlug,
    },
  });
  window.open(routeData.href, '_blank');
};

const advanceToShipped = async () => {
  if (!order.value || !canMarkShipped.value) return;

  advancingStatus.value = true;
  try {
    if (useDummyData.value) {
      orderStatus.value = 'shipped';
      showSuccessNotification('Preview: status updated to shipped');
      return;
    }

    const { data, error } = await supabase.rpc('advance_dropship_order_status', {
      p_order_id: order.value.id,
      p_target_status: 'shipped',
    });
    if (error) throw error;
    if (data && typeof data === 'object' && (data as { success?: boolean }).success === false) {
      throw new Error((data as { error?: string }).error || 'Failed to update status');
    }

    orderStatus.value = 'shipped';
    showSuccessNotification('Status updated to shipped');
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to update status'));
  } finally {
    advancingStatus.value = false;
  }
};
</script>

<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <DropshipOrderDetailUiToggle />

      <q-banner dense rounded class="bg-blue-1 text-blue-10 dropship-order-detail-v2__dummy-banner no-print">
        <template #avatar>
          <q-icon name="ph ph-check-circle" color="blue-8" />
        </template>
        <span class="text-caption">
          {{
            orderStatus === 'shipped'
              ? 'Shipped — order is locked. Print the customer resell invoice for the recipient.'
              : 'Ready for pickup — order is locked. Print the customer resell invoice for the recipient.'
          }}
        </span>
        <template #action>
          <q-toggle
            v-model="useDummyData"
            dense
            color="primary"
            label="Sample data"
            left-label
            class="text-caption text-weight-medium"
          />
        </template>
      </q-banner>

      <div v-if="order" class="dropship-order-detail-v2__ready-actions no-print">
        <q-btn
          v-if="canMarkShipped"
          color="primary"
          unelevated
          no-caps
          icon="ph ph-truck"
          label="Mark as shipped"
          class="text-weight-bold"
          style="border-radius: 8px; min-width: 200px"
          :loading="advancingStatus"
          @click="advanceToShipped"
        />
        <q-btn
          outline
          color="primary"
          unelevated
          no-caps
          icon="ph ph-printer"
          label="Print customer invoice"
          class="text-weight-bold"
          style="border-radius: 8px; min-width: 220px"
          @click="openCustomerInvoicePreview"
        />
      </div>

      <DropshipOrderConfirmedInvoicePaper
        v-if="order"
        :order="order"
        :order-items="orderItems"
        readonly
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
      />

      <q-card v-else flat bordered class="form-card">
        <q-card-section class="column items-center justify-center q-pa-xl text-center">
          <q-icon name="ph ph-wrench" size="48px" color="grey-5" class="q-mb-md" />
          <div class="text-subtitle1 text-weight-bold text-grey-8 q-mb-xs">
            Ready for pickup view
          </div>
          <p class="text-body2 text-grey-6 q-mb-none" style="max-width: 420px">
            Live order loading will go here.
          </p>
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<style scoped>
.dropship-order-detail-v2 {
  background: #eef1f4;
}

.dropship-order-detail-v2__dummy-banner {
  border: 1px solid rgba(59, 130, 246, 0.25);
}

.dropship-order-detail-v2__ready-actions {
  max-width: 920px;
  margin: 0 auto;
  width: 100%;
  display: flex;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 0.5rem;
}
</style>

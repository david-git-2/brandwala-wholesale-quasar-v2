<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import DropshipOrderDetailUiToggle from '../components/DropshipOrderDetailUiToggle.vue';
import DropshipOrderConfirmedInvoicePaper from '../components/DropshipOrderConfirmedInvoicePaper.vue';
import { DROPSHIP_ORDER_DETAIL_V2_DUMMY } from '../fixtures/dropshipOrderDetailV2Dummy';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
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
import { DROPSHIP_ORDER_DETAIL_V2_READY_FOR_PICKUP_ROUTE } from '../composables/useDropshipOrderDetailUiToggle';

const route = useRoute();
const router = useRouter();
const useDummyData = ref(true);

const order = computed(() => {
  if (!useDummyData.value) return null;
  return {
    ...DROPSHIP_ORDER_DETAIL_V2_DUMMY.order,
    status: 'processing' as const,
  };
});

const orderItems = computed(() =>
  useDummyData.value ? DROPSHIP_ORDER_DETAIL_V2_DUMMY.items : [],
);

const summaryForm = ref<DropshipInvoiceSummaryState>(
  createDropshipInvoiceSummaryFromOrder(DROPSHIP_ORDER_DETAIL_V2_DUMMY.order),
);

const deliveredQuantitiesForm = ref<DropshipInvoiceDeliveredQuantitiesState>(
  createDeliveredQuantitiesFromItems(DROPSHIP_ORDER_DETAIL_V2_DUMMY.items),
);

const couriers = ref<CourierServiceRow[]>(DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierServices);
const merchantOptions = DROPSHIP_ORDER_DETAIL_V2_DUMMY.merchantOptions;

const pickupForm = reactive<DropshipInvoicePickupState>({
  merchant_id: DROPSHIP_ORDER_DETAIL_V2_DUMMY.pickup.merchant_id,
  sender_name: DROPSHIP_ORDER_DETAIL_V2_DUMMY.pickup.sender_name,
  pickup_phone: DROPSHIP_ORDER_DETAIL_V2_DUMMY.pickup.pickup_phone,
  pickup_address: DROPSHIP_ORDER_DETAIL_V2_DUMMY.pickup.pickup_address,
});

const courierForm = reactive<DropshipInvoiceCourierState>({
  courier_service_id: DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierForm.courier_service_id,
  courier_awb_number: DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierForm.courier_awb_number,
  tracking_url: DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierForm.tracking_url,
  allow_open_box: DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierForm.allow_open_box,
  cod_charge: DROPSHIP_ORDER_DETAIL_V2_DUMMY.courierForm.cod_charge,
});

const merchantPickupPresets: Record<
  string,
  Pick<DropshipInvoicePickupState, 'sender_name' | 'pickup_phone' | 'pickup_address'>
> = {
  'dummy-merchant-rahim': {
    sender_name: 'Rahim Electronics Warehouse',
    pickup_phone: '01987654321',
    pickup_address: 'Shop 12, Multiplan Center, Elephant Road, Dhaka 1205',
  },
  'dummy-merchant-metro': {
    sender_name: 'Metro Gadget Hub',
    pickup_phone: '01811223344',
    pickup_address: 'Level 3, Bashundhara City, Panthapath, Dhaka 1205',
  },
};

const courierOptions = computed(() =>
  couriers.value.map((courier) => ({ label: courier.name, value: courier.id })),
);

const selectedCourier = computed(() =>
  couriers.value.find((courier) => courier.id === courierForm.courier_service_id),
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

const onMerchantSelect = (merchantId: string | null) => {
  if (!merchantId) return;
  const preset = merchantPickupPresets[merchantId];
  if (!preset) return;
  pickupForm.sender_name = preset.sender_name;
  pickupForm.pickup_phone = preset.pickup_phone;
  pickupForm.pickup_address = preset.pickup_address;
};

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

const goToReadyForPickupPage = () => {
  void router.push({
    name: DROPSHIP_ORDER_DETAIL_V2_READY_FOR_PICKUP_ROUTE,
    params: {
      id: route.params.id,
      tenantSlug: route.params.tenantSlug,
    },
  });
};
</script>

<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <DropshipOrderDetailUiToggle />

      <q-banner dense rounded class="bg-orange-1 text-orange-10 dropship-order-detail-v2__dummy-banner">
        <template #avatar>
          <q-icon name="ph ph-package" color="orange-9" />
        </template>
        <span class="text-caption">
          Processing desk — edit charges, pickup location, and courier before packing.
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

      <div v-if="order" class="dropship-order-detail-v2__status-actions">
        <q-btn
          color="primary"
          unelevated
          no-caps
          icon="ph ph-check-circle"
          label="Ready for pickup"
          class="text-weight-bold"
          style="border-radius: 8px; min-width: 220px"
          @click="goToReadyForPickupPage"
        />
      </div>

      <DropshipOrderConfirmedInvoicePaper
        v-if="order"
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

      <q-card v-else flat bordered class="form-card">
        <q-card-section class="column items-center justify-center q-pa-xl text-center">
          <q-icon name="ph ph-wrench" size="48px" color="grey-5" class="q-mb-md" />
          <div class="text-subtitle1 text-weight-bold text-grey-8 q-mb-xs">
            Processing view
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
  border: 1px solid rgba(249, 115, 22, 0.25);
}

.dropship-order-detail-v2__status-actions {
  max-width: 920px;
  margin: 0 auto;
  width: 100%;
  display: flex;
  justify-content: flex-end;
}
</style>

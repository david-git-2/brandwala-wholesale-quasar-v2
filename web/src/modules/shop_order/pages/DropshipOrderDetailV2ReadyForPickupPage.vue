<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import DropshipOrderConfirmedInvoicePaper from '../components/DropshipOrderConfirmedInvoicePaper.vue';
import {
  createEmptyDropshipInvoiceSummary,
  type DropshipInvoiceSummaryState,
} from '../utils/dropshipInvoiceSummary';
import type {
  DropshipInvoiceCourierState,
  DropshipInvoiceDeliveredQuantitiesState,
  DropshipInvoicePickupState,
} from '../utils/dropshipInvoiceFulfillment';
import { createDeliveredQuantitiesFromItems } from '../utils/dropshipInvoiceFulfillment';
import { DROPSHIP_ORDER_DETAIL_CUSTOMER_INVOICE_PREVIEW_ROUTE } from '../composables/dropshipOrderDetailRoutes';
import DropshipOrderCancelDialog from '../components/DropshipOrderCancelDialog.vue';
import { useDropshipOrderDetailV2Query } from '../composables/useDropshipOrderDetailV2Query';
import { useDropshipCourierOptions } from '../composables/useDropshipCourierOptions';
import { useDropshipOrderStatusRedirect } from '../composables/useDropshipOrderStatusRedirect';
import { saveDropshipV2CustomerInvoiceSnapshot } from '../utils/dropshipV2CustomerInvoiceStorage';
import { pickupLocationRepository } from '../repositories/pickupLocationRepository';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderService } from '../services/shopOrderService';
import {
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
  requestConfirmation,
} from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const queryClient = useQueryClient();
const advancingStatus = ref(false);
const cancelDialogOpen = ref(false);

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);
const orderId = computed(() => Number(route.params.id || 0));
const tenantId = computed(() => authStore.tenantId ?? 0);

const orderDetailQuery = useDropshipOrderDetailV2Query({ tenantSlug, orderId });

const locationsQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.pickupLocations(tenantSlug.value)),
  enabled: computed(() => tenantId.value > 0),
  staleTime: 60_000,
  queryFn: () => pickupLocationRepository.listLocations(),
});

const order = computed(() => orderDetailQuery.data.value?.order ?? null);

const { couriers, courierOptions } = useDropshipCourierOptions({
  tenantSlug,
  orderTenantId: computed(() => order.value?.tenant_id),
});

const canMarkShipped = computed(
  () => orderDetailQuery.data.value?.permissions.can_mark_shipped ?? false,
);
const canCancelOrder = computed(
  () => orderDetailQuery.data.value?.permissions.can_cancel_order ?? false,
);

const orderItems = computed(() => orderDetailQuery.data.value?.items ?? []);

const summaryForm = ref<DropshipInvoiceSummaryState>(createEmptyDropshipInvoiceSummary());

const deliveredQuantitiesForm = ref<DropshipInvoiceDeliveredQuantitiesState>({});

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

watch(
  () => orderDetailQuery.data.value,
  (detail) => {
    if (!detail) return;
    summaryForm.value = { ...detail.summary };
    Object.assign(pickupForm, detail.fulfillment.pickup);
    Object.assign(courierForm, detail.fulfillment.courier);
    deliveredQuantitiesForm.value = createDeliveredQuantitiesFromItems(detail.items);
  },
  { immediate: true },
);

const isLoading = computed(() => orderDetailQuery.isLoading.value);
const loadError = computed(() => orderDetailQuery.error.value);

useDropshipOrderStatusRedirect({
  expectedView: 'ready',
  status: computed(() => order.value?.status ?? null),
  orderId,
  tenantSlug,
  enabled: computed(() => !isLoading.value && !!order.value),
});

const pickupLocationOptions = computed(() =>
  (locationsQuery.data.value ?? [])
    .filter((location) => location.is_active)
    .map((location) => ({
      label: `${location.location_name}${location.store_name ? ` (${location.store_name})` : ''} — ${location.phone_primary}`,
      value: location.id,
    })),
);

const selectedCourier = computed(() =>
  couriers.value.find((courier) => courier.id === courierForm.courier_service_id),
);

const deliveryZoneLabel = computed(
  () =>
    orderDetailQuery.data.value?.computed.delivery_zone_label ??
    (order.value?.shipping_district?.trim().toLowerCase() === 'dhaka' ? 'Inside Dhaka' : 'Outside Dhaka'),
);

const displayStatus = computed(() => order.value?.status ?? 'ready_for_pickup');

const openCustomerInvoicePreview = () => {
  if (!order.value) return;

  saveDropshipV2CustomerInvoiceSnapshot(order.value.id, {
    summary: summaryForm.value,
    deliveredQuantities: deliveredQuantitiesForm.value,
  });

  const routeData = router.resolve({
    name: DROPSHIP_ORDER_DETAIL_CUSTOMER_INVOICE_PREVIEW_ROUTE,
    params: {
      id: order.value.id,
      tenantSlug: route.params.tenantSlug,
    },
  });
  window.open(routeData.href, '_blank');
};

const advanceToShipped = async () => {
  if (!order.value || !canMarkShipped.value) return;

  const confirmed = await requestConfirmation(
    'Mark this order as shipped and issue the merchant bill? The order stays locked after this step.',
    'Mark as shipped',
    'Mark as shipped',
  );
  if (!confirmed) return;

  if (tenantId.value <= 0) {
    showErrorNotification('Tenant context is missing. Reload the page and try again.');
    return;
  }

  advancingStatus.value = true;
  try {
    const shipRes = await shopOrderService.shipDropshipOrderAndIssueMerchantBill(
      tenantId.value,
      order.value.id,
    );
    if (!shipRes.success) {
      throw new Error(shipRes.error ?? 'Failed to ship order and issue merchant bill.');
    }

    const billIssued = (shipRes.data as { created?: boolean })?.created === true;
    showSuccessNotification(
      billIssued ? 'Shipped and merchant bill issued.' : 'Shipped. Merchant bill was already on file.',
    );
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.dropshipDetailV2(authStore.tenantId ?? 0, orderId.value),
    });
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.orderDetail(authStore.tenantId ?? null, orderId.value),
    });
    await orderDetailQuery.refetch();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to update status'));
  } finally {
    advancingStatus.value = false;
  }
};

const onOrderCancelled = () => {
  void router.push({ name: 'app-shop-dropship-orders-page' });
};
</script>

<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <q-banner dense rounded class="bg-blue-1 text-blue-10 dropship-order-detail-v2__info-banner no-print">
        <template #avatar>
          <q-icon name="ph ph-check-circle" color="blue-8" />
        </template>
        <span class="text-caption">
          {{
            displayStatus === 'reseller_paid' || displayStatus === 'payment_received'
              ? 'Settlement complete — invoice paid and merchant profit credited from courier remittance.'
              : displayStatus === 'delivered'
                  ? 'Delivered — reconcile settlement on the dropship management desk.'
                  : displayStatus === 'shipped'
                    ? 'Shipped — order is locked. Print the packing slip for the recipient.'
                    : 'Ready for pickup — order is locked. Print the packing slip for the recipient.'
          }}
        </span>
      </q-banner>

      <section v-if="isLoading" class="dropship-order-detail-v2__loading">
        <q-skeleton type="rect" height="520px" class="dropship-order-detail-v2__paper-skeleton" />
      </section>

      <section v-else-if="loadError" class="text-caption text-negative">
        {{ loadError instanceof Error ? loadError.message : 'Failed to load order.' }}
      </section>

      <template v-else-if="order">
        <div class="dropship-order-detail-v2__ready-actions no-print">
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
            label="Print packing slip"
            class="text-weight-bold"
            style="border-radius: 8px; min-width: 220px"
            @click="openCustomerInvoicePreview"
          />
        </div>

        <DropshipOrderConfirmedInvoicePaper
          :order="order"
          :order-items="orderItems"
          readonly
          show-delivered-quantities
          show-fulfillment-blocks
          v-model:summary="summaryForm"
          v-model:pickup="pickupForm"
          v-model:courier="courierForm"
          v-model:delivered-quantities="deliveredQuantitiesForm"
          :pickup-location-options="pickupLocationOptions"
          :courier-options="courierOptions"
          :delivery-zone-label="deliveryZoneLabel"
        />
      </template>
    </div>

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
  border: 1px solid rgba(59, 130, 246, 0.25);
  max-width: 1100px;
  margin: 0 auto;
  width: 100%;
}

.dropship-order-detail-v2__paper-skeleton {
  max-width: 1100px;
  margin: 0 auto;
  border-radius: 12px;
}

.dropship-order-detail-v2__ready-actions {
  max-width: 1100px;
  margin: 0 auto;
  width: 100%;
  display: flex;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 0.5rem;
}
</style>

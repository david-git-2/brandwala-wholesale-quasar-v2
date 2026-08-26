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
import { useDropshipOrderDetailV2Query } from '../composables/useDropshipOrderDetailV2Query';
import { useDropshipOrderStatusRedirect } from '../composables/useDropshipOrderStatusRedirect';
import { saveDropshipV2CustomerInvoiceSnapshot } from '../utils/dropshipV2CustomerInvoiceStorage';
import { dropshipMerchantRepository } from '../repositories/dropshipMerchantRepository';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import {
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
} from 'src/utils/appFeedback';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const queryClient = useQueryClient();
const advancingStatus = ref(false);

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);
const orderId = computed(() => Number(route.params.id || 0));
const tenantId = computed(() => authStore.tenantId ?? 0);

const orderDetailQuery = useDropshipOrderDetailV2Query({ tenantSlug, orderId });

const merchantsQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.merchants(tenantSlug.value)),
  enabled: computed(() => tenantId.value > 0),
  staleTime: 60_000,
  queryFn: () => dropshipMerchantRepository.listMerchants(),
});

const couriers = ref<CourierServiceRow[]>([]);

const order = computed(() => orderDetailQuery.data.value?.order ?? null);

const canMarkShipped = computed(
  () => orderDetailQuery.data.value?.permissions.can_mark_shipped ?? false,
);

const orderItems = computed(() => orderDetailQuery.data.value?.items ?? []);

const summaryForm = ref<DropshipInvoiceSummaryState>(createEmptyDropshipInvoiceSummary());

const deliveredQuantitiesForm = ref<DropshipInvoiceDeliveredQuantitiesState>({});

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
    deliveredQuantitiesForm.value = createDeliveredQuantitiesFromItems(detail.items);
    couriers.value = detail.lookups.courier_services;
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

const merchantOptions = computed(() =>
  (merchantsQuery.data.value ?? [])
    .filter((merchant) => merchant.is_active)
    .map((merchant) => ({
      label: `${merchant.merchant_name}${merchant.store_name ? ` (${merchant.store_name})` : ''} — ${merchant.phone_primary}`,
      value: merchant.id,
    })),
);

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

  advancingStatus.value = true;
  try {
    const { data, error } = await supabase.rpc('advance_dropship_order_status', {
      p_order_id: order.value.id,
      p_target_status: 'shipped',
    });
    if (error) throw error;
    if (data && typeof data === 'object' && (data as { success?: boolean }).success === false) {
      throw new Error((data as { error?: string }).error || 'Failed to update status');
    }

    showSuccessNotification('Status updated to shipped');
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.dropshipDetailV2(authStore.tenantId ?? 0, orderId.value),
    });
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
      <q-banner dense rounded class="bg-blue-1 text-blue-10 dropship-order-detail-v2__info-banner no-print">
        <template #avatar>
          <q-icon name="ph ph-check-circle" color="blue-8" />
        </template>
        <span class="text-caption">
          {{
            displayStatus === 'shipped'
              ? 'Shipped — order is locked. Print the customer resell invoice for the recipient.'
              : 'Ready for pickup — order is locked. Print the customer resell invoice for the recipient.'
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
      </template>
    </div>
  </q-page>
</template>

<style scoped>
.dropship-order-detail-v2 {
  background: #eef1f4;
}

.dropship-order-detail-v2__info-banner {
  border: 1px solid rgba(59, 130, 246, 0.25);
}

.dropship-order-detail-v2__paper-skeleton {
  max-width: 920px;
  margin: 0 auto;
  border-radius: 2px;
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

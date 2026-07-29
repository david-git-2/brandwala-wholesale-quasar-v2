<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Loading Skeleton -->
      <StaffOrderDetailSkeleton v-if="isLoading" />

      <!-- Error State -->
      <div v-else-if="isError" class="column items-center justify-center q-pa-xl text-center">
        <q-icon name="ph ph-warning-circle" size="48px" color="negative" class="q-mb-sm" />
        <div class="text-h6 text-grey-8">{{ error?.message || 'Failed to load order details.' }}</div>
        <q-btn flat color="primary" label="Go Back to Orders" class="q-mt-md" @click="goBack" />
      </div>

      <template v-else-if="currentOrder">
        <!-- Header & Dropship Banner -->
        <StaffOrderHeader
          :order="currentOrder"
          :can-fulfill="canFulfill"
          :is-processing-dropship="isProcessingDropship"
          @go-back="goBack"
          @add-to-dropship="addToDropshipDesk"
        />

        <!-- Workflow Statuses Strip -->
        <StaffOrderStatusWorkflow
          :order="currentOrder"
          :workflow-statuses="workflowStatuses"
          :changing-status="isUpdatingStatus"
          :target-updating-status="targetUpdatingStatus"
          @change-status="changeOrderStatus"
        />

        <!-- Main Columns -->
        <div class="row q-col-gutter-lg">
          <!-- Items & Actions Panel (8 cols) -->
          <div class="col-xs-12 col-md-8">
            <StaffOrderItemsList
              :order="currentOrder"
              :order-items="orderItems"
              :currency-symbol="currencySymbol"
              :can-action="canAction"
              :can-fulfill="canFulfill"
              :is-deleting-order="isDeletingOrder"
              :is-submitting-pricing="isSubmittingPricing"
              :is-confirming-order="isConfirmingOrder"
              :is-placing-procurement="isPlacingProcurement"
              :is-fulfilling-to-invoice="isFulfillingToInvoice"
              @delete-order="confirmDeleteOrder"
              @submit-pricing="handleSubmitStaffPricing"
              @confirm-order="handleConfirmOrder"
              @place-procurement="handlePlaceForProcurement"
              @fulfill-invoice="handleFulfillToInvoice"
            />
          </div>

          <!-- Sidebar (4 cols) -->
          <div class="col-xs-12 col-md-4">
            <div class="column q-gutter-md">
              <StaffOrderSummaryCard
                :order="currentOrder"
                :order-items="orderItems"
                :currency-symbol="currencySymbol"
                :is-updating-charges="isUpdatingCharges"
                @update-charges="handleUpdateCharges"
              />
              <StaffOrderShippingCard
                :order="currentOrder"
              />
            </div>
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useQuasar } from 'quasar';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { useShopOrderDetailQuery } from '../composables/useShopOrderDetailQuery';
import {
  useUpdateOrderStatusMutation,
  useSubmitStaffPricingMutation,
  useConfirmShopOrderMutation,
  usePlaceOrderForProcurementMutation,
  useFulfillOrderToInvoiceMutation,
  useUpdateOrderChargesMutation,
  useDeleteShopOrderMutation,
  useProcessDropshipOrderMutation,
} from '../composables/useShopOrderMutations';
import { shopOrderRepository } from '../repositories/shopOrderRepository';

import StaffOrderHeader from '../components/StaffOrderHeader.vue';
import StaffOrderStatusWorkflow from '../components/StaffOrderStatusWorkflow.vue';
import StaffOrderItemsList from '../components/StaffOrderItemsList.vue';
import StaffOrderSummaryCard from '../components/StaffOrderSummaryCard.vue';
import StaffOrderShippingCard from '../components/StaffOrderShippingCard.vue';
import StaffOrderDetailSkeleton from '../components/StaffOrderDetailSkeleton.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const $q = useQuasar();

const orderId = computed(() => Number(route.params.id || 0));
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '',
);

const { data: orderDetailsData, isLoading, isError, error } = useShopOrderDetailQuery(orderId);
const currentOrder = computed(() => orderDetailsData.value?.order || null);

const { mutate: updateOrderStatus, isPending: isUpdatingStatus } = useUpdateOrderStatusMutation();
const { mutate: submitStaffPricing, isPending: isSubmittingPricing } = useSubmitStaffPricingMutation();
const { mutate: confirmShopOrder, isPending: isConfirmingOrder } = useConfirmShopOrderMutation();
const { mutate: placeOrderForProcurement, isPending: isPlacingProcurement } = usePlaceOrderForProcurementMutation();
const { mutate: fulfillOrderToInvoice, isPending: isFulfillingToInvoice } = useFulfillOrderToInvoiceMutation();
const { mutate: updateOrderCharges, isPending: isUpdatingCharges } = useUpdateOrderChargesMutation();
const { mutate: deleteShopOrder, isPending: isDeletingOrder } = useDeleteShopOrderMutation();
const { mutate: processDropshipOrder, isPending: isProcessingDropship } = useProcessDropshipOrderMutation();

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value || []);

const targetUpdatingStatus = ref<string | null>(null);
const orderItems = ref<any[]>([]);
const shopSellCurrencyId = ref<number | null>(null);

watch(
  () => orderDetailsData.value,
  async (newData) => {
    if (newData) {
      if (newData.order?.shop_type_snapshot === 'dropship') {
        void router.replace({
          name: 'app-shop-dropship-order-detail-page',
          params: { tenantSlug: tenantSlug.value, id: orderId.value },
        });
        return;
      }
      orderItems.value = JSON.parse(JSON.stringify(newData.items || []));
      const shopId = newData.order?.shop_id;
      if (shopId) {
        shopSellCurrencyId.value = await shopOrderRepository.getShopSellCurrencyId(shopId);
      }
    }
  },
  { immediate: true },
);

const workflowStatuses = computed(() => {
  if (currentOrder.value?.shop_type_snapshot === 'dropship') {
    return [
      'submitted',
      'confirmed',
      'processing',
      'ready_for_pickup',
      'shipped',
      'delivered',
      'returned',
      'payment_received',
    ];
  }
  return [
    'draft',
    'submitted',
    'negotiating',
    'priced',
    'confirmed',
    'placed',
    'fulfilled',
  ];
});

const currencySymbol = computed(() => {
  if (shopSellCurrencyId.value) {
    const curr = currencies.value.find((c) => c.id === shopSellCurrencyId.value);
    if (curr?.symbol) return curr.symbol;
  }
  const firstItem = orderItems.value?.[0];
  const currId =
    firstItem?.unit_sell_price_currency_id ||
    firstItem?.customer_offer_currency_id ||
    firstItem?.unit_list_price_currency_id;
  if (currId) {
    const curr = currencies.value.find((c) => c.id === currId);
    if (curr?.symbol) return curr.symbol;
  }
  return '৳';
});

const canAction = computed(() => {
  const o = currentOrder.value;
  return !!(o && (o.status === 'submitted' || o.status === 'negotiating' || o.status === 'priced'));
});

const canFulfill = computed(() => {
  const o = currentOrder.value;
  return !!(o && o.status === 'confirmed');
});

const changeOrderStatus = (newStatus: string) => {
  if (!orderId.value || !currentOrder.value) return;
  if (currentOrder.value.status === newStatus) return;

  targetUpdatingStatus.value = newStatus;
  updateOrderStatus(
    { orderId: orderId.value, status: newStatus },
    {
      onSettled: () => {
        targetUpdatingStatus.value = null;
      },
    },
  );
};

const handlePlaceForProcurement = () => {
  if (orderId.value) {
    placeOrderForProcurement(orderId.value);
  }
};

const handleFulfillToInvoice = () => {
  if (orderId.value) {
    fulfillOrderToInvoice(orderId.value);
  }
};

const addToDropshipDesk = () => {
  if (orderId.value) {
    processDropshipOrder(orderId.value, {
      onSuccess: (res) => {
        if (res.success) {
          void router.push({
            name: 'app-shop-dropship-order-detail-page',
            params: {
              tenantSlug: route.params.tenantSlug,
              id: orderId.value,
            },
          });
        }
      },
    });
  }
};

const confirmDeleteOrder = () => {
  $q.dialog({
    title: t('shop_admin.delete_order'),
    message:
      'Are you sure you want to delete this order? This action is permanent and cannot be undone.',
    persistent: true,
    ok: {
      label: t('shop_admin.delete'),
      color: 'negative',
      flat: true,
    },
    cancel: {
      label: t('shop_admin.cancel'),
      flat: true,
    },
  }).onOk(() => {
    if (orderId.value) {
      deleteShopOrder(orderId.value, {
        onSuccess: () => {
          void router.push({
            name: 'app-shop-orders-page',
            params: { tenantSlug: route.params.tenantSlug },
          });
        },
      });
    }
  });
};

const handleSubmitStaffPricing = () => {
  if (!orderId.value || !currentOrder.value) return;
  const payload = orderItems.value.map((item) => ({
    id: item.id,
    staff_offer_amount: Number(item.staff_offer_amount || 0),
    staff_offer_currency_id:
      item.staff_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      item.unit_list_price_currency_id,
  }));

  const isInitialSubmission = currentOrder.value.status === 'submitted';
  submitStaffPricing({
    orderId: orderId.value,
    items: payload,
    isInitialSubmission,
  });
};

const handleConfirmOrder = () => {
  if (orderId.value) {
    confirmShopOrder(orderId.value);
  }
};

const handleUpdateCharges = ({ payload, closeDialog }: { payload: any; closeDialog: () => void }) => {
  if (!orderId.value) return;
  updateOrderCharges(
    { orderId: orderId.value, payload },
    {
      onSuccess: () => {
        closeDialog();
      },
    },
  );
};

const goBack = () => {
  const slug = route.params.tenantSlug;
  const tenantSlug = typeof slug === 'string' && slug ? `/${slug}` : '';
  void router.push(`${tenantSlug}/app/shop/orders`);
};
</script>

<script lang="ts">
export default {
  name: 'StaffOrderDetailPage',
};
</script>

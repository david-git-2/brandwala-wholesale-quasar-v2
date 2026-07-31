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
          :visible-columns="catalogVisibleColumns"
          @go-back="goBack"
          @add-to-dropship="addToDropshipDesk"
          @update:visible-columns="onCatalogVisibleColumnsUpdate"
        />

        <!-- VENDOR CATALOG S1 SPECIFIC LAYOUT -->
        <template v-if="isCatalogShop">
          <!-- Catalog Workflow Statuses Strip -->
          <CatalogOrderWorkflowBar
            :order="currentOrder"
            v-model:rates-expanded="ratesExpanded"
            :is-loading="isLoading"
            :updating-status="isUpdatingStatus"
            :target-updating-status="targetUpdatingStatus"
            @change-status="changeOrderStatus"
          />

          <!-- Rates Panel -->
          <CatalogOrderRatesBar
            v-if="ratesExpanded"
            :order="currentOrder"
            :saving="isSavingRates"
            @save-rates="handleSaveRates"
            @change-rates="handleChangeRates"
          />

          <!-- Main Catalog Content -->
          <CatalogOrderItemsTable
            :order="currentOrder"
            :items="orderItems"
            :currency-symbol="currencySymbol"
            :buy-currency-symbol="buyCurrencySymbol"
            :visible-columns="catalogVisibleColumns"
            @open-column-selector="openColumnSelector"
            @update:visible-columns="onCatalogVisibleColumnsUpdate"
            @update-item="handleUpdateCatalogOrderItem"
          />


          <!-- Catalog Status-Gated Sticky Action Bar -->
          <q-card flat bordered class="q-pa-md bg-grey-1">
            <div class="row items-center justify-between q-col-gutter-sm">
              <div class="text-caption text-grey-7">
                Status: <strong>{{ currentOrder.status }}</strong>
              </div>

              <div class="row items-center q-gutter-sm">
                <q-btn
                  v-if="currentOrder.status === 'submitted'"
                  color="warning"
                  unelevated
                  no-caps
                  label="Start Costing (Pending)"
                  :loading="isUpdatingStatus && targetUpdatingStatus === 'costing_pending'"
                  @click="changeOrderStatus('costing_pending')"
                />

                <q-btn
                  v-if="['submitted', 'costing_pending'].includes(currentOrder.status)"
                  color="primary"
                  unelevated
                  no-caps
                  icon="ph ph-check"
                  label="Save Costing & Price Order → Priced"
                  :loading="isSavingStaffPricing"
                  @click="handleSaveStaffCatalogPricing"
                />

                <q-btn
                  v-if="['priced', 'countered'].includes(currentOrder.status)"
                  color="purple"
                  unelevated
                  no-caps
                  icon="ph ph-paper-plane-tilt"
                  label="Save Final Prices → Final Offered"
                  :loading="isFinalizingPrices"
                  @click="handleSaveFinalCatalogPrices"
                />

                <q-btn
                  v-if="currentOrder.status === 'final_offered'"
                  outline
                  color="purple"
                  no-caps
                  label="Awaiting Customer Confirmation"
                  disable
                />

                <q-btn
                  v-if="currentOrder.status === 'confirmed'"
                  color="primary"
                  unelevated
                  no-caps
                  icon="ph ph-shopping-bag"
                  label="Start Procuring"
                  :loading="isStartingProcurement"
                  @click="handleStartCatalogProcurement"
                />

                <q-btn
                  v-if="['confirmed', 'procuring'].includes(currentOrder.status)"
                  color="indigo-9"
                  unelevated
                  no-caps
                  icon="ph ph-package"
                  label="Save Ordered Qty → Ordered"
                  :loading="isSavingOrderedQty"
                  @click="handleSaveStaffOrderedQty"
                />

                <q-btn
                  v-if="['procuring', 'ordered'].includes(currentOrder.status)"
                  color="positive"
                  unelevated
                  no-caps
                  icon="ph ph-truck"
                  label="Save Delivered Qty → Delivered"
                  :loading="isSavingDeliveredQty"
                  @click="handleSaveStaffDeliveredQty"
                />

                <q-btn
                  v-if="currentOrder.billing_profile_id"
                  flat
                  color="primary"
                  no-caps
                  icon="ph ph-tray"
                  label="View Backlog"
                  @click="showBacklogDrawer = true"
                />
              </div>
            </div>
          </q-card>
        </template>

        <!-- OTHER SHOP TYPES (Dropship/Fixed) -->
        <template v-else>
          <StaffOrderStatusWorkflow
            :order="currentOrder"
            :workflow-statuses="workflowStatuses"
            :changing-status="isUpdatingStatus"
            :target-updating-status="targetUpdatingStatus"
            @change-status="changeOrderStatus"
          />

          <div class="row q-col-gutter-lg">
            <div class="col-xs-12 col-md-8" style="min-width: 0">
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

            <div class="col-xs-12 col-md-4">
              <div class="column q-gutter-md">
                <StaffOrderSummaryCard
                  :order="currentOrder"
                  :order-items="orderItems"
                  :currency-symbol="currencySymbol"
                  :is-updating-charges="isUpdatingCharges"
                  @update-charges="handleUpdateCharges"
                />
                <StaffOrderShippingCard :order="currentOrder" />
              </div>
            </div>
          </div>
        </template>
      </template>
    </div>

    <!-- Catalog Customer Backlog Drawer -->
    <CatalogBacklogDrawer
      v-if="currentOrder && currentOrder.billing_profile_id"
      v-model="showBacklogDrawer"
      :tenant-id="currentOrder.tenant_id"
      :billing-profile-id="currentOrder.billing_profile_id"
    />
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
import {
  useSaveCatalogRatesMutation,
  useStaffPriceCatalogOrderMutation,
  useStaffFinalizeCatalogPricesMutation,
  useStaffStartCatalogProcurementMutation,
  useStaffSetCatalogOrderedQtyMutation,
  useStaffSetCatalogDeliveredQtyMutation,
  useUpdateCatalogOrderItemMutation,
} from '../composables/useCatalogOrderMutations';
import { shopOrderRepository } from '../repositories/shopOrderRepository';

import StaffOrderHeader from '../components/StaffOrderHeader.vue';
import StaffOrderStatusWorkflow from '../components/StaffOrderStatusWorkflow.vue';
import StaffOrderItemsList from '../components/StaffOrderItemsList.vue';
import StaffOrderSummaryCard from '../components/StaffOrderSummaryCard.vue';
import StaffOrderShippingCard from '../components/StaffOrderShippingCard.vue';
import StaffOrderDetailSkeleton from '../components/StaffOrderDetailSkeleton.vue';

import CatalogOrderWorkflowBar from '../components/CatalogOrderWorkflowBar.vue';
import CatalogOrderRatesBar from '../components/CatalogOrderRatesBar.vue';
import CatalogOrderItemsTable from '../components/CatalogOrderItemsTable.vue';
import CatalogBacklogDrawer from '../components/CatalogBacklogDrawer.vue';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';

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

const isCatalogShop = computed(
  () => currentOrder.value?.shop_type_snapshot === 'vendor_catalog',
);

const { mutate: updateOrderStatus, isPending: isUpdatingStatus } = useUpdateOrderStatusMutation();
const { mutate: submitStaffPricing, isPending: isSubmittingPricing } = useSubmitStaffPricingMutation();
const { mutate: confirmShopOrder, isPending: isConfirmingOrder } = useConfirmShopOrderMutation();
const { mutate: placeOrderForProcurement, isPending: isPlacingProcurement } = usePlaceOrderForProcurementMutation();
const { mutate: fulfillOrderToInvoice, isPending: isFulfillingToInvoice } = useFulfillOrderToInvoiceMutation();
const { mutate: updateOrderCharges, isPending: isUpdatingCharges } = useUpdateOrderChargesMutation();
const { mutate: deleteShopOrder, isPending: isDeletingOrder } = useDeleteShopOrderMutation();
const { mutate: processDropshipOrder, isPending: isProcessingDropship } = useProcessDropshipOrderMutation();

// Catalog Specific Mutations
const { mutate: saveCatalogRates, isPending: isSavingRates } = useSaveCatalogRatesMutation();
const { mutate: staffPriceCatalogOrder, isPending: isSavingStaffPricing } = useStaffPriceCatalogOrderMutation();
const { mutate: staffFinalizeCatalogPrices, isPending: isFinalizingPrices } = useStaffFinalizeCatalogPricesMutation();
const { mutate: staffStartCatalogProcurement, isPending: isStartingProcurement } = useStaffStartCatalogProcurementMutation();
const { mutate: staffSetCatalogOrderedQty, isPending: isSavingOrderedQty } = useStaffSetCatalogOrderedQtyMutation();
const { mutate: staffSetCatalogDeliveredQty, isPending: isSavingDeliveredQty } = useStaffSetCatalogDeliveredQtyMutation();
const { mutate: updateCatalogOrderItem } = useUpdateCatalogOrderItemMutation();

const handleUpdateCatalogOrderItem = ({
  itemId,
  productId,
  payload,
}: {
  itemId: number;
  productId: number | null;
  payload: any;
}) => {
  if (!orderId.value) return;
  updateCatalogOrderItem({
    orderId: orderId.value,
    itemId,
    productId,
    payload,
  });
};

const showBacklogDrawer = ref(false);

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value || []);

const targetUpdatingStatus = ref<string | null>(null);
const orderItems = ref<any[]>([]);
const shopSellCurrencyId = ref<number | null>(null);
const shopBuyCurrencyId = ref<number | null>(null);

const ratesExpanded = ref(false);

const catalogAllColumnNames = [
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'code_barcode_id',
  'qty_customer',
  'ordered_qty',
  'delivered_qty',
  'purchase_price_unit',
  'purchase_price_total',
  'product_weight_gm',
  'package_weight_gm',
  'total_weight_gm',
  'cargo_rate',
  'cargo_cost_unit_purchase',
  'landed_cost_unit_purchase',
  'landed_cost_row_purchase',
  'landed_cost_unit_sell',
  'landed_cost_row_sell',
  'first_offer_unit',
  'first_offer_row',
  'first_offer_margin',
  'counter_offer_unit',
  'counter_offer_row',
  'counter_offer_margin',
  'final_offer_unit',
  'final_offer_row',
  'final_offer_margin',
  'status',
  'action',
];

const catalogAlwaysVisibleColumns = ['sl', 'image', 'name', 'status', 'action'];

const catalogDefaultVisibleColumns = [
  'sl',
  'image',
  'name',
  'brand',
  'qty_customer',
  'ordered_qty',
  'delivered_qty',
  'code_barcode_id',
  'purchase_price_unit',
  'purchase_price_total',
  'total_weight_gm',
  'cargo_cost_unit_purchase',
  'landed_cost_unit_purchase',
  'landed_cost_unit_sell',
  'landed_cost_row_sell',
  'first_offer_unit',
  'first_offer_row',
  'first_offer_margin',
  'counter_offer_unit',
  'counter_offer_row',
  'counter_offer_margin',
  'final_offer_unit',
  'final_offer_row',
  'final_offer_margin',
  'status',
  'action',
];

const { visibleColumns: rawCatalogVisibleColumns } = useMembershipColumnPreference({
  preferenceKey: 'ui.shopOrder.staffCatalogVisibleColumns',
  allColumnNames: catalogAllColumnNames,
  alwaysVisibleColumns: catalogAlwaysVisibleColumns,
  defaultVisibleColumns: catalogDefaultVisibleColumns,
});

const submittedModeColumns = [
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'code_barcode_id',
  'qty_customer',
  'purchase_price_unit',
  'product_weight_gm',
  'package_weight_gm',
  'status',
  'action',
];

const catalogVisibleColumns = computed<string[]>({
  get: () => {
    if (currentOrder.value?.status === 'submitted') {
      return submittedModeColumns;
    }
    if (['priced', 'costing_pending'].includes(currentOrder.value?.status || '')) {
      const hiddenInPriced = [
        'ordered_qty',
        'delivered_qty',
        'counter_offer_unit',
        'counter_offer_row',
        'counter_offer_margin',
        'final_offer_unit',
        'final_offer_row',
        'final_offer_margin',
      ];
      return rawCatalogVisibleColumns.value.filter((col) => !hiddenInPriced.includes(col));
    }
    return rawCatalogVisibleColumns.value;
  },
  set: (val: string[]) => {
    rawCatalogVisibleColumns.value = val;
  },
});

const onCatalogVisibleColumnsUpdate = (columns: string[]) => {
  catalogVisibleColumns.value = columns;
};

watch(
  () => orderDetailsData.value,
  (newData) => {
    if (newData) {
      if (newData.order?.shop_type_snapshot === 'dropship') {
        void router.replace({
          name: 'app-shop-dropship-order-detail-page',
          params: { tenantSlug: tenantSlug.value, id: orderId.value },
        });
        return;
      }
      const fetchedItems = newData.items || [];
      const currentItemsMap = new Map(orderItems.value.map((i) => [i.id, i]));

      orderItems.value = fetchedItems.map((item: any) => {
        const local = currentItemsMap.get(item.id);
        if (local && local.is_first_offer_manual) {
          return {
            ...item,
            staff_offer_amount: local.staff_offer_amount,
            is_first_offer_manual: true,
          };
        }
        return { ...item };
      });

      shopSellCurrencyId.value = newData.order?.shop_sell_currency_id ?? null;
      shopBuyCurrencyId.value = newData.order?.shop_buy_currency_id ?? null;
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

const buyCurrencySymbol = computed(() => {
  if (shopBuyCurrencyId.value) {
    const curr = currencies.value.find((c) => c.id === shopBuyCurrencyId.value);
    if (curr?.symbol) return curr.symbol;
  }
  const firstItem = orderItems.value?.[0];
  const currId = firstItem?.cost_price_currency_id || firstItem?.unit_list_price_currency_id;
  if (currId) {
    const curr = currencies.value.find((c) => c.id === currId);
    if (curr?.symbol) return curr.symbol;
  }
  return '£';
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

const recalculateFirstOffers = (rates: {
  conversion_rate: number | null;
  cargo_rate: number | null;
  profit_rate: number | null;
  first_offer_rate?: number | null;
  final_offer_rate?: number | null;
  profit_basis: 'purchase' | 'total_cost';
}) => {
  const fx = rates.conversion_rate ?? currentOrder.value?.conversion_rate ?? 140;
  const cargoRate = rates.cargo_rate ?? currentOrder.value?.cargo_rate ?? 0;
  const profitRate = rates.first_offer_rate ?? rates.profit_rate ?? currentOrder.value?.first_offer_rate ?? currentOrder.value?.profit_rate ?? 25;
  const profitBasis = rates.profit_basis ?? currentOrder.value?.profit_basis ?? 'total_cost';

  orderItems.value.forEach((item) => {
    if (item.is_first_offer_manual) {
      return;
    }
    const purchasePrice = Number(item.cost_price_amount || 0);
    const prodGm = Number(item.product_weight_gm || 0);
    const pkgGm = Number(item.package_weight_gm || 0);
    const weightKg = (prodGm + pkgGm) > 0 ? (prodGm + pkgGm) / 1000 : Number(item.weight_kg || 0);
    const cargoCostBuy = weightKg * cargoRate;
    const landedCostBuy = purchasePrice + cargoCostBuy;

    if (profitBasis === 'purchase') {
      const purchaseSell = purchasePrice * fx;
      const markup = (profitRate || 0) / 100;
      item.staff_offer_amount = Math.ceil(purchaseSell * (1 + markup) + cargoCostBuy * fx);
    } else {
      const landedCostSell = landedCostBuy * fx;
      const markup = (profitRate || 0) / 100;
      item.staff_offer_amount = Math.ceil(landedCostSell * (1 + markup));
    }
  });
};

const handleChangeRates = (payload: {
  conversion_rate: number | null;
  cargo_rate: number | null;
  profit_rate: number | null;
  first_offer_rate: number | null;
  final_offer_rate: number | null;
  profit_basis: 'purchase' | 'total_cost';
}) => {
  recalculateFirstOffers(payload);
};

const handleSaveRates = (payload: {
  conversion_rate: number | null;
  cargo_rate: number | null;
  profit_rate: number | null;
  first_offer_rate: number | null;
  final_offer_rate: number | null;
  profit_basis: 'purchase' | 'total_cost';
}) => {
  if (!orderId.value) return;
  recalculateFirstOffers(payload);
  saveCatalogRates({ orderId: orderId.value, payload });
};

const handleSaveStaffCatalogPricing = () => {
  if (!orderId.value || !currentOrder.value) return;

  const itemsPayload = orderItems.value.map((item) => ({
    id: item.id,
    staff_offer_amount: Number(item.staff_offer_amount || 0),
    staff_offer_currency_id:
      item.staff_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      item.unit_list_price_currency_id ||
      1,
    weight_kg: Number(item.weight_kg || 0),
    cost_price_amount: Number(item.cost_price_amount || 0),
    product_weight_gm: Number(item.product_weight_gm || 0),
    package_weight_gm: Number(item.package_weight_gm || 0),
  }));

  staffPriceCatalogOrder({
    orderId: orderId.value,
    items: itemsPayload,
    profitBasis: currentOrder.value.profit_basis || 'total_cost',
  });
};

const handleSaveFinalCatalogPrices = () => {
  if (!orderId.value || !currentOrder.value) return;

  const itemsPayload = orderItems.value.map((item) => ({
    id: item.id,
    final_offer_amount: Number(item.final_price_amount || item.staff_offer_amount || 0),
    final_offer_currency_id:
      item.final_price_currency_id ||
      item.staff_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      1,
  }));

  staffFinalizeCatalogPrices({
    orderId: orderId.value,
    items: itemsPayload,
  });
};

const handleStartCatalogProcurement = () => {
  if (orderId.value) {
    staffStartCatalogProcurement(orderId.value);
  }
};

const handleSaveStaffOrderedQty = () => {
  if (!orderId.value) return;
  const itemsPayload = orderItems.value.map((item) => ({
    id: item.id,
    ordered_quantity: Number(item.ordered_quantity ?? item.confirmed_quantity ?? item.quantity ?? 0),
  }));
  staffSetCatalogOrderedQty({ orderId: orderId.value, items: itemsPayload });
};

const handleSaveStaffDeliveredQty = () => {
  if (!orderId.value) return;
  const itemsPayload = orderItems.value.map((item) => ({
    id: item.id,
    delivered_quantity: Number(item.delivered_quantity ?? item.ordered_quantity ?? item.confirmed_quantity ?? item.quantity ?? 0),
  }));
  staffSetCatalogDeliveredQty({ orderId: orderId.value, items: itemsPayload });
};

const openColumnSelector = () => {
  // Column selector handled via top header 3-dot menu
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

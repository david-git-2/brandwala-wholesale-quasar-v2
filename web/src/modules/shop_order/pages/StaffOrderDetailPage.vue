<template>
  <q-page
    :class="isCatalogShop && currentOrder
      ? 'staff-order-detail-page staff-order-detail-page--catalog column no-wrap'
      : 'q-pa-md staff-order-detail-page'"
    :style="isCatalogShop && currentOrder ? 'height: calc(100vh - 55px); overflow: hidden' : undefined"
  >
    <!-- Loading Skeleton -->
    <StaffOrderDetailSkeleton v-if="isLoading" :variant="skeletonVariant" />

    <!-- Error State -->
    <div v-else-if="isError" class="column items-center justify-center q-pa-xl text-center">
      <q-icon name="ph ph-warning-circle" size="48px" color="negative" class="q-mb-sm" />
      <div class="text-h6 text-grey-8">{{ error?.message || 'Failed to load order details.' }}</div>
      <q-btn flat color="primary" label="Go Back to Orders" class="q-mt-md" @click="goBack" />
    </div>

    <template v-else-if="currentOrder">
      <!-- VENDOR CATALOG S1 — PBC V2 layout -->
      <template v-if="isCatalogShop">
        <div class="staff-order-catalog-top shrink-0 bg-white border-bottom shadow-xs q-px-md q-py-xs">
          <CatalogOrderWorkflowBar
            :order="currentOrder"
            :is-loading="isLoading"
            :visible-columns="catalogVisibleColumns"
            @update:visible-columns="onCatalogVisibleColumnsUpdate"
            @open-settings="showCatalogSettingsDialog = true"
          />
          <CatalogOrderRatesBar
            variant="compact"
            :order="currentOrder"
            :saving="isSavingRates"
            @save-rates="handleSaveRates"
            @change-rates="handleChangeRates"
          />
        </div>

        <CatalogOrderItemsTable
          ref="catalogItemsTableRef"
          class="col overflow-hidden"
          :order="currentOrder"
          :items="orderItems"
          :currency-symbol="currencySymbol"
          :buy-currency-symbol="buyCurrencySymbol"
          :visible-columns="catalogVisibleColumns"
          @update:visible-columns="onCatalogVisibleColumnsUpdate"
          @update-item="handleUpdateCatalogOrderItem"
          @table-scroll="updateCatalogScrollbar"
        />

        <div class="staff-order-catalog-footer shrink-0 bg-white border-top shadow-xs">
          <CatalogOrderStaffActions
            variant="footer"
            :status="currentOrder.status"
            :is-primary-loading="isCatalogPrimaryLoading"
            :primary-disabled="catalogPrimaryDisabled"
            :primary-disabled-reason="catalogPrimaryDisabledReason"
            @primary-action="handleCatalogPrimaryAction"
          >
            <div class="excel-scrollbar-wrapper row items-center no-wrap">
              <button type="button" class="excel-scroll-arrow-btn" @click="scrollCatalogTableByStep(-150)">
                <q-icon name="ph ph-caret-left" size="13px" />
              </button>
              <div
                ref="catalogScrollTrackRef"
                class="excel-scroll-track cursor-pointer"
                @click="onCatalogScrollTrackClick"
              >
                <div
                  class="excel-scroll-thumb"
                  :style="{ width: catalogScrollThumbWidth + '%', left: catalogScrollThumbLeft + '%' }"
                  @mousedown="startCatalogScrollThumbDrag"
                />
              </div>
              <button type="button" class="excel-scroll-arrow-btn" @click="scrollCatalogTableByStep(150)">
                <q-icon name="ph ph-caret-right" size="13px" />
              </button>
            </div>
          </CatalogOrderStaffActions>
        </div>
      </template>

      <!-- OTHER SHOP TYPES (Dropship/Fixed) -->
      <div v-else class="q-gutter-y-md">
        <StaffOrderHeader
          :order="currentOrder"
          :can-fulfill="canFulfill"
          :is-processing-dropship="isProcessingDropship"
          @add-to-dropship="addToDropshipDesk"
        />

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
      </div>
    </template>

    <!-- Catalog Customer Backlog Drawer -->
    <CatalogBacklogDrawer
      v-if="currentOrder && currentOrder.billing_profile_id"
      v-model="showBacklogDrawer"
      :tenant-id="currentOrder.tenant_id"
      :billing-profile-id="currentOrder.billing_profile_id"
    />

    <CatalogOrderSettingsDialog
      v-if="currentOrder"
      v-model="showCatalogSettingsDialog"
      :item-count="catalogSummarySnapshot.itemCount"
      :buy-currency-symbol="catalogSummarySnapshot.buyCurrencySymbol"
      :sell-currency-symbol="catalogSummarySnapshot.sellCurrencySymbol"
      :conversion-rate="catalogSummarySnapshot.conversionRate"
      :cargo-rate="catalogSummarySnapshot.cargoRate"
      :totals="catalogSummarySnapshot.totals"
      :show-cancel="currentOrder.status !== 'delivered' && currentOrder.status !== 'cancelled'"
      :is-deleting="isDeletingOrder"
      @override-status="onCatalogSettingsOverrideStatus"
      @cancel-order="onCatalogSettingsCancelOrder"
    />

    <CatalogOrderStatusOverrideDialog
      v-if="currentOrder"
      v-model="showStatusOverrideDialog"
      :order="currentOrder"
      :loading="isUpdatingStatus"
      @apply="handleStatusOverride"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted, unref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
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
  useUpdateCatalogOrderItemMutation,
  useStaffPriceCatalogOrderMutation,
  useStaffFinalizeCatalogPricesMutation,
  useStaffStartCatalogProcurementMutation,
  useStaffSetCatalogOrderedQtyMutation,
  useStaffSetCatalogDeliveredQtyMutation,
} from '../composables/useCatalogOrderMutations';
import {
  calculateItemFirstOfferPrice,
  calculateItemFinalOfferPrice,
  getFirstOfferUnitAmount,
  getFinalOfferUnitAmount,
} from '../utils/catalogPricingUtils';
import {
  isCatalogFirstOfferLocked,
  getStaffCatalogPrimaryAction,
  normalizeCatalogOrderStatus,
  type StaffCatalogPrimaryAction,
} from '../utils/catalogOrderStatus';
import { requestConfirmation } from 'src/utils/appFeedback';

import StaffOrderHeader from '../components/StaffOrderHeader.vue';
import StaffOrderStatusWorkflow from '../components/StaffOrderStatusWorkflow.vue';
import StaffOrderItemsList from '../components/StaffOrderItemsList.vue';
import StaffOrderSummaryCard from '../components/StaffOrderSummaryCard.vue';
import StaffOrderShippingCard from '../components/StaffOrderShippingCard.vue';
import StaffOrderDetailSkeleton from '../components/StaffOrderDetailSkeleton.vue';

import CatalogOrderWorkflowBar from '../components/CatalogOrderWorkflowBar.vue';
import CatalogOrderRatesBar from '../components/CatalogOrderRatesBar.vue';
import CatalogOrderItemsTable from '../components/CatalogOrderItemsTable.vue';
import CatalogOrderStaffActions from '../components/CatalogOrderStaffActions.vue';
import CatalogOrderStatusOverrideDialog from '../components/CatalogOrderStatusOverrideDialog.vue';
import CatalogOrderSettingsDialog from '../components/CatalogOrderSettingsDialog.vue';
import CatalogBacklogDrawer from '../components/CatalogBacklogDrawer.vue';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { t } = useI18n();
const $q = useQuasar();

const orderId = computed(() => Number(route.params.id || 0));
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '',
);

const skeletonVariant = computed<'catalog' | 'dropship'>(() => {
  const state = history.state as { shopTypeSnapshot?: string } | null;
  return state?.shopTypeSnapshot === 'vendor_catalog' ? 'catalog' : 'dropship';
});

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
const { mutate: updateCatalogOrderItem } = useUpdateCatalogOrderItemMutation();
const { mutate: staffPriceCatalog, isPending: isStaffPricingCatalog } = useStaffPriceCatalogOrderMutation();
const { mutate: staffFinalizeCatalog, isPending: isStaffFinalizingCatalog } =
  useStaffFinalizeCatalogPricesMutation();
const { mutate: staffStartProcurement, isPending: isStaffStartingProcurement } =
  useStaffStartCatalogProcurementMutation();
const { mutate: staffSetOrderedQty, isPending: isStaffMarkingOrdered } =
  useStaffSetCatalogOrderedQtyMutation();
const { mutate: staffSetDeliveredQty, isPending: isStaffMarkingDelivered } =
  useStaffSetCatalogDeliveredQtyMutation();

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

  let nextPayload = payload;
  if (isCatalogFirstOfferLocked(currentOrder.value?.status)) {
    const {
      cost_price_amount: _cost,
      staff_offer_amount: _staff,
      is_first_offer_manual: _manual,
      ...rest
    } = payload ?? {};
    nextPayload = rest;
    if (!Object.keys(nextPayload).length) return;
  }

  updateCatalogOrderItem({
    tenantId: authStore.tenantId,
    orderId: orderId.value,
    itemId,
    productId,
    payload: nextPayload,
  });
};

const showBacklogDrawer = ref(false);
const showStatusOverrideDialog = ref(false);
const showCatalogSettingsDialog = ref(false);

const targetUpdatingStatus = ref<string | null>(null);
const orderItems = ref<any[]>([]);

const catalogAllColumnNames = [
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'code_barcode_id',
  'qty_customer',
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
];

const catalogAlwaysVisibleColumns = ['sl', 'image', 'name', 'status'];

const catalogDefaultVisibleColumns = [
  'sl',
  'image',
  'name',
  'brand',
  'qty_customer',
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
];

const { visibleColumns: rawCatalogVisibleColumns } = useMembershipColumnPreference({
  preferenceKey: 'ui.shopOrder.staffCatalogVisibleColumns',
  allColumnNames: catalogAllColumnNames,
  alwaysVisibleColumns: catalogAlwaysVisibleColumns,
  defaultVisibleColumns: catalogDefaultVisibleColumns,
});

const processingModeColumns = [
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'code_barcode_id',
  'qty_customer',
  'purchase_price_unit',
  'purchase_price_total',
  'product_weight_gm',
  'package_weight_gm',
  'total_weight_gm',
  'cargo_cost_unit_purchase',
  'landed_cost_unit_purchase',
  'landed_cost_row_purchase',
  'landed_cost_unit_sell',
  'landed_cost_row_sell',
  'first_offer_unit',
  'first_offer_row',
  'first_offer_margin',
  'status',
];

const counteredModeColumns = [
  'sl',
  'image',
  'name',
  'purchase_price_unit',
  'landed_cost_unit_sell',
  'first_offer_unit',
  'counter_offer_unit',
  'counter_offer_margin',
  'final_offer_unit',
  'final_offer_margin',
  'status',
];

const confirmedModeColumns = [
  'sl',
  'image',
  'name',
  'brand',
  'code_barcode_id',
  'qty_customer',
  'status',
];

const procuringModeColumns = [...confirmedModeColumns];

const readyForShipmentModeColumns = [...confirmedModeColumns];

const catalogOrderStatus = computed(() =>
  normalizeCatalogOrderStatus(currentOrder.value?.status),
);

const catalogVisibleColumns = computed<string[]>({
  get: () => {
    if (catalogOrderStatus.value === 'submitted') {
      return processingModeColumns;
    }
    if (catalogOrderStatus.value === 'countered') {
      return counteredModeColumns;
    }
    if (catalogOrderStatus.value === 'confirmed') {
      return confirmedModeColumns;
    }
    if (catalogOrderStatus.value === 'procuring') {
      return procuringModeColumns;
    }
    if (catalogOrderStatus.value === 'ready_for_shipment') {
      return readyForShipmentModeColumns;
    }
    if (catalogOrderStatus.value === 'priced') {
      const hiddenInPriced = [
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

const catalogRatesParams = computed(() => ({
  conversion_rate: currentOrder.value?.conversion_rate,
  cargo_rate: currentOrder.value?.cargo_rate,
  first_offer_rate: currentOrder.value?.first_offer_rate ?? currentOrder.value?.profit_rate,
  final_offer_rate: currentOrder.value?.final_offer_rate,
  profit_rate: currentOrder.value?.profit_rate,
  profit_basis: currentOrder.value?.profit_basis,
}));

const isCatalogPrimaryLoading = computed(
  () =>
    isStaffPricingCatalog.value ||
    isStaffFinalizingCatalog.value ||
    isStaffStartingProcurement.value ||
    isStaffMarkingOrdered.value ||
    isStaffMarkingDelivered.value,
);

const catalogPrimaryDisabled = computed(() => {
  const action = getStaffCatalogPrimaryAction(currentOrder.value?.status);
  if (!action || !orderItems.value.length) return true;
  if (action === 'send_first_offer') {
    return !orderItems.value.every(
      (item) =>
        getFirstOfferUnitAmount(
          item,
          catalogRatesParams.value,
          currentOrder.value?.package_weight_kg,
        ) > 0,
    );
  }
  if (action === 'send_final_offer') {
    return !orderItems.value.every(
      (item) =>
        getFinalOfferUnitAmount(
          item,
          catalogRatesParams.value,
          currentOrder.value?.package_weight_kg,
        ) > 0,
    );
  }
  return false;
});

const catalogPrimaryDisabledReason = computed(() => {
  const action = getStaffCatalogPrimaryAction(currentOrder.value?.status);
  if (action === 'send_first_offer' && catalogPrimaryDisabled.value) {
    return 'Complete costing and first-offer prices for all lines';
  }
  if (action === 'send_final_offer' && catalogPrimaryDisabled.value) {
    return 'Set final offer prices for all lines';
  }
  return '';
});

function buildStaffOfferPayload() {
  return orderItems.value.map((item) => ({
    id: item.id,
    staff_offer_amount: getFirstOfferUnitAmount(
      item,
      catalogRatesParams.value,
      currentOrder.value?.package_weight_kg,
    ),
    staff_offer_currency_id:
      item.staff_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      item.unit_list_price_currency_id,
    is_first_offer_manual: item.is_first_offer_manual,
    weight_kg: item.weight_kg,
    product_weight_gm: item.product_weight_gm,
    package_weight_gm: item.package_weight_gm,
  }));
}

function buildFinalOfferPayload() {
  return orderItems.value.map((item) => ({
    id: item.id,
    final_offer_amount: getFinalOfferUnitAmount(
      item,
      catalogRatesParams.value,
      currentOrder.value?.package_weight_kg,
    ),
    final_offer_currency_id:
      item.staff_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      item.unit_list_price_currency_id,
  }));
}

function buildProcuredQtyPayload() {
  return orderItems.value.map((item) => ({
    id: item.id,
    ordered_quantity: Number(item.confirmed_quantity ?? item.quantity ?? 0),
  }));
}

const handleStatusOverride = ({
  status,
  reason,
}: {
  status: string;
  reason: string;
}) => {
  if (!orderId.value) return;
  updateOrderStatus(
    { orderId: orderId.value, status },
    {
      onSuccess: () => {
        showStatusOverrideDialog.value = false;
        $q.notify({
          type: 'info',
          message: `Status overridden to ${status}. ${reason}`,
        });
      },
    },
  );
};

const handleCatalogPrimaryAction = async (action: StaffCatalogPrimaryAction) => {
  if (!orderId.value) return;

  if (action === 'send_first_offer') {
    const ok = await requestConfirmation(
      'Send the first offer to the customer? They will be able to accept or counter each line.',
      'Send first offer',
      'Send offer',
    );
    if (!ok) return;
    staffPriceCatalog({
      orderId: orderId.value,
      items: buildStaffOfferPayload(),
      profitBasis: currentOrder.value?.profit_basis,
    });
    return;
  }

  if (action === 'send_final_offer') {
    const ok = await requestConfirmation(
      'Send the final offer to the customer?',
      'Send final offer',
      'Send final offer',
    );
    if (!ok) return;
    staffFinalizeCatalog({
      orderId: orderId.value,
      items: buildFinalOfferPayload(),
    });
    return;
  }

  if (action === 'start_procurement') {
    staffStartProcurement(orderId.value);
    return;
  }

  if (action === 'mark_ready_for_shipment') {
    staffSetOrderedQty({
      orderId: orderId.value,
      items: buildProcuredQtyPayload(),
    });
    return;
  }

  if (action === 'mark_delivered') {
    staffSetDeliveredQty({ orderId: orderId.value });
  }
};

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
        const res = { ...item };
        if (local && local.is_first_offer_manual) {
          res.staff_offer_amount = local.staff_offer_amount;
          res.is_first_offer_manual = true;
        }
        if (local && local.is_final_offer_manual) {
          res.final_price_amount = local.final_price_amount;
          res.is_final_offer_manual = true;
        }
        return res;
      });

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

const currencySymbol = computed(
  () => currentOrder.value?.shop_sell_currency_symbol || '৳',
);

const buyCurrencySymbol = computed(
  () => currentOrder.value?.shop_buy_currency_symbol || '£',
);

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

const recalculateOffers = (rates: {
  conversion_rate: number | null;
  cargo_rate: number | null;
  profit_rate: number | null;
  first_offer_rate?: number | null;
  final_offer_rate?: number | null;
  profit_basis: 'purchase' | 'total_cost';
}) => {
  const firstOfferLocked = isCatalogFirstOfferLocked(currentOrder.value?.status);
  orderItems.value.forEach((item) => {
    if (!firstOfferLocked && !item.is_first_offer_manual) {
      item.staff_offer_amount = calculateItemFirstOfferPrice(
        item,
        {
          conversion_rate: rates.conversion_rate ?? currentOrder.value?.conversion_rate,
          cargo_rate: rates.cargo_rate ?? currentOrder.value?.cargo_rate,
          first_offer_rate: rates.first_offer_rate ?? rates.profit_rate ?? currentOrder.value?.first_offer_rate ?? currentOrder.value?.profit_rate,
          profit_basis: rates.profit_basis ?? currentOrder.value?.profit_basis,
        },
        currentOrder.value?.package_weight_kg,
      );
    }
    if (!item.is_final_offer_manual) {
      if (rates.final_offer_rate != null && rates.final_offer_rate > 0) {
        item.final_price_amount = calculateItemFinalOfferPrice(
          item,
          {
            conversion_rate: rates.conversion_rate ?? currentOrder.value?.conversion_rate,
            cargo_rate: rates.cargo_rate ?? currentOrder.value?.cargo_rate,
            final_offer_rate: rates.final_offer_rate,
            first_offer_rate: rates.first_offer_rate ?? rates.profit_rate ?? currentOrder.value?.first_offer_rate ?? currentOrder.value?.profit_rate,
            profit_basis: rates.profit_basis ?? currentOrder.value?.profit_basis,
          },
          currentOrder.value?.package_weight_kg,
        );
      } else {
        item.final_price_amount = item.staff_offer_amount;
      }
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
  recalculateOffers(payload);
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
  recalculateOffers(payload);
  saveCatalogRates({ orderId: orderId.value, payload });
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

const catalogItemsTableRef = ref<InstanceType<typeof CatalogOrderItemsTable> | null>(null);

const EMPTY_CATALOG_TOTALS = {
  totalQuantity: 0,
  totalWeightGm: 0,
  grandTotalPurchasePrice: 0,
  grandTotalLandedPurchase: 0,
  grandTotalLandedSell: 0,
  grandTotalFirstOffer: 0,
  overallFirstOfferMargin: 0,
  grandTotalCounterOffer: 0,
  overallCounterOfferMargin: 0,
  grandTotalFinalOffer: 0,
  overallFinalOfferMargin: 0,
};

const catalogSummarySnapshot = computed(() => {
  const table = catalogItemsTableRef.value as {
    itemCount?: number | { value: number };
    buyCurrency?: string | { value: string };
    sellCurrency?: string | { value: string };
    FX?: number | { value: number };
    cargoRate?: number | { value: number };
    summaryTotals?: typeof EMPTY_CATALOG_TOTALS | { value: typeof EMPTY_CATALOG_TOTALS };
  } | null;

  return {
    itemCount: Number(unref(table?.itemCount) ?? 0),
    buyCurrencySymbol: String(unref(table?.buyCurrency) ?? buyCurrencySymbol.value),
    sellCurrencySymbol: String(unref(table?.sellCurrency) ?? currencySymbol.value),
    conversionRate: Number(unref(table?.FX) ?? 0),
    cargoRate: Number(unref(table?.cargoRate) ?? 0),
    totals: unref(table?.summaryTotals) ?? EMPTY_CATALOG_TOTALS,
  };
});

function onCatalogSettingsOverrideStatus() {
  showCatalogSettingsDialog.value = false;
  showStatusOverrideDialog.value = true;
}

function onCatalogSettingsCancelOrder() {
  showCatalogSettingsDialog.value = false;
  confirmDeleteOrder();
}
const catalogScrollTrackRef = ref<HTMLElement | null>(null);
const catalogScrollThumbWidth = ref(30);
const catalogScrollThumbLeft = ref(0);

const getCatalogTableScrollEl = (): HTMLElement | null =>
  catalogItemsTableRef.value?.tableScrollContainerRef ?? null;

const updateCatalogScrollbar = () => {
  const el = getCatalogTableScrollEl();
  if (!el) return;
  const maxScrollLeft = el.scrollWidth - el.clientWidth;
  if (maxScrollLeft <= 0) {
    catalogScrollThumbWidth.value = 100;
    catalogScrollThumbLeft.value = 0;
    return;
  }
  const ratio = el.clientWidth / el.scrollWidth;
  const thumbWidthPct = Math.max(15, Math.min(80, ratio * 100));
  catalogScrollThumbWidth.value = thumbWidthPct;
  const scrollFraction = el.scrollLeft / maxScrollLeft;
  catalogScrollThumbLeft.value = scrollFraction * (100 - thumbWidthPct);
};

const scrollCatalogTableByStep = (delta: number) => {
  getCatalogTableScrollEl()?.scrollBy({ left: delta, behavior: 'smooth' });
};

const onCatalogScrollTrackClick = (e: MouseEvent) => {
  const table = getCatalogTableScrollEl();
  const track = catalogScrollTrackRef.value;
  if (!table || !track) return;
  const rect = track.getBoundingClientRect();
  const fraction = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
  const maxScrollLeft = table.scrollWidth - table.clientWidth;
  table.scrollTo({ left: fraction * maxScrollLeft, behavior: 'smooth' });
};

const startCatalogScrollThumbDrag = (e: MouseEvent) => {
  e.preventDefault();
  e.stopPropagation();
  const table = getCatalogTableScrollEl();
  const track = catalogScrollTrackRef.value;
  if (!table || !track) return;

  const startX = e.clientX;
  const startScrollLeft = table.scrollLeft;
  const trackRect = track.getBoundingClientRect();
  const availableTrackWidth = trackRect.width * (1 - catalogScrollThumbWidth.value / 100);
  const maxScrollLeft = table.scrollWidth - table.clientWidth;

  const onMouseMove = (moveEvent: MouseEvent) => {
    if (availableTrackWidth <= 0) return;
    const deltaScroll = ((moveEvent.clientX - startX) / availableTrackWidth) * maxScrollLeft;
    table.scrollLeft = Math.max(0, Math.min(maxScrollLeft, startScrollLeft + deltaScroll));
    updateCatalogScrollbar();
  };

  const onMouseUp = () => {
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mouseup', onMouseUp);
  };

  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
};

watch(
  () => [orderItems.value.length, catalogVisibleColumns.value],
  () => {
    requestAnimationFrame(updateCatalogScrollbar);
  },
);

onMounted(() => {
  window.addEventListener('resize', updateCatalogScrollbar);
  requestAnimationFrame(updateCatalogScrollbar);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateCatalogScrollbar);
});
</script>

<script lang="ts">
export default {
  name: 'StaffOrderDetailPage',
};
</script>

<style scoped>
.staff-order-detail-page {
  padding-bottom: 88px;
}

.staff-order-detail-page--catalog {
  padding-bottom: 0;
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.excel-scrollbar-wrapper {
  width: min(420px, 100%);
  gap: 4px;
}

.excel-scroll-track {
  position: relative;
  flex: 1;
  height: 10px;
  background: #e2e8f0;
  border-radius: 999px;
  overflow: hidden;
}

.excel-scroll-thumb {
  position: absolute;
  top: 0;
  height: 100%;
  background: #64748b;
  border-radius: 999px;
  cursor: grab;
}

.excel-scroll-arrow-btn {
  border: none;
  background: transparent;
  color: #64748b;
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 4px;
}

.excel-scroll-arrow-btn:hover {
  background: #f1f5f9;
  color: #334155;
}
</style>

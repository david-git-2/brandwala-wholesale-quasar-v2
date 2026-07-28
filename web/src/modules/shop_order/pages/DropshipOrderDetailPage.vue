<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Loading Skeleton -->
      <DropshipOrderDetailSkeleton v-if="loading" />

      <template v-else>
        <!-- Confirmed Handoff Warning Banner -->
        <q-banner v-if="order?.status === 'confirmed'" class="bg-amber-2 text-amber-10 rounded-borders q-mb-md border-all-1">
          <template #avatar>
            <q-icon name="ph ph-warning" color="amber-9" size="32px" />
          </template>
          <div class="text-subtitle2 text-weight-bold">
            {{ $t('shop_admin.dropship_handoff_required_banner') }}
          </div>
          <div>
            Use <strong>Add to Dropship Desk</strong> in the header to hand off this order from the Service Desk and start courier operations.
          </div>
        </q-banner>

        <!-- Header -->
        <DropshipOrderHeader
          :order="order"
          :primary-cta="primaryCta"
          @open-recipient-invoice="openRecipientInvoicePreview"
        />

        <!-- Status Workflow Strip -->
        <DropshipOrderStatusWorkflow
          :order="order"
          :updating-status="updatingStatus"
          :target-updating-status="targetUpdatingStatus"
          @update-status="onUpdateStatus"
        />

        <div class="row q-col-gutter-lg">
          <!-- Main Form Sections -->
          <div class="col-xs-12 col-md-8">
            <div class="q-gutter-y-md">
              <!-- Block A: Recipient Information -->
              <DropshipRecipientFormCard
                :form="form"
                :district-options="districtOptions"
                :thana-options="thanaOptions"
                :postcode-options="postcodeOptions"
                @copy="handleCopy"
                @phone-blur="onRecipientPhoneBlur"
                @filter-district="filterDistrict"
                @filter-thana="filterThana"
                @filter-postcode="filterPostcode"
                @create-postcode="createPostcode"
                @district-change="onDistrictChange"
                @thana-change="onThanaChange"
                @update:form-field="(k, v) => (form as any)[k] = v"
              />

              <!-- Ordered Items -->
              <DropshipOrderItemsCard
                :order-items="orderItems"
                :format-bdt="formatBdt"
              />

              <!-- Block B: Parcel & COD -->
              <DropshipParcelFormCard
                :form="form"
                :selected-courier="selectedCourier"
                @delivery-charge-edit="onDeliveryChargeManualEdit"
                @calculate-cod="calculateCodCharge"
                @recalculate-collect="recalculateCollectAmount"
                @update:form-field="(k, v) => (form as any)[k] = v"
              />

              <!-- Block C: Merchant Sender Pickup -->
              <DropshipMerchantFormCard
                v-model:selected-merchant-id="selectedMerchantId"
                v-model:block-c-expanded="blockCExpanded"
                :form="form"
                :merchant-options="merchantOptions"
                @merchant-select="onMerchantSelect"
                @update:form-field="(k, v) => (form as any)[k] = v"
              />

              <!-- Block D: Driver Notes & Policy Flags -->
              <DropshipDeliveryNotesCard
                :form="form"
                @update:form-field="(k, v) => (form as any)[k] = v"
              />
            </div>
          </div>

          <!-- Right Side: Courier Tracking & Totals -->
          <div class="col-xs-12 col-md-4">
            <div class="q-gutter-y-md">
              <!-- Block E: Courier Assignment -->
              <DropshipCourierCard
                :form="form"
                :courier-options="courierOptions"
                :selected-courier="selectedCourier"
                :delivery-zone-label="deliveryZoneLabel"
                :suggested-delivery-fee="suggestedDeliveryFee"
                :cod-rate-label="codRateLabel"
                :format-bdt="formatBdt"
                @courier-change="onCourierChange"
                @update:form-field="(k, v) => (form as any)[k] = v"
              />

              <!-- Totals & Settlement Breakdown -->
              <DropshipTotalsCard
                :order="order"
                :form="form"
                :recipient-subtotal="recipientSubtotal"
                :delivery-charge-val="deliveryChargeVal"
                :cod-charge-val="codChargeVal"
                :print-charge-val="printChargeVal"
                :packing-charge-val="packingChargeVal"
                :discount-val="discountVal"
                :recipient-grand-total="recipientGrandTotal"
                :middleman-total-cost="middlemanTotalCost"
                :estimated-profit="estimatedProfit"
                :show-settlement-card="showSettlementCard"
                :tenant-slug="tenantSlug"
                :format-bdt="formatBdt"
                @toggle-deduct="onToggleDeduct"
                @update:form-field="(k, v) => (form as any)[k] = v"
              />
            </div>
          </div>
        </div>

        <!-- Dialogs -->
        <DropshipOrderDialogs
          v-model:remittance-dialog-open="remittanceDialogOpen"
          v-model:dual-invoice-dialog-open="dualInvoiceDialogOpen"
          v-model:confirm-b2b-invoice-dialog-open="confirmB2bInvoiceDialogOpen"
          v-model:confirm-delete-invoice-dialog-open="confirmDeleteInvoiceDialogOpen"
          :order="order"
          :remittance-form="remittanceForm"
          :saving-remittance="savingRemittance"
          :can-save-order-remittance="canSaveOrderRemittance"
          :creating-invoice="creatingInvoice"
          :updating-status="updatingStatus"
          :recipient-grand-total="recipientGrandTotal"
          :delivery-charge-val="deliveryChargeVal"
          :cod-charge-val="codChargeVal"
          :accounting-subtotal="accountingSubtotal"
          :print-charge-val="printChargeVal"
          :packing-charge-val="packingChargeVal"
          :estimated-profit="estimatedProfit"
          :cod-collect-amount="form.cod_collect_amount"
          :format-bdt="formatBdt"
          @save-remittance="saveOrderRemittance"
          @confirm-dual-invoice="confirmDualInvoice"
          @execute-status-update="executeStatusUpdate"
          @update:remittance-field="(k, v) => (remittanceForm as any)[k] = v"
        />

        <!-- Floating Unsaved Changes Footer Bar -->
        <div v-if="isFormDirty && !loading" style="height: 100px;"></div>

        <q-slide-transition>
          <div v-if="isFormDirty && !loading" class="fixed-bottom row justify-center q-pb-lg z-top">
            <q-card flat class="bg-grey-10 text-white shadow-24 row items-center justify-between q-py-md q-px-lg" style="width: 90%; max-width: 800px; border-radius: 12px; border-left: 5px solid var(--q-warning); box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4), 0 0 16px rgba(242, 193, 46, 0.25);">
              <div class="row items-center q-gutter-x-md">
                <q-icon name="ph ph-warning" color="warning" size="32px" class="animate-flash" />
                <div>
                  <div class="text-subtitle1 text-weight-bold text-white row items-center">
                    Unsaved Changes in Consignment
                  </div>
                  <div class="text-caption text-grey-4">You have modified details on this page. Click Save to persist updates.</div>
                </div>
              </div>
              <div class="row q-gutter-sm items-center">
                <q-btn
                  flat
                  color="white"
                  label="Discard"
                  no-caps
                  @click="discardChanges"
                />
                <q-btn
                  color="warning"
                  text-color="dark"
                  unelevated
                  label="Save Changes"
                  no-caps
                  icon="ph ph-floppy-disk"
                  :loading="saving"
                  class="text-weight-bold"
                  @click="saveChanges"
                />
              </div>
            </q-card>
          </div>
        </q-slide-transition>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useRoute } from 'vue-router';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { dropshipCourierService } from '../services/dropshipCourierService';
import { dropshipMerchantService } from '../services/dropshipMerchantService';
import { shopOrderQueryKeys } from '../services/shopOrderQueryKeys';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import type { MerchantProfileRow } from '../repositories/dropshipMerchantRepository';
import type { ShopOrder, ShopOrderItem } from '../types';
import { showErrorNotification } from 'src/utils/appFeedback';

import DropshipOrderDetailSkeleton from '../components/DropshipOrderDetailSkeleton.vue';
import DropshipOrderHeader from '../components/DropshipOrderHeader.vue';
import DropshipOrderStatusWorkflow from '../components/DropshipOrderStatusWorkflow.vue';
import DropshipRecipientFormCard from '../components/DropshipRecipientFormCard.vue';
import DropshipOrderItemsCard from '../components/DropshipOrderItemsCard.vue';
import DropshipParcelFormCard from '../components/DropshipParcelFormCard.vue';
import DropshipMerchantFormCard from '../components/DropshipMerchantFormCard.vue';
import DropshipDeliveryNotesCard from '../components/DropshipDeliveryNotesCard.vue';
import DropshipCourierCard from '../components/DropshipCourierCard.vue';
import DropshipTotalsCard from '../components/DropshipTotalsCard.vue';
import DropshipOrderDialogs from '../components/DropshipOrderDialogs.vue';

import { useBDAddressOptions } from '../composables/useBDAddressOptions';
import { useDropshipOrderForm } from '../composables/useDropshipOrderForm';
import { useDropshipOrderActions } from '../composables/useDropshipOrderActions';

const route = useRoute();
const queryClient = useQueryClient();
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);
const orderId = computed(() => Number(route.params.id || 0));

const order = ref<ShopOrder | null>(null);
const orderItems = ref<ShopOrderItem[]>([]);
const couriers = ref<CourierServiceRow[]>([]);
const merchants = ref<MerchantProfileRow[]>([]);

const {
  districtOptions,
  thanaOptions,
  postcodeOptions,
  loadInitialDistricts,
  updateThanaList,
  updatePostcodeList,
  filterDistrict,
  filterThana,
  filterPostcode,
  createPostcode,
} = useBDAddressOptions();

const {
  form,
  hydratingForm,
  selectedMerchantId,
  blockCExpanded,
  isFormDirty,
  deliveryZoneLabel,
  selectedCourier,
  suggestedDeliveryFee,
  codRateLabel,
  formatBdt,
  recipientSubtotal,
  accountingSubtotal,
  deliveryChargeVal,
  codChargeVal,
  printChargeVal,
  packingChargeVal,
  discountVal,
  recipientGrandTotal,
  middlemanTotalCost,
  estimatedProfit,
  courierOptions,
  merchantOptions,
  discardChanges,
  recalculateCollectAmount,
  calculateCodCharge,
  onToggleDeduct,
  applySuggestedCharges,
  onDeliveryChargeManualEdit,
  onMerchantSelect,
  handleCopy,
  onRecipientPhoneBlur,
  hydrateFormFromOrder,
} = useDropshipOrderForm(
  order,
  orderItems,
  couriers,
  merchants,
  updateThanaList,
  updatePostcodeList,
);

const orderDetailQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.detail(tenantSlug.value, orderId.value)),
  enabled: computed(() => orderId.value > 0),
  staleTime: 15_000,
  queryFn: async () => {
    return await shopOrderRepository.getShopOrderById(orderId.value);
  },
});

const couriersQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.couriers(tenantSlug.value)),
  staleTime: 10 * 60_000,
  queryFn: async () => {
    const res = await dropshipCourierService.fetchCouriers();
    if (!res.success) {
      throw new Error(res.error || 'Failed to load courier services');
    }
    return res.data;
  },
});

const merchantsQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.merchants(tenantSlug.value)),
  staleTime: 10 * 60_000,
  queryFn: async () => {
    const res = await dropshipMerchantService.fetchMerchants();
    if (!res.success) {
      throw new Error(res.error || 'Failed to load merchant profiles');
    }
    return res.data;
  },
});

const loading = computed(() =>
  orderDetailQuery.isLoading.value ||
  couriersQuery.isLoading.value ||
  merchantsQuery.isLoading.value ||
  hydratingForm.value,
);

const refetchOrderDetail = async () => {
  if (orderId.value <= 0) return;
  await queryClient.invalidateQueries({
    queryKey: shopOrderQueryKeys.detail(tenantSlug.value, orderId.value),
  });
  await orderDetailQuery.refetch();
};

const {
  saving,
  updatingStatus,
  targetUpdatingStatus,
  primaryCta,
  showSettlementCard,
  canSaveOrderRemittance,
  remittanceDialogOpen,
  savingRemittance,
  remittanceForm,
  dualInvoiceDialogOpen,
  creatingInvoice,
  confirmB2bInvoiceDialogOpen,
  confirmDeleteInvoiceDialogOpen,
  saveChanges,
  onUpdateStatus,
  executeStatusUpdate,
  saveOrderRemittance,
  openRecipientInvoicePreview,
  confirmDualInvoice,
} = useDropshipOrderActions(
  tenantSlug,
  order,
  form,
  selectedCourier,
  refetchOrderDetail,
);

const onDistrictChange = async (newDistName: string) => {
  form.thana = '';
  form.post_code = '';
  await updateThanaList(newDistName);
  applySuggestedCharges();
};

const onThanaChange = async (newThanaName: string) => {
  form.post_code = '';
  await updatePostcodeList(form.district, newThanaName);
};

const onCourierChange = () => {
  applySuggestedCharges();
};

watch(
  () => couriersQuery.data.value,
  (data) => {
    if (data) couriers.value = data;
  },
  { immediate: true },
);

watch(
  () => merchantsQuery.data.value,
  (data) => {
    if (data) merchants.value = data;
  },
  { immediate: true },
);

watch(
  () => orderDetailQuery.data.value,
  async (data) => {
    if (!data) return;
    order.value = data.order;
    orderItems.value = data.items;
    await loadInitialDistricts();
    await hydrateFormFromOrder(data.order as any);
  },
  { immediate: true },
);

watch(
  () => orderDetailQuery.error.value,
  (err) => {
    if (!err) return;
    showErrorNotification((err as Error).message || 'Failed to load order details');
  },
);

watch(
  () => couriersQuery.error.value,
  (err) => {
    if (!err) return;
    showErrorNotification((err as Error).message || 'Failed to load courier services');
  },
);

watch(
  () => merchantsQuery.error.value,
  (err) => {
    if (!err) return;
    showErrorNotification((err as Error).message || 'Failed to load merchant profiles');
  },
);
</script>

<style scoped>
@keyframes pulse-glow {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.8;
    transform: scale(1.08);
  }
}
.animate-flash {
  animation: pulse-glow 2s infinite ease-in-out;
}
</style>

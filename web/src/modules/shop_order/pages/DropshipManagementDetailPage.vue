<template>
  <q-page class="tf-page dropship-order-detail-v2">
    <div class="tf-page__stack">
      <template v-if="isLoading">
        <section class="dropship-order-detail-v2__loading">
          <q-skeleton type="rect" height="520px" class="dropship-order-detail-v2__paper-skeleton" />
        </section>
      </template>

      <section v-else-if="loadError" class="text-caption text-negative">
        {{ loadError }}
      </section>

      <div v-else-if="!orderData" class="text-center text-grey-6 q-pa-xl">
        Order not found.
      </div>

      <template v-else>
        <div
          v-if="showFooterActions || (settlementDirty && !paperReadonly)"
          class="dropship-order-detail-v2__ready-actions no-print"
        >
          <q-chip
            v-if="settlementDirty && !paperReadonly"
            dense
            color="orange-2"
            text-color="orange-10"
            icon="ph ph-warning"
            class="dropship-order-detail-v2__unsaved-chip"
          >
            Unsaved changes
          </q-chip>
          <q-btn
            v-if="settlementDirty && !paperReadonly"
            dense
            unelevated
            color="primary"
            no-caps
            icon="ph ph-floppy-disk"
            label="Save"
            class="dropship-order-detail-v2__desk-btn"
            :loading="saveDraftLoading"
            @click="onSaveSettlement"
          />
          <q-btn
            v-if="orderData.invoice?.id"
            dense
            outline
            color="primary"
            no-caps
            icon="ph ph-receipt"
            label="Customer bill"
            class="dropship-order-detail-v2__desk-btn"
            @click="openMerchantInvoice"
          />
          <q-btn
            v-if="orderData.order.courier_ap_bill_id"
            dense
            outline
            color="primary"
            no-caps
            icon="ph ph-truck"
            label="Courier bill"
            class="dropship-order-detail-v2__desk-btn"
            @click="openCourierBill"
          />

          <template v-if="deskStep === 'outcome'">
            <q-btn
              dense
              color="primary"
              unelevated
              no-caps
              icon="ph ph-package"
              label="Mark as delivered"
              class="dropship-order-detail-v2__desk-btn"
              :disable="!orderData.step_state.can_mark_delivered"
              :loading="actionKind === 'delivered'"
              @click="onMarkDelivered"
            />
            <q-btn
              dense
              outline
              color="negative"
              no-caps
              icon="ph ph-arrow-u-up-left"
              label="Mark as returned"
              class="dropship-order-detail-v2__desk-btn"
              :disable="!orderData.step_state.can_mark_returned"
              @click="onMarkReturned"
            />
          </template>

          <q-btn
            v-else-if="deskStep === 'remit'"
            dense
            color="primary"
            unelevated
            no-caps
            icon="ph ph-bank"
            label="Courier pay in"
            class="dropship-order-detail-v2__desk-btn"
            :loading="courierPayInSubmitting"
            @click="onCourierPayIn"
          />

          <q-btn
            v-else-if="orderData.step_state.can_transfer_to_reseller"
            dense
            color="primary"
            unelevated
            no-caps
            icon="ph ph-hand-coins"
            label="Pay dropshipper profit"
            class="dropship-order-detail-v2__desk-btn"
            @click="goToShopPayout"
          />
        </div>

        <q-banner dense rounded class="bg-blue-1 text-blue-10 dropship-order-detail-v2__info-banner no-print">
          <template #avatar>
            <q-icon name="ph ph-info" color="blue-8" />
          </template>
          <div class="column q-gutter-y-xs">
            <span class="text-caption">{{ deskBannerText }}</span>
          </div>
        </q-banner>

        <DropshipManagementSettlementPaper
          ref="paperRef"
          :data="orderData"
          :readonly="paperReadonly"
          :return-section-mode="returnSectionMode"
          @dirty-change="onSettlementDirtyChange"
        />
      </template>
    </div>

  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  requestConfirmation,
  requestUnsavedChangesConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import DropshipManagementSettlementPaper from '../components/DropshipManagementSettlementPaper.vue';
import { shopOrderService } from '../services/shopOrderService';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { DropshipManagementOrderView } from '../types/dropshipManagementOrder';
import {
  parseDropshipDeliverBillNotesPreview,
  requestDropshipMarkDeliveredConfirmation,
} from '../utils/dropshipDeliverBillNotesPreview';
import { dropshipFinanceRepository } from '../repositories/dropshipFinanceRepository';
import {
  requestDropshipCourierPayInDialog,
  toFinanceHubQueueItemFromManagementView,
} from '../utils/dropshipCourierPayInDialog';

const route = useRoute();
const router = useRouter();
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '',
);
const authStore = useAuthStore();
const queryClient = useQueryClient();

const paperRef = ref<InstanceType<typeof DropshipManagementSettlementPaper> | null>(null);
const actionKind = ref<'delivered' | null>(null);
const courierPayInSubmitting = ref(false);
const settlementDirty = ref(false);
const saveDraftLoading = ref(false);
type ManagementDeskStep = 'outcome' | 'remit' | 'done';

const orderId = computed(() => Number(route.params.id));

const detailQueryKey = computed(() =>
  shopOrderQueryKeys.dropshipManagementDetail(authStore.tenantId ?? 0, orderId.value),
);

const {
  data: orderData,
  isLoading,
  error: queryError,
} = useQuery({
  queryKey: detailQueryKey,
  enabled: computed(() => !!authStore.tenantId && Number.isFinite(orderId.value) && orderId.value > 0),
  queryFn: async (): Promise<DropshipManagementOrderView | null> => {
    if (!authStore.tenantId) return null;
    const res = await shopOrderService.fetchDropshipManagementOrder(authStore.tenantId, orderId.value);
    if (!res.success) {
      throw new Error(res.error ?? 'Failed to load order');
    }
    if (!res.data) {
      throw new Error('Failed to load order');
    }
    return res.data;
  },
});

const loadError = computed(() => (queryError.value instanceof Error ? queryError.value.message : null));

const isSettlementReadonly = computed(() => {
  const data = orderData.value;
  if (!data) return false;
  if (data.order.status === 'returned') return true;
  if (data.settlement.status === 'confirmed' || data.settlement.merchant_payout_at) {
    return true;
  }
  return data.order.status !== 'shipped';
});

const returnSectionMode = computed(() =>
  orderData.value?.order.status === 'returned' ? 'readonly' : 'hidden',
);

const deskStep = computed((): ManagementDeskStep => {
  const status = orderData.value?.order.status;
  if (!status) return 'done';
  if (status === 'shipped') return 'outcome';
  if (status === 'delivered') return 'remit';
  return 'done';
});

const deskBannerText = computed(() => {
  switch (deskStep.value) {
    case 'outcome':
      return 'Parcel is in transit. Confirm delivery or mark a return — cash is recorded when the courier remits.';
    case 'remit':
      return 'Parcel delivered. Use Courier pay in for net bank in from the courier — customer invoice clears here; dropshipper profit stays on cashbook until Pay out.';
    default:
      if (orderData.value?.order.status === 'returned') {
        return 'Return finalized — settlement is read-only.';
      }
      if (orderData.value?.step_state.can_transfer_to_reseller) {
        return 'Remittance posted. Dropshipper profit is on cashbook — use Pay out when you send money to the dropshipper.';
      }
      if (
        orderData.value?.order.status === 'payment_received'
        || orderData.value?.order.status === 'reseller_paid'
      ) {
        return 'Settlement complete — remittance posted and dropshipper profit paid out.';
      }
      return 'Settlement desk — read-only recap.';
  }
});

const paperReadonly = computed(() => {
  if (isSettlementReadonly.value) return true;
  return deskStep.value !== 'outcome';
});

const showFooterActions = computed(() => {
  const status = orderData.value?.order.status;
  if (!status || status === 'returned') return deskStep.value === 'done' && !!orderData.value?.invoice?.id;
  return deskStep.value !== 'done' || !!orderData.value?.invoice?.id;
});

function getPayload() {
  return paperRef.value?.getDraftPayload();
}

async function invalidateDetail() {
  await queryClient.invalidateQueries({ queryKey: detailQueryKey.value });
}

function onSettlementDirtyChange(dirty: boolean) {
  settlementDirty.value = dirty;
}

async function onSaveSettlement(): Promise<boolean> {
  if (!authStore.tenantId || paperReadonly.value) return true;
  const payload = getPayload();
  if (!payload) return false;

  saveDraftLoading.value = true;
  try {
    const res = await shopOrderService.saveDropshipSettlementDraft(
      authStore.tenantId,
      orderId.value,
      payload,
    );
    if (!res.success) {
      showErrorNotification(res.error ?? 'Failed to save settlement.');
      return false;
    }
    showSuccessNotification('Settlement saved.');
    await invalidateDetail();
    return true;
  } finally {
    saveDraftLoading.value = false;
  }
}

onBeforeRouteLeave(async () => {
  if (!settlementDirty.value) return true;
  const choice = await requestUnsavedChangesConfirmation();
  return choice === 'discard';
});

const onBeforeUnload = (event: BeforeUnloadEvent) => {
  if (!settlementDirty.value) return;
  event.preventDefault();
};

if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', onBeforeUnload);
}

onBeforeUnmount(() => {
  if (typeof window !== 'undefined') {
    window.removeEventListener('beforeunload', onBeforeUnload);
  }
});

function openBill(billId: number) {
  void router.push({
    name: 'app-bill-detail-page',
    params: {
      ...(tenantSlug.value ? { tenantSlug: tenantSlug.value } : {}),
      billId: String(billId),
    },
  });
}

function openMerchantInvoice() {
  const invoiceId = orderData.value?.invoice?.id;
  if (!invoiceId) return;
  openBill(invoiceId);
}

function openCourierBill() {
  const billId = orderData.value?.order.courier_ap_bill_id;
  if (!billId) return;
  openBill(billId);
}

async function onCourierPayIn() {
  if (!orderData.value || courierPayInSubmitting.value) return;

  const queueItem = toFinanceHubQueueItemFromManagementView(orderData.value);
  const payload = await requestDropshipCourierPayInDialog(queueItem);
  if (!payload) return;

  courierPayInSubmitting.value = true;
  try {
    await dropshipFinanceRepository.confirmCourierRemittance({
      orderId: payload.orderId,
      netAmount: payload.netAmount,
      courierCharge: payload.courierCharge,
      deliveryCharge: payload.deliveryCharge,
      codCharge: payload.codCharge,
      remittanceRef: payload.remittanceRef ?? `REMIT-${payload.orderId}`,
      bankTrxId: payload.bankTrxId,
      cashbookPointId: payload.cashbookPointId,
    });
    showSuccessNotification('Courier pay in recorded.');
    await invalidateDetail();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Courier pay in failed.');
  } finally {
    courierPayInSubmitting.value = false;
  }
}

function goToShopPayout() {
  void router.push({
    name: 'app-shop-dropship-finance-hub-page',
    params: { tenantSlug: tenantSlug.value },
    query: { orderId: String(orderId.value), step: 'middleman_payout' },
  });
}

async function onMarkDelivered() {
  if (!authStore.tenantId) return;
  const payload = getPayload();
  if (!payload) return;

  if (!orderData.value?.step_state.can_mark_delivered) return;

  actionKind.value = 'delivered';
  try {
    const saveRes = await shopOrderService.saveDropshipSettlementDraft(
      authStore.tenantId,
      orderId.value,
      payload,
    );
    if (!saveRes.success) {
      showErrorNotification(saveRes.error ?? 'Failed to save settlement before deliver.');
      return;
    }

    const previewRes = await shopOrderService.previewDropshipDeliverBillNotes(
      authStore.tenantId,
      orderId.value,
    );
    const confirmed = await requestDropshipMarkDeliveredConfirmation(
      previewRes.success ? parseDropshipDeliverBillNotesPreview(previewRes.data) : null,
      { orderNo: orderData.value?.order.order_no },
    );
    if (!confirmed) return;

    const res = await shopOrderService.markDropshipOrderDelivered(
      authStore.tenantId,
      orderId.value,
      payload,
    );
    if (!res.success) {
      showErrorNotification(res.error ?? 'Failed to mark as delivered.');
      return;
    }

    showSuccessNotification('Order marked as delivered.');
    await invalidateDetail();
  } finally {
    actionKind.value = null;
  }
}

async function onMarkReturned() {
  if (!orderData.value?.step_state.can_mark_returned) return;

  const confirmed = await requestConfirmation(
    'Mark this order as returned? You will choose return lines and restock details on the next screen.',
    'Mark as returned',
    'Mark as returned',
  );
  if (!confirmed) return;

  router.push({
    name: 'app-shop-dropship-return-page',
    params: { tenantSlug: route.params.tenantSlug, id: orderId.value },
  });
}

</script>

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
  align-items: center;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.dropship-order-detail-v2__unsaved-chip {
  font-weight: 600;
  margin-right: auto;
}

.dropship-order-detail-v2__desk-btn {
  border-radius: 6px;
  font-size: 0.8125rem;
  font-weight: 600;
  min-height: 32px;
  padding: 0 10px;
}
</style>

<script lang="ts">
export default {
  name: 'DropshipManagementDetailPage',
};
</script>

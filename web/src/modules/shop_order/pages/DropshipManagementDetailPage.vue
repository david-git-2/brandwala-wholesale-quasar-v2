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
        <q-banner dense rounded class="bg-blue-1 text-blue-10 dropship-order-detail-v2__info-banner no-print">
          <template #avatar>
            <q-icon name="ph ph-info" color="blue-8" />
          </template>
          <div class="column q-gutter-y-xs">
            <span class="text-caption">{{ deskBannerText }}</span>
          </div>
        </q-banner>

        <div v-if="showFooterActions" class="dropship-order-detail-v2__ready-actions no-print">
          <q-btn
            v-if="orderData.invoice?.id && deskStep !== 'done'"
            outline
            color="primary"
            no-caps
            icon="ph ph-receipt"
            label="View customer invoice"
            class="text-weight-bold"
            style="border-radius: 8px"
            @click="openMerchantInvoice"
          />

          <template v-if="deskStep === 'outcome'">
            <q-btn
              color="primary"
              unelevated
              no-caps
              icon="ph ph-package"
              label="Mark as delivered"
              class="text-weight-bold"
              style="border-radius: 8px; min-width: 200px"
              :disable="!orderData.step_state.can_mark_delivered"
              :loading="actionKind === 'delivered'"
              @click="onMarkDelivered"
            />
            <q-btn
              outline
              color="negative"
              no-caps
              icon="ph ph-arrow-u-up-left"
              label="Mark as returned"
              class="text-weight-bold"
              style="border-radius: 8px"
              :disable="!orderData.step_state.can_mark_returned"
              @click="onMarkReturned"
            />
          </template>

          <q-btn
            v-else-if="deskStep === 'remit'"
            color="primary"
            unelevated
            no-caps
            icon="ph ph-bank"
            label="Courier pay in"
            class="text-weight-bold"
            style="border-radius: 8px; min-width: 220px"
            :loading="courierPayInSubmitting"
            @click="onCourierPayIn"
          />

          <q-btn
            v-else-if="orderData.step_state.can_transfer_to_reseller"
            color="primary"
            unelevated
            no-caps
            icon="ph ph-hand-coins"
            label="Pay dropshipper profit"
            class="text-weight-bold"
            style="border-radius: 8px; min-width: 220px"
            @click="goToShopPayout"
          />

          <q-btn
            v-else-if="deskStep === 'done' && orderData.invoice?.id"
            outline
            color="primary"
            no-caps
            icon="ph ph-receipt"
            label="View customer invoice"
            class="text-weight-bold"
            style="border-radius: 8px; min-width: 200px"
            @click="openMerchantInvoice"
          />
        </div>

        <DropshipManagementSettlementPaper
          ref="paperRef"
          :data="orderData"
          :readonly="paperReadonly"
          :return-section-mode="returnSectionMode"
          @autosave="onAutosaveDraft"
        />
      </template>
    </div>

  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { requestConfirmation, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import DropshipManagementSettlementPaper from '../components/DropshipManagementSettlementPaper.vue';
import { shopOrderService } from '../services/shopOrderService';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type {
  DropshipManagementOrderView,
  DropshipSettlementDraftPayload,
} from '../types/dropshipManagementOrder';
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
    if (!res.success || !res.data) {
      throw new Error(res.error ?? 'Failed to load order');
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

async function onAutosaveDraft(payload: DropshipSettlementDraftPayload) {
  if (!authStore.tenantId || paperReadonly.value) return;

  const res = await shopOrderService.saveDropshipSettlementDraft(
    authStore.tenantId,
    orderId.value,
    payload,
  );
  if (!res.success) {
    showErrorNotification(res.error ?? 'Failed to save settlement.');
  }
}

function openMerchantInvoice() {
  const invoiceId = orderData.value?.invoice?.id;
  if (!invoiceId) return;
  void router.push({
    name: 'app-global-invoice-details-page',
    params: { tenantSlug: tenantSlug.value, id: String(invoiceId) },
  });
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
  flex-wrap: wrap;
  gap: 0.5rem;
}
</style>

<script lang="ts">
export default {
  name: 'DropshipManagementDetailPage',
};
</script>

<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
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
            label="View merchant bill"
            class="text-weight-bold"
            style="border-radius: 8px"
            @click="openMerchantInvoice"
          />

          <template v-if="deskStep === 'outcome' && !isSettlementReadonly">
            <q-btn
              v-if="!adjustFeesOpen"
              outline
              color="primary"
              no-caps
              icon="ph ph-sliders-horizontal"
              label="Adjust fees"
              style="border-radius: 8px"
              @click="adjustFeesOpen = true"
            />
            <template v-else>
              <q-btn flat no-caps color="grey-8" label="Done adjusting" @click="adjustFeesOpen = false" />
              <q-btn
                outline
                color="primary"
                no-caps
                icon="ph ph-floppy-disk"
                label="Save draft"
                style="border-radius: 8px"
                :loading="savingDraft"
                @click="onSaveDraft"
              />
            </template>
          </template>

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
            v-else-if="deskStep === 'done' && orderData.invoice?.id"
            outline
            color="primary"
            no-caps
            icon="ph ph-receipt"
            label="View merchant invoice"
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
        />
      </template>
    </div>

  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { requestConfirmation, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import DropshipManagementSettlementPaper from '../components/DropshipManagementSettlementPaper.vue';
import { shopOrderService } from '../services/shopOrderService';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { DropshipManagementOrderView } from '../types/dropshipManagementOrder';

const route = useRoute();
const router = useRouter();
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '',
);
const authStore = useAuthStore();
const queryClient = useQueryClient();

const paperRef = ref<InstanceType<typeof DropshipManagementSettlementPaper> | null>(null);
const savingDraft = ref(false);
const actionKind = ref<'delivered' | null>(null);
const adjustFeesOpen = ref(false);

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
      return 'Parcel delivered. Record courier remittance on Payments (Cash in) to pay the merchant bill and credit reseller profit.';
    default:
      if (orderData.value?.order.status === 'returned') {
        return 'Return finalized — settlement is read-only.';
      }
      if (
        orderData.value?.order.status === 'payment_received'
        || orderData.value?.order.status === 'reseller_paid'
      ) {
        return 'Settlement complete — remittance posted and merchant profit credited.';
      }
      return 'Settlement desk — read-only recap.';
  }
});

const paperReadonly = computed(() => {
  if (isSettlementReadonly.value) return true;
  if (deskStep.value !== 'outcome') return true;
  return !adjustFeesOpen.value;
});

const showFooterActions = computed(() => {
  const status = orderData.value?.order.status;
  if (!status || status === 'returned') return deskStep.value === 'done' && !!orderData.value?.invoice?.id;
  return deskStep.value !== 'done' || !!orderData.value?.invoice?.id;
});

watch(orderData, () => {
  if (deskStep.value !== 'outcome') {
    adjustFeesOpen.value = false;
  }
});

function getPayload() {
  return paperRef.value?.getDraftPayload();
}

async function invalidateDetail() {
  await queryClient.invalidateQueries({ queryKey: detailQueryKey.value });
}

async function onSaveDraft() {
  if (!authStore.tenantId) return;
  const payload = getPayload();
  if (!payload) return;

  savingDraft.value = true;
  try {
    const res = await shopOrderService.saveDropshipSettlementDraft(
      authStore.tenantId,
      orderId.value,
      payload,
    );
    if (!res.success) {
      showErrorNotification(res.error ?? 'Failed to save draft.');
      return;
    }
    showSuccessNotification('Settlement draft saved.');
    await invalidateDetail();
  } finally {
    savingDraft.value = false;
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

async function onMarkDelivered() {
  if (!authStore.tenantId) return;
  const payload = getPayload();
  if (!payload) return;

  if (!orderData.value?.step_state.can_mark_delivered) return;

  const confirmed = await requestConfirmation(
    'Mark this parcel as delivered? The merchant bill was already issued at ship. Cash comes when the courier remits.',
    'Mark as delivered',
    'Mark delivered',
  );
  if (!confirmed) return;

  actionKind.value = 'delivered';
  try {
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

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { useDropshipOrderDetailV2Query } from '../composables/useDropshipOrderDetailV2Query';
import { useDropshipOrderStatusRedirect } from '../composables/useDropshipOrderStatusRedirect';
import DropshipOrderConfirmedInvoicePaper from '../components/DropshipOrderConfirmedInvoicePaper.vue';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import {
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
  requestConfirmation,
} from 'src/utils/appFeedback';

const route = useRoute();
const authStore = useAuthStore();
const queryClient = useQueryClient();
const callActionLoading = ref<'no_answer' | 'confirm' | 'cancel' | null>(null);
const cancelDialogOpen = ref(false);
const cancelReason = ref('');

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);
const orderId = computed(() => Number(route.params.id || 0));

const orderDetailQuery = useDropshipOrderDetailV2Query({ tenantSlug, orderId });

const order = computed(() => orderDetailQuery.data.value?.order ?? null);
const orderItems = computed(() => orderDetailQuery.data.value?.items ?? []);
const isConfirmed = computed(() => order.value?.status === 'confirmed');
const isLoading = computed(() => orderDetailQuery.isLoading.value);
const loadError = computed(() => orderDetailQuery.error.value);

const callAttemptCount = computed(() => Number(order.value?.recipient_call_attempt_count ?? 0));

const recipientPhoneDisplay = computed(() => {
  const primary = order.value?.recipient_phone?.trim();
  const secondary = order.value?.recipient_phone_secondary?.trim();
  if (primary && secondary) return `${primary} · ${secondary}`;
  return primary || secondary || '—';
});

useDropshipOrderStatusRedirect({
  expectedView: 'confirmed',
  status: computed(() => order.value?.status ?? null),
  orderId,
  tenantSlug,
  enabled: computed(() => !isLoading.value && !!order.value),
});

const invalidateOrderQueries = async () => {
  await queryClient.invalidateQueries({
    queryKey: shopOrderQueryKeys.dropshipDetailV2(authStore.tenantId ?? 0, orderId.value),
  });
  await queryClient.invalidateQueries({
    queryKey: shopOrderQueryKeys.orderDetail(authStore.tenantId ?? null, orderId.value),
  });
};

const logNoAnswer = async () => {
  if (!order.value) return;
  callActionLoading.value = 'no_answer';
  try {
    const res = await shopOrderRepository.recordDropshipRecipientCallNoAnswer(order.value.id);
    showSuccessNotification(
      `No answer logged (${res.recipient_call_attempt_count ?? callAttemptCount.value + 1} calls).`,
    );
    await invalidateOrderQueries();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to log call attempt'));
  } finally {
    callActionLoading.value = null;
  }
};

const confirmRecipient = async () => {
  if (!order.value) return;
  const confirmed = await requestConfirmation(
    'Did the recipient confirm they want this order?',
    'Recipient confirmed',
    'Confirm & start processing',
  );
  if (!confirmed) return;

  callActionLoading.value = 'confirm';
  try {
    await shopOrderRepository.confirmDropshipRecipientCall(order.value.id);
    showSuccessNotification('Recipient confirmed. Order is now processing.');
    await invalidateOrderQueries();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to confirm recipient'));
  } finally {
    callActionLoading.value = null;
  }
};

const openCancelDialog = () => {
  cancelReason.value = '';
  cancelDialogOpen.value = true;
};

const submitRecipientCancel = async () => {
  if (!order.value) return;
  const reason = cancelReason.value.trim();
  if (!reason) {
    showErrorNotification('Please enter why the recipient cancelled.');
    return;
  }

  callActionLoading.value = 'cancel';
  try {
    await shopOrderRepository.cancelShopOrderDropship(order.value.id, reason);
    cancelDialogOpen.value = false;
    showSuccessNotification('Order cancelled.');
    await invalidateOrderQueries();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to cancel order'));
  } finally {
    callActionLoading.value = null;
  }
};
</script>

<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <section v-if="isLoading" class="dropship-order-detail-v2__loading">
        <q-skeleton type="rect" height="520px" class="dropship-order-detail-v2__paper-skeleton" />
      </section>

      <section v-else-if="loadError" class="text-caption text-negative">
        {{ loadError instanceof Error ? loadError.message : 'Failed to load order.' }}
      </section>

      <template v-else-if="order">
        <DropshipOrderConfirmedInvoicePaper
          v-if="isConfirmed"
          :order="order"
          :order-items="orderItems"
        />

        <q-card
          v-if="isConfirmed"
          flat
          bordered
          class="form-card dropship-order-detail-v2__call-card"
        >
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold q-mb-xs">Recipient confirmation call</div>
            <p class="text-body2 text-grey-7 q-mb-sm">
              Call the recipient and log the outcome before processing starts.
            </p>
            <div class="row q-col-gutter-md q-mb-md">
              <div class="col-12 col-sm-6">
                <div class="text-caption text-grey-6 text-uppercase">Recipient</div>
                <div class="text-body1 text-weight-medium">
                  {{ order.recipient_name || '—' }}
                </div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="text-caption text-grey-6 text-uppercase">Phone</div>
                <div class="text-body1 text-weight-medium">{{ recipientPhoneDisplay }}</div>
              </div>
            </div>
            <q-chip dense color="blue-grey-1" text-color="blue-grey-9" icon="ph ph-phone">
              Calls: {{ callAttemptCount }}
            </q-chip>
          </q-card-section>
          <q-separator />
          <q-card-actions class="dropship-order-detail-v2__footer-actions q-pa-md">
            <q-btn
              outline
              color="grey-8"
              no-caps
              icon="ph ph-phone-slash"
              label="No answer"
              :loading="callActionLoading === 'no_answer'"
              :disable="callActionLoading !== null && callActionLoading !== 'no_answer'"
              @click="logNoAnswer"
            />
            <q-btn
              color="negative"
              outline
              no-caps
              icon="ph ph-x-circle"
              label="Recipient cancelled"
              :disable="callActionLoading !== null"
              @click="openCancelDialog"
            />
            <q-btn
              color="primary"
              unelevated
              no-caps
              icon="ph ph-check-circle"
              label="Recipient confirmed"
              class="text-weight-bold"
              :loading="callActionLoading === 'confirm'"
              :disable="callActionLoading !== null && callActionLoading !== 'confirm'"
              @click="confirmRecipient"
            />
          </q-card-actions>
        </q-card>

        <q-card v-else flat bordered class="form-card">
          <q-card-section class="q-pa-lg text-center">
            <q-icon name="ph ph-file-text" size="40px" color="grey-5" class="q-mb-sm" />
            <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-xs">
              Paper invoice view
            </div>
            <p class="text-body2 text-grey-6 q-mb-sm">
              Full recipient and item details appear here once the order is confirmed.
            </p>
            <q-chip dense outline color="grey-7" class="text-capitalize">
              Current status: {{ order.status.replace(/_/g, ' ') }}
            </q-chip>
          </q-card-section>
        </q-card>
      </template>
    </div>

    <q-dialog v-model="cancelDialogOpen" persistent>
      <q-card style="min-width: 320px; max-width: 480px">
        <q-card-section>
          <div class="text-h6">Recipient cancelled</div>
          <p class="text-body2 text-grey-7 q-mt-sm q-mb-none">
            This reason is shown to the reseller on their order page.
          </p>
        </q-card-section>
        <q-card-section class="q-pt-none">
          <q-input
            v-model="cancelReason"
            type="textarea"
            autogrow
            outlined
            dense
            label="Cancellation reason *"
            :disable="callActionLoading === 'cancel'"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn
            flat
            no-caps
            label="Back"
            :disable="callActionLoading === 'cancel'"
            @click="cancelDialogOpen = false"
          />
          <q-btn
            color="negative"
            unelevated
            no-caps
            label="Cancel order"
            :loading="callActionLoading === 'cancel'"
            @click="submitRecipientCancel"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<style scoped>
.dropship-order-detail-v2 {
  min-height: 100%;
}

.dropship-order-detail-v2__paper-skeleton {
  max-width: 1100px;
  margin: 0 auto;
  border-radius: 12px;
}

.dropship-order-detail-v2__call-card {
  max-width: 1100px;
  margin: 0 auto;
}

.dropship-order-detail-v2__footer-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 0.5rem;
}
</style>

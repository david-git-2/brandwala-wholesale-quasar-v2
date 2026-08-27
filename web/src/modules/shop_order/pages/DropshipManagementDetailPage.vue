<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <div v-if="isLoading" class="row justify-center q-py-xl">
        <q-spinner color="primary" size="3em" />
      </div>

      <div v-else-if="loadError" class="text-center text-negative q-pa-xl">
        {{ loadError }}
      </div>

      <div v-else-if="!orderData" class="text-center text-grey-6 q-pa-xl">
        Order not found.
      </div>

      <template v-else>
        <DropshipManagementSettlementPaper
          ref="paperRef"
          :data="orderData"
          :readonly="isReadonly"
        />

        <div class="dropship-order-detail-v2__toolbar">
          <q-btn
            v-if="!isReadonly"
            outline
            color="primary"
            no-caps
            icon="ph ph-floppy-disk"
            label="Save draft"
            :loading="savingDraft"
            @click="onSaveDraft"
          />
        </div>

        <div class="dropship-order-detail-v2__footer-actions">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-package"
            label="Mark as delivered"
            class="text-weight-bold dropship-order-detail-v2__action-btn"
            :disable="!orderData.step_state.can_mark_delivered || isReadonly"
            :loading="actionKind === 'delivered'"
            @click="onMarkDelivered"
          />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-bank"
            label="Bank transfer from courier"
            class="text-weight-bold dropship-order-detail-v2__action-btn"
            :disable="!orderData.step_state.can_record_bank_transfer || isReadonly"
            :loading="actionKind === 'remittance'"
            @click="showRemittanceDialog = true"
          />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-wallet"
            label="Transfer to reseller"
            class="text-weight-bold dropship-order-detail-v2__action-btn"
            :disable="!orderData.step_state.can_transfer_to_reseller || isReadonly"
            :loading="actionKind === 'payout'"
            @click="onTransferReseller"
          />
        </div>
      </template>
    </div>

    <q-dialog v-model="showRemittanceDialog" persistent>
      <q-card style="min-width: 360px; max-width: 480px">
        <q-card-section>
          <div class="text-h6">Bank transfer from courier</div>
        </q-card-section>
        <q-card-section class="q-gutter-md q-pt-none">
          <q-input
            v-model="remittanceForm.remittance_ref"
            dense
            outlined
            label="Remittance reference *"
          />
          <q-input
            v-model="remittanceForm.bank_trx_id"
            dense
            outlined
            label="Bank transaction ID"
          />
          <q-input
            v-model.number="remittanceForm.net_amount"
            dense
            outlined
            type="number"
            min="0"
            step="0.01"
            label="Net amount received *"
          />
          <q-input
            v-model.number="remittanceForm.courier_charge"
            dense
            outlined
            type="number"
            min="0"
            step="0.01"
            label="Courier charge"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Confirm transfer"
            :loading="actionKind === 'remittance'"
            @click="onRecordBankTransfer"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import DropshipManagementSettlementPaper from '../components/DropshipManagementSettlementPaper.vue';
import { shopOrderService } from '../services/shopOrderService';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { DropshipManagementOrderView } from '../types/dropshipManagementOrder';

const route = useRoute();
const authStore = useAuthStore();
const queryClient = useQueryClient();

const paperRef = ref<InstanceType<typeof DropshipManagementSettlementPaper> | null>(null);
const savingDraft = ref(false);
const actionKind = ref<'delivered' | 'remittance' | 'payout' | null>(null);
const showRemittanceDialog = ref(false);

const remittanceForm = reactive({
  remittance_ref: '',
  bank_trx_id: '',
  net_amount: 0,
  courier_charge: 0,
});

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

const isReadonly = computed(
  () => orderData.value?.settlement.status === 'confirmed' || !!orderData.value?.settlement.merchant_payout_at,
);

watch(orderData, (data) => {
  if (!data) return;
  remittanceForm.net_amount = data.settlement.collected_cod_amount;
  const codLine = data.settlement.charge_lines.find((l) => l.charge_type === 'cod');
  remittanceForm.courier_charge = codLine?.amount ?? data.order.cod_charge_amount ?? 0;
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

async function onMarkDelivered() {
  if (!authStore.tenantId) return;
  const payload = getPayload();
  if (!payload) return;

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

async function onRecordBankTransfer() {
  if (!authStore.tenantId) return;
  const payload = getPayload();
  if (!payload) return;

  if (!remittanceForm.remittance_ref.trim()) {
    showErrorNotification('Remittance reference is required.');
    return;
  }
  if (!remittanceForm.net_amount || remittanceForm.net_amount <= 0) {
    showErrorNotification('Net amount must be greater than zero.');
    return;
  }

  actionKind.value = 'remittance';
  try {
    const res = await shopOrderService.recordDropshipCourierBankTransfer(authStore.tenantId, orderId.value, {
      ...payload,
      remittance_ref: remittanceForm.remittance_ref.trim(),
      bank_trx_id: remittanceForm.bank_trx_id.trim() || null,
      net_amount: remittanceForm.net_amount,
      courier_charge: remittanceForm.courier_charge ?? 0,
    });
    if (!res.success) {
      showErrorNotification(res.error ?? 'Failed to record bank transfer.');
      return;
    }
    showSuccessNotification('Courier bank transfer recorded.');
    showRemittanceDialog.value = false;
    await invalidateDetail();
  } finally {
    actionKind.value = null;
  }
}

async function onTransferReseller() {
  if (!authStore.tenantId) return;
  const payload = getPayload();
  if (!payload) return;

  actionKind.value = 'payout';
  try {
    const res = await shopOrderService.transferDropshipResellerProfit(
      authStore.tenantId,
      orderId.value,
      payload,
    );
    if (!res.success) {
      showErrorNotification(res.error ?? 'Failed to transfer reseller profit.');
      return;
    }
    showSuccessNotification('Reseller profit transferred.');
    await invalidateDetail();
  } finally {
    actionKind.value = null;
  }
}
</script>

<style scoped>
.dropship-order-detail-v2 {
  background: #eef1f4;
}

.dropship-order-detail-v2__toolbar {
  width: 100%;
  max-width: 800px;
  margin: 0 auto;
  display: flex;
  justify-content: flex-end;
}

.dropship-order-detail-v2__footer-actions {
  width: 100%;
  max-width: 800px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 0.5rem;
  padding-top: 0.25rem;
}

.dropship-order-detail-v2__action-btn {
  border-radius: 8px;
  min-height: 44px;
}
</style>

<script lang="ts">
export default {
  name: 'DropshipManagementDetailPage',
};
</script>

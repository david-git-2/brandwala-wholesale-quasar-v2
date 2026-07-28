<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Loading Skeleton -->
      <courier-remittance-skeleton v-if="isLoading" />

      <template v-else>
        <!-- Page Header -->
        <section class="row items-center justify-between q-col-gutter-md">
          <div class="col">
            <div class="text-overline text-primary">Shop &amp; Dropship</div>
            <h1 class="text-h5 text-weight-bold q-my-none flex items-center gap-2">
              <span>{{ isNew ? 'New Courier Remittance Batch' : `Statement #${batchNo || numericBatchId}` }}</span>
              <q-chip
                v-if="!isNew"
                dense
                :color="getStatusColor(batchStatus)"
                text-color="white"
                class="text-weight-bold uppercase"
                size="md"
              >
                {{ batchStatus }}
              </q-chip>
            </h1>
          </div>

          <!-- Actions Toolbar -->
          <div class="col-auto row q-gutter-sm items-center">
            <q-btn
              outline
              color="primary"
              icon="ph ph-arrow-left"
              label="Back to List"
              no-caps
              @click="goBack"
            />

            <!-- Save Draft Action (Only for new or draft status) -->
            <q-btn
              v-if="isNew || batchStatus === 'draft'"
              color="primary"
              outline
              icon="save"
              label="Save Draft"
              no-caps
              :loading="saving"
              @click="handleSaveDraft"
            />

            <!-- Post & Settle Action (Only for existing draft batches) -->
            <q-btn
              v-if="!isNew && batchStatus === 'draft'"
              color="positive"
              unelevated
              icon="check_circle"
              label="Post & Settle Batch"
              no-caps
              :loading="posting"
              :disable="selectedOrderIds.length === 0"
              @click="handlePostBatch"
            >
              <q-tooltip v-if="selectedOrderIds.length === 0">
                Select at least 1 delivered order to settle
              </q-tooltip>
            </q-btn>
          </div>
        </section>

        <!-- Statement & Bank Header Form Card -->
        <remittance-batch-header-form
          v-model:courier-service-id="courierServiceId"
          v-model:batch-no="batchNo"
          v-model:bank-trx-id="bankTrxId"
          v-model:payment-date="paymentDate"
          v-model:net-deposited-amount="netDepositedAmount"
          v-model:gross-cod-amount="grossCodAmount"
          v-model:courier-charges-amount="courierChargesAmount"
          v-model:note="note"
          :courier-options="couriers"
          :read-only="readOnly"
          :disable-courier-select="!isNew && batchStatus !== 'draft'"
        />

        <!-- Live Reconciliation Card -->
        <remittance-reconciliation-card
          :item-count="reconciliationStats.itemCount"
          :total-cod="reconciliationStats.totalCod"
          :total-charges="reconciliationStats.totalCharges"
          :calculated-net="reconciliationStats.calculatedNet"
          :net-deposited-amount="netDepositedAmount"
        />

        <!-- Delivered Orders Selector Table -->
        <remittance-order-selector-table
          v-model:selected-order-ids="selectedOrderIds"
          :orders="availableDeliveredOrders"
          :loading="loadingOrders"
          :read-only="readOnly"
          @open-bulk-paste="bulkPasteModalOpen = true"
        />

        <!-- Bulk Paste Modal -->
        <remittance-bulk-paste-modal
          v-model="bulkPasteModalOpen"
          :available-orders="availableDeliveredOrders"
          @apply-selection="handleApplyBulkSelection"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { dropshipCourierService } from '../services/dropshipCourierService';
import { useDeliveredOrdersForCourierQuery } from '../composables/useDeliveredOrdersForCourierQuery';
import { useCourierRemittanceDetailQuery } from '../composables/useCourierRemittanceDetailQuery';
import { useCourierRemittanceMutations } from '../composables/useCourierRemittanceMutations';
import RemittanceBatchHeaderForm from '../components/RemittanceBatchHeaderForm.vue';
import RemittanceReconciliationCard from '../components/RemittanceReconciliationCard.vue';
import RemittanceOrderSelectorTable from '../components/RemittanceOrderSelectorTable.vue';
import RemittanceBulkPasteModal from '../components/RemittanceBulkPasteModal.vue';
import CourierRemittanceSkeleton from '../components/CourierRemittanceSkeleton.vue';
import {
  showSuccessNotification,
  showErrorNotification,
  requestConfirmation,
} from 'src/utils/appFeedback';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import type { ShopOrder } from '../types';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const tenantId = computed(() => (authStore.tenantId as number) ?? 0);
const batchIdParam = computed(() => route.params.id as string);
const isNew = computed(() => !batchIdParam.value || batchIdParam.value === 'new');
const numericBatchId = computed(() => (isNew.value ? null : Number(batchIdParam.value)));

// Form State
const courierServiceId = ref<string | null>(null);
const batchNo = ref('');
const bankTrxId = ref('');
const paymentDate = ref(new Date().toISOString().slice(0, 10));
const netDepositedAmount = ref<number>(0);
const grossCodAmount = ref<number>(0);
const courierChargesAmount = ref<number>(0);
const note = ref('');
const selectedOrderIds = ref<number[]>([]);
const bulkPasteModalOpen = ref(false);

const couriers = ref<CourierServiceRow[]>([]);

// Data Queries
const { data: detailData, isLoading: loadingDetail } = useCourierRemittanceDetailQuery(
  tenantId,
  numericBatchId,
);

const { data: unremittedDeliveredOrders, isLoading: loadingOrders } = useDeliveredOrdersForCourierQuery(
  tenantId,
  courierServiceId,
);

const { saveBatchDraftMutation, postBatchMutation } = useCourierRemittanceMutations();
const saving = computed(() => saveBatchDraftMutation.isPending.value);
const posting = computed(() => postBatchMutation.isPending.value);

const isLoading = computed(() => (!isNew.value && loadingDetail.value));

const batchStatus = computed(() => detailData.value?.batch?.status ?? 'draft');
const readOnly = computed(() => !isNew.value && batchStatus.value !== 'draft');

// Combine unremitted delivered orders with already staged batch items
const availableDeliveredOrders = computed<ShopOrder[]>(() => {
  const list: ShopOrder[] = [...(unremittedDeliveredOrders.value || [])];

  if (detailData.value?.items) {
    detailData.value.items.forEach((item) => {
      if (item.shop_order && !list.some((o) => o.id === item.shop_order_id)) {
        list.push({
          ...item.shop_order,
          tenant_id: tenantId.value,
          shop_id: 0,
          customer_group_id: 0,
          cart_id: null,
          name: '',
          shop_type_snapshot: 'dropship',
          order_mode_snapshot: 'procurement_intent',
          is_negotiable_snapshot: false,
          negotiate_round: 0,
          cargo_rate: null,
          conversion_rate: null,
          profit_rate: null,
          recipient_phone: null,
          shipping_address: null,
          billing_profile_id: null,
          placed_at: null,
          fulfilled_at: null,
          global_invoice_id: item.global_invoice_id,
          created_by_email: '',
          created_at: item.created_at,
          updated_at: item.created_at,
          cod_collect_amount: item.cod_collected_amount,
          delivery_charge_amount: item.courier_charge_amount,
        } as ShopOrder);
      }
    });
  }

  return list;
});

// Watch detail data to populate form fields
watch(
  detailData,
  (val) => {
    if (val?.batch) {
      courierServiceId.value = val.batch.courier_service_id;
      batchNo.value = val.batch.batch_no;
      bankTrxId.value = val.batch.bank_trx_id ?? '';
      paymentDate.value = val.batch.payment_date;
      netDepositedAmount.value = val.batch.net_deposited_amount;
      grossCodAmount.value = val.batch.gross_cod_amount;
      courierChargesAmount.value = val.batch.courier_charges_amount;
      note.value = val.batch.note ?? '';
    }
    if (val?.items) {
      selectedOrderIds.value = val.items.map((i) => i.shop_order_id).filter(Boolean) as number[];
    }
  },
  { immediate: true },
);

// Load couriers on mount
onMounted(async () => {
  const res = await dropshipCourierService.fetchCouriers();
  if (res.success && res.data) {
    couriers.value = res.data.filter((c) => c.is_active);
    if (isNew.value && couriers.value.length > 0 && couriers.value[0] && !courierServiceId.value) {
      courierServiceId.value = couriers.value[0].id;
    }
  }
});

// Live reconciliation math
const reconciliationStats = computed(() => {
  const selectedOrders = availableDeliveredOrders.value.filter((o) =>
    selectedOrderIds.value.includes(o.id),
  );

  let totalCod = 0;
  let totalCharges = 0;

  selectedOrders.forEach((o) => {
    const cod = o.cod_collect_amount ?? o.total_amount ?? 0;
    const charge = (o.delivery_charge_amount ?? 0) + (o.cod_charge_amount ?? 0);
    totalCod += cod;
    totalCharges += charge;
  });

  const calculatedNet = Number((totalCod - totalCharges).toFixed(2));

  return {
    itemCount: selectedOrders.length,
    totalCod,
    totalCharges,
    calculatedNet,
  };
});

function handleApplyBulkSelection(matchedOrderIds: number[]) {
  const combined = Array.from(new Set([...selectedOrderIds.value, ...matchedOrderIds]));
  selectedOrderIds.value = combined;
  showSuccessNotification(`Selected ${matchedOrderIds.length} matching orders`);
}

async function handleSaveDraft() {
  if (!courierServiceId.value) {
    showErrorNotification('Please select a courier service');
    return;
  }
  if (!batchNo.value.trim()) {
    showErrorNotification('Statement ID / Batch No is required');
    return;
  }

  const selectedOrders = availableDeliveredOrders.value.filter((o) =>
    selectedOrderIds.value.includes(o.id),
  );

  const itemsPayload = selectedOrders.map((o) => {
    const cod = o.cod_collect_amount ?? o.total_amount ?? 0;
    const charge = (o.delivery_charge_amount ?? 0) + (o.cod_charge_amount ?? 0);
    return {
      shop_order_id: o.id,
      global_invoice_id: o.global_invoice_id ?? null,
      tracking_number: o.courier_awb_number ?? null,
      awb_number: o.courier_awb_number ?? null,
      cod_collected_amount: cod,
      courier_charge_amount: charge,
      net_remitted_amount: cod - charge,
    };
  });

  try {
    const res = await saveBatchDraftMutation.mutateAsync({
      batch_id: numericBatchId.value,
      tenant_id: tenantId.value,
      courier_service_id: courierServiceId.value,
      batch_no: batchNo.value.trim(),
      bank_trx_id: bankTrxId.value.trim() || null,
      payment_date: paymentDate.value,
      gross_cod_amount: grossCodAmount.value || reconciliationStats.value.totalCod,
      courier_charges_amount: courierChargesAmount.value || reconciliationStats.value.totalCharges,
      net_deposited_amount: netDepositedAmount.value,
      note: note.value.trim() || null,
      items: itemsPayload,
    });

    showSuccessNotification('Courier remittance batch saved as draft');

    if (isNew.value && res.batch_id) {
      const tenantSlug = authStore.selectedTenant?.slug;
      const path = tenantSlug
        ? `/${tenantSlug}/app/shop/dropship/courier-remittances/${res.batch_id}`
        : `/app/shop/dropship/courier-remittances/${res.batch_id}`;
      void router.replace(path);
    }
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to save remittance batch');
  }
}

async function handlePostBatch() {
  if (!numericBatchId.value) return;

  const confirm = await requestConfirmation(
    `Are you sure you want to Post & Settle batch #${batchNo.value}? This will advance ${selectedOrderIds.value.length} orders to payment received status and record invoice payments.`,
    'Post Batch & Execute Settlement',
    'Post & Settle',
  );

  if (!confirm) return;

  try {
    await postBatchMutation.mutateAsync({
      tenantId: tenantId.value,
      batchId: numericBatchId.value,
    });
    showSuccessNotification('Batch posted and settled successfully!');
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to post batch settlement');
  }
}

function getStatusColor(status: string): string {
  switch (status) {
    case 'posted':
      return 'positive';
    case 'draft':
      return 'warning';
    case 'voided':
      return 'grey-7';
    default:
      return 'primary';
  }
}

function goBack() {
  const tenantSlug = authStore.selectedTenant?.slug;
  if (tenantSlug) {
    void router.push(`/${tenantSlug}/app/shop/dropship/courier-remittances`);
  } else {
    void router.push('/app/shop/dropship/courier-remittances');
  }
}
</script>

<style scoped lang="scss">
.bw-page {
  padding: clamp(1rem, 2.4vw, 2rem);
}
</style>

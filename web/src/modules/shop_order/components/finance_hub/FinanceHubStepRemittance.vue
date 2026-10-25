<template>
  <component :is="rootTag" v-bind="rootProps">
    <div
      v-if="variant === 'card'"
      class="text-subtitle1 text-weight-bold text-primary q-mb-md row items-center gap-xs"
    >
      <q-icon name="ph ph-bank" size="20px" />
      <span>Step 2: Confirm Courier Remittance</span>
    </div>

    <div v-if="!selectedOrder" class="text-body2 text-grey-6 q-my-md">
      Please select an order from the queue above to record courier remittance.
    </div>

    <q-banner
      v-else-if="selectedOrder.isPrepaidSnapshot"
      class="bg-amber-1 text-amber-10 rounded-borders q-mb-md"
      dense
    >
      Prepaid / billing-profile collection — end customer courier remittance is not applicable for this order.
    </q-banner>

    <q-form
      v-else
      class="q-gutter-y-sm"
      @submit.prevent="handleConfirm"
    >
      <template v-if="context === 'payin'">
        <div class="text-subtitle2 text-weight-bold">
          {{ selectedOrder.orderNo }}
          <span v-if="selectedOrder.courierName" class="text-grey-7 text-body2 text-weight-regular">
            · {{ selectedOrder.courierName }}
          </span>
        </div>
        <div class="text-caption text-grey-7 q-mb-sm">
          Expected bank in
          <span class="text-weight-bold text-positive">{{ formatAmt(expectedFromCourier) }} BDT</span>
          <span v-if="invoiceDue > 0">
            · clears up to {{ formatAmt(invoiceDue) }} on customer bill
          </span>
        </div>

        <q-input
          v-model.number="form.netAmount"
          type="number"
          label="Amount received (BDT)"
          outlined
          dense
          step="0.01"
          class="soft-input"
          :rules="[val => val > 0 || 'Required']"
        />

        <q-select
          v-model="form.cashbookPointId"
          :options="cashbookPointOptions"
          emit-value
          map-options
          outlined
          dense
          label="Deposit to"
          :loading="pointsQuery.isLoading.value"
          :rules="[val => !!val || 'Required']"
        />

        <q-input
          v-model="form.remittanceRef"
          label="Reference"
          outlined
          dense
          class="soft-input"
          hint="Courier statement or batch ID"
          :rules="[val => !!val || 'Required']"
        />

        <q-expansion-item
          dense
          expand-icon-class="text-grey-7"
          header-class="q-px-none"
          label="Adjust courier fees"
          caption="Only if different from settlement"
        >
          <div class="row q-col-gutter-sm q-pt-xs">
            <div class="col-6">
              <q-input
                v-model.number="form.deliveryCharge"
                type="number"
                label="Delivery fee"
                outlined
                dense
                step="0.01"
                @update:model-value="onDeliveryOrCodFeeEdited"
              />
            </div>
            <div class="col-6">
              <q-input
                v-model.number="form.codCharge"
                type="number"
                label="COD fee"
                outlined
                dense
                step="0.01"
                @update:model-value="onDeliveryOrCodFeeEdited"
              />
            </div>
          </div>
        </q-expansion-item>

        <div
          v-if="overCod"
          class="text-negative text-caption"
        >
          Received amount plus fees exceeds COD collected ({{ formatAmt(codFace()) }}).
        </div>

        <div class="row justify-end q-mt-sm">
          <q-btn
            type="submit"
            color="primary"
            unelevated
            no-caps
            :loading="loading || previewLoading"
            :disable="
              netRemitted <= 0
              || overCod
              || !form.remittanceRef
              || form.netAmount <= 0
              || !form.cashbookPointId
            "
            label="Post pay in"
          />
        </div>
      </template>

      <template v-else>
      <q-banner
        v-if="invoiceDue > 0"
        dense
        rounded
        class="bg-blue-1 text-blue-10 q-mb-sm"
      >
        Customer invoice due: {{ formatAmt(invoiceDue) }} BDT — cleared from this pay in (up to net received).
      </q-banner>

      <div v-if="variant === 'card'" class="text-subtitle2 text-weight-bold q-mb-xs">
        Order #{{ selectedOrder.orderNo }}
        <span v-if="selectedOrder.courierName" class="text-grey-7 text-body2 text-weight-regular">
          · {{ selectedOrder.courierName }}
        </span>
      </div>
      <div v-else-if="selectedOrder.courierName" class="text-caption text-grey-7 q-mb-sm">
        Courier: {{ selectedOrder.courierName }}
      </div>

      <q-card flat bordered class="bg-blue-grey-1 q-pa-sm q-mb-sm">
        <div class="text-caption text-weight-medium text-blue-grey-9 q-mb-sm">
          Charges &amp; expected from courier
        </div>
        <div class="row q-col-gutter-sm">
          <div class="col-6 col-sm-4">
            <div class="text-caption text-grey-7 q-mb-xs">COD face (collect)</div>
            <div class="text-weight-medium font-mono q-mb-sm">{{ formatAmt(codFace()) }}</div>
          </div>
          <div class="col-6 col-sm-4">
            <q-input
              v-model.number="form.deliveryCharge"
              type="number"
              label="Delivery fee (BDT)"
              outlined
              dense
              step="0.01"
              class="soft-input bg-white"
              :rules="[val => val >= 0 || 'Must be >= 0']"
              @update:model-value="onDeliveryOrCodFeeEdited"
            />
          </div>
          <div class="col-6 col-sm-4">
            <q-input
              v-model.number="form.codCharge"
              type="number"
              label="COD fee (BDT)"
              outlined
              dense
              step="0.01"
              class="soft-input bg-white"
              :rules="[val => val >= 0 || 'Must be >= 0']"
              @update:model-value="onDeliveryOrCodFeeEdited"
            />
          </div>
          <div class="col-6 col-sm-4">
            <div class="text-caption text-grey-7 q-mb-xs">Total courier charge</div>
            <div class="text-weight-medium font-mono">{{ formatAmt(totalCourierCharge) }}</div>
            <div class="text-2xs text-grey-6">Delivery + COD fee</div>
          </div>
          <div class="col-12">
            <div class="row items-center justify-between">
              <span class="text-caption text-grey-8">Expected bank in</span>
              <span class="text-subtitle2 text-weight-bold text-positive font-mono">
                {{ formatAmt(expectedFromCourier) }} BDT
              </span>
            </div>
            <div class="row justify-end q-mt-xs">
              <q-btn
                flat
                dense
                no-caps
                size="sm"
                color="primary"
                label="Use expected amount"
                @click="applyExpectedNet"
              />
            </div>
          </div>
        </div>
      </q-card>

      <div class="row q-col-gutter-sm">
        <div class="col-12">
          <q-input
            v-model.number="form.netAmount"
            type="number"
            label="Amount from courier (BDT) *"
            outlined
            dense
            step="0.01"
            class="soft-input"
            hint="Actual bank in for this order"
            :rules="[val => val > 0 || 'Must be greater than 0']"
          />
        </div>

        <div class="col-12">
          <q-input
            v-model="form.remittanceRef"
            label="Remittance Ref / Statement ID"
            outlined
            dense
            class="soft-input"
            :rules="[val => !!val || 'Required']"
          />
        </div>

        <div class="col-12">
          <q-input
            v-model="form.bankTrxId"
            label="Bank Transaction ID"
            outlined
            dense
            class="soft-input"
          />
        </div>

        <div class="col-12">
          <q-select
            v-model="form.cashbookPointId"
            :options="cashbookPointOptions"
            emit-value
            map-options
            outlined
            dense
            label="Deposit to (cashbook location) *"
            hint="Till, safe, or bank where courier money landed"
            :loading="pointsQuery.isLoading.value"
            :rules="[val => !!val || 'Required']"
          />
        </div>
      </div>

      <div class="bg-grey-2 q-pa-sm rounded-borders q-gutter-y-xs">
        <div class="row items-center justify-between text-caption">
          <span>Net remitted to tenant</span>
          <span class="text-positive text-subtitle2 text-weight-bold">{{ formatAmt(netRemitted) }} BDT</span>
        </div>
        <q-separator />
        <div class="row items-center justify-between text-caption text-grey-8">
          <span>→ Clears B2B invoice (up to due)</span>
          <span>{{ formatAmt(invoiceAllocated) }} BDT</span>
        </div>
        <div class="row items-center justify-between text-caption text-grey-8">
          <span>→ Held for dropshipper profit payout</span>
          <span>{{ formatAmt(merchantHeld) }} BDT</span>
        </div>
        <div class="row items-center justify-between text-caption text-grey-8">
          <span>Courier fee (tenant cost)</span>
          <span>{{ formatAmt(totalCourierCharge) }} BDT</span>
        </div>
        <div
          v-if="overCod"
          class="text-negative text-caption q-mt-xs"
        >
          Amount from courier + courier charges exceeds COD collect ({{ formatAmt(codFace()) }}).
        </div>
      </div>

      <div class="row justify-end q-mt-md">
        <q-btn
          type="submit"
          color="primary"
          unelevated
          no-caps
          :loading="loading || previewLoading"
          :disable="
            netRemitted <= 0
            || overCod
            || !form.remittanceRef
            || form.netAmount <= 0
            || !form.cashbookPointId
          "
          label="Confirm Remittance"
        />
      </div>
      </template>
    </q-form>
  </component>
</template>

<script setup lang="ts">
import { reactive, computed, watch, ref } from 'vue';
import { QCard } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCashbookPointsQuery } from 'src/modules/bills_pays/composables/useCashbookPointsQuery';
import {
  dropshipFinanceRepository,
  type FinanceHubOrderQueueItem,
} from '../../repositories/dropshipFinanceRepository';
import { expectedCourierRemittanceNet } from '../../utils/expectedCourierRemittanceNet';
import {
  parseDropshipCourierPayInSettlementPreview,
  requestDropshipCourierPayInConfirmation,
} from '../../utils/dropshipDeliverBillNotesPreview';
import { showErrorNotification } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});
const pointsContext = computed(() => ({
  booksTenantId: booksTenantId.value,
  entityType: 'tenant',
  entityId: booksTenantId.value,
  enabled: booksTenantId.value > 0,
}));
const { pointsQuery } = useCashbookPointsQuery(pointsContext);
const cashbookPointOptions = computed(() =>
  (pointsQuery.data.value ?? []).map((p) => ({ label: p.name, value: p.id })),
);

const props = withDefaults(
  defineProps<{
    selectedOrder: FinanceHubOrderQueueItem | null;
    loading: boolean;
    /** Optional B2B invoice outstanding; defaults to order totalAmount when unknown */
    invoiceOutstanding?: number | null;
    variant?: 'card' | 'panel';
    /** When set from Payments → Pay in → Courier */
    context?: 'hub' | 'payin';
  }>(),
  { variant: 'card', context: 'hub' },
);

const emit = defineEmits<{
  (
    e: 'submit',
    payload: {
      orderId: number;
      netAmount: number;
      courierCharge: number;
      deliveryCharge: number;
      codCharge: number;
      remittanceRef?: string;
      bankTrxId?: string;
      cashbookPointId: number;
    },
  ): void;
}>();

const previewLoading = ref(false);

const rootTag = computed(() => (props.variant === 'card' ? QCard : 'div'));
const rootProps = computed(() =>
  props.variant === 'card' ? { flat: true, bordered: true, class: 'q-pa-md' } : {},
);

const form = reactive({
  netAmount: 0,
  deliveryCharge: 0,
  codCharge: 0,
  remittanceRef: '',
  bankTrxId: '',
  cashbookPointId: null as number | null,
});

const totalCourierCharge = computed(
  () => Math.max(0, (Number(form.deliveryCharge) || 0) + (Number(form.codCharge) || 0)),
);

const expectedFromCourier = computed(() => {
  if (!props.selectedOrder) return 0;
  return expectedCourierRemittanceNet({
    codCollectAmount: props.selectedOrder.codCollectAmount,
    deliveryChargeAmount: form.deliveryCharge,
    codChargeAmount: form.codCharge,
  });
});

function codFace(): number {
  return props.selectedOrder?.codCollectAmount || 0;
}

function resetFeesFromOrder(order: FinanceHubOrderQueueItem) {
  form.deliveryCharge = Number(order.deliveryChargeAmount) || 0;
  form.codCharge = Number(order.codChargeAmount) || 0;
}

function applyExpectedNet() {
  form.netAmount = expectedFromCourier.value;
}

function onDeliveryOrCodFeeEdited() {
  applyExpectedNet();
}

watch(
  () => props.selectedOrder,
  (order) => {
    if (order) {
      form.remittanceRef = order.courierRemittanceRef || '';
      form.bankTrxId = order.courierBankTrxId || '';
      resetFeesFromOrder(order);
      applyExpectedNet();
    }
  },
  { immediate: true },
);

watch(
  cashbookPointOptions,
  (options) => {
    if (!form.cashbookPointId && options.length === 1) {
      form.cashbookPointId = options[0].value;
    }
  },
  { immediate: true },
);

const formatAmt = (n: number) =>
  Number(n || 0).toLocaleString('en-BD', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

const netRemitted = computed(() => Math.max(0, form.netAmount || 0));

const invoiceDue = computed(() => {
  if (props.selectedOrder?.invoiceOutstanding != null) {
    return props.selectedOrder.invoiceOutstanding;
  }
  if (props.invoiceOutstanding != null && props.invoiceOutstanding >= 0) {
    return props.invoiceOutstanding;
  }
  return 0;
});

const invoiceAllocated = computed(() =>
  Math.min(netRemitted.value, Math.max(invoiceDue.value, 0)),
);

const merchantHeld = computed(() =>
  Math.max(0, netRemitted.value - invoiceAllocated.value),
);

const overCod = computed(() => {
  if (!props.selectedOrder) return false;
  const cod = codFace();
  if (cod <= 0) return false;
  return (netRemitted.value + totalCourierCharge.value) > cod + 0.01;
});

async function handleConfirm() {
  if (
    !props.selectedOrder
    || netRemitted.value <= 0
    || overCod.value
    || !form.cashbookPointId
  ) {
    return;
  }

  const deliveryCharge = Math.max(0, Number(form.deliveryCharge) || 0);
  const codCharge = Math.max(0, Number(form.codCharge) || 0);

  previewLoading.value = true;
  try {
    const raw = await dropshipFinanceRepository.previewCourierPayInSettlement({
      orderId: props.selectedOrder.id,
      netAmount: netRemitted.value,
      deliveryCharge,
      codCharge,
    });
    const preview = parseDropshipCourierPayInSettlementPreview(raw);
    if (!preview?.success) {
      showErrorNotification(preview?.error ?? 'Could not preview pay in settlement.');
      return;
    }
    const confirmed = await requestDropshipCourierPayInConfirmation(preview, {
      orderNo: props.selectedOrder.orderNo,
    });
    if (!confirmed) return;
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Pay in preview failed.');
    return;
  } finally {
    previewLoading.value = false;
  }

  emit('submit', {
    orderId: props.selectedOrder.id,
    netAmount: netRemitted.value,
    courierCharge: totalCourierCharge.value,
    deliveryCharge,
    codCharge,
    remittanceRef: form.remittanceRef,
    bankTrxId: form.bankTrxId,
    cashbookPointId: form.cashbookPointId,
  });
}
</script>

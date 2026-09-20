<template>
  <q-page class="q-pa-xs page-fixed-layout column no-wrap overflow-hidden collect-page">
    <div class="q-pa-md bg-grey-1 border-bottom row items-center justify-between no-wrap flex-shrink-0">
      <div class="row items-center q-gutter-sm no-wrap">
        <q-btn
          flat
          round
          dense
          icon="ph ph-arrow-left"
          color="grey-7"
          aria-label="Back to payments"
          @click="goBack"
        />
        <q-avatar size="38px" color="primary" text-color="white" square class="rounded-avatar">
          <q-icon name="ph ph-buildings" size="22px" />
        </q-avatar>
        <div>
          <div class="text-subtitle1 text-weight-bold text-grey-9 leading-tight">{{ headerName }}</div>
          <div class="text-caption text-grey-6 flex items-center q-gutter-x-xs">
            <span>{{ headerCode }}</span>
            <span>•</span>
            <span>{{ invoices.length }} Open Invoice{{ invoices.length === 1 ? '' : 's' }}</span>
          </div>
        </div>
      </div>

      <div class="row items-center q-gutter-x-md no-wrap">
        <div class="text-right">
          <div class="text-2xs text-grey-6 text-uppercase">Total Invoiced</div>
          <div class="text-caption font-mono text-weight-bold text-grey-8">৳{{ formatCurrency(totalInvoiced) }}</div>
        </div>
        <q-separator vertical style="height: 24px" />
        <div class="text-right">
          <div class="text-2xs text-grey-6 text-uppercase">Already Paid</div>
          <div class="text-caption font-mono text-weight-bold text-positive">৳{{ formatCurrency(totalPaid) }}</div>
        </div>
        <q-separator vertical style="height: 24px" />
        <div class="text-right">
          <div class="text-2xs text-grey-6 text-uppercase text-weight-bold">Current Due</div>
          <div class="text-h6 font-mono text-weight-bolder text-negative leading-tight">
            ৳{{ formatCurrency(totalDue) }}
          </div>
        </div>
        <q-btn
          flat
          no-caps
          color="grey-8"
          icon="ph ph-clock-counter-clockwise"
          label="History"
          class="rounded-btn q-ml-sm"
          @click="historyOpen = true"
        />
      </div>
    </div>

    <div class="col row no-wrap overflow-hidden">
      <div class="col-12 col-md-5 column no-wrap border-right bg-white">
        <div class="q-pa-md column q-gutter-sm col scroll">
          <div class="row items-center justify-between">
            <div>
              <div class="text-subtitle2 text-weight-bold text-grey-9">This visit</div>
              <div class="text-h6 font-mono text-weight-bolder text-primary leading-tight">
                ৳{{ formatCurrency(instrumentTotal) }}
              </div>
              <div class="text-2xs text-grey-6">Money received now — separate lines per cheque or transfer.</div>
            </div>
            <div class="row items-center q-gutter-x-xs">
              <q-btn
                flat
                dense
                no-caps
                size="sm"
                label="Pay full due"
                color="primary"
                class="text-weight-bold rounded-xs"
                @click="setFullAmount"
              />
              <q-btn flat dense no-caps size="sm" label="Clear" color="grey-6" class="rounded-xs" @click="clearAmounts" />
            </div>
          </div>

          <PaymentInstrumentLinesEditor
            v-model="instrumentLines"
            title="Each payment (separate amount)"
            @validation-change="onInstrumentValidation"
          />
        </div>
      </div>

      <div class="col-12 col-md-7 column no-wrap bg-grey-50">
        <div class="q-pa-md col scroll">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm">Open bills</div>
        <div v-if="isLoading" class="row flex-center q-pa-xl">
          <q-spinner-dots size="36px" color="primary" />
        </div>

        <div v-else-if="!invoices.length" class="row flex-center text-grey-6 q-py-lg">
          No open invoices for this customer.
        </div>

        <div v-else class="column q-gutter-y-xs">
          <div class="row items-center justify-between text-2xs text-weight-bold text-grey-6 text-uppercase q-px-xs q-mb-2xs">
            <div>Invoice & Outlet Details</div>
            <div>Payment Allocation</div>
          </div>

          <div
            v-for="inv in invoices"
            :key="inv.id"
            class="invoice-settle-card q-pa-sm bg-white rounded-borders border"
            :class="{ 'invoice-card-settled': (inv.allocated_amount || 0) >= inv.due_amount && (inv.allocated_amount || 0) > 0 }"
          >
            <div class="row items-center justify-between no-wrap">
              <div class="col-grow">
                <div class="row items-center q-gutter-x-xs no-wrap">
                  <span class="font-mono text-weight-bolder text-primary">{{ inv.invoice_no }}</span>
                  <q-badge color="grey-2" text-color="grey-8" class="text-2xs" style="border-radius: 4px">
                    {{ inv.invoice_type }}
                  </q-badge>
                  <span class="text-caption text-grey-5">•</span>
                  <span class="text-caption text-grey-7">{{ inv.branch_name }}</span>
                  <q-badge
                    v-if="inv.paid_amount > 0"
                    color="amber-1"
                    text-color="amber-9"
                    class="text-2xs text-weight-bold q-ml-2xs"
                    style="border-radius: 4px"
                  >
                    Partial (৳{{ formatCurrency(inv.paid_amount) }} paid)
                  </q-badge>
                </div>
                <div class="text-2xs text-grey-5 q-mt-3xs">
                  Issued: {{ inv.invoice_date }} • Due: {{ inv.due_date || 'N/A' }}
                </div>
              </div>

              <div class="col-auto text-right q-px-md font-mono">
                <div class="text-2xs text-grey-5">
                  Total: ৳{{ formatCurrency(inv.total_amount) }}
                  <span v-if="inv.paid_amount > 0" class="text-positive text-weight-bold q-ml-2xs">
                    (৳{{ formatCurrency(inv.paid_amount) }} paid)
                  </span>
                </div>
                <div class="text-body2 text-weight-bold text-negative">
                  Still Due: ৳{{ formatCurrency(inv.due_amount) }}
                </div>
              </div>

              <div class="col-auto row items-center q-gutter-x-xs no-wrap">
                <q-input
                  v-model.number="inv.allocated_amount"
                  type="number"
                  dense
                  outlined
                  placeholder="0"
                  style="width: 120px"
                  class="bg-white"
                  input-class="text-right font-mono text-weight-bolder text-positive"
                  :min="0"
                  :max="inv.due_amount"
                >
                  <template #append>
                    <q-btn
                      flat
                      dense
                      size="xs"
                      label="Max"
                      color="primary"
                      class="text-weight-bold"
                      @click="setLineMax(inv)"
                    />
                  </template>
                </q-input>

                <div style="width: 110px" class="text-center">
                  <q-badge
                    v-if="(inv.allocated_amount || 0) >= inv.due_amount && (inv.allocated_amount || 0) > 0"
                    color="positive"
                    text-color="white"
                    class="q-py-2xs q-px-xs text-weight-bold full-width"
                    style="border-radius: 6px"
                  >
                    Will Settle Due
                  </q-badge>
                  <q-badge
                    v-else-if="(inv.allocated_amount || 0) > 0"
                    color="primary"
                    text-color="white"
                    class="q-py-2xs q-px-xs text-weight-bold full-width"
                    style="border-radius: 6px"
                  >
                    +৳{{ formatCurrency(inv.allocated_amount || 0) }}
                  </q-badge>
                  <span v-else class="text-2xs text-grey-5 font-mono">No payment</span>
                </div>
              </div>
            </div>

            <div class="row items-center justify-between q-mt-xs pt-xs border-top-dashed text-2xs">
              <div class="row items-center q-gutter-x-xs">
                <q-checkbox
                  v-model="inv.is_write_off_enabled"
                  dense
                  size="xs"
                  color="negative"
                  @update:model-value="onWriteOffToggle(inv)"
                />
                <span class="text-grey-7" :class="{ 'text-negative text-weight-bold': inv.is_write_off_enabled }">
                  Concession / Write-Off
                </span>
              </div>

              <div v-if="inv.is_write_off_enabled" class="row items-center q-gutter-x-xs">
                <q-input
                  v-model.number="inv.written_off_amount_input"
                  type="number"
                  dense
                  outlined
                  placeholder="Amount"
                  style="width: 90px"
                  class="bg-white"
                  input-class="text-right font-mono text-weight-bold text-negative"
                />
                <q-select
                  v-model="inv.written_off_reason"
                  :options="writeOffReasons"
                  dense
                  outlined
                  emit-value
                  map-options
                  style="font-size: 11px; width: 140px"
                  class="bg-white"
                />
              </div>

              <div class="font-mono text-grey-6">
                Remaining Due:
                <strong :class="getNewDue(inv) === 0 ? 'text-positive' : 'text-negative'">
                  ৳{{ formatCurrency(getNewDue(inv)) }}
                </strong>
              </div>
            </div>
          </div>
        </div>
        </div>
      </div>
    </div>

    <CustomerPaymentHistoryDrawer
      v-model="historyOpen"
      :customer-group-id="customerGroupId"
      :customer-name="headerName"
      :account-code="headerCode"
      @void-and-reenter="onVoidAndReenter"
    />

    <div class="q-pa-md bg-white border-top row items-center justify-between no-wrap flex-shrink-0">
      <div class="row items-center q-gutter-x-lg">
        <div>
          <div class="text-2xs text-grey-6 text-uppercase">Money received</div>
          <div class="text-subtitle1 font-mono text-weight-bolder text-primary leading-tight">
            ৳{{ formatCurrency(instrumentTotal) }}
          </div>
        </div>
        <q-separator vertical style="height: 28px" />
        <div>
          <div class="text-2xs text-grey-6 text-uppercase">Applied to Invoices</div>
          <div class="text-subtitle1 font-mono text-weight-bolder text-positive leading-tight">
            ৳{{ formatCurrency(totalAllocated) }}
          </div>
        </div>
        <q-separator vertical style="height: 28px" />
        <div>
          <div class="text-2xs text-grey-6 text-uppercase">Store credit leftover</div>
          <div class="text-subtitle1 font-mono text-weight-bolder text-orange-9 leading-tight">
            ৳{{ formatCurrency(storeCreditLeftover) }}
          </div>
        </div>
        <q-separator vertical style="height: 28px" />
        <div>
          <div class="text-2xs text-grey-6 text-uppercase">Concession / write-off</div>
          <div class="text-subtitle1 font-mono text-weight-bolder text-negative leading-tight">
            ৳{{ formatCurrency(totalWrittenOff) }}
          </div>
        </div>
        <q-separator vertical style="height: 28px" />
        <div>
          <div class="text-2xs text-grey-6 text-uppercase">Remaining Outstanding</div>
          <div
            class="text-subtitle1 font-mono text-weight-bolder leading-tight"
            :class="remainingDueTotal === 0 ? 'text-positive' : 'text-negative'"
          >
            ৳{{ formatCurrency(remainingDueTotal) }}
          </div>
        </div>
      </div>

      <div class="row items-center q-gutter-sm">
        <q-btn flat label="Cancel" color="grey-7" no-caps class="rounded-btn q-px-md" @click="goBack" />
        <q-btn
          unelevated
          color="primary"
          no-caps
          class="rounded-btn text-weight-bold q-px-lg"
          style="font-size: 14px; height: 40px"
          :loading="isSubmittingPayment"
          :disable="cannotPost"
          @click="submitPayment"
        >
          <q-icon name="ph ph-check-circle" size="18px" class="q-mr-xs" />
          <span>{{ postButtonLabel }}</span>
        </q-btn>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { usePayments } from '../composables/usePaymentsQuery';
import type { OpenInvoicePaymentItem } from '../types/paymentsTypes';
import PaymentInstrumentLinesEditor from 'src/modules/wallet/components/PaymentInstrumentLinesEditor.vue';
import CustomerPaymentHistoryDrawer from '../components/CustomerPaymentHistoryDrawer.vue';
import {
  createPaymentInstrumentLine,
  localPaymentDate,
  mapInstrumentLinesToPayload,
  type PaymentInstrumentLineForm,
} from 'src/modules/wallet/utils/paymentInstruments';

const $q = useQuasar();
const route = useRoute();
const router = useRouter();

const { tenantId, customerGroups, fetchGroupInvoices, recordPayment, isSubmittingPayment } = usePayments();

const writeOffReasons = [
  { label: 'Dispute settlement', value: 'dispute_settlement' },
  { label: 'Bad debt', value: 'bad_debt' },
  { label: 'Currency rounding', value: 'currency_rounding' },
  { label: 'Management concession', value: 'management_concession' },
];

const invoices = ref<OpenInvoicePaymentItem[]>([]);
const isLoading = ref(false);
const instrumentLines = ref<PaymentInstrumentLineForm[]>([createPaymentInstrumentLine()]);
const instrumentTotal = ref(0);
const instrumentValid = ref(true);
const historyOpen = ref(false);

const customerGroupId = computed(() => Number(route.params.customerGroupId));
const focusInvoiceId = computed(() => {
  const raw = route.query.invoiceId;
  const n = Number(Array.isArray(raw) ? raw[0] : raw);
  return Number.isFinite(n) && n > 0 ? n : null;
});

const matchedGroup = computed(() => customerGroups.value.find((g) => g.id === customerGroupId.value) ?? null);

const headerName = computed(
  () => matchedGroup.value?.name || invoices.value[0]?.customer_group_name || 'Customer',
);
const headerCode = computed(() => matchedGroup.value?.account_code || '—');
const useLiveInvoiceTotals = computed(() => invoices.value.length > 0);

const totalInvoiced = computed(() =>
  useLiveInvoiceTotals.value
    ? invoices.value.reduce((s, i) => s + i.total_amount, 0)
    : (matchedGroup.value?.total_invoiced ?? 0),
);
const totalPaid = computed(() =>
  useLiveInvoiceTotals.value
    ? invoices.value.reduce((s, i) => s + i.paid_amount, 0)
    : (matchedGroup.value?.total_paid ?? 0),
);
const totalDue = computed(() =>
  useLiveInvoiceTotals.value
    ? invoices.value.reduce((s, i) => s + i.due_amount, 0)
    : (matchedGroup.value?.total_due ?? 0),
);

const totalAllocated = computed(() => invoices.value.reduce((s, i) => s + (i.allocated_amount || 0), 0));
const totalWrittenOff = computed(() =>
  invoices.value.reduce((s, i) => s + (i.is_write_off_enabled ? i.written_off_amount_input || 0 : 0), 0),
);
const remainingDueTotal = computed(() => invoices.value.reduce((s, i) => s + getNewDue(i), 0));
const storeCreditLeftover = computed(() =>
  Math.max(0, instrumentTotal.value - totalAllocated.value),
);
const hasCashReceived = computed(() => instrumentTotal.value > 0);
const hasWriteOff = computed(() => totalWrittenOff.value > 0);

const writeOffInvalid = computed(() =>
  invoices.value.some((inv) => {
    if (!inv.is_write_off_enabled) return false;
    const amount = inv.written_off_amount_input || 0;
    const maxWriteOff = Math.max(0, inv.due_amount - (inv.allocated_amount || 0));
    return amount <= 0 || amount > maxWriteOff;
  }),
);

const cannotPost = computed(() => {
  if (!hasCashReceived.value && !hasWriteOff.value) return true;
  if (hasCashReceived.value) {
    if (!instrumentValid.value || instrumentTotal.value < totalAllocated.value) return true;
    if (totalAllocated.value === 0 && !hasWriteOff.value) return true;
  }
  if (hasWriteOff.value && writeOffInvalid.value) return true;
  return false;
});

const postButtonLabel = computed(() => {
  if (hasCashReceived.value && hasWriteOff.value) {
    return `Post payment & concession (৳${formatCurrency(totalAllocated.value)} + ৳${formatCurrency(totalWrittenOff.value)})`;
  }
  if (hasWriteOff.value) {
    return `Save concession (৳${formatCurrency(totalWrittenOff.value)})`;
  }
  return `Post payment (৳${formatCurrency(totalAllocated.value)})`;
});

function goBack() {
  void router.push({ name: 'app-finance-payments-page' });
}

async function onVoidAndReenter() {
  historyOpen.value = false;
  await loadInvoices();
}

async function loadInvoices() {
  if (!customerGroupId.value) return;
  isLoading.value = true;
  instrumentLines.value = [createPaymentInstrumentLine()];
  instrumentTotal.value = 0;
  instrumentValid.value = true;
  try {
    const invs = await fetchGroupInvoices(customerGroupId.value);
    invoices.value = invs.map((i) => ({
      ...i,
      allocated_amount: 0,
      is_write_off_enabled: false,
      written_off_amount_input: 0,
      written_off_reason: 'dispute_settlement',
    }));

    const focus = focusInvoiceId.value
      ? invoices.value.find((i) => i.id === focusInvoiceId.value)
      : null;
    if (focus) {
      instrumentLines.value = [{ ...createPaymentInstrumentLine(), amount: focus.due_amount }];
      instrumentTotal.value = focus.due_amount;
      focus.allocated_amount = focus.due_amount;
    }
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: `Failed to load invoices: ${(err as Error).message}`,
      position: 'top-right',
    });
  } finally {
    isLoading.value = false;
  }
}

watch(customerGroupId, () => {
  void loadInvoices();
}, { immediate: true });

function setFullAmount() {
  const due = totalDue.value;
  instrumentLines.value = [{ ...createPaymentInstrumentLine(), amount: due }];
  instrumentTotal.value = due;
  applyFIFOAllocation(due);
}

function clearAmounts() {
  instrumentLines.value = [createPaymentInstrumentLine()];
  instrumentTotal.value = 0;
  invoices.value.forEach((inv) => {
    inv.allocated_amount = 0;
  });
}

function applyFIFOAllocation(receivedTotal?: number) {
  let remaining = Number(receivedTotal ?? instrumentTotal.value ?? 0);
  for (const inv of invoices.value) {
    const due = inv.due_amount - (inv.is_write_off_enabled ? inv.written_off_amount_input || 0 : 0);
    if (remaining >= due) {
      inv.allocated_amount = due;
      remaining -= due;
    } else {
      inv.allocated_amount = remaining;
      remaining = 0;
    }
  }
}

function setLineMax(inv: OpenInvoicePaymentItem) {
  inv.allocated_amount = inv.due_amount - (inv.is_write_off_enabled ? inv.written_off_amount_input || 0 : 0);
}

function onInstrumentValidation(payload: { valid: boolean; message: string | null; total: number }) {
  instrumentValid.value = payload.valid;
  instrumentTotal.value = payload.total;
  if (payload.total > 0 && !focusInvoiceId.value) {
    applyFIFOAllocation(payload.total);
  }
}

function onWriteOffToggle(inv: OpenInvoicePaymentItem) {
  if (inv.is_write_off_enabled) {
    inv.written_off_amount_input = Math.max(0, inv.due_amount - (inv.allocated_amount || 0));
  } else {
    inv.written_off_amount_input = 0;
  }
}

function getNewDue(inv: OpenInvoicePaymentItem) {
  const alloc = inv.allocated_amount || 0;
  const wo = inv.is_write_off_enabled ? inv.written_off_amount_input || 0 : 0;
  return Math.max(0, inv.due_amount - alloc - wo);
}

async function submitPayment() {
  if (!tenantId.value || !customerGroupId.value) return;

  const allocations = invoices.value
    .filter((inv) => (inv.allocated_amount || 0) > 0)
    .map((inv) => ({ invoice_id: inv.id, amount: inv.allocated_amount || 0 }));

  const writeOffs = invoices.value
    .filter((inv) => inv.is_write_off_enabled && (inv.written_off_amount_input || 0) > 0)
    .map((inv) => ({
      invoice_id: inv.id,
      amount: inv.written_off_amount_input || 0,
      reason: inv.written_off_reason || 'dispute_settlement',
    }));

  try {
    const res = await recordPayment({
      tenant_id: tenantId.value,
      customer_group_id: customerGroupId.value,
      amount: instrumentTotal.value,
      payment_date: localPaymentDate(),
      note: null,
      instruments: hasCashReceived.value ? mapInstrumentLinesToPayload(instrumentLines.value) : [],
      allocations,
      write_offs: writeOffs,
    });
    const successMessage = hasWriteOff.value && !hasCashReceived.value
      ? `Concession of ৳${formatCurrency(res.total_written_off)} saved.`
      : hasWriteOff.value
        ? `Payment and concession posted (৳${formatCurrency(res.total_amount)} + ৳${formatCurrency(res.total_written_off)}).`
        : `Payment of ৳${formatCurrency(res.total_amount)} posted successfully!`;
    $q.notify({
      type: 'positive',
      message: successMessage,
      position: 'top-right',
    });
    if (focusInvoiceId.value) {
      await router.replace({
        name: 'app-finance-payments-collect-page',
        params: { customerGroupId: String(customerGroupId.value) },
      });
    }
    await loadInvoices();
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: `Failed to post payment: ${(err as Error).message}`,
      position: 'top-right',
    });
  }
}

function formatCurrency(val: number) {
  return Number(val || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.border {
  border: 1px solid var(--q-separator-color, #e2e0db);
}

.border-bottom {
  border-bottom: 1px solid var(--q-separator-color, #e2e0db);
}

.border-right {
  border-right: 1px solid var(--q-separator-color, #e2e0db);
}

.border-top {
  border-top: 1px solid var(--q-separator-color, #e2e0db);
}

.border-top-dashed {
  border-top: 1px dashed #e2e0db;
}

.rounded-btn {
  border-radius: 8px;
}

.rounded-avatar {
  border-radius: 8px;
}

.rounded-xs {
  border-radius: 4px;
}

.text-2xs {
  font-size: 10px;
  line-height: 1.2;
}

.bg-grey-50 {
  background-color: #f8fafc;
}

.invoice-settle-card {
  border-radius: 8px;
}

.invoice-card-settled {
  background-color: #f0fdf4 !important;
  border-color: #bbf7d0 !important;
}
</style>

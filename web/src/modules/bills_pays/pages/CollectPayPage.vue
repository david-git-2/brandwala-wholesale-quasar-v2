<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="col overflow-auto">
      <div class="pay-form-card q-pa-md">
        <q-tabs
          v-model="payInKind"
          dense
          align="left"
          active-color="primary"
          indicator-color="primary"
          class="q-mb-sm"
          @update:model-value="onPayInKindChange"
        >
          <q-tab name="customer" label="Customer" />
          <q-tab name="courier" label="Courier" />
        </q-tabs>
        <q-separator class="q-mb-md" />

        <template v-if="payInKind === 'courier'">
          <div class="text-subtitle1 text-weight-bold">Pay in — courier</div>
          <p class="text-caption text-grey-7 q-ma-none q-mb-md">
            Net bank in from the courier (COD minus their charges). Pays the merchant B2B bill; shop profit goes to
            cashbook — use Pay out when you send money to the shop.
          </p>

          <template v-if="!courierSelectedOrder">
            <div v-if="courierLoading" class="text-grey-7 q-pa-md">Loading orders…</div>
            <q-list v-else-if="courierOrders.length" bordered separator class="rounded-borders collect-group-list">
              <q-item
                v-for="order in courierOrders"
                :key="order.id"
                clickable
                v-ripple
                @click="courierSelectedOrder = order"
              >
                <q-item-section>
                  <q-item-label class="text-weight-medium">{{ order.orderNo }}</q-item-label>
                  <q-item-label caption>
                    {{ order.shopName || order.customerName || '—' }}
                    · COD {{ formatAmountBdt(order.codCollectAmount) }}
                    · Bill due {{ formatAmountBdt(order.invoiceOutstanding ?? 0) }}
                  </q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-icon name="ph ph-caret-right" color="grey-6" />
                </q-item-section>
              </q-item>
            </q-list>
            <div v-else class="text-center text-grey-7 q-pa-lg">
              No dropship orders awaiting courier pay in.
            </div>
          </template>

          <template v-else>
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              icon="ph ph-arrow-left"
              label="Change order"
              class="q-mb-sm q-px-none"
              @click="courierSelectedOrder = null"
            />
            <FinanceHubStepRemittance
              :selected-order="courierSelectedOrder"
              :loading="courierSubmitting"
              variant="panel"
              context="payin"
              @submit="submitCourierPayIn"
            />
          </template>
        </template>

        <!-- Step 1: pick customer group -->
        <template v-else-if="!selectedGroupId">
          <div class="text-subtitle1 text-weight-bold">Pay in — customer</div>
          <p class="text-caption text-grey-7 q-ma-none q-mb-md">
            Money they pay you against your sales bills. Courier dropship uses the Courier tab. Vendor AP uses Pay out.
          </p>

          <q-input
            v-model="groupSearch"
            outlined
            dense
            label="Search customer group"
            debounce="300"
            class="q-mb-sm"
            @update:model-value="loadGroups"
          />
          <q-toggle
            v-model="onlyWithDue"
            dense
            label="Only with open bills"
            class="q-mb-md"
            @update:model-value="loadGroups"
          />

          <q-list v-if="groups.length" bordered separator class="rounded-borders collect-group-list">
            <q-item
              v-for="g in groups"
              :key="g.id"
              clickable
              v-ripple
              @click="selectGroup(g)"
            >
              <q-item-section avatar>
                <q-avatar color="primary" text-color="white" size="36px" font-size="14px">
                  {{ groupInitials(g.name) }}
                </q-avatar>
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ g.name }}</q-item-label>
                <q-item-label caption>
                  Due {{ formatAmountBdt(g.total_due) }} · {{ g.open_invoice_count }} open
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-icon name="ph ph-caret-right" color="grey-6" />
              </q-item-section>
            </q-item>
          </q-list>
          <div v-else class="text-center text-grey-7 q-pa-lg">
            No customer groups match. Try turning off “Only with open bills” or change your search.
          </div>
        </template>

        <!-- Step 2: receipt against selected group -->
        <template v-else-if="payInKind === 'customer'">
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-arrow-left"
            label="Change customer"
            class="q-mb-sm q-px-none"
            @click="changeCustomer"
          />

          <div class="collect-customer-banner q-pa-md q-mb-md">
            <div class="collect-customer-banner__title text-subtitle1 text-weight-bold">{{ selectedGroup?.name }}</div>
            <div class="collect-customer-banner__meta text-caption q-mt-xs">
              Total due {{ formatAmountBdt(selectedGroup?.total_due ?? 0) }}
              · {{ selectedGroup?.open_invoice_count ?? 0 }} open bill{{
                (selectedGroup?.open_invoice_count ?? 0) === 1 ? '' : 's'
              }}
            </div>
          </div>

          <q-select
            v-if="profiles.length > 1"
            v-model="billingProfileId"
            :options="profiles"
            option-value="id"
            option-label="name"
            emit-value
            map-options
            outlined
            dense
            label="Bill-to profile"
            class="q-mb-md"
          />
          <div v-else-if="profiles.length === 1" class="text-caption text-grey-7 q-mb-md">
            Bill-to: <span class="text-weight-medium text-grey-9">{{ profiles[0].name }}</span>
          </div>

          <template v-if="billingProfileId">
            <div class="row items-center justify-between q-mb-sm">
              <div class="text-subtitle2 text-weight-medium">Allocate to bills</div>
              <div class="row items-center q-gutter-xs">
                <q-btn
                  v-if="openBills.length"
                  flat
                  dense
                  no-caps
                  color="primary"
                  label="Fill oldest first"
                  :disable="!(cashAmount && cashAmount > 0)"
                  @click="fillOldestFirst"
                />
                <q-btn
                  v-if="selectedAllocTotal > 0"
                  flat
                  dense
                  no-caps
                  label="Clear"
                  @click="clearAllocations"
                />
                <span v-if="selectedAllocTotal > 0" class="text-caption text-grey-7">
                  {{ formatAmountBdt(selectedAllocTotal) }}
                </span>
              </div>
            </div>
            <p class="text-caption text-grey-7 q-mt-none q-mb-sm">
              Tick bills now, or post with none selected and apply leftover later from the payment.
            </p>

            <div v-if="loadingBills" class="flex flex-center q-pa-lg">
              <q-spinner color="primary" size="28px" />
            </div>
            <div v-else-if="!openBills.length" class="text-grey-7 q-pa-md text-center rounded-borders collect-empty-bills">
              No open bills for this profile.
            </div>
            <q-list v-else bordered separator class="rounded-borders q-mb-md collect-bill-list">
              <q-item v-for="bill in openBills" :key="bill.id" class="collect-bill-item">
                <q-item-section side top>
                  <q-checkbox
                    :model-value="bill.selected"
                    dense
                    @update:model-value="(v) => onBillSelected(bill, !!v)"
                  />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-weight-medium">{{ bill.invoice_no }}</q-item-label>
                  <q-item-label v-if="bill.sourceLabel" caption>{{ bill.sourceLabel }}</q-item-label>
                  <q-item-label caption>Due {{ formatAmountBdt(bill.due_amount) }}</q-item-label>
                </q-item-section>
                <q-item-section side top>
                  <q-input
                    v-model.number="bill.allocAmount"
                    type="number"
                    outlined
                    dense
                    label="Amount"
                    class="collect-alloc-input"
                    :disable="!bill.selected"
                  />
                </q-item-section>
              </q-item>
            </q-list>

            <q-separator class="q-mb-md" />

            <div class="text-subtitle2 text-weight-medium q-mb-sm">Payment</div>
            <div class="row q-col-gutter-sm q-mb-md">
              <div class="col-12 col-sm-6">
                <q-input v-model="receivedOn" outlined dense readonly label="Received on">
                  <template #append>
                    <q-icon name="ph ph-calendar" class="cursor-pointer">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-date v-model="receivedOn" mask="YYYY-MM-DD">
                          <div class="row items-center justify-end">
                            <q-btn v-close-popup label="Done" color="primary" flat no-caps />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
              </div>
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="methodCode"
                  :options="methodOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  label="Method"
                  :loading="loadingPaymentMeta"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="cashAmount"
                  outlined
                  dense
                  label="Amount received"
                  type="number"
                />
              </div>
              <div v-if="methodFieldFlags.showBank" class="col-12">
                <q-select
                  v-model="bdBankId"
                  :options="bdBankOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  :clearable="!methodFieldFlags.bankRequired"
                  :label="methodFieldFlags.bankLabel"
                  :loading="loadingPaymentMeta"
                  :rules="methodFieldFlags.bankRequired ? [(v) => v != null || 'Required'] : undefined"
                  hide-bottom-space
                />
              </div>
              <div v-if="methodFieldFlags.showChequeNumber" class="col-12 col-sm-6">
                <q-input
                  v-model="chequeNumber"
                  outlined
                  dense
                  :clearable="!methodFieldFlags.chequeNumberRequired"
                  label="Cheque number"
                  :rules="methodFieldFlags.chequeNumberRequired ? [(v) => !!String(v || '').trim() || 'Required'] : undefined"
                  hide-bottom-space
                />
              </div>
              <div v-if="methodFieldFlags.showInstrumentDate" class="col-12 col-sm-6">
                <q-input
                  v-model="instrumentDate"
                  outlined
                  dense
                  :clearable="!methodFieldFlags.instrumentDateRequired"
                  readonly
                  :label="methodFieldFlags.instrumentDateLabel"
                  :rules="methodFieldFlags.instrumentDateRequired ? [(v) => !!String(v || '').trim() || 'Required'] : undefined"
                  hide-bottom-space
                >
                  <template #append>
                    <q-icon name="ph ph-calendar" class="cursor-pointer">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-date v-model="instrumentDate" mask="YYYY-MM-DD">
                          <div class="row items-center justify-end">
                            <q-btn v-close-popup label="Done" color="primary" flat no-caps />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
              </div>
              <div v-if="methodFieldFlags.showInstrumentReference" class="col-12">
                <q-input
                  v-model="instrumentReference"
                  outlined
                  dense
                  clearable
                  :label="methodFieldFlags.instrumentReferenceLabel"
                  :hint="methodFieldFlags.bankOrReferenceRequired && !bdBankId && !instrumentReference.trim()
                    ? 'Bank or transaction reference is required'
                    : undefined"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model="reference" outlined dense clearable label="Payment reference (optional)" />
              </div>
              <div class="col-12">
                <q-input v-model="note" outlined dense label="Note (optional)" type="textarea" autogrow />
              </div>
            </div>

            <q-banner
              v-if="leftoverAmount > 0 && (cashAmount ?? 0) > 0"
              dense
              rounded
              class="bg-blue-1 text-blue-10 q-mb-md"
            >
              Leftover {{ formatAmountBdt(leftoverAmount) }} stays on this payment. Apply it to bills later.
            </q-banner>
            <q-banner
              v-if="allocOverCash"
              dense
              rounded
              class="bg-orange-1 text-orange-10 q-mb-md"
            >
              Allocations ({{ formatAmountBdt(selectedAllocTotal) }}) cannot exceed the payment amount.
            </q-banner>

            <span class="full-width inline-block">
              <q-btn
                unelevated
                color="primary"
                no-caps
                class="full-width"
                label="Post receipt"
                :loading="collectMutation.isPending.value"
                :disable="!canSubmit"
                @click="submit"
              />
              <q-tooltip v-if="submitDisabledReason">
                {{ submitDisabledReason }}
              </q-tooltip>
            </span>
          </template>
        </template>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { paymentsPageRoute } from '../utils/paymentsNavigation';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import FinanceHubStepRemittance from 'src/modules/shop_order/components/finance_hub/FinanceHubStepRemittance.vue';
import {
  dropshipFinanceRepository,
  type FinanceHubOrderQueueItem,
} from 'src/modules/shop_order/repositories/dropshipFinanceRepository';
import { isAwaitingCourierRemittance } from 'src/modules/shop_order/utils/isAwaitingCourierRemittance';
import { getInitials } from 'src/modules/sales_invoice/utils/invoiceListDisplay';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import { paysRepository, type CustomerGroupPaymentSummary } from '../repositories/paysRepository';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { useCollectPayMutation } from '../composables/useCollectPayMutation';
import {
  buildWholesalePaymentInstrument,
  paymentInstrumentExtrasBlockReason,
  paymentMethodFieldFlags,
} from '../utils/paymentInstrumentFields';
import { fifoFillByOldest } from '../utils/fifoBillAlloc';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const collectMutation = useCollectPayMutation();

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);

type PayInKind = 'customer' | 'courier';
const payInKind = ref<PayInKind>(route.query.mode === 'courier' ? 'courier' : 'customer');
const courierOrders = ref<FinanceHubOrderQueueItem[]>([]);
const courierSelectedOrder = ref<FinanceHubOrderQueueItem | null>(null);
const courierLoading = ref(false);
const courierSubmitting = ref(false);

const loadCourierQueue = async () => {
  if (!tenantId.value) return;
  courierLoading.value = true;
  try {
    const hub = await dropshipFinanceRepository.getHubData(tenantId.value);
    courierOrders.value = hub.orders.filter(isAwaitingCourierRemittance);
  } finally {
    courierLoading.value = false;
  }
};

const selectCourierOrderFromQuery = () => {
  const raw = route.query.orderId;
  const orderId = typeof raw === 'string' ? Number(raw) : Array.isArray(raw) ? Number(raw[0]) : NaN;
  if (!Number.isFinite(orderId) || orderId <= 0) return;
  const match = courierOrders.value.find((o) => o.id === orderId);
  if (match) courierSelectedOrder.value = match;
};

const onPayInKindChange = (kind: PayInKind) => {
  if (kind === 'courier') {
    void loadCourierQueue();
  } else {
    courierSelectedOrder.value = null;
  }
};

const submitCourierPayIn = async (payload: {
  orderId: number;
  netAmount: number;
  courierCharge: number;
  remittanceRef?: string;
  bankTrxId?: string;
}) => {
  courierSubmitting.value = true;
  try {
    await dropshipFinanceRepository.confirmCourierRemittance({
      orderId: payload.orderId,
      netAmount: payload.netAmount,
      courierCharge: payload.courierCharge,
      remittanceRef: payload.remittanceRef ?? `REMIT-${payload.orderId}`,
      bankTrxId: payload.bankTrxId,
    });
    showSuccessNotification('Courier pay in recorded.');
    goBack();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Courier pay in failed.');
  } finally {
    courierSubmitting.value = false;
  }
};
const parentTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return null;
  return t.parent_id ?? t.id;
});

const groupSearch = ref('');
const onlyWithDue = ref(true);
const groups = ref<CustomerGroupPaymentSummary[]>([]);
const selectedGroupId = ref<number | null>(null);
const selectedGroupSnapshot = ref<CustomerGroupPaymentSummary | null>(null);
const profiles = ref<Array<{ id: number; name: string }>>([]);
const billingProfileId = ref<number | null>(null);
const loadingBills = ref(false);

const selectedGroup = computed(
  () =>
    selectedGroupSnapshot.value ??
    groups.value.find((g) => g.id === selectedGroupId.value) ??
    null,
);

type BillAlloc = {
  id: number;
  invoice_no: string;
  invoice_date: string;
  due_amount: number;
  selected: boolean;
  allocAmount: number;
  sourceLabel: string | null;
};
const openBills = ref<BillAlloc[]>([]);

const receivedOn = ref(new Date().toISOString().slice(0, 10));
const reference = ref('');
const note = ref('');
const cashAmount = ref<number | null>(null);
const methodCode = ref('cash');
const loadingPaymentMeta = ref(false);
const methodOptions = ref<Array<{ label: string; value: string; code: string; category: string }>>([]);
const bdBankOptions = ref<Array<{ label: string; value: number }>>([]);
const bdBankId = ref<number | null>(null);
const chequeNumber = ref('');
const instrumentDate = ref('');
const instrumentReference = ref('');

const selectedMethodMeta = computed(() => {
  const row = methodOptions.value.find((m) => m.value === methodCode.value);
  if (!row) return null;
  return { code: row.code, category: row.category };
});

const methodFieldFlags = computed(() => paymentMethodFieldFlags(selectedMethodMeta.value));

const loadPaymentMeta = async () => {
  loadingPaymentMeta.value = true;
  try {
    const [methods, banks] = await Promise.all([
      globalReferenceRepository.listPaymentMethods(),
      globalReferenceRepository.listBdBanks(),
    ]);
    methodOptions.value = methods
      .filter((m) => m.scope === 'bd' || m.scope === 'both')
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((m) => ({
        label: m.name,
        value: m.code.toLowerCase(),
        code: m.code.toUpperCase(),
        category: m.category,
      }));
    if (!methodOptions.value.some((m) => m.value === methodCode.value)) {
      methodCode.value = methodOptions.value.find((m) => m.value === 'cash')?.value ?? methodOptions.value[0]?.value ?? 'cash';
    }
    bdBankOptions.value = banks
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((b) => ({ label: b.name, value: b.id }));
  } finally {
    loadingPaymentMeta.value = false;
  }
};

const groupInitials = (name: string) => getInitials(name);

const loadGroups = async () => {
  if (!tenantId.value) return;
  groups.value = await paysRepository.listCustomerGroupsPaymentSummary(tenantId.value, {
    search: groupSearch.value,
    onlyWithDue: onlyWithDue.value,
  });
};

const resetInstrumentFields = () => {
  bdBankId.value = null;
  chequeNumber.value = '';
  instrumentDate.value = '';
  instrumentReference.value = '';
};

const resetReceiptForm = () => {
  openBills.value = [];
  billingProfileId.value = null;
  cashAmount.value = null;
  reference.value = '';
  note.value = '';
  resetInstrumentFields();
};

watch(methodCode, () => {
  resetInstrumentFields();
});

const changeCustomer = () => {
  selectedGroupId.value = null;
  selectedGroupSnapshot.value = null;
  profiles.value = [];
  resetReceiptForm();
};

const selectGroup = async (group: CustomerGroupPaymentSummary) => {
  selectedGroupId.value = group.id;
  selectedGroupSnapshot.value = group;
  resetReceiptForm();
  profiles.value = await paysRepository.listBillingProfilesForGroup(group.id);
  billingProfileId.value = profiles.value[0]?.id ?? null;
};

watch(billingProfileId, async (profileId) => {
  openBills.value = [];
  if (!profileId || !parentTenantId.value) return;
  loadingBills.value = true;
  try {
    const { data } = await invoiceRepository.listGlobalInvoices({
      parentTenantId: parentTenantId.value,
      billingProfileId: profileId,
      invoiceStatus: 'issued',
      quickFilter: 'unpaid',
      pageSize: 100,
    });
    openBills.value = data.map((b) => ({
      id: b.id,
      invoice_no: b.invoice_no,
      invoice_date: b.invoice_date,
      due_amount: b.due_amount,
      selected: false,
      allocAmount: b.due_amount,
      sourceLabel: b.source_context_label ?? null,
    }));
  } finally {
    loadingBills.value = false;
  }
});

const allocations = computed(() =>
  openBills.value
    .filter((b) => b.selected && b.allocAmount > 0)
    .map((b) => ({ bill_id: b.id, amount: Number(b.allocAmount) })),
);

const selectedAllocTotal = computed(() =>
  allocations.value.reduce((sum, row) => sum + row.amount, 0),
);

const leftoverAmount = computed(() =>
  Math.max(0, (cashAmount.value ?? 0) - selectedAllocTotal.value),
);

const remainingCashExcluding = (billId: number) => {
  const used = openBills.value
    .filter((b) => b.selected && b.id !== billId)
    .reduce((sum, b) => sum + (Number(b.allocAmount) || 0), 0);
  return Math.max(0, (cashAmount.value ?? 0) - used);
};

const onBillSelected = (bill: BillAlloc, selected: boolean) => {
  if (!selected) {
    bill.selected = false;
    bill.allocAmount = bill.due_amount;
    return;
  }
  const take = Math.min(bill.due_amount, remainingCashExcluding(bill.id));
  if (take <= 0) {
    bill.selected = false;
    bill.allocAmount = bill.due_amount;
    return;
  }
  bill.selected = true;
  bill.allocAmount = take;
};

watch(cashAmount, () => {
  let remaining = cashAmount.value ?? 0;
  for (const bill of openBills.value) {
    if (!bill.selected) continue;
    const take = Math.min(bill.due_amount, Number(bill.allocAmount) || 0, remaining);
    if (take <= 0) {
      bill.selected = false;
      bill.allocAmount = bill.due_amount;
    } else {
      bill.allocAmount = take;
      remaining -= take;
    }
  }
});

const allocOverCash = computed(
  () => selectedAllocTotal.value > (cashAmount.value ?? 0) && (cashAmount.value ?? 0) > 0,
);

const fillOldestFirst = () => {
  const cash = cashAmount.value ?? 0;
  if (cash <= 0) return;
  const filled = fifoFillByOldest(openBills.value, cash);
  openBills.value = openBills.value.map((bill) => {
    const take = filled.get(bill.id);
    if (take == null) {
      return { ...bill, selected: false, allocAmount: bill.due_amount };
    }
    return { ...bill, selected: true, allocAmount: take };
  });
};

const clearAllocations = () => {
  openBills.value = openBills.value.map((bill) => ({
    ...bill,
    selected: false,
    allocAmount: bill.due_amount,
  }));
};

const instrumentFields = computed(() => ({
  bdBankId: bdBankId.value,
  chequeNumber: chequeNumber.value,
  instrumentDate: instrumentDate.value,
  instrumentReference: instrumentReference.value,
}));

const submitDisabledReason = computed((): string | null => {
  if (!billingProfileId.value) return 'Select a billing profile';
  if ((cashAmount.value ?? 0) <= 0) return 'Enter an amount received';
  if (selectedAllocTotal.value > (cashAmount.value ?? 0)) {
    return 'Bill allocations cannot exceed the payment amount';
  }
  return paymentInstrumentExtrasBlockReason(methodFieldFlags.value, instrumentFields.value);
});

const canSubmit = computed(() => submitDisabledReason.value === null);

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push(paymentsPageRoute(tenantSlug, 'in'));
};

const submit = async () => {
  if (!billingProfileId.value || !canSubmit.value) return;
  await collectMutation.mutateAsync({
    tenantId: tenantId.value,
    billingProfileId: billingProfileId.value,
    receivedOn: receivedOn.value,
    note: note.value || null,
    reference: reference.value || null,
    instruments: [
      buildWholesalePaymentInstrument({
        payment_method_code: methodCode.value,
        amount: Number(cashAmount.value),
        instrument_reference: instrumentReference.value,
        bd_bank_id: bdBankId.value,
        cheque_number: chequeNumber.value,
        instrument_date: instrumentDate.value,
      }),
    ],
    allocations: allocations.value,
  });
  goBack();
};

void loadGroups();
void loadPaymentMeta();

onMounted(async () => {
  if (payInKind.value === 'courier') {
    await loadCourierQueue();
    selectCourierOrderFromQuery();
  }
});
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.pay-form-card {
  max-width: 720px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: 8px;
}
.collect-group-list {
  max-height: min(60vh, 520px);
  overflow: auto;
}
.collect-customer-banner {
  background: var(--bw-neutral-canvas);
  border: 1px solid var(--bw-neutral-border);
  border-radius: var(--bw-radius-sm, 8px);
  color: var(--bw-neutral-ink);
}
.collect-customer-banner__title {
  color: var(--bw-neutral-ink);
}
.collect-customer-banner__meta {
  color: var(--bw-neutral-muted);
}
.collect-empty-bills {
  border: 1px dashed var(--bw-neutral-border, #e7e1d8);
}
.collect-bill-list {
  max-height: min(40vh, 360px);
  overflow: auto;
}
.collect-alloc-input {
  width: 112px;
}
</style>

<template>
  <q-page class="q-pa-xs page-fixed-layout column no-wrap overflow-hidden payments-page">
    <q-card flat bordered class="q-pa-xs flex-shrink-0 q-mb-xs">
      <div class="row items-center q-col-gutter-xs">
        <div class="col-12 col-sm-auto">
          <div class="row items-center q-gutter-x-2xs quick-filter-toggle side-toggle">
            <q-btn
              v-for="sideTab in deskSideTabs"
              :key="sideTab.value"
              dense
              unelevated
              no-caps
              :color="deskSide === sideTab.value ? 'primary' : 'transparent'"
              :text-color="deskSide === sideTab.value ? 'white' : 'grey-8'"
              class="quick-filter-btn"
              @click="setDeskSide(sideTab.value)"
            >
              <q-icon :name="sideTab.icon" size="14px" class="q-mr-xs" />
              <span>{{ sideTab.label }}</span>
            </q-btn>
          </div>
        </div>
      </div>
    </q-card>

    <!-- Cash in -->
    <template v-if="deskSide === 'in'">
      <q-card flat bordered class="q-pa-xs flex-shrink-0 q-mb-xs">
        <div class="row items-center justify-between q-col-gutter-xs no-wrap">
          <div class="col-auto row items-center q-gutter-x-xs no-wrap">
            <div class="row items-center q-gutter-x-2xs quick-filter-toggle">
              <q-btn
                v-for="tab in cashInTabs"
                :key="tab.value"
                dense
                unelevated
                no-caps
                :color="paymentMode === tab.value ? 'primary' : 'transparent'"
                :text-color="paymentMode === tab.value ? 'white' : 'grey-8'"
                class="quick-filter-btn"
                @click="paymentMode = tab.value"
              >
                <q-icon :name="tab.icon" size="14px" class="q-mr-xs" />
                <span>{{ tab.label }}</span>
              </q-btn>
            </div>

            <q-separator v-if="paymentMode === 'customer' || paymentMode === 'invoice'" vertical class="q-mx-2xs" />

            <div
              v-if="paymentMode === 'customer'"
              class="row items-center q-gutter-x-2xs no-wrap"
            >
              <q-chip
                clickable
                dense
                :outline="customerGroupDueFilter !== 'with_due'"
                :color="customerGroupDueFilter === 'with_due' ? 'primary' : 'grey-4'"
                :text-color="customerGroupDueFilter === 'with_due' ? 'white' : 'grey-9'"
                @click="customerGroupDueFilter = 'with_due'"
              >
                With due
              </q-chip>
              <q-chip
                clickable
                dense
                :outline="customerGroupDueFilter !== 'all'"
                :color="customerGroupDueFilter === 'all' ? 'primary' : 'grey-4'"
                :text-color="customerGroupDueFilter === 'all' ? 'white' : 'grey-9'"
                @click="customerGroupDueFilter = 'all'"
              >
                All groups
              </q-chip>
            </div>

            <q-select
              v-if="paymentMode === 'invoice'"
              v-model="invoiceStatusFilter"
              :options="statusOptions"
              outlined
              dense
              emit-value
              map-options
              options-dense
              style="min-width: 120px"
              class="dense-filter-select"
            >
              <template #prepend>
                <q-icon name="ph ph-funnel" size="14px" class="text-grey-6" />
              </template>
            </q-select>
          </div>

          <div class="col-grow row items-center justify-end q-gutter-x-xs no-wrap">
            <div class="text-right q-mr-sm">
              <div class="text-2xs text-grey-6 text-uppercase text-weight-medium">Parent tenant cash</div>
              <div class="text-subtitle2 text-weight-bold text-positive font-mono leading-tight">
                <q-spinner-dots v-if="isDashboardLoading" size="18px" color="positive" />
                <span v-else>৳{{ formatCurrency(tenantCashBalance) }}</span>
              </div>
            </div>

            <q-separator v-if="paymentMode !== 'courier'" vertical class="q-mx-xs" style="height: 28px" />

            <q-input
              v-if="paymentMode !== 'courier'"
              v-model="searchQuery"
              outlined
              rounded
              dense
              clearable
              style="min-width: 260px; max-width: 360px"
              class="col-grow col-sm-auto dense-search-input"
              :placeholder="
                paymentMode === 'customer'
                  ? 'Search customer, group, outlet...'
                  : 'Search invoice no, outlet, phone...'
              "
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-5" />
              </template>
            </q-input>

            <q-btn flat round dense icon="ph ph-arrow-clockwise" color="grey-7" @click="refetchAll">
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>
          </div>
        </div>
      </q-card>

      <div v-if="paymentMode === 'customer'" class="col column no-wrap overflow-hidden payments-desk-panel">
        <q-inner-loading :showing="isCustomerGroupsLoading" color="primary">
          <q-spinner-dots size="32px" />
        </q-inner-loading>

        <div
          v-if="!isCustomerGroupsLoading && customerGroups.length === 0"
          class="payments-desk-panel__empty text-grey-6 row flex-center q-gutter-xs"
        >
          <q-icon name="ph ph-users-three" size="28px" />
          <span>{{ customerGroupsEmptyMessage }}</span>
        </div>

        <q-scroll-area v-else class="col">
          <div class="payments-desk-cards">
            <q-card
              v-for="grp in customerGroups"
              :key="grp.id"
              v-ripple
              flat
              bordered
              clickable
              class="payments-desk-card"
              @click="goCollectGroup(grp)"
            >
              <q-card-section class="row items-start no-wrap q-pa-sm q-gutter-sm">
                <q-avatar color="primary" text-color="white" size="40px" font-size="14px">
                  {{ groupInitials(grp.name) }}
                </q-avatar>
                <div class="col min-width-0">
                  <div class="text-weight-medium text-primary">{{ grp.name }}</div>
                  <div class="text-caption font-mono text-grey-6">{{ grp.account_code }}</div>
                  <div v-if="grp.branches?.length" class="text-caption text-grey-7 q-mt-2xs">
                    {{ grp.branches.join(' · ') }}
                  </div>
                  <div class="row items-center q-gutter-xs q-mt-xs">
                    <q-badge color="grey-2" text-color="grey-9" class="text-weight-bold status-chip">
                      {{ grp.open_invoice_count }} open invoice{{ grp.open_invoice_count === 1 ? '' : 's' }}
                    </q-badge>
                    <span v-if="grp.total_paid > 0" class="text-caption text-positive">
                      Paid ৳{{ formatCurrency(grp.total_paid) }}
                    </span>
                  </div>
                </div>
                <div class="column items-end q-gutter-y-xs flex-shrink-0">
                  <div class="text-right">
                    <div class="text-2xs text-grey-6 text-uppercase">Due</div>
                    <div class="text-subtitle2 text-weight-bold text-negative font-mono">
                      ৳{{ formatCurrency(grp.total_due) }}
                    </div>
                  </div>
                  <div class="row items-center no-wrap q-gutter-x-xs">
                    <q-btn
                      flat
                      dense
                      round
                      size="sm"
                      color="grey-7"
                      icon="ph ph-clock-counter-clockwise"
                      aria-label="Payment history"
                      @click.stop="openHistory(grp)"
                    >
                      <q-tooltip>History</q-tooltip>
                    </q-btn>
                    <q-icon name="ph ph-caret-right" size="18px" class="text-grey-5" />
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </q-scroll-area>
      </div>

      <div v-else-if="paymentMode === 'invoice'" class="col column no-wrap overflow-hidden payments-desk-panel">
        <q-inner-loading :showing="isOpenInvoicesLoading" color="primary">
          <q-spinner-dots size="32px" />
        </q-inner-loading>

        <div
          v-if="!isOpenInvoicesLoading && filteredInvoices.length === 0"
          class="payments-desk-panel__empty text-grey-6 row flex-center q-gutter-xs"
        >
          <q-icon name="ph ph-receipt" size="28px" />
          <span>No open due invoices found.</span>
        </div>

        <q-scroll-area v-else class="col">
          <div class="payments-desk-cards">
            <q-card
              v-for="inv in filteredInvoices"
              :key="inv.id"
              v-ripple
              flat
              bordered
              clickable
              class="payments-desk-card"
              :class="getRowStatusClass(inv)"
              @click="goCollectInvoice(inv)"
            >
              <q-card-section class="q-pa-sm">
                <div class="row items-start justify-between no-wrap q-gutter-sm">
                  <div class="col min-width-0">
                    <div class="row items-center q-gutter-xs no-wrap">
                      <span class="font-mono text-weight-bold text-primary">{{ inv.invoice_no }}</span>
                      <q-badge color="grey-2" text-color="grey-8" class="text-2xs text-uppercase status-chip">
                        {{ inv.invoice_type }}
                      </q-badge>
                      <q-badge
                        :color="inv.paid_amount > 0 ? 'amber-1' : 'grey-2'"
                        :text-color="inv.paid_amount > 0 ? 'amber-9' : 'grey-8'"
                        class="text-uppercase text-weight-bold status-chip"
                      >
                        {{ inv.paid_amount > 0 ? 'Partial' : 'Due' }}
                      </q-badge>
                    </div>
                    <div class="text-weight-medium text-grey-9 q-mt-xs">{{ inv.customer_group_name }}</div>
                    <div v-if="inv.branch_name" class="text-caption text-grey-6">{{ inv.branch_name }}</div>
                    <div class="row q-gutter-md q-mt-sm text-caption text-grey-7 font-mono">
                      <span>Issued {{ inv.invoice_date }}</span>
                      <span
                        :class="isOverdue(inv.due_date) ? 'text-negative text-weight-bold' : ''"
                      >
                        Due {{ inv.due_date || '—' }}
                      </span>
                    </div>
                  </div>
                  <div class="column items-end flex-shrink-0">
                    <div class="text-2xs text-grey-6 text-uppercase">Balance due</div>
                    <div class="text-subtitle2 text-weight-bold text-negative font-mono">
                      ৳{{ formatCurrency(inv.due_amount) }}
                    </div>
                    <div class="text-caption text-grey-7 font-mono q-mt-xs">
                      Total ৳{{ formatCurrency(inv.total_amount) }}
                      <span v-if="inv.paid_amount > 0" class="text-positive">
                        · Paid ৳{{ formatCurrency(inv.paid_amount) }}
                      </span>
                    </div>
                    <q-icon name="ph ph-caret-right" size="18px" class="text-grey-5 q-mt-sm" />
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </q-scroll-area>
      </div>

      <div v-else class="col column no-wrap overflow-hidden payments-desk-panel">
        <q-inner-loading :showing="isHubLoading" color="primary">
          <q-spinner-dots size="32px" />
        </q-inner-loading>

        <div
          v-if="!isHubLoading && remittanceOrders.length === 0"
          class="payments-desk-panel__empty text-grey-6 row flex-center q-gutter-xs"
        >
          <q-icon name="ph ph-truck" size="28px" />
          <span>No delivered orders awaiting courier remittance.</span>
        </div>

        <q-scroll-area v-else class="col">
          <div class="payments-desk-cards">
            <q-card
              v-for="order in remittanceOrders"
              :key="order.id"
              v-ripple
              flat
              bordered
              clickable
              class="payments-desk-card"
              @click="selectRemittanceOrder(order)"
            >
              <q-card-section class="row items-center no-wrap q-pa-sm q-gutter-sm">
                <q-avatar color="primary" text-color="white" icon="ph ph-package" size="40px" />
                <div class="col min-width-0">
                  <div class="text-weight-bold text-primary">{{ order.orderNo }}</div>
                  <div v-if="order.shopName" class="text-caption text-grey-8">{{ order.shopName }}</div>
                  <div v-if="order.courierName" class="text-caption text-grey-6">
                    {{ order.courierName }}
                  </div>
                </div>
                <div class="column items-end flex-shrink-0 q-gutter-y-2xs">
                  <div class="text-right">
                    <div class="text-2xs text-grey-6 text-uppercase">COD face</div>
                    <div class="font-mono text-grey-8">৳{{ formatCurrency(order.codCollectAmount) }}</div>
                  </div>
                  <div class="text-right">
                    <div class="text-2xs text-grey-6 text-uppercase">Expected in</div>
                    <div class="text-subtitle2 text-weight-bold text-positive font-mono">
                      ৳{{ formatCurrency(expectedCourierRemittanceNet(order)) }}
                    </div>
                  </div>
                  <q-icon name="ph ph-caret-right" size="18px" class="text-grey-5" />
                </div>
              </q-card-section>
            </q-card>
          </div>
        </q-scroll-area>
      </div>
    </template>

    <!-- Cash out -->
    <template v-else>
      <q-card flat bordered class="q-pa-xs flex-shrink-0 q-mb-xs">
        <div class="row items-center justify-between q-col-gutter-xs no-wrap">
          <div class="col-auto row items-center q-gutter-x-xs no-wrap">
            <div class="row items-center q-gutter-x-2xs quick-filter-toggle">
            <q-btn
              dense
              unelevated
              no-caps
              color="primary"
              text-color="white"
              class="quick-filter-btn"
            >
              <q-icon name="ph ph-storefront" size="14px" class="q-mr-xs" />
              <span>Merchant payout</span>
            </q-btn>
            <q-btn dense unelevated no-caps disable class="quick-filter-btn" color="transparent" text-color="grey-6">
              <q-icon name="ph ph-dots-three" size="14px" class="q-mr-xs" />
              <span>Other (later)</span>
            </q-btn>
            </div>
            <q-separator vertical class="q-mx-2xs" style="height: 28px" />
            <q-chip
              clickable
              dense
              :outline="payoutBalanceFilter !== 'with_payable'"
              :color="payoutBalanceFilter === 'with_payable' ? 'positive' : 'grey-4'"
              :text-color="payoutBalanceFilter === 'with_payable' ? 'white' : 'grey-9'"
              @click="payoutBalanceFilter = 'with_payable'"
            >
              With wallet balance
            </q-chip>
            <q-chip
              clickable
              dense
              :outline="payoutBalanceFilter !== 'all'"
              :color="payoutBalanceFilter === 'all' ? 'positive' : 'grey-4'"
              :text-color="payoutBalanceFilter === 'all' ? 'white' : 'grey-9'"
              @click="payoutBalanceFilter = 'all'"
            >
              All groups
            </q-chip>
          </div>
          <div class="col-grow row items-center justify-end q-gutter-x-xs no-wrap">
            <div class="text-right q-mr-sm">
              <div class="text-2xs text-grey-6 text-uppercase text-weight-medium">Parent tenant cash</div>
              <div class="text-subtitle2 text-weight-bold text-positive font-mono leading-tight">
                <q-spinner-dots v-if="isDashboardLoading" size="18px" color="positive" />
                <span v-else>৳{{ formatCurrency(tenantCashBalance) }}</span>
              </div>
            </div>
            <q-btn flat round dense icon="ph ph-arrow-clockwise" color="grey-7" @click="refetchAll">
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>
          </div>
        </div>
      </q-card>

      <div class="col column no-wrap overflow-hidden">
        <payments-merchant-payout-panel
          ref="merchantPayoutPanelRef"
          :tenant-id="tenantId"
          :tenant-cash-balance="tenantCashBalance"
          :only-with-payable="payoutBalanceFilter === 'with_payable'"
          :preselected-customer-group-id="preselectedCustomerGroupId"
          :preselected-billing-profile-id="preselectedMerchantId"
          :loading="dispenseMiddlemanPayoutMutation.isPending.value"
          @submit="handleDispensePayout"
        />
      </div>
    </template>

    <q-drawer
      v-model="remittanceDrawerOpen"
      side="right"
      overlay
      elevated
      :width="520"
      class="courier-remittance-drawer bg-white"
    >
      <div class="column full-height">
        <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
          <div>
            <div class="text-subtitle1 text-weight-bold row items-center">
              <q-icon name="ph ph-truck" class="q-mr-xs text-primary" size="20px" />
              Courier remittance
            </div>
            <div v-if="selectedRemittanceOrder" class="text-caption text-grey-7">
              {{ selectedRemittanceOrder.orderNo }}
              <span v-if="selectedRemittanceOrder.shopName"> · {{ selectedRemittanceOrder.shopName }}</span>
            </div>
          </div>
          <q-btn
            icon="ph ph-x"
            flat
            round
            dense
            aria-label="Close remittance panel"
            @click="remittanceDrawerOpen = false"
          />
        </div>

        <div class="col scroll q-pa-md">
          <finance-hub-step-remittance
            v-if="selectedRemittanceOrder"
            variant="panel"
            :selected-order="selectedRemittanceOrder"
            :loading="confirmCourierRemittanceMutation.isPending.value"
            @submit="handleConfirmRemittance"
          />
        </div>
      </div>
    </q-drawer>

    <customer-payment-history-drawer
      v-if="historyGroup"
      v-model="historyOpen"
      :customer-group-id="historyGroup.id"
      :customer-name="historyGroup.name"
      :account-code="historyGroup.account_code"
      @void-and-reenter="onVoidAndReenter"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { usePayments } from '../composables/usePaymentsQuery';
import type { CustomerGroupPaymentSummary, OpenInvoicePaymentItem } from '../types/paymentsTypes';
import CustomerPaymentHistoryDrawer from '../components/CustomerPaymentHistoryDrawer.vue';
import { useDropshipFinanceHubQuery } from 'src/modules/shop_order/composables/useDropshipFinanceHubQuery';
import { useDropshipFinanceHubMutations } from 'src/modules/shop_order/composables/useDropshipFinanceHubMutations';
import type { FinanceHubOrderQueueItem } from 'src/modules/shop_order/repositories/dropshipFinanceRepository';
import { expectedCourierRemittanceNet } from 'src/modules/shop_order/utils/expectedCourierRemittanceNet';
import { isAwaitingCourierRemittance } from 'src/modules/shop_order/utils/isAwaitingCourierRemittance';
import FinanceHubStepRemittance from 'src/modules/shop_order/components/finance_hub/FinanceHubStepRemittance.vue';
import { useWalletAccounts } from '../composables/useWalletAccounts';
import PaymentsMerchantPayoutPanel from '../components/PaymentsMerchantPayoutPanel.vue';

type DeskSide = 'in' | 'out';
type CashInMode = 'customer' | 'invoice' | 'courier';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

const {
  searchQuery,
  customerGroupDueFilter,
  customerGroups,
  isCustomerGroupsLoading,
  openInvoices,
  isOpenInvoicesLoading,
  refetchAll: refetchPayments,
} = usePayments();

const { orders, isLoading: isHubLoading, refetch: refetchHub } = useDropshipFinanceHubQuery(tenantId);
const { confirmCourierRemittanceMutation, dispenseMiddlemanPayoutMutation } =
  useDropshipFinanceHubMutations(tenantId);

const { dashboardSummary, isDashboardLoading, refetchDashboard } = useWalletAccounts();

const tenantCashBalance = computed(() => dashboardSummary.value?.tenant_cash_total ?? 0);

const deskSide = ref<DeskSide>('in');
const paymentMode = ref<CashInMode>('customer');
const invoiceStatusFilter = ref('all');
const historyOpen = ref(false);
const historyGroup = ref<CustomerGroupPaymentSummary | null>(null);
const selectedRemittanceOrder = ref<FinanceHubOrderQueueItem | null>(null);
const remittanceDrawerOpen = ref(false);
const merchantPayoutPanelRef = ref<{
  closePayoutDrawer?: () => void;
  refreshGroups?: () => Promise<void>;
} | null>(null);
const preselectedMerchantId = ref<number | null>(null);
const preselectedCustomerGroupId = ref<number | null>(null);
const payoutBalanceFilter = ref<'with_payable' | 'all'>('with_payable');

const deskSideTabs = [
  { label: 'Cash in', value: 'in' as DeskSide, icon: 'ph ph-arrow-down-left' },
  { label: 'Cash out', value: 'out' as DeskSide, icon: 'ph ph-arrow-up-right' },
];

const cashInTabs = [
  { label: 'Customer', value: 'customer' as CashInMode, icon: 'ph ph-users-three' },
  { label: 'Invoice', value: 'invoice' as CashInMode, icon: 'ph ph-receipt' },
  { label: 'Courier remittance', value: 'courier' as CashInMode, icon: 'ph ph-truck' },
];

const statusOptions = [
  { label: 'All Open', value: 'all' },
  { label: 'Due Only', value: 'due' },
  { label: 'Partial Only', value: 'partial' },
];

const remittanceOrders = computed(() => orders.value.filter(isAwaitingCourierRemittance));

const customerGroupsEmptyMessage = computed(() =>
  customerGroupDueFilter.value === 'with_due'
    ? 'No customer groups with outstanding dues.'
    : 'No customer groups match your search.',
);

function syncFromRoute() {
  const side = route.query.side;
  deskSide.value = side === 'out' ? 'out' : 'in';

  const merchantId = route.query.merchantId;
  if (merchantId) {
    const parsed = Number(merchantId);
    preselectedMerchantId.value = Number.isFinite(parsed) ? parsed : null;
  }

  const groupId = route.query.customerGroupId;
  if (groupId) {
    const parsed = Number(groupId);
    preselectedCustomerGroupId.value = Number.isFinite(parsed) ? parsed : null;
  } else {
    preselectedCustomerGroupId.value = null;
  }
}

watch(() => [route.query.side, route.query.merchantId, route.query.customerGroupId], syncFromRoute, {
  immediate: true,
});

function setDeskSide(side: DeskSide) {
  deskSide.value = side;
  void router.replace({
    name: 'app-finance-payments-page',
    query: {
      ...route.query,
      side,
    },
  });
  void refetchDashboard();
}

const filteredInvoices = computed(() => {
  let list = openInvoices.value;
  if (invoiceStatusFilter.value === 'due') {
    list = list.filter((i) => i.paid_amount === 0);
  } else if (invoiceStatusFilter.value === 'partial') {
    list = list.filter((i) => i.paid_amount > 0);
  }
  return list;
});

function getRowStatusClass(inv: OpenInvoicePaymentItem) {
  if (inv.paid_amount > 0) return 'row-tint-partial';
  return 'row-tint-due';
}

function isOverdue(dueDate: string | null) {
  if (!dueDate) return false;
  return new Date(dueDate) < new Date();
}

function openHistory(grp: CustomerGroupPaymentSummary) {
  historyGroup.value = grp;
  historyOpen.value = true;
}

async function refetchAll() {
  refetchPayments();
  if (deskSide.value === 'in' || deskSide.value === 'out') {
    await refetchDashboard();
  }
  if (deskSide.value === 'out' || paymentMode.value === 'courier') {
    await refetchHub();
  }
}

function selectRemittanceOrder(order: FinanceHubOrderQueueItem) {
  selectedRemittanceOrder.value = order;
  remittanceDrawerOpen.value = true;
}

watch(remittanceDrawerOpen, (open) => {
  if (!open) {
    selectedRemittanceOrder.value = null;
  }
});

async function handleConfirmRemittance(payload: {
  orderId: number;
  netAmount: number;
  courierCharge: number;
  remittanceRef?: string;
  bankTrxId?: string;
}) {
  await confirmCourierRemittanceMutation.mutateAsync(payload);
  await refetchDashboard();
  await refetchHub();
  remittanceDrawerOpen.value = false;
}

async function handleDispensePayout(payload: {
  billingProfileId: number;
  amount: number;
  payoutMethod?: string;
  referenceNotes?: string;
}) {
  if (!tenantId.value) return;
  await dispenseMiddlemanPayoutMutation.mutateAsync({
    tenantId: tenantId.value,
    ...payload,
  });
  await refetchDashboard();
  await refetchHub();
  merchantPayoutPanelRef.value?.closePayoutDrawer?.();
  await merchantPayoutPanelRef.value?.refreshGroups?.();
}

function onVoidAndReenter(groupId: number) {
  historyOpen.value = false;
  refetchPayments();
  void router.push({
    name: 'app-finance-payments-collect-page',
    params: { customerGroupId: String(groupId) },
  });
}

function goCollectGroup(grp: CustomerGroupPaymentSummary) {
  void router.push({
    name: 'app-finance-payments-collect-page',
    params: { customerGroupId: String(grp.id) },
  });
}

function goCollectInvoice(inv: OpenInvoicePaymentItem) {
  if (!inv.customer_group_id) return;
  void router.push({
    name: 'app-finance-payments-collect-page',
    params: { customerGroupId: String(inv.customer_group_id) },
    query: { invoiceId: String(inv.id) },
  });
}

function formatCurrency(val: number) {
  return Number(val || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function groupInitials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.rounded-btn {
  border-radius: 8px;
}

.status-chip {
  border-radius: 6px;
  font-size: 11px;
}

.text-2xs {
  font-size: 10px;
  line-height: 1.2;
}

.quick-filter-toggle {
  background: rgba(0, 0, 0, 0.04);
  border-radius: 8px;
  padding: 2px;
}

.side-toggle .quick-filter-btn {
  padding: 6px 14px;
}

.quick-filter-btn {
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  padding: 4px 10px;
}

.dense-filter-select :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
  border-radius: 8px;
}

.dense-search-input :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
}

.row-tint-partial {
  box-shadow: inset 3px 0 0 #f59e0b;
}

.row-tint-due {
  box-shadow: inset 3px 0 0 #9ca3af;
}

.payments-desk-panel {
  min-height: 0;
  position: relative;
}

.payments-desk-panel__empty {
  padding: 2rem 1rem;
  text-align: center;
  border: 1px dashed var(--bw-neutral-border, #e2e8f0);
  border-radius: 8px;
}

.payments-desk-cards {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 4px;
}

.payments-desk-card {
  border-radius: 8px;
  background: var(--bw-theme-surface, #fff);
}

.min-width-0 {
  min-width: 0;
}
</style>

<template>
  <q-page class="tf-page dropship-mgmt-page page-fixed-layout column no-wrap overflow-hidden">
    <section class="column col no-wrap overflow-hidden q-gutter-y-sm dropship-mgmt-page__body">
      <app-page-header
        class="shrink-0"
        title="Dropship management"
        subtitle="Post-ship list — COD, fees, bills, delivered and returned actions"
        eyebrow="SHOP & ORDER"
      />

      <q-card flat bordered class="form-card q-pa-sm shrink-0">
        <div class="row items-center q-col-gutter-md">
          <div class="col-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              rounded
              clearable
              debounce="300"
              placeholder="Search order no, dropshipper, end customer..."
              @update:model-value="onSearchChange"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>

          <div class="col-12 col-sm-6 col-md-3">
            <q-select
              v-model="statusFilter"
              dense
              outlined
              emit-value
              map-options
              :options="statusOptions"
              label="Status"
              @update:model-value="onStatusChange"
            />
          </div>

          <div v-if="isParentTenant" class="col-12 col-sm-6 col-md-3">
            <q-select
              v-model="selectedChildTenantId"
              dense
              outlined
              emit-value
              map-options
              clearable
              :loading="childTenantsLoading"
              :options="childTenantOptions"
              label="Business"
            />
          </div>
        </div>
      </q-card>

      <q-card flat bordered class="form-card column col no-wrap overflow-hidden dropship-mgmt-table-card">
        <div v-if="loading" class="row justify-center q-py-xl">
          <q-spinner color="primary" size="3em" />
        </div>

        <template v-else>
          <div
            ref="tableScrollRef"
            class="col dropship-mgmt-list-scroll hide-native-scrollbar"
            @scroll="onTableScroll"
          >
            <q-markup-table flat :responsive="false" class="dropship-mgmt-list-table">
            <thead>
              <tr>
                <th class="text-left">Order</th>
                <th v-if="isParentTenant" class="text-left">Business</th>
                <th class="text-left">Dropshipper</th>
                <th class="text-left">End customer</th>
                <th class="text-left">Courier</th>
                <th class="text-right">COD</th>
                <th class="text-right">Collected COD</th>
                <th class="text-right">Delivery</th>
                <th class="text-right">COD rate</th>
                <th class="text-right">Dropshipper cost</th>
                <th class="text-left">Bills</th>
                <th class="text-right">Status</th>
                <th class="text-right dropship-mgmt-list-table__actions-col">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="displayOrders.length === 0">
                <td :colspan="actionColspan" class="text-center text-grey-6 q-py-lg">
                  No orders match your search or filter.
                </td>
              </tr>
              <tr
                v-for="order in displayOrders"
                :key="order.id"
                class="dropship-mgmt-list-row"
                :class="{ 'dropship-mgmt-list-row--highlight': order.id === highlightOrderId }"
                :style="rowAccentStyle(order.status)"
              >
                <td class="text-weight-medium">{{ order.order_no }}</td>
                <td v-if="isParentTenant">{{ order.tenant_name || '—' }}</td>
                <td>{{ order.customer_group_name || '—' }}</td>
                <td>{{ order.recipient_name || '—' }}</td>
                <td>
                  <div>{{ order.courier_name || '—' }}</div>
                  <div v-if="order.courier_awb_number" class="text-caption text-grey-7">
                    {{ order.courier_awb_number }}
                  </div>
                </td>
                <td class="text-right text-weight-medium">{{ formatMoney(order.cod_collect_amount) }}</td>
                <td class="text-right dropship-mgmt-money-cell">
                  <q-input
                    v-if="showSettlementEditors(order) && getRowEdit(order.id)"
                    v-model.number="rowEdits[order.id]!.collectedCod"
                    type="number"
                    min="0"
                    step="0.01"
                    dense
                    outlined
                    hide-bottom-space
                    class="dropship-mgmt-money-input"
                    input-class="text-right"
                    :disable="!canEditSettlement(order)"
                  >
                    <q-tooltip v-if="!canEditSettlement(order)">
                      Locked after payment received
                    </q-tooltip>
                  </q-input>
                  <span v-else>{{ formatMoney(order.collected_cod_amount ?? order.cod_collect_amount) }}</span>
                </td>
                <td class="text-right dropship-mgmt-money-cell">
                  <q-input
                    v-if="showSettlementEditors(order) && getRowEdit(order.id)"
                    v-model.number="rowEdits[order.id]!.delivery"
                    type="number"
                    min="0"
                    step="0.01"
                    dense
                    outlined
                    hide-bottom-space
                    class="dropship-mgmt-money-input"
                    input-class="text-right"
                    :disable="!canEditSettlement(order)"
                  />
                  <span v-else>{{ formatMoney(order.delivery_charge_amount) }}</span>
                </td>
                <td class="text-right dropship-mgmt-money-cell">
                  <q-input
                    v-if="showSettlementEditors(order) && getRowEdit(order.id)"
                    v-model.number="rowEdits[order.id]!.codRate"
                    type="number"
                    min="0"
                    step="0.01"
                    dense
                    outlined
                    hide-bottom-space
                    class="dropship-mgmt-money-input"
                    input-class="text-right"
                    :disable="!canEditSettlement(order)"
                  />
                  <span v-else>{{ formatMoney(order.cod_charge_amount) }}</span>
                </td>
                <td class="text-right text-weight-medium">{{ formatMoney(order.dropshipper_bill_amount) }}</td>
                <td class="dropship-mgmt-list-table__bills-cell">
                  <div
                    v-if="!order.global_invoice_id && !order.courier_ar_bill_id"
                    class="text-grey-6"
                  >
                    —
                  </div>
                  <div v-else class="column q-gutter-y-xs items-start">
                    <span
                      v-if="order.global_invoice_id"
                      class="dropship-mgmt-bill-link"
                    >
                      <q-btn
                        flat
                        dense
                        no-caps
                        color="primary"
                        size="sm"
                        class="q-px-xs"
                        :to="billLinkRoute(order.global_invoice_id)"
                        @click.stop
                      >
                        <q-icon name="ph ph-receipt" size="14px" class="q-mr-xs" />
                        Dropshipper
                      </q-btn>
                      <q-tooltip v-if="order.customer_invoice_no">
                        {{ order.customer_invoice_no }}
                      </q-tooltip>
                    </span>
                    <span
                      v-if="order.courier_ar_bill_id"
                      class="dropship-mgmt-bill-link"
                    >
                      <q-btn
                        flat
                        dense
                        no-caps
                        color="primary"
                        size="sm"
                        class="q-px-xs"
                        :to="billLinkRoute(order.courier_ar_bill_id)"
                        @click.stop
                      >
                        <q-icon name="ph ph-truck" size="14px" class="q-mr-xs" />
                        Courier
                      </q-btn>
                      <q-tooltip>Bill #{{ order.courier_ar_bill_id }}</q-tooltip>
                    </span>
                  </div>
                </td>
                <td class="text-right">
                  <q-badge :color="statusColor(order.status)" :label="statusLabel(order.status)" />
                </td>
                <td class="text-right dropship-mgmt-list-table__actions-col">
                  <div v-if="order.status === 'shipped'" class="row no-wrap justify-end q-gutter-xs">
                    <q-btn
                      dense
                      color="primary"
                      unelevated
                      no-caps
                      size="sm"
                      label="Delivered"
                      :loading="deliveringOrderId === order.id"
                      @click.stop="onMarkDelivered(order)"
                    />
                    <q-btn
                      dense
                      outline
                      color="negative"
                      no-caps
                      size="sm"
                      label="Returned"
                      @click.stop="onMarkReturned(order.id)"
                    />
                  </div>
                  <div
                    v-else-if="order.status === 'delivered'"
                    class="row no-wrap justify-end q-gutter-xs"
                  >
                    <q-btn
                      v-if="isRowDirty(order.id)"
                      dense
                      color="primary"
                      unelevated
                      no-caps
                      size="sm"
                      label="Save"
                      :loading="savingOrderId === order.id"
                      :disable="!canEditSettlement(order)"
                      @click.stop="onSaveSettlement(order)"
                    />
                    <q-btn
                      dense
                      outline
                      color="info"
                      unelevated
                      no-caps
                      size="sm"
                      label="Payment received"
                      :disable="!canConfirmPaymentReceived(order)"
                      :loading="paymentReceivedOrderId === order.id"
                      @click.stop="onPaymentReceived(order)"
                    >
                      <q-tooltip v-if="isRowDirty(order.id)">
                        Save settlement changes first
                      </q-tooltip>
                      <q-tooltip v-else-if="order.courier_remittance_ref">
                        Remittance already recorded
                      </q-tooltip>
                    </q-btn>
                  </div>
                  <span v-else class="text-grey-6">—</span>
                </td>
              </tr>
            </tbody>
            </q-markup-table>
          </div>
          <ExcelTableScrollFooter
            ref="scrollFooterRef"
            class="dropship-mgmt-scroll-footer shrink-0"
            :get-scroll-container="getTableScrollContainer"
          />
        </template>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { Dialog } from 'quasar';
import ExcelTableScrollFooter from 'src/components/ui/ExcelTableScrollFooter.vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import DropshipPaymentReceivedConfirmDialog from '../../components/DropshipPaymentReceivedConfirmDialog.vue';
import { dropshipFinanceRepository } from '../../repositories/dropshipFinanceRepository';
import {
  buildDropshipMgmtPaymentReceivedMoney,
  type DropshipMgmtPaymentReceivedMoney,
} from '../../utils/dropshipManagementPaymentReceived';
import { resolveMainCashbookPointId } from '../../utils/resolveMainCashbookPointId';
import { useChildTenantsQuery } from 'src/modules/procurement_stock/composables/useProcurementStockQuery';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import { billDetailRoute } from 'src/modules/finance/submodules/bills_pays/utils/billRoutes';
import { shopOrderService } from '../../services/shopOrderService';
import type { DropshipSettlementDraftPayload } from '../../types/dropshipManagementOrder';
import type { ShopOrder, ShopOrderStatus } from '../../types';

interface RowMoneyEdit {
  collectedCod: number;
  delivery: number;
  codRate: number;
}

const DROPSHIP_MANAGEMENT_STATUSES = [
  'shipped',
  'delivered',
  'payment_received',
  'reseller_paid',
  'returned',
] as const satisfies readonly ShopOrderStatus[];

type DropshipManagementStatusFilter = 'all' | (typeof DROPSHIP_MANAGEMENT_STATUSES)[number];

const EMPTY_SETTLEMENT_PAYLOAD: DropshipSettlementDraftPayload = {
  collected_cod_amount: 0,
  discount_company_pay: 0,
  return_reason_note: '',
  charge_lines: [],
};

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const loading = ref(false);
const orders = ref<ShopOrder[]>([]);
const searchQuery = ref('');
const statusFilter = ref<DropshipManagementStatusFilter>('all');
const selectedChildTenantId = ref<number | null>(null);
const deliveringOrderId = ref<number | null>(null);
const savingOrderId = ref<number | null>(null);
const paymentReceivedOrderId = ref<number | null>(null);
const rowEdits = ref<Record<number, RowMoneyEdit>>({});
const rowBaselines = ref<Record<number, RowMoneyEdit>>({});
const tableScrollRef = ref<HTMLElement | null>(null);
const scrollFooterRef = ref<InstanceType<typeof ExcelTableScrollFooter> | null>(null);

const getTableScrollContainer = () => tableScrollRef.value;

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '',
);

const highlightOrderId = computed(() => {
  const raw = route.query.highlightOrderId;
  if (raw == null || raw === '') return null;
  const id = Number(raw);
  return Number.isFinite(id) && id > 0 ? id : null;
});

const actionColspan = computed(() => (isParentTenant.value ? 13 : 12));

const tenantId = computed(() => authStore.tenantId as number | undefined);

const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return Number(t.parent_id ?? t.id);
});

const isParentTenant = computed(() => {
  if (!tenantId.value) return false;
  return Number(booksTenantId.value) === Number(tenantId.value);
});

const { data: childTenants, isLoading: childTenantsLoading } = useChildTenantsQuery(booksTenantId);

const childTenantOptions = computed(() => {
  const map = new Map<number, string>();
  for (const t of childTenants.value ?? []) {
    if (t.parent_id === booksTenantId.value) {
      map.set(t.id, t.name);
    }
  }
  for (const o of orders.value) {
    if (o.tenant_id && o.tenant_name && o.tenant_id !== booksTenantId.value) {
      map.set(o.tenant_id, o.tenant_name);
    }
  }
  return Array.from(map.entries()).map(([value, label]) => ({ label, value }));
});

const displayOrders = computed(() => {
  let list = orders.value;
  if (selectedChildTenantId.value != null) {
    list = list.filter((o) => o.tenant_id === selectedChildTenantId.value);
  }
  return list;
});

const statusOptions = [
  { label: 'All statuses', value: 'all' },
  { label: 'Shipped', value: 'shipped' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Payment received', value: 'payment_received' },
  { label: 'Dropshipper paid', value: 'reseller_paid' },
  { label: 'Returned', value: 'returned' },
] as const;

function resolveStatusPayload(filter: DropshipManagementStatusFilter): ShopOrderStatus[] {
  if (filter === 'all') return [...DROPSHIP_MANAGEMENT_STATUSES];
  return [filter];
}

const loadOrders = async () => {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const res = await shopOrderService.fetchDropshipStaffOrders(authStore.tenantId, {
      limit: 200,
      statuses: resolveStatusPayload(statusFilter.value),
      search: searchQuery.value.trim() || null,
    });
    orders.value = res.success && res.data ? res.data : [];
    seedRowEdits(orders.value);
    if (!res.success && res.error) {
      showErrorNotification(res.error);
    }
    await nextTick();
    requestAnimationFrame(() => scrollFooterRef.value?.updateThumb?.());
  } catch (err) {
    console.error('Failed to load dropship management orders:', err);
    showErrorNotification('Failed to load dropship management orders.');
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadOrders();
});

watch(
  () => authStore.tenantId,
  (nextTenantId) => {
    if (nextTenantId) void loadOrders();
  },
);

const onSearchChange = () => {
  void loadOrders();
};

const onStatusChange = () => {
  void loadOrders();
};

function onTableScroll() {
  scrollFooterRef.value?.updateThumb?.();
}

function formatMoney(amount: number | null | undefined): string {
  if (amount == null || !Number.isFinite(Number(amount))) return '—';
  return `৳${Number(amount).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function rowMoneyFromOrder(order: ShopOrder): RowMoneyEdit {
  return {
    collectedCod: Number(order.collected_cod_amount ?? order.cod_collect_amount ?? 0),
    delivery: Number(order.delivery_charge_amount ?? 0),
    codRate: Number(order.cod_charge_amount ?? 0),
  };
}

function seedRowEdits(list: ShopOrder[]) {
  const edits: Record<number, RowMoneyEdit> = {};
  const baselines: Record<number, RowMoneyEdit> = {};
  for (const order of list) {
    if (order.status !== 'delivered') continue;
    const snap = rowMoneyFromOrder(order);
    edits[order.id] = { ...snap };
    baselines[order.id] = { ...snap };
  }
  rowEdits.value = edits;
  rowBaselines.value = baselines;
}

function getRowEdit(orderId: number): RowMoneyEdit | undefined {
  return rowEdits.value[orderId];
}

function isRowDirty(orderId: number): boolean {
  const current = rowEdits.value[orderId];
  const base = rowBaselines.value[orderId];
  if (!current || !base) return false;
  return (
    current.collectedCod !== base.collectedCod
    || current.delivery !== base.delivery
    || current.codRate !== base.codRate
  );
}

/** Editable on list until order advances past delivered (e.g. payment_received). */
function showSettlementEditors(order: ShopOrder): boolean {
  return order.status === 'delivered';
}

function canEditSettlement(order: ShopOrder): boolean {
  return showSettlementEditors(order);
}

function billLinkRoute(billId: number) {
  return billDetailRoute(billId, tenantSlug.value || undefined);
}

function statusLabel(status: ShopOrderStatus): string {
  if (status === 'payment_received') return 'Payment received';
  if (status === 'reseller_paid') return 'Dropshipper paid';
  return status.charAt(0).toUpperCase() + status.slice(1);
}

function statusColor(status: ShopOrderStatus): string {
  const colors: Partial<Record<ShopOrderStatus, string>> = {
    shipped: 'amber-9',
    delivered: 'positive',
    payment_received: 'info',
    reseller_paid: 'primary',
    returned: 'negative',
  };
  return colors[status] ?? 'grey-7';
}

function rowAccentColor(status: ShopOrderStatus): string {
  const map: Partial<Record<ShopOrderStatus, string>> = {
    shipped: '#b45309',
    delivered: '#1a7f4b',
    payment_received: '#2563eb',
    reseller_paid: '#0d6b5c',
    returned: '#b83a3a',
  };
  return map[status] ?? '#64748b';
}

function rowAccentStyle(status: ShopOrderStatus) {
  const color = rowAccentColor(status);
  return {
    boxShadow: `inset 3px 0 0 ${color}`,
    background: `color-mix(in srgb, ${color} 8%, var(--tf-neutral-surface, #fff))`,
  };
}

async function onMarkDelivered(order: ShopOrder) {
  if (!authStore.tenantId || deliveringOrderId.value != null) return;
  const confirmed = await requestConfirmation(
    `Mark order ${order.order_no} as delivered?`,
    'Mark as delivered',
    'Mark delivered',
  );
  if (!confirmed) return;

  deliveringOrderId.value = order.id;
  try {
    const res = await shopOrderService.markDropshipOrderDelivered(
      authStore.tenantId,
      order.id,
      EMPTY_SETTLEMENT_PAYLOAD,
    );
    if (!res.success) {
      showErrorNotification(res.error ?? 'Failed to mark as delivered.');
      return;
    }
    showSuccessNotification('Order marked as delivered.');
    await loadOrders();
  } finally {
    deliveringOrderId.value = null;
  }
}

async function onSaveSettlement(order: ShopOrder) {
  if (!authStore.tenantId || savingOrderId.value != null) return;
  const edit = rowEdits.value[order.id];
  if (!edit || !isRowDirty(order.id)) return;
  if (!canEditSettlement(order)) {
    showErrorNotification('Settlement is locked after payment received.');
    return;
  }

  savingOrderId.value = order.id;
  try {
    const res = await shopOrderService.saveDropshipManagementListSettlement(
      authStore.tenantId,
      order.id,
      {
        collected_cod_amount: edit.collectedCod,
        delivery_charge_amount: edit.delivery,
        cod_charge_amount: edit.codRate,
      },
    );
    if (!res.success) {
      showErrorNotification(res.error ?? 'Failed to save settlement.');
      return;
    }
    showSuccessNotification('Settlement saved.');
    await loadOrders();
  } finally {
    savingOrderId.value = null;
  }
}

function settlementOverridesForOrder(order: ShopOrder): {
  collectedCod: number;
  delivery: number;
  codRate: number;
} {
  const edit = rowEdits.value[order.id];
  if (edit) {
    return { collectedCod: edit.collectedCod, delivery: edit.delivery, codRate: edit.codRate };
  }
  return rowMoneyFromOrder(order);
}

function canConfirmPaymentReceived(order: ShopOrder): boolean {
  if (order.status !== 'delivered') return false;
  if (isRowDirty(order.id)) return false;
  if (order.courier_remittance_ref) return false;
  return true;
}

function applyPaymentReceivedToList(
  orderId: number,
  remittanceRef: string,
  result: unknown,
): void {
  const idx = orders.value.findIndex((o) => o.id === orderId);
  if (idx === -1) return;
  const row = orders.value[idx];
  const remainder = Number(
    (result as { merchant_remainder?: number } | null)?.merchant_remainder ?? 0,
  );
  orders.value[idx] = {
    ...row,
    status: 'payment_received',
    courier_remittance_ref: remittanceRef,
    payout_settlement_status: remainder > 0 ? 'unpaid' : 'paid',
  };
}

function openPaymentReceivedDialog(money: DropshipMgmtPaymentReceivedMoney): Promise<boolean> {
  return new Promise((resolve) => {
    Dialog.create({
      component: DropshipPaymentReceivedConfirmDialog,
      componentProps: { money },
    })
      .onOk(() => resolve(true))
      .onCancel(() => resolve(false))
      .onDismiss(() => resolve(false));
  });
}

async function onPaymentReceived(order: ShopOrder) {
  if (!authStore.tenantId || paymentReceivedOrderId.value != null) return;
  if (!canConfirmPaymentReceived(order)) {
    if (isRowDirty(order.id)) {
      showErrorNotification('Save settlement changes before recording payment.');
    } else if (order.courier_remittance_ref) {
      showErrorNotification('Courier remittance already recorded for this order.');
    }
    return;
  }

  const overrides = settlementOverridesForOrder(order);
  const money = buildDropshipMgmtPaymentReceivedMoney(order, overrides);
  if (!(money.courierPaysTenant > 0)) {
    showErrorNotification('Courier net remittance must be positive.');
    return;
  }

  const confirmed = await openPaymentReceivedDialog(money);
  if (!confirmed) return;

  paymentReceivedOrderId.value = order.id;
  try {
  if (isRowDirty(order.id)) {
    const saveRes = await shopOrderService.saveDropshipManagementListSettlement(
      authStore.tenantId,
      order.id,
      {
        collected_cod_amount: overrides.collectedCod,
        delivery_charge_amount: overrides.delivery,
        cod_charge_amount: overrides.codRate,
      },
    );
    if (!saveRes.success) {
      showErrorNotification(saveRes.error ?? 'Failed to save settlement.');
      return;
    }
  }

  const cashbookPointId = await resolveMainCashbookPointId(booksTenantId.value);

  const remittanceRef = money.remittanceRef ?? `REMIT-${order.id}`;
  const result = await dropshipFinanceRepository.confirmCourierRemittance({
    orderId: order.id,
    netAmount: money.courierPaysTenant,
    deliveryCharge: money.delivery,
    codCharge: money.codRate,
    courierCharge: money.delivery + money.codRate,
    remittanceRef,
    cashbookPointId,
    note: money.remittanceNote,
  });

  const alreadyRecorded =
    Boolean((result as { already_recorded?: boolean } | null)?.already_recorded);
  if (!alreadyRecorded) {
    applyPaymentReceivedToList(order.id, remittanceRef, result);
  }
  showSuccessNotification(
    alreadyRecorded
      ? `Remittance already recorded for ${money.orderNo}.`
      : `Payment received for ${money.orderNo}.`,
  );
  await loadOrders();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Payment received failed.');
  } finally {
    paymentReceivedOrderId.value = null;
  }
}

async function onMarkReturned(orderId: number) {
  const confirmed = await requestConfirmation(
    'Mark this order as returned? You will choose return lines on the next screen.',
    'Mark as returned',
    'Continue',
  );
  if (!confirmed) return;

  void router.push({
    name: 'app-shop-dropship-return-page',
    params: { tenantSlug: route.params.tenantSlug, id: orderId },
  });
}
</script>

<script lang="ts">
export default {
  name: 'DropshipManagementPage',
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
}

.dropship-mgmt-page__body {
  flex: 1 1 0%;
  min-height: 0;
}

.dropship-mgmt-table-card {
  flex: 1 1 0%;
  overflow: hidden;
  min-height: 0;
}

.dropship-mgmt-list-scroll {
  flex: 1 1 0%;
  width: 100%;
  max-width: 100%;
  min-width: 0;
  min-height: 0;
  overflow-x: auto;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}

.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
  width: 0;
  height: 0;
}

.dropship-mgmt-scroll-footer {
  box-shadow: 0 -1px 0 rgba(0, 0, 0, 0.06);
}

.dropship-mgmt-list-scroll :deep(.q-markup-table) {
  overflow: visible;
  max-width: none;
}

.dropship-mgmt-list-scroll :deep(table) {
  width: max-content;
  min-width: 88rem;
  table-layout: auto;
}

.dropship-mgmt-list-scroll :deep(th),
.dropship-mgmt-list-scroll :deep(td) {
  white-space: nowrap;
}

.dropship-mgmt-list-scroll :deep(.dropship-mgmt-list-table__bills-cell),
.dropship-mgmt-list-scroll :deep(.dropship-mgmt-list-table__bills-cell *) {
  white-space: normal;
}

.dropship-mgmt-list-row:hover {
  filter: brightness(0.98);
}

.dropship-mgmt-list-row--highlight {
  outline: 2px solid rgba(var(--q-primary-rgb, 13, 107, 92), 0.35);
  outline-offset: -2px;
}

.dropship-mgmt-list-scroll thead tr th {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-chrome, #64748b);
}

.dropship-mgmt-list-table__bills-cell {
  min-width: 9rem;
  vertical-align: middle;
}

.dropship-mgmt-bill-link {
  display: inline-block;
  position: relative;
}

.dropship-mgmt-list-table__actions-col {
  min-width: 11rem;
  white-space: nowrap;
}

.dropship-mgmt-money-cell {
  min-width: 6.5rem;
  vertical-align: middle;
}

.dropship-mgmt-money-input {
  width: 6.25rem;
  max-width: 100%;
  margin-left: auto;
}

.dropship-mgmt-money-input :deep(.q-field__control) {
  min-height: 28px;
}
</style>
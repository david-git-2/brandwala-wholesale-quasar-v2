<template>
  <q-page class="q-pa-md thrift-invoice-details-page">
    <div class="q-gutter-y-md">
      <!-- Header Section -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn
              flat
              dense
              icon="ph ph-arrow-left"
              color="grey-7"
              :to="salesListPath"
              aria-label="Back to Sales"
            >
              <q-tooltip>Back to Sales</q-tooltip>
            </q-btn>
            <div>
              <div class="text-overline text-primary">Thrift / Sales</div>
              <h1 class="text-h5 text-weight-bold q-my-none row items-center q-gutter-x-sm">
                <span>{{ invoice?.invoiceNumber || 'Invoice Details' }}</span>
                <q-badge
                  v-if="invoice"
                  :color="invoiceStatusColor(invoice.status)"
                  :label="labelize(invoice.status)"
                />
                <q-badge
                  v-if="invoice"
                  outline
                  :color="saleChannelColor(invoice.saleChannel)"
                  :label="saleChannelLabel(invoice.saleChannel)"
                />
              </h1>
            </div>
          </div>
        </div>
        <div class="col-auto row q-gutter-sm items-center">
          <LearnMoreHelpBtn guide-id="thrift_sales" />
          <q-btn
            outline
            color="primary"
            no-caps
            icon="ph ph-printer"
            label="Print"
            :disable="!invoice"
            @click="openPrintPreview"
          />
          <template v-if="invoice?.status === 'ACTIVE'">
            <q-btn
              v-if="canRecordRemittance && canShowRemittance"
              color="primary"
              unelevated
              no-caps
              icon="ph ph-hand-coins"
              label="Record COD"
              :disable="!!reverting || remitting || updatingDelivery"
              @click="openRemittanceDialog()"
            />
            <q-btn
              v-if="canReturn || canForceReturn"
              outline
              color="warning"
              no-caps
              icon="ph ph-arrow-u-up-left"
              label="Return"
              :loading="reverting === 'RETURN'"
              :disable="!!reverting || remitting || updatingDelivery"
              @click="confirmRevert('RETURN')"
            />
            <q-btn
              v-if="canStaffMistake"
              outline
              color="negative"
              no-caps
              icon="ph ph-trash"
              label="Staff Mistake"
              :loading="reverting === 'STAFF_MISTAKE'"
              :disable="!!reverting || remitting || updatingDelivery"
              @click="confirmRevert('STAFF_MISTAKE')"
            />
          </template>
        </div>
      </section>

      <!-- Skeleton Loader -->
      <ThriftSalesInvoiceDetailsSkeleton v-if="loading" />

      <!-- Loaded Content -->
      <template v-else-if="invoice">
        <ThriftSalesInvoiceStatusTracks
          :sale-channel="invoice.saleChannel"
          :delivery-status="invoice.deliveryStatus"
          :payment-status="invoice.paymentStatus"
          :invoice-active="invoice.status === 'ACTIVE'"
          :can-update-delivery="canUpdateDelivery && !reverting"
          :can-record-remittance="canRecordRemittance && !reverting"
          :updating-delivery="updatingDelivery"
          :remitting="remitting"
          :target-delivery="targetDeliveryStatus"
          :target-payment="targetPaymentStatus"
          :allowed-delivery-next="allowedDeliveryNext"
          @select-delivery="advanceDelivery"
          @select-payment="onSelectPaymentStatus"
        />

        <div class="row q-col-gutter-md">
          <div class="col-12 col-lg-8 q-gutter-y-md">
            <q-card flat bordered>
              <q-card-section class="q-pb-none">
                <div class="text-subtitle1 text-weight-bold row items-center">
                  <q-icon name="ph ph-receipt" class="q-mr-xs text-primary" size="20px" />
                  Invoice Header
                </div>
              </q-card-section>
              <q-card-section>
                <div class="row q-col-gutter-md">
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Invoice #</div>
                    <div class="text-weight-bold">{{ invoice.invoiceNumber }}</div>
                  </div>
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Date</div>
                    <div class="text-weight-medium">{{ formatDate(invoice.date) }}</div>
                  </div>
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Cashier</div>
                    <div class="text-weight-medium">{{ invoice.createdBy || '—' }}</div>
                  </div>
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Invoice Status</div>
                    <q-badge
                      :color="invoiceStatusColor(invoice.status)"
                      :label="labelize(invoice.status)"
                    />
                  </div>
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Channel</div>
                    <q-badge
                      outline
                      :color="saleChannelColor(invoice.saleChannel)"
                      :label="saleChannelLabel(invoice.saleChannel)"
                    />
                  </div>
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Payment Method</div>
                    <q-badge outline color="grey-7" :label="labelize(invoice.paymentMethod)" />
                  </div>
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Customer</div>
                    <div class="text-weight-medium">
                      {{ invoice.customerName || 'Walk-in' }}
                    </div>
                    <div v-if="invoice.customerPhone" class="text-caption text-grey-7">
                      {{ invoice.customerPhone }}
                    </div>
                    <div
                      v-if="invoice.customerSecondaryPhone"
                      class="text-caption text-grey-7"
                    >
                      Alt: {{ invoice.customerSecondaryPhone }}
                    </div>
                  </div>
                  <div v-if="invoice.customerAddress" class="col-12">
                    <div class="text-caption text-grey-6">Address</div>
                    <div>{{ invoice.customerAddress }}</div>
                    <div
                      v-if="addressPartsLabel"
                      class="text-caption text-grey-7 q-mt-xs"
                    >
                      {{ addressPartsLabel }}
                    </div>
                  </div>
                  <div
                    v-if="invoice.status === 'ACTIVE' && returnEligibility"
                    class="col-12"
                  >
                    <q-banner dense rounded class="bg-grey-2 text-grey-9">
                      <template #avatar>
                        <q-icon
                          :name="
                            returnEligibility.withinWindow
                              ? 'ph ph-clock'
                              : 'ph ph-warning'
                          "
                          :color="returnEligibility.withinWindow ? 'primary' : 'warning'"
                        />
                      </template>
                      {{ returnEligibility.message }}
                    </q-banner>
                  </div>
                  <div v-if="invoice.revertedAt" class="col-12">
                    <div class="text-caption text-grey-6">Reverted</div>
                    <div>
                      {{ formatDate(invoice.revertedAt) }}
                      <span v-if="invoice.revertedBy"> · {{ invoice.revertedBy }}</span>
                      <span v-if="invoice.revertReason"> · {{ labelize(invoice.revertReason) }}</span>
                    </div>
                    <div v-if="invoice.revertNotes" class="text-caption text-grey-7">
                      {{ invoice.revertNotes }}
                    </div>
                  </div>
                  <div v-if="invoice.notes" class="col-12">
                    <div class="text-caption text-grey-6">Notes</div>
                    <div>{{ invoice.notes }}</div>
                  </div>
                </div>
              </q-card-section>
            </q-card>

            <q-card flat bordered>
              <q-card-section class="q-pb-none">
                <div class="text-subtitle1 text-weight-bold">
                  Line Items ({{ invoice.items.length }})
                </div>
              </q-card-section>
              <q-table
                flat
                :rows="invoice.items"
                :columns="itemColumns"
                row-key="id"
                hide-pagination
                :rows-per-page-options="[0]"
                class="thrift-table"
              >
                <template #body-cell-item="props">
                  <q-td :props="props">
                    <div class="text-weight-medium">
                      {{ props.row.stockName || `Stock #${props.row.stockId}` }}
                    </div>
                    <div v-if="props.row.barcode" class="text-caption text-grey-7">
                      {{ props.row.barcode }}
                    </div>
                  </q-td>
                </template>

                <template #body-cell-sellPrice="props">
                  <q-td :props="props" class="text-right">
                    {{ formatThriftAmount(props.row.sellPrice) }}
                  </q-td>
                </template>

                <template #body-cell-discountAmount="props">
                  <q-td :props="props" class="text-right">
                    {{ formatThriftAmount(props.row.discountAmount) }}
                  </q-td>
                </template>

                <template #body-cell-finalPrice="props">
                  <q-td :props="props" class="text-right text-weight-medium">
                    {{ formatThriftAmount(props.row.finalPrice) }}
                  </q-td>
                </template>
              </q-table>
            </q-card>
          </div>

          <div class="col-12 col-lg-4">
            <q-card flat bordered>
              <q-card-section>
                <div class="text-subtitle1 text-weight-bold q-mb-md">Summary</div>
                <div class="row justify-between q-mb-sm">
                  <span class="text-grey-7">Items</span>
                  <span class="text-weight-medium">{{ invoice.items.length }}</span>
                </div>
                <q-separator class="q-my-md" />
                <div class="row justify-between items-center">
                  <span class="text-subtitle1 text-weight-bold">Item total</span>
                  <span class="text-h6 text-weight-bold text-primary">
                    {{ formatThriftAmount(invoice.totalInvoiceAmount) }}
                  </span>
                </div>
                <template v-if="invoice.courierAmount > 0">
                  <q-separator class="q-my-md" />
                  <div class="row justify-between q-mb-sm text-body2">
                    <span class="text-grey-7">
                      Courier
                      <span class="text-caption">
                        ({{ invoice.courierPaidBy === 'CUSTOMER' ? 'customer' : 'shop' }})
                      </span>
                    </span>
                    <span>{{ formatThriftAmount(invoice.courierAmount) }}</span>
                  </div>
                  <div
                    v-if="invoice.courierPaidBy === 'SHOP'"
                    class="text-caption text-grey-6 q-mb-sm"
                  >
                    Shop expense — not charged to customer
                  </div>
                </template>
                <template v-if="invoice.codExpected != null">
                  <q-separator class="q-my-md" />
                  <div class="row justify-between items-center text-body2">
                    <span class="text-grey-8 text-weight-bold">COD expected</span>
                    <span class="text-weight-bold">
                      {{ formatThriftAmount(invoice.codExpected) }}
                    </span>
                  </div>
                  <div
                    v-if="invoice.codRemittedAmount != null && invoice.codRemittedAmount > 0"
                    class="row justify-between q-mt-sm text-caption text-grey-7"
                  >
                    <span>Remitted</span>
                    <span>{{ formatThriftAmount(invoice.codRemittedAmount) }}</span>
                  </div>
                  <div
                    v-if="invoice.codRemittedAt"
                    class="row justify-between q-mt-xs text-caption text-grey-6"
                  >
                    <span>Remitted at</span>
                    <span>{{ formatDate(invoice.codRemittedAt) }}</span>
                  </div>
                  <div
                    v-if="invoice.codRemittanceRef"
                    class="row justify-between q-mt-xs text-caption text-grey-6"
                  >
                    <span>Ref</span>
                    <span>{{ invoice.codRemittanceRef }}</span>
                  </div>
                  <q-btn
                    v-if="canRecordRemittance && canShowRemittance"
                    class="full-width q-mt-md"
                    color="primary"
                    outline
                    no-caps
                    icon="ph ph-hand-coins"
                    label="Record COD remittance"
                    :disable="remitting"
                    @click="openRemittanceDialog()"
                  />
                </template>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </template>

      <q-card v-else flat bordered class="q-pa-xl text-center">
        <q-icon name="ph ph-warning" size="48px" color="warning" class="q-mb-sm" />
        <div class="text-subtitle1 text-weight-medium">Invoice not found</div>
        <q-btn
          class="q-mt-md"
          color="primary"
          unelevated
          no-caps
          label="Back to Sales"
          :to="salesListPath"
        />
      </q-card>
    </div>

    <q-dialog
      v-model="remittanceDialogOpen"
      persistent
      @hide="targetPaymentStatus = null"
    >
      <q-card style="min-width: 360px; max-width: 440px">
        <q-card-section>
          <div class="text-h6">Record COD remittance</div>
          <div class="text-caption text-grey-7">
            Updates payment status only — does not post revenue again.
          </div>
        </q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <q-input
            v-model.number="remittanceForm.amount"
            type="number"
            dense
            outlined
            label="Amount remitted"
            min="0"
            step="0.01"
          />
          <q-input
            v-model="remittanceForm.date"
            dense
            outlined
            type="datetime-local"
            label="Remitted at"
          />
          <q-input
            v-model="remittanceForm.ref"
            dense
            outlined
            clearable
            label="Reference (optional)"
            placeholder="Statement / SMS / deposit ref"
          />
          <q-select
            v-model="remittanceForm.outcome"
            dense
            outlined
            emit-value
            map-options
            :options="remittanceOutcomeOptions"
            label="Outcome"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" color="grey-8" v-close-popup :disable="remitting" />
          <q-btn
            unelevated
            no-caps
            color="primary"
            label="Save remittance"
            :loading="remitting"
            @click="submitRemittance"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useQuasar, type QTableColumn } from 'quasar';
import LearnMoreHelpBtn from 'src/modules/help/components/LearnMoreHelpBtn.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { thriftSettingsRepository } from 'src/modules/thrift/settings/repositories/thriftSettingsRepository';
import { requestConfirmation, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import ThriftSalesInvoiceDetailsSkeleton from '../components/ThriftSalesInvoiceDetailsSkeleton.vue';
import ThriftSalesInvoiceStatusTracks from '../components/ThriftSalesInvoiceStatusTracks.vue';
import {
  useRecordThriftCodRemittanceMutation,
  useRevertThriftSalesInvoiceMutation,
  useUpdateThriftDeliveryStatusMutation,
} from '../composables/useThriftSalesMutations';
import { formatThriftActionableError } from 'src/modules/thrift/shared/utils/formatThriftActionableError';
import {
  thriftSalesRepository,
  type ThriftCodRemittanceOutcome,
  type ThriftDeliveryStatus,
  type ThriftSalesInvoiceDetail,
  type ThriftSalesRevertReason,
} from '../repositories/thriftSalesRepository';

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);
const { hasModuleAccess } = useModulePermissions();
const revertMutation = useRevertThriftSalesInvoiceMutation();
const remittanceMutation = useRecordThriftCodRemittanceMutation();
const deliveryMutation = useUpdateThriftDeliveryStatusMutation();

const canReturn = computed(() => hasModuleAccess('thrift_sales', 'return'));
const canForceReturn = computed(() => hasModuleAccess('thrift_sales', 'force_return'));
const canStaffMistake = computed(() => hasModuleAccess('thrift_sales', 'staff_mistake'));
const canRecordRemittance = computed(
  () =>
    hasModuleAccess('thrift_sales', 'create') || hasModuleAccess('thrift_sales', 'edit'),
);
const canUpdateDelivery = computed(
  () =>
    hasModuleAccess('thrift_sales', 'create') || hasModuleAccess('thrift_sales', 'return'),
);

const loading = ref(false);
const reverting = ref<ThriftSalesRevertReason | null>(null);
const remitting = ref(false);
const updatingDelivery = ref(false);
const targetDeliveryStatus = ref<string | null>(null);
const targetPaymentStatus = ref<string | null>(null);
const remittanceDialogOpen = ref(false);
const invoice = ref<ThriftSalesInvoiceDetail | null>(null);
const returnWindowDays = ref(30);

const remittanceForm = ref({
  amount: 0,
  date: '',
  ref: '',
  outcome: 'PAID' as ThriftCodRemittanceOutcome,
});

const remittanceOutcomeOptions = [
  { label: 'Paid', value: 'PAID' },
  { label: 'Keep pending', value: 'KEEP_PENDING' },
  { label: 'Written off', value: 'WRITTEN_OFF' },
];

const salesListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/sales`,
);

const invoiceId = computed(() => Number(route.params.invoiceId));

const addressPartsLabel = computed(() => {
  const parts = invoice.value?.customerAddressParts;
  if (!parts) return '';
  return [parts.thana, parts.district, parts.post_code].filter(Boolean).join(' · ');
});

const canShowRemittance = computed(
  () =>
    invoice.value?.status === 'ACTIVE' &&
    (invoice.value.paymentStatus || '').toUpperCase() === 'COD_PENDING',
);

const deliveryAdvanceOptions = computed(() => {
  const inv = invoice.value;
  if (!inv || inv.status !== 'ACTIVE' || inv.saleChannel !== 'ONLINE') return [];
  const current = (inv.deliveryStatus || 'PENDING') as ThriftDeliveryStatus;
  const all: Array<{ value: Exclude<ThriftDeliveryStatus, 'RETURNED'>; label: string }> = [
    { value: 'READY', label: 'Mark Ready' },
    { value: 'IN_TRANSIT', label: 'Mark In transit' },
    { value: 'DELIVERED', label: 'Mark Delivered' },
  ];
  if (current === 'PENDING') return all;
  if (current === 'READY') return all.filter((o) => o.value !== 'READY');
  if (current === 'IN_TRANSIT') return all.filter((o) => o.value === 'DELIVERED');
  return [];
});

const allowedDeliveryNext = computed(() =>
  deliveryAdvanceOptions.value.map((o) => o.value),
);

const returnEligibility = computed(() => {
  const inv = invoice.value;
  if (!inv || inv.status !== 'ACTIVE') return null;
  const days = returnWindowDays.value;
  if (days === 0) {
    return {
      withinWindow: false,
      message: 'Customer returns are disabled. Staff can force a return if needed.',
    };
  }
  const invoiceDate = new Date(inv.date);
  if (Number.isNaN(invoiceDate.getTime())) return null;
  const deadline = new Date(invoiceDate.getTime());
  deadline.setDate(deadline.getDate() + days);
  const withinWindow = Date.now() <= deadline.getTime();
  return {
    withinWindow,
    message: withinWindow
      ? `Return window: ${days} day(s) — open until ${deadline.toLocaleString()}.`
      : `Outside return window (${days} day(s) ended ${deadline.toLocaleString()}). Force required.`,
  };
});

const itemColumns: QTableColumn[] = [
  { name: 'item', label: 'Item', field: 'stockName', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'center' },
  { name: 'sellPrice', label: 'Sell', field: 'sellPrice', align: 'right' },
  { name: 'discountAmount', label: 'Discount', field: 'discountAmount', align: 'right' },
  { name: 'finalPrice', label: 'Final', field: 'finalPrice', align: 'right' },
];

function labelize(value: string): string {
  return (value || '—').replace(/_/g, ' ').toUpperCase();
}

function saleChannelLabel(channel: string): string {
  return channel === 'ONLINE' ? 'Online' : 'In-store';
}

function saleChannelColor(channel: string): string {
  return channel === 'ONLINE' ? 'primary' : 'grey-7';
}

function invoiceStatusColor(status: string): string {
  const s = (status || '').toUpperCase();
  if (s === 'ACTIVE') return 'positive';
  if (s === 'RETURNED') return 'warning';
  if (s === 'STAFF_MISTAKE') return 'negative';
  return 'grey';
}

function formatDate(value: string): string {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString();
}

async function advanceDelivery(
  next: Exclude<ThriftDeliveryStatus, 'RETURNED'>,
) {
  if (!tenantId.value || !invoice.value) return;
  updatingDelivery.value = true;
  targetDeliveryStatus.value = next;
  try {
    await deliveryMutation.mutateAsync({
      tenantId: tenantId.value,
      invoiceId: invoice.value.id,
      deliveryStatus: next,
      actor: authStore.user?.email || 'cashier',
    });
    showSuccessNotification(`Delivery set to ${labelize(next)}`);
    await loadInvoice();
  } catch (err: any) {
    showErrorNotification(
      formatThriftActionableError(err, 'Failed to update delivery status'),
    );
  } finally {
    updatingDelivery.value = false;
    targetDeliveryStatus.value = null;
  }
}

function toDatetimeLocalValue(date = new Date()): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function openRemittanceDialog(outcome: ThriftCodRemittanceOutcome = 'PAID') {
  const inv = invoice.value;
  if (!inv) return;
  remittanceForm.value = {
    amount: Number(inv.codExpected ?? inv.totalInvoiceAmount) || 0,
    date: toDatetimeLocalValue(),
    ref: inv.codRemittanceRef || '',
    outcome,
  };
  remittanceDialogOpen.value = true;
}

function onSelectPaymentStatus(status: 'PAID' | 'WRITTEN_OFF') {
  targetPaymentStatus.value = status;
  openRemittanceDialog(status === 'WRITTEN_OFF' ? 'WRITTEN_OFF' : 'PAID');
}

async function submitRemittance() {
  if (!tenantId.value || !invoice.value) return;
  const amount = Number(remittanceForm.value.amount);
  if (!Number.isFinite(amount) || amount < 0) {
    showErrorNotification('Remitted amount must be zero or greater.');
    return;
  }

  remitting.value = true;
  try {
    const remittedAt = remittanceForm.value.date
      ? new Date(remittanceForm.value.date).toISOString()
      : undefined;
    await remittanceMutation.mutateAsync({
      tenantId: tenantId.value,
      invoiceId: invoice.value.id,
      remittedAmount: amount,
      actor: authStore.user?.email || 'cashier',
      remittedAt,
      remittanceRef: remittanceForm.value.ref || undefined,
      outcome: remittanceForm.value.outcome,
    });
    showSuccessNotification('COD remittance recorded');
    remittanceDialogOpen.value = false;
    targetPaymentStatus.value = null;
    await loadInvoice();
  } catch (err: any) {
    showErrorNotification(
      formatThriftActionableError(err, 'Failed to record COD remittance'),
    );
  } finally {
    remitting.value = false;
    targetPaymentStatus.value = null;
  }
}

function openPrintPreview() {
  if (!invoiceId.value || Number.isNaN(invoiceId.value)) return;
  const previewRoute = router.resolve({
    name: 'thrift-sales-invoice-print-preview',
    params: {
      tenantSlug: tenantSlug.value || undefined,
      invoiceId: String(invoiceId.value),
    },
  });
  window.open(previewRoute.href, '_blank', 'noopener,noreferrer');
}

async function loadInvoice() {
  if (!tenantId.value || !invoiceId.value || Number.isNaN(invoiceId.value)) {
    invoice.value = null;
    return;
  }
  loading.value = true;
  try {
    const [inv, settings] = await Promise.all([
      thriftSalesRepository.getSalesInvoice(tenantId.value, invoiceId.value),
      thriftSettingsRepository.fetchSettings(tenantId.value),
    ]);
    invoice.value = inv;
    returnWindowDays.value = settings?.return_window_days ?? 30;
  } catch (err: any) {
    invoice.value = null;
    showErrorNotification(
      formatThriftActionableError(err, 'Failed to load invoice'),
    );
  } finally {
    loading.value = false;
  }
}

async function confirmRevert(reason: ThriftSalesRevertReason) {
  const isReturn = reason === 'RETURN';
  if (!isReturn && !canStaffMistake.value) {
    showErrorNotification(
      'You do not have permission to mark staff mistake on thrift sales invoices.',
    );
    return;
  }
  if (isReturn && !canReturn.value && !canForceReturn.value) {
    showErrorNotification(
      'You do not have permission to return thrift sales invoices.',
    );
    return;
  }

  let force = false;

  if (isReturn && returnEligibility.value && !returnEligibility.value.withinWindow) {
    if (!canForceReturn.value) {
      showErrorNotification(
        'Outside return window — force return requires thrift_sales force_return permission.',
      );
      return;
    }
    const ok = await requestConfirmation(
      'This invoice is outside the return window — force return anyway?',
      'Outside return window — force?',
      'Force Return',
    );
    if (!ok) return;
    force = true;
  } else if (isReturn && !canReturn.value) {
    showErrorNotification(
      'Customer return requires thrift_sales return permission.',
    );
    return;
  }

  $q.dialog({
    title: isReturn
      ? force
        ? 'Confirm Force Return'
        : 'Confirm Return'
      : 'Confirm Staff Mistake',
    message: isReturn
      ? force
        ? 'Force will bypass the return window. Stock will be restored, a REFUND ledger entry posted, and the invoice marked RETURNED. Sale expense ledger rows are removed.'
        : 'This will restore stock to AVAILABLE, post a REFUND ledger entry, mark the invoice as RETURNED, and remove sale expense ledger rows.'
      : [
          `Permanently erase invoice ${invoice.value?.invoiceNumber || ''} as a staff entry error.`,
          'Stock returns to AVAILABLE. Ledger and PnL rows for this invoice are scrubbed (no refund/loss events).',
          'The invoice number is not reused — the monthly counter continues (gaps are OK).',
          'Blocked if any post-pay returns already exist. This cannot be undone.',
        ].join(' '),
    prompt: {
      model: '',
      type: 'text',
      label: 'Notes (optional)',
    },
    cancel: { flat: true, label: 'Cancel', color: 'grey-8', noCaps: true },
    ok: {
      unelevated: true,
      label: isReturn
        ? force
          ? 'Force Return Invoice'
          : 'Return Invoice'
        : 'Delete Mistake Invoice',
      color: isReturn ? 'warning' : 'negative',
      noCaps: true,
    },
    persistent: true,
  }).onOk((notes: string) => {
    void runRevert(reason, notes, force);
  });
}

async function runRevert(reason: ThriftSalesRevertReason, notes?: string, force = false) {
  if (!tenantId.value || !invoice.value) return;
  reverting.value = reason;
  try {
    const result = await revertMutation.mutateAsync({
      tenantId: tenantId.value,
      invoiceId: invoice.value.id,
      reason,
      revertedBy: authStore.user?.email || 'cashier',
      notes: notes?.trim() || undefined,
      force: force || undefined,
    });
    if (result.deleted) {
      showSuccessNotification(
        `Mistake invoice ${result.invoiceNumber || ''} deleted — stock restored (invoice # not reused)`,
      );
      await router.push(salesListPath.value);
      return;
    }
    showSuccessNotification(
      force ? 'Invoice force-returned and stock restored' : 'Invoice returned and stock restored',
    );
    await loadInvoice();
  } catch (err: any) {
    showErrorNotification(
      formatThriftActionableError(err, 'Failed to revert invoice'),
    );
  } finally {
    reverting.value = null;
  }
}

watch(
  [tenantId, invoiceId],
  () => {
    void loadInvoice();
  },
  { immediate: true },
);
</script>

<style scoped>
.thrift-invoice-details-page {
  max-width: 1400px;
  margin: 0 auto;
}
</style>

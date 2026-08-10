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
            >
              <q-tooltip>
                Cash remittance from courier — not a return / RTO
              </q-tooltip>
            </q-btn>
            <q-btn
              v-if="canShowMarkRto"
              outline
              color="warning"
              no-caps
              icon="ph ph-package"
              label="Mark RTO"
              :loading="reverting === 'RTO'"
              :disable="!!reverting || remitting || updatingDelivery"
              @click="openRtoDialog()"
            >
              <q-tooltip>
                No pickup / refuse — closes parcel as RETURNED. Not COD remittance.
              </q-tooltip>
            </q-btn>
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
                    v-if="invoice.status === 'ACTIVE' && invoice.saleChannel === 'ONLINE'"
                    class="col-12"
                  >
                    <q-banner dense rounded class="bg-grey-2 text-grey-9">
                      <template #avatar>
                        <q-icon name="ph ph-info" color="primary" />
                      </template>
                      <strong>Record COD</strong> = courier paid you cash.
                      <strong>Mark RTO</strong> = no pickup / refuse (stock comes back).
                      After delivered, use Return items (not RTO).
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
                    :disable="remitting || !!reverting"
                    @click="openRemittanceDialog()"
                  />
                </template>
                <template v-if="canShowMarkRto">
                  <div
                    v-if="canShowRemittance"
                    class="text-caption text-grey-6 q-mt-sm"
                  >
                    COD = cash from courier. RTO = customer refused / no pickup.
                  </div>
                  <q-btn
                    class="full-width q-mt-sm"
                    color="warning"
                    outline
                    no-caps
                    icon="ph ph-package"
                    label="Mark RTO (no pickup)"
                    :disable="remitting || !!reverting"
                    @click="openRtoDialog()"
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

    <q-dialog v-model="rtoDialogOpen" persistent>
      <q-card style="min-width: 360px; max-width: 440px">
        <q-card-section>
          <div class="text-h6">Mark RTO — no pickup</div>
          <div class="text-caption text-grey-7">
            Customer did not accept the parcel. Closes the whole order as RETURNED /
            REFUNDED and restores stock. This is not COD remittance.
          </div>
        </q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <q-banner dense rounded class="bg-orange-1 text-grey-9">
            <template #avatar>
              <q-icon name="ph ph-info" color="warning" />
            </template>
            Use <strong>Record COD</strong> only when the courier paid you cash.
            Use this when the parcel comes back.
          </q-banner>
          <q-input
            v-model.number="rtoForm.returnCourierAmount"
            type="number"
            dense
            outlined
            label="Return courier cost (shop)"
            hint="Courier RTO / return fee your shop pays — 0 if none"
            min="0"
            step="0.01"
          />
          <q-input
            v-model="rtoForm.notes"
            type="textarea"
            dense
            outlined
            autogrow
            label="Notes (optional)"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" color="grey-8" v-close-popup />
          <q-btn
            unelevated
            no-caps
            color="warning"
            label="Confirm Mark RTO"
            :loading="reverting === 'RTO'"
            @click="submitRto"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog
      v-model="remittanceDialogOpen"
      persistent
      @hide="targetPaymentStatus = null"
    >
      <q-card style="min-width: 360px; max-width: 440px">
        <q-card-section>
          <div class="text-h6">Record COD remittance</div>
          <div class="text-caption text-grey-7">
            Cash settlement only — does not mark RTO or change delivery.
          </div>
        </q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <div>
            <div class="text-caption text-grey-6">COD expected</div>
            <div class="text-weight-bold">
              {{ formatThriftAmount(invoice?.codExpected ?? null) }}
            </div>
          </div>
          <q-input
            v-model.number="remittanceForm.amount"
            type="number"
            dense
            outlined
            label="Amount remitted"
            min="0"
            step="0.01"
          />
          <div
            v-if="remittanceAcceptsShortfall"
            class="text-caption text-warning"
          >
            Remitted is less than expected — saving as Paid accepts this shortfall
            (expected is not changed).
          </div>
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
          <q-input
            v-model="remittanceForm.notes"
            dense
            outlined
            type="textarea"
            autogrow
            :label="
              remittanceForm.outcome === 'WRITTEN_OFF'
                ? 'Notes *'
                : 'Notes (optional)'
            "
            :hint="
              remittanceForm.outcome === 'WRITTEN_OFF'
                ? 'Required for write-off'
                : 'Appended to invoice notes'
            "
            placeholder="Dispute / deposit / write-off reason"
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
const rtoDialogOpen = ref(false);
const invoice = ref<ThriftSalesInvoiceDetail | null>(null);

const remittanceForm = ref({
  amount: 0,
  date: '',
  ref: '',
  notes: '',
  outcome: 'PAID' as ThriftCodRemittanceOutcome,
});

const rtoForm = ref({
  returnCourierAmount: 0,
  notes: '',
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

/** Online refuse only — never after DELIVERED (that is post-accept Return items). */
const canShowMarkRto = computed(() => {
  const inv = invoice.value;
  if (!inv || inv.status !== 'ACTIVE' || inv.saleChannel !== 'ONLINE') return false;
  if (!canReturn.value && !canForceReturn.value) return false;
  const ds = (inv.deliveryStatus || 'PENDING').toUpperCase();
  return ds !== 'DELIVERED' && ds !== 'RETURNED';
});

const remittanceAcceptsShortfall = computed(() => {
  if (remittanceForm.value.outcome !== 'PAID') return false;
  const expected = invoice.value?.codExpected;
  if (expected == null) return false;
  const amount = Number(remittanceForm.value.amount);
  return Number.isFinite(amount) && amount < Number(expected);
});

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
    notes: '',
    outcome,
  };
  remittanceDialogOpen.value = true;
}

function onSelectPaymentStatus(status: 'PAID' | 'WRITTEN_OFF') {
  targetPaymentStatus.value = status;
  openRemittanceDialog(status === 'WRITTEN_OFF' ? 'WRITTEN_OFF' : 'PAID');
}

function remittanceSuccessMessage(outcome: ThriftCodRemittanceOutcome): string {
  if (outcome === 'WRITTEN_OFF') return 'COD written off';
  if (outcome === 'KEEP_PENDING') return 'COD remittance saved — still pending';
  return 'COD remittance recorded as paid';
}

async function submitRemittance() {
  if (!tenantId.value || !invoice.value) return;
  const amount = Number(remittanceForm.value.amount);
  if (!Number.isFinite(amount) || amount < 0) {
    showErrorNotification('Remitted amount must be zero or greater.');
    return;
  }
  const notes = remittanceForm.value.notes.trim();
  if (remittanceForm.value.outcome === 'WRITTEN_OFF' && !notes) {
    showErrorNotification('Notes are required when writing off COD.');
    return;
  }

  remitting.value = true;
  try {
    const remittedAt = remittanceForm.value.date
      ? new Date(remittanceForm.value.date).toISOString()
      : undefined;
    const outcome = remittanceForm.value.outcome;
    await remittanceMutation.mutateAsync({
      tenantId: tenantId.value,
      invoiceId: invoice.value.id,
      remittedAmount: amount,
      actor: authStore.user?.email || 'cashier',
      remittedAt,
      remittanceRef: remittanceForm.value.ref || undefined,
      notes: notes || undefined,
      outcome,
    });
    showSuccessNotification(remittanceSuccessMessage(outcome));
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
    invoice.value = await thriftSalesRepository.getSalesInvoice(
      tenantId.value,
      invoiceId.value,
    );
  } catch (err: any) {
    invoice.value = null;
    showErrorNotification(
      formatThriftActionableError(err, 'Failed to load invoice'),
    );
  } finally {
    loading.value = false;
  }
}

function openRtoDialog() {
  if (!canShowMarkRto.value) {
    showErrorNotification(
      'Mark RTO is only for Online invoices that are not yet delivered.',
    );
    return;
  }
  rtoForm.value = { returnCourierAmount: 0, notes: '' };
  rtoDialogOpen.value = true;
}

async function submitRto() {
  if (!tenantId.value || !invoice.value) return;
  const amount = Number(rtoForm.value.returnCourierAmount);
  if (!Number.isFinite(amount) || amount < 0) {
    showErrorNotification('Return courier cost must be 0 or greater.');
    return;
  }
  if (!canReturn.value && !canForceReturn.value) {
    showErrorNotification('Mark RTO requires thrift_sales return permission.');
    return;
  }

  const ok = await requestConfirmation(
    [
      `Mark ${invoice.value.invoiceNumber} as RTO (no pickup)?`,
      'Parcel → RETURNED, payment → REFUNDED, stock restored.',
      'This is not Record COD.',
    ].join(' '),
    'Confirm Mark RTO',
    'Mark RTO',
  );
  if (!ok) return;

  reverting.value = 'RTO';
  try {
    await revertMutation.mutateAsync({
      tenantId: tenantId.value,
      invoiceId: invoice.value.id,
      reason: 'RTO',
      revertedBy: authStore.user?.email || 'cashier',
      notes: rtoForm.value.notes.trim() || undefined,
      returnCourierAmount: amount,
      force: !canReturn.value && canForceReturn.value ? true : undefined,
    });
    showSuccessNotification('Marked RTO — stock restored, invoice closed');
    rtoDialogOpen.value = false;
    await loadInvoice();
  } catch (err: any) {
    showErrorNotification(formatThriftActionableError(err, 'Failed to mark RTO'));
  } finally {
    reverting.value = null;
  }
}

async function confirmRevert(reason: ThriftSalesRevertReason) {
  if (reason !== 'STAFF_MISTAKE') {
    openRtoDialog();
    return;
  }
  if (!canStaffMistake.value) {
    showErrorNotification(
      'You do not have permission to mark staff mistake on thrift sales invoices.',
    );
    return;
  }

  $q.dialog({
    title: 'Confirm Staff Mistake',
    message: [
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
      label: 'Delete Mistake Invoice',
      color: 'negative',
      noCaps: true,
    },
    persistent: true,
  }).onOk((notes: string) => {
    void runStaffMistake(notes);
  });
}

async function runStaffMistake(notes?: string) {
  if (!tenantId.value || !invoice.value) return;
  reverting.value = 'STAFF_MISTAKE';
  try {
    const result = await revertMutation.mutateAsync({
      tenantId: tenantId.value,
      invoiceId: invoice.value.id,
      reason: 'STAFF_MISTAKE',
      revertedBy: authStore.user?.email || 'cashier',
      notes: notes?.trim() || undefined,
    });
    if (result.deleted) {
      showSuccessNotification(
        `Mistake invoice ${result.invoiceNumber || ''} deleted — stock restored (invoice # not reused)`,
      );
      await router.push(salesListPath.value);
      return;
    }
    await loadInvoice();
  } catch (err: any) {
    showErrorNotification(
      formatThriftActionableError(err, 'Failed to delete mistake invoice'),
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

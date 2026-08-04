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
              outline
              color="warning"
              no-caps
              icon="ph ph-arrow-u-up-left"
              label="Return"
              :loading="reverting === 'RETURN'"
              :disable="!!reverting"
              @click="confirmRevert('RETURN')"
            />
            <q-btn
              outline
              color="negative"
              no-caps
              icon="ph ph-trash"
              label="Staff Mistake"
              :loading="reverting === 'STAFF_MISTAKE'"
              :disable="!!reverting"
              @click="confirmRevert('STAFF_MISTAKE')"
            />
          </template>
        </div>
      </section>

      <!-- Skeleton Loader -->
      <ThriftSalesInvoiceDetailsSkeleton v-if="loading" />

      <!-- Loaded Content -->
      <template v-else-if="invoice">
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
                    <div class="text-caption text-grey-6">Payment Method</div>
                    <q-badge outline color="grey-7" :label="labelize(invoice.paymentMethod)" />
                  </div>
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Payment Status</div>
                    <q-badge
                      :color="paymentStatusColor(invoice.paymentStatus)"
                      :label="labelize(invoice.paymentStatus)"
                    />
                  </div>
                  <div class="col-6 col-sm-4">
                    <div class="text-caption text-grey-6">Customer</div>
                    <div class="text-weight-medium">
                      {{ invoice.customerName || 'Walk-in' }}
                    </div>
                    <div v-if="invoice.customerPhone" class="text-caption text-grey-7">
                      {{ invoice.customerPhone }}
                    </div>
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

                <template #body-cell-landedUnitCostAtSale="props">
                  <q-td :props="props" class="text-right">
                    {{ formatThriftAmount(props.row.landedUnitCostAtSale) }}
                  </q-td>
                </template>

                <template #body-cell-netProfit="props">
                  <q-td
                    :props="props"
                    class="text-right text-weight-bold"
                    :class="props.row.netProfit >= 0 ? 'text-positive' : 'text-negative'"
                  >
                    {{ formatThriftAmount(props.row.netProfit) }}
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
                <div class="row justify-between q-mb-sm">
                  <span class="text-grey-7">Total Profit</span>
                  <span
                    class="text-weight-bold"
                    :class="totalProfit >= 0 ? 'text-positive' : 'text-negative'"
                  >
                    {{ formatThriftAmount(totalProfit) }}
                  </span>
                </div>
                <q-separator class="q-my-md" />
                <div class="row justify-between items-center">
                  <span class="text-subtitle1 text-weight-bold">Invoice Total</span>
                  <span class="text-h6 text-weight-bold text-primary">
                    {{ formatThriftAmount(invoice.totalInvoiceAmount) }}
                  </span>
                </div>
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
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useQuasar, type QTableColumn } from 'quasar';
import LearnMoreHelpBtn from 'src/modules/help/components/LearnMoreHelpBtn.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import ThriftSalesInvoiceDetailsSkeleton from '../components/ThriftSalesInvoiceDetailsSkeleton.vue';
import {
  thriftSalesRepository,
  type ThriftSalesInvoiceDetail,
  type ThriftSalesRevertReason,
} from '../repositories/thriftSalesRepository';

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const loading = ref(false);
const reverting = ref<ThriftSalesRevertReason | null>(null);
const invoice = ref<ThriftSalesInvoiceDetail | null>(null);

const salesListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/sales`,
);

const invoiceId = computed(() => Number(route.params.invoiceId));

const totalProfit = computed(() =>
  (invoice.value?.items || []).reduce((sum, item) => sum + (item.netProfit || 0), 0),
);

const itemColumns: QTableColumn[] = [
  { name: 'item', label: 'Item', field: 'stockName', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'center' },
  { name: 'sellPrice', label: 'Sell', field: 'sellPrice', align: 'right' },
  { name: 'discountAmount', label: 'Discount', field: 'discountAmount', align: 'right' },
  { name: 'finalPrice', label: 'Final', field: 'finalPrice', align: 'right' },
  {
    name: 'landedUnitCostAtSale',
    label: 'Landed Cost',
    field: 'landedUnitCostAtSale',
    align: 'right',
  },
  { name: 'netProfit', label: 'Profit', field: 'netProfit', align: 'right' },
];

function labelize(value: string): string {
  return (value || '—').replace(/_/g, ' ').toUpperCase();
}

function paymentStatusColor(status: string): string {
  const s = (status || '').toLowerCase();
  if (s === 'paid') return 'positive';
  if (s === 'partial') return 'warning';
  if (s === 'unpaid') return 'negative';
  if (s === 'refunded') return 'orange';
  return 'grey';
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
    invoice.value = await thriftSalesRepository.getSalesInvoice(tenantId.value, invoiceId.value);
  } catch (err: any) {
    invoice.value = null;
    $q.notify({
      type: 'negative',
      message: err?.message || 'Failed to load invoice',
    });
  } finally {
    loading.value = false;
  }
}

function confirmRevert(reason: ThriftSalesRevertReason) {
  const isReturn = reason === 'RETURN';
  $q.dialog({
    title: isReturn ? 'Confirm Return' : 'Confirm Staff Mistake',
    message: isReturn
      ? 'This will restore stock to AVAILABLE, post a REFUND ledger entry, and mark the invoice as RETURNED.'
      : 'This permanently deletes the invoice and its line items, restores stock to AVAILABLE, and removes related ledger entries. This cannot be undone.',
    prompt: {
      model: '',
      type: 'text',
      label: 'Notes (optional)',
    },
    cancel: { flat: true, label: 'Cancel', color: 'grey-8', noCaps: true },
    ok: {
      unelevated: true,
      label: isReturn ? 'Return Invoice' : 'Delete Mistake Invoice',
      color: isReturn ? 'warning' : 'negative',
      noCaps: true,
    },
    persistent: true,
  }).onOk((notes: string) => {
    void runRevert(reason, notes);
  });
}

async function runRevert(reason: ThriftSalesRevertReason, notes?: string) {
  if (!tenantId.value || !invoice.value) return;
  reverting.value = reason;
  try {
    const result = await thriftSalesRepository.revertSalesInvoice({
      tenantId: tenantId.value,
      invoiceId: invoice.value.id,
      reason,
      revertedBy: authStore.user?.email || 'cashier',
      notes: notes?.trim() || undefined,
    });
    if (result.deleted) {
      $q.notify({
        type: 'positive',
        message: 'Mistake invoice deleted and stock restored',
      });
      await router.push(salesListPath.value);
      return;
    }
    $q.notify({
      type: 'positive',
      message: 'Invoice returned and stock restored',
    });
    await loadInvoice();
  } catch (err: any) {
    $q.notify({
      type: 'negative',
      message: err?.message || 'Failed to revert invoice',
    });
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

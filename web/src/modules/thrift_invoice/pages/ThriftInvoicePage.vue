<template>
  <q-page class="q-pa-md thrift-invoice-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Invoices</div>
            <div class="text-caption text-grey-8">Manage sales invoices, shipping cost splits, and payment status</div>
          </div>
          <div class="col-12 col-sm-auto row justify-start justify-sm-end q-mt-xs q-mt-sm-none">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="shopping_cart"
              label="Mark Items As Sold"
              @click="openSellDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Table -->
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="invoices"
        :columns="columns"
        row-key="id"
        :loading="loading"
        class="thrift-table"
      >
        <template #body-cell-payment_status="props">
          <q-td :props="props">
            <q-chip dense square :style="paymentStatusStyle(props.value)" class="thrift-status-chip">
              <span class="status-dot" :style="{ backgroundColor: paymentStatusDot(props.value) }" />
              {{ props.value }}
            </q-chip>
          </q-td>
        </template>
        <template #body-cell-delivery_status="props">
          <q-td :props="props">
            <q-chip dense square :style="deliveryStatusStyle(props.value)" class="thrift-status-chip">
              <span class="status-dot" :style="{ backgroundColor: deliveryStatusDot(props.value) }" />
              {{ props.value }}
            </q-chip>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Mark As Sold Dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 680px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">Mark Items As Sold</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section>
          <q-form @submit="onSubmit" class="q-gutter-sm q-pt-sm">
            <!-- Recipient -->
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input v-model="form.recipient_name" outlined dense label="Recipient Name *" class="soft-input"
                  :rules="[val => !!val && val.length > 0 || 'Required']" />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model="form.phone" outlined dense label="Phone *" class="soft-input"
                  :rules="[val => !!val && val.length > 0 || 'Required']" />
              </div>
            </div>
            <q-input v-model="form.address" outlined dense type="textarea" rows="2" label="Address *" class="soft-input"
              :rules="[val => !!val && val.length > 0 || 'Required']" />
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select v-model="form.transaction_method" outlined dense label="Transaction Method *" class="soft-input"
                  :options="['CASH', 'CARD', 'MOBILE_BANKING', 'COD']" :rules="[val => !!val || 'Required']" />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model="form.invoice_number" outlined dense label="Invoice Number *" class="soft-input"
                  :rules="[val => !!val && val.length > 0 || 'Required']" />
              </div>
            </div>

            <q-separator class="q-my-xs" />
            <div class="text-caption text-grey-8">Charges Split</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-3">
                <q-input v-model.number="form.cod_charge" type="number" step="0.01" outlined dense label="COD Fee" class="soft-input" />
              </div>
              <div class="col-12 col-sm-3">
                <q-input v-model.number="form.packing_charge" type="number" step="0.01" outlined dense label="Packing Fee" class="soft-input" />
              </div>
              <div class="col-12 col-sm-3">
                <q-input v-model.number="form.invoice_print_charge" type="number" step="0.01" outlined dense label="Print Fee" class="soft-input" />
              </div>
              <div class="col-12 col-sm-3">
                <q-input v-model.number="form.shipping_charge_customer" type="number" step="0.01" outlined dense label="Shipping (Customer)" class="soft-input" />
              </div>
            </div>

            <q-separator class="q-my-xs" />
            <div class="row items-center justify-between">
              <div class="text-caption text-grey-8">Invoice Lines</div>
              <q-btn flat dense no-caps size="sm" icon="add" label="Add Item" color="primary" @click="addLine" />
            </div>

            <div v-for="(line, idx) in lines" :key="idx" class="row q-col-gutter-xs items-center q-mb-xs">
              <div class="col-12 col-sm-4">
                <q-select v-model="line.stock_id" outlined dense label="Stock *" class="soft-input"
                  :options="availableStocks" option-value="id" option-label="name" emit-value map-options
                  @update:model-value="onSelectStock(idx)" />
              </div>
              <div class="col-2">
                <q-input v-model.number="line.quantity" type="number" outlined dense label="Qty" class="soft-input" />
              </div>
              <div class="col-2">
                <q-input v-model.number="line.sold_price" type="number" step="0.01" outlined dense label="Price" class="soft-input" />
              </div>
              <div class="col-2">
                <q-input v-model.number="line.platform_fees" type="number" step="0.01" outlined dense label="Fees" class="soft-input" />
              </div>
              <div class="col-2">
                <q-input v-model.number="line.shipping_cost_paid_by_shop" type="number" step="0.01" outlined dense label="Ship" class="soft-input" />
              </div>
              <div class="col-auto">
                <q-btn flat round dense icon="o_delete" color="negative" size="sm" @click="removeLine(idx)" />
              </div>
            </div>

            <div class="row justify-end q-gutter-sm q-pt-sm">
              <q-btn flat no-caps label="Cancel" v-close-popup />
              <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Sale" type="submit" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftInvoiceStore } from '../stores/thriftInvoiceStore';
import { useThriftStockStore } from 'src/modules/thrift_stock/stores/thriftStockStore';
import { useQuasar, type QTableColumn } from 'quasar';

const $q = useQuasar();
const authStore = useAuthStore();
const store = useThriftInvoiceStore();
const stockStore = useThriftStockStore();

const dialogOpen = ref(false);

const invoices = computed(() => store.invoices);
const loading = computed(() => store.loading);
const availableStocks = computed(() =>
  stockStore.stocks.filter(s => s.status === 'AVAILABLE' && s.quantity > 0)
);

const form = ref({
  recipient_name: '',
  phone: '',
  address: '',
  transaction_method: 'CASH',
  invoice_number: '',
  cod_charge: 0,
  packing_charge: 0,
  invoice_print_charge: 0,
  shipping_charge_customer: 0,
});

const lines = ref<Array<{
  stock_id: number | null;
  quantity: number;
  sold_price: number;
  platform_fees: number;
  shipping_cost_paid_by_shop: number;
}>>([]);

const columns: QTableColumn[] = [
  { name: 'invoice_number', align: 'left', label: 'Invoice No', field: 'invoice_number', sortable: true },
  { name: 'recipient_name', align: 'left', label: 'Recipient', field: 'recipient_name', sortable: true },
  { name: 'phone', align: 'left', label: 'Phone', field: 'phone' },
  { name: 'transaction_method', align: 'left', label: 'Method', field: 'transaction_method' },
  { name: 'delivery_status', align: 'center', label: 'Delivery', field: 'delivery_status', sortable: true },
  { name: 'payment_status', align: 'center', label: 'Payment', field: 'payment_status', sortable: true },
  { name: 'total_invoice_amount', align: 'right', label: 'Total', field: 'total_invoice_amount', format: (val: any) => `${val}`, sortable: true },
  { name: 'created_at', align: 'left', label: 'Issued', field: 'created_at', format: (val: any) => new Date(val).toLocaleDateString() },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await Promise.all([
      store.loadInvoices(authStore.tenantId),
      stockStore.loadStocks(authStore.tenantId),
    ]);
  }
});

function openSellDialog() {
  form.value = {
    recipient_name: '',
    phone: '',
    address: '',
    transaction_method: 'CASH',
    invoice_number: 'INV-THRIFT-' + Math.floor(Math.random() * 900000 + 100000),
    cod_charge: 0,
    packing_charge: 0,
    invoice_print_charge: 0,
    shipping_charge_customer: 0,
  };
  lines.value = [{
    stock_id: availableStocks.value[0]?.id || null,
    quantity: 1,
    sold_price: availableStocks.value[0]?.pricing?.listed_price || 0,
    platform_fees: 0,
    shipping_cost_paid_by_shop: 0,
  }];
  dialogOpen.value = true;
}

function addLine() {
  lines.value.push({
    stock_id: availableStocks.value[0]?.id || null,
    quantity: 1,
    sold_price: 0,
    platform_fees: 0,
    shipping_cost_paid_by_shop: 0,
  });
}

function removeLine(idx: number) {
  lines.value.splice(idx, 1);
}

function onSelectStock(idx: number) {
  const line = lines.value[idx];
  if (!line || !line.stock_id) return;
  const stock = stockStore.stocks.find(s => s.id === line.stock_id);
  if (stock?.pricing) line.sold_price = stock.pricing.listed_price;
}

async function onSubmit() {
  if (!authStore.tenantId) return;
  if (lines.value.length === 0) {
    $q.notify({ type: 'negative', message: 'Add at least one invoice line.' });
    return;
  }
  $q.loading.show();
  try {
    await store.sellThriftItems({
      tenantId: authStore.tenantId,
      invoiceNumber: form.value.invoice_number,
      recipientName: form.value.recipient_name,
      address: form.value.address,
      phone: form.value.phone,
      transactionMethod: form.value.transaction_method,
      codCharge: form.value.cod_charge || 0,
      packingCharge: form.value.packing_charge || 0,
      invoicePrintCharge: form.value.invoice_print_charge || 0,
      shippingChargeCustomer: form.value.shipping_charge_customer || 0,
      insertedBy: authStore.user?.email || 'admin@brandwala.com',
      items: lines.value.map(l => ({
        stock_id: l.stock_id!,
        quantity: l.quantity,
        sold_price: l.sold_price,
        platform_fees: l.platform_fees || 0,
        shipping_cost_paid_by_shop: l.shipping_cost_paid_by_shop || 0,
      })),
    });
    $q.notify({ type: 'positive', message: 'Invoice created and stock updated!' });
    dialogOpen.value = false;
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Invoice creation failed' });
  } finally {
    $q.loading.hide();
  }
}

const paymentStatusStyle = (v: string) => {
  if (v === 'PAID') return { backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #6ee7b7' }
  if (v === 'UNPAID') return { backgroundColor: '#fef3c7', color: '#92400e', border: '1px solid #fcd34d' }
  return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' }
}
const paymentStatusDot = (v: string) => {
  if (v === 'PAID') return '#059669'
  if (v === 'UNPAID') return '#d97706'
  return '#9ca3af'
}
const deliveryStatusStyle = (v: string) => {
  if (v === 'DELIVERED') return { backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #6ee7b7' }
  if (v === 'PENDING') return { backgroundColor: '#eff6ff', color: '#1e40af', border: '1px solid #93c5fd' }
  if (v === 'SHIPPED') return { backgroundColor: '#f0fdf4', color: '#166534', border: '1px solid #86efac' }
  return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' }
}
const deliveryStatusDot = (v: string) => {
  if (v === 'DELIVERED') return '#059669'
  if (v === 'PENDING') return '#3b82f6'
  if (v === 'SHIPPED') return '#22c55e'
  return '#9ca3af'
}
</script>

<style scoped>
.thrift-invoice-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.thrift-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>

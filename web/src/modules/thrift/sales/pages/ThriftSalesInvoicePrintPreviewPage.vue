<template>
  <q-page class="thrift-invoice-preview-page q-pa-md">
    <div v-if="loading" class="column flex-center q-pa-xl">
      <q-spinner color="primary" size="40px" />
    </div>

    <div v-else-if="invoice" class="row q-col-gutter-md">
      <div class="col-12 col-md-4 no-print">
        <q-card flat bordered class="q-pa-md">
          <div class="text-subtitle1 text-weight-bold q-mb-md">Customize Print</div>
          <q-input
            v-model="brandName"
            label="Brand Name"
            outlined
            dense
            class="q-mb-sm"
          />
          <q-input
            v-model="brandAddress"
            label="Brand Address"
            type="textarea"
            outlined
            dense
            rows="2"
            class="q-mb-sm"
          />
          <q-input
            v-model="clientName"
            label="Customer Name"
            outlined
            dense
            class="q-mb-sm"
          />
          <q-input
            v-model="thankYouMessage"
            label="Thank you message"
            outlined
            dense
            class="q-mb-md"
          />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-printer"
            label="Print"
            class="full-width"
            @click="printInvoice"
          />
        </q-card>
      </div>

      <div class="col-12 col-md-8">
        <InvoicePrintSheet :model="printModel" :show-images="false" />
      </div>
    </div>

    <div v-else class="column flex-center q-pa-xl text-grey-7 no-print">
      Invoice not found.
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import InvoicePrintSheet from 'src/modules/invoice_shared/components/InvoicePrintSheet.vue';
import type { InvoicePrintModel } from 'src/modules/invoice_shared/types/invoicePrintModel';
import {
  thriftSalesRepository,
  type ThriftSalesInvoiceDetail,
} from '../repositories/thriftSalesRepository';

const route = useRoute();
const authStore = useAuthStore();

const loading = ref(true);
const invoice = ref<ThriftSalesInvoiceDetail | null>(null);

const brandName = ref('');
const brandAddress = ref('');
const clientName = ref('');
const thankYouMessage = ref('Thank you for your purchase!');

const printModel = computed<InvoicePrintModel>(() => {
  const inv = invoice.value;
  const items = inv?.items ?? [];
  const subtotal = items.reduce((sum, item) => sum + (item.sellPrice || 0) * (item.quantity || 1), 0);
  const discount = items.reduce(
    (sum, item) => sum + (item.discountAmount || 0) * (item.quantity || 1),
    0,
  );
  const total = Number(inv?.totalInvoiceAmount ?? 0);
  const isPaid = (inv?.paymentStatus || '').toLowerCase() === 'paid';

  return {
    id: inv?.id ?? 0,
    invoiceNo: inv?.invoiceNumber ?? '-',
    invoiceDate: inv?.date ? new Date(inv.date).toLocaleDateString() : '-',
    invoiceType: 'thrift',
    brandName: brandName.value,
    brandAddress: brandAddress.value,
    clientName: clientName.value || inv?.customerName || 'Walk-in Customer',
    recipientName: clientName.value || inv?.customerName || 'Walk-in Customer',
    recipientPhone: inv?.customerPhone ?? null,
    recipientAddress: null,
    lines: items.map((item) => ({
      id: item.id,
      name: [item.stockName, item.barcode].filter(Boolean).join(' · ') || `Stock #${item.stockId}`,
      quantity: item.quantity || 1,
      unitPrice: item.sellPrice || 0,
      lineTotal: item.finalPrice || 0,
    })),
    charges: [],
    subtotal,
    discount,
    total,
    paid: isPaid ? total : 0,
    due: isPaid ? 0 : total,
    thankYouMessage: thankYouMessage.value,
    isWholesale: false,
  };
});

function printInvoice() {
  window.print();
}

onMounted(async () => {
  const tenantId = authStore.tenantId;
  const invoiceId = Number(route.params.invoiceId);
  try {
    if (!tenantId || !invoiceId || Number.isNaN(invoiceId)) {
      invoice.value = null;
      return;
    }
    invoice.value = await thriftSalesRepository.getSalesInvoice(tenantId, invoiceId);
    brandName.value =
      authStore.selectedTenant?.name ?? authStore.tenant?.name ?? 'Thrift Store';
    clientName.value = invoice.value.customerName || '';
  } catch (err) {
    console.error('Failed to load thrift invoice preview:', err);
    invoice.value = null;
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
@media print {
  .no-print {
    display: none !important;
  }
}
</style>

<template>
  <q-page class="invoice-preview-page q-pa-md">
    <PageInitialLoader v-if="loading" />
    <div v-else class="row q-col-gutter-md">
      <div class="col-12 col-md-4 no-print">
        <q-card flat class="floating-surface shadow-1 q-pa-md">
          <div class="text-subtitle1 text-weight-bold q-mb-md">Customize</div>
          <q-select
            v-model="selectedBrandId"
            :options="brandOptions"
            option-value="id"
            option-label="name"
            emit-value
            map-options
            label="Business Profile (Brand)"
            outlined
            dense
            clearable
            class="soft-input q-mb-sm"
            @update:model-value="onBrandChanged"
          />
          <q-input
            v-model="brandName"
            label="Brand Name"
            outlined
            dense
            class="soft-input q-mb-sm"
          />
          <q-input
            v-model="brandAddress"
            label="Brand Address"
            type="textarea"
            outlined
            dense
            rows="2"
            class="soft-input q-mb-sm"
          />
          <q-input
            v-model="clientName"
            label="Client Name"
            outlined
            dense
            class="soft-input q-mb-sm"
          />
          <q-input
            v-model="thankYouMessage"
            label="Thank you message"
            outlined
            dense
            class="soft-input q-mb-md"
          />
          <q-btn
            color="primary"
            icon="print"
            label="Print"
            no-caps
            class="full-width pill-btn"
            @click="printInvoice"
          />
        </q-card>
      </div>
      <div class="col-12 col-md-8">
        <InvoicePrintSheet :model="printModel" />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import InvoicePrintSheet from 'src/modules/invoice_shared/components/InvoicePrintSheet.vue';
import type { InvoicePrintModel } from 'src/modules/invoice_shared/types/invoicePrintModel';
import { invoiceGrossProfit } from 'src/modules/reporting_treasury/utils/margin';
import { useInvoiceStore } from 'src/modules/sales_invoice/stores/invoiceStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

import { invoiceRepository } from '../repositories/invoiceRepository';
import { useInvoiceItemUnitCosts } from '../composables/useInvoiceItemUnitCosts';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from '../types';

const route = useRoute();
const authStore = useAuthStore();
const invoiceStore = useInvoiceStore();

const loading = ref(true);
const invoice = ref<GlobalInvoiceDetail | null>(null);
const items = ref<GlobalInvoiceItemRow[]>([]);
const { resolveItemUnitCosts, getItemUnitCost } = useInvoiceItemUnitCosts();

const selectedBrandId = ref<number | null>(null);
const brandName = ref('');
const brandAddress = ref('');
const clientName = ref('');
const thankYouMessage = ref('Thank you for your business!');

const brandOptions = computed(() => {
  return invoiceStore.brands.map((b) => ({
    id: b.id,
    name: b.name,
    address: b.address,
  }));
});

const onBrandChanged = (id: number | null) => {
  if (id) {
    const selected = invoiceStore.brands.find((b) => b.id === id);
    if (selected) {
      brandName.value = selected.name;
      brandAddress.value = selected.address;
    }
  } else {
    brandName.value = '';
    brandAddress.value = '';
  }
};

const printModel = computed<InvoicePrintModel>(() => {
  const inv = invoice.value;
  const isWholesale = inv?.invoice_type === 'wholesale';
  const isDropship = inv?.invoice_type === 'dropship';
  const subtotal = isDropship
    ? (inv?.face_subtotal_amount ?? inv?.subtotal_amount ?? 0)
    : (inv?.subtotal_amount ?? 0);

  // Construct charges array from inline header columns
  const inlineCharges = [
    { type: 'delivery', label: 'Delivery', amount: Number(inv?.shipping_charge ?? 0) },
    { type: 'cod', label: 'COD', amount: Number(inv?.cod_charge ?? 0) },
    { type: 'print', label: 'Print', amount: Number(inv?.print_charge ?? 0) },
    { type: 'packing', label: 'Wrapping', amount: Number(inv?.wrapping_charge ?? 0) },
  ].filter((c) => c.amount > 0);

  const totalCost = items.value.reduce(
    (sum, row) => sum + (getItemUnitCost(row) ?? 0) * Number(row.quantity),
    0,
  );
  const profit = invoiceGrossProfit(
    {
      invoice_type: inv?.invoice_type as 'wholesale' | 'retail' | 'dropship',
      shipping_charge: inv?.shipping_charge,
      cod_charge: inv?.cod_charge,
      print_charge: inv?.print_charge,
      wrapping_charge: inv?.wrapping_charge,
      discount_amount: inv?.discount_amount,
      invoice_status: 'posted', // bypass check
    },
    items.value.map((row) => ({
      ...row,
      id: row.id,
      unit_cost_price: getItemUnitCost(row) ?? 0,
    })),
  );
  const rate = totalCost > 0 ? (profit / totalCost) * 100 : 0;
  const averageProfitRate = totalCost > 0 ? `${rate.toFixed(2)}%` : '-';

  return {
    id: inv?.id ?? 0,
    invoiceNo: inv?.invoice_no ?? '-',
    invoiceDate: inv?.invoice_date ?? '-',
    invoiceType: inv?.invoice_type ?? 'wholesale',
    brandName: brandName.value,
    brandAddress: brandAddress.value,
    clientName: clientName.value || inv?.billing_profiles?.name || '-',
    recipientName: inv?.recipient_name || inv?.billing_profiles?.name || '-',
    recipientPhone: inv?.recipient_phone ?? null,
    recipientAddress: inv?.recipient_address ?? null,
    lines: items.value.map((row) => {
      const unit = isDropship
        ? Number(row.recipient_price_amount ?? row.sell_price_amount)
        : Number(row.sell_price_amount);
      const lineTotal = isDropship
        ? Number(row.line_face_total_amount ?? row.line_total_amount)
        : Number(row.line_total_amount);
      return {
        id: row.id,
        name: row.name_snapshot,
        quantity: Number(row.quantity),
        unitPrice: unit,
        lineTotal,
        imageUrl: row.image_url ?? null,
      };
    }),
    charges: inlineCharges,
    subtotal,
    discount: Number(inv?.discount_amount ?? 0),
    total: Number(inv?.total_amount ?? 0),
    paid: Number(inv?.paid_amount ?? 0),
    due: Number(inv?.due_amount ?? 0),
    thankYouMessage: thankYouMessage.value,
    isWholesale,
    totalCost,
    profit,
    averageProfitRate,
  };
});

const printInvoice = () => window.print();

onMounted(async () => {
  const id = Number(route.params.id);
  try {
    const [inv, invItems] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(id),
      invoiceRepository.listGlobalInvoiceItems(id),
    ]);
    invoice.value = inv;
    items.value = invItems;
    await resolveItemUnitCosts(invItems);

    clientName.value = inv.billing_profiles?.name ?? '';

    if (inv?.tenant_id) {
      await invoiceStore.fetchInvoiceBrands({ tenant_id: inv.tenant_id });
    }

    if (invoiceStore.brands.length > 0) {
      const defaultBrand = invoiceStore.brands[0];
      if (defaultBrand) {
        selectedBrandId.value = defaultBrand.id;
        brandName.value = defaultBrand.name;
        brandAddress.value = defaultBrand.address;
      }
    } else {
      const tenantName = authStore.selectedTenant?.name ?? authStore.tenant?.name ?? '';
      brandName.value = tenantName || inv.billing_profiles?.name || '';
      brandAddress.value = '';
    }
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

<template>
  <q-page class="recipient-preview-page q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md no-print">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat dense icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline text-primary">Dropship Orders</div>
              <h1 class="text-h5 text-weight-bold q-my-none">Customer Invoice</h1>
              <p v-if="order?.order_no" class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Order #{{ order.order_no }} · delivered quantities
              </p>
            </div>
          </div>
        </div>
        <div class="col-auto row q-gutter-sm items-center">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-printer"
            label="Print invoice"
            @click="printInvoice"
          />
        </div>
      </section>

      <DropshipOrderRecipientInvoicePreviewSkeleton v-if="loading" />

      <div v-else class="row q-col-gutter-md">
        <div class="col-12 col-md-4 no-print">
          <q-card flat bordered class="q-pa-md">
            <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">Customize print</div>

            <q-input v-model="brandName" label="Brand name" outlined dense class="q-mb-md" />
            <q-input
              v-model="brandAddress"
              label="Brand address"
              type="textarea"
              outlined
              dense
              rows="2"
              class="q-mb-md"
            />

            <q-separator class="q-my-md" />

            <q-input v-model="recipientName" label="Recipient name" outlined dense class="q-mb-md" />
            <q-input v-model="recipientPhone" label="Recipient phone" outlined dense class="q-mb-md" />
            <q-input
              v-model="recipientAddress"
              label="Recipient address"
              type="textarea"
              outlined
              dense
              rows="2"
              class="q-mb-md"
            />

            <q-input v-model="thankYouMessage" label="Thank you message" outlined dense class="q-mb-md" />

            <q-toggle v-model="showItemImages" label="Show product images on print" class="q-mb-lg" />

            <q-btn
              color="primary"
              unelevated
              no-caps
              icon="ph ph-printer"
              label="Print customer invoice"
              class="full-width text-weight-bold"
              @click="printInvoice"
            />
          </q-card>
        </div>

        <div class="col-12 col-md-8 print-sheet-col">
          <div class="a4-container shadow-4">
            <InvoicePrintSheet :model="printModel" :show-images="showItemImages" />
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import InvoicePrintSheet from 'src/modules/invoice_shared/components/InvoicePrintSheet.vue';
import DropshipOrderRecipientInvoicePreviewSkeleton from '../components/DropshipOrderRecipientInvoicePreviewSkeleton.vue';
import type { InvoicePrintModel } from 'src/modules/invoice_shared/types/invoicePrintModel';
import type { ShopOrder, ShopOrderItem } from '../types';
import {
  buildSummaryChargeRows,
  computeRecipientGrandTotal,
  createEmptyDropshipInvoiceSummary,
  type DropshipInvoiceSummaryState,
} from '../utils/dropshipInvoiceSummary';
import type { DropshipInvoiceDeliveredQuantitiesState } from '../utils/dropshipInvoiceFulfillment';
import { loadDropshipV2CustomerInvoiceSnapshot } from '../utils/dropshipV2CustomerInvoiceStorage';

const route = useRoute();
const router = useRouter();
const loading = ref(true);

const order = ref<ShopOrder | null>(null);
const items = ref<ShopOrderItem[]>([]);
const summaryState = ref<DropshipInvoiceSummaryState>(createEmptyDropshipInvoiceSummary());
const deliveredQuantities = ref<DropshipInvoiceDeliveredQuantitiesState>({});

const brandName = ref('');
const brandAddress = ref('');
const recipientName = ref('');
const recipientPhone = ref('');
const recipientAddress = ref('');
const thankYouMessage = ref('Thank you for shopping with us!');
const showItemImages = ref(true);

const resolveDeliveredQuantity = (item: ShopOrderItem) => {
  const delivered = deliveredQuantities.value[item.id];
  return Number.isFinite(delivered) ? delivered : item.quantity;
};

const printModel = computed<InvoicePrintModel>(() => {
  const o = order.value;
  if (!o) {
    return {
      id: 0,
      invoiceNo: '-',
      invoiceDate: '-',
      invoiceType: 'dropship',
      brandName: '',
      brandAddress: '',
      clientName: '-',
      recipientName: '-',
      recipientPhone: null,
      recipientAddress: null,
      lines: [],
      charges: [],
      subtotal: 0,
      discount: 0,
      total: 0,
      paid: 0,
      due: 0,
      isWholesale: false,
    };
  }

  const inlineCharges = buildSummaryChargeRows(summaryState.value)
    .filter((row) => row.countsTowardRecipientTotal)
    .map((row) => ({
      type: row.key,
      label: row.label,
      amount: row.amount,
    }));

  const lines = items.value.map((item) => {
    const quantity = resolveDeliveredQuantity(item);
    const unitPrice = Number(item.customer_sell_price_amount ?? item.unit_sell_price_amount ?? 0);
    return {
      id: item.id,
      name: item.name || '',
      quantity,
      unitPrice,
      lineTotal: unitPrice * quantity,
      imageUrl: item.image_url || null,
    };
  });

  const subtotal = lines.reduce((sum, line) => sum + line.lineTotal, 0);
  const discount = Number(summaryState.value.discount_amount || 0);
  const total = computeRecipientGrandTotal(subtotal, summaryState.value);

  return {
    id: o.id,
    invoiceNo: o.order_no || '-',
    invoiceDate: o.placed_at
      ? new Date(o.placed_at).toLocaleDateString()
      : o.created_at
        ? new Date(o.created_at).toLocaleDateString()
        : '-',
    invoiceType: 'dropship',
    brandName: brandName.value,
    brandAddress: brandAddress.value,
    clientName: brandName.value,
    recipientName: recipientName.value,
    recipientPhone: recipientPhone.value || null,
    recipientAddress: recipientAddress.value || null,
    lines,
    charges: inlineCharges,
    subtotal,
    discount,
    total,
    paid: 0,
    due: total,
    thankYouMessage: thankYouMessage.value,
    isWholesale: false,
  };
});

const goBack = () => {
  window.close();
  if (!window.closed) {
    if (window.history.length > 1) {
      router.back();
    } else {
      void router.push({ name: 'dropship-orders' });
    }
  }
};

const printInvoice = () => {
  window.print();
};

const hydrateRecipientFields = (loadedOrder: ShopOrder) => {
  recipientName.value = loadedOrder.recipient_name || '';
  recipientPhone.value = loadedOrder.recipient_phone || '';

  const orderWithPostCode = loadedOrder as ShopOrder & {
    shipping_post_code?: string | null;
    post_code?: string | null;
  };
  const resolvedPostCode = orderWithPostCode.shipping_post_code || orderWithPostCode.post_code || '';
  const addressParts = [
    loadedOrder.shipping_address,
    loadedOrder.shipping_thana,
    loadedOrder.shipping_district,
    resolvedPostCode ? `Post Code: ${resolvedPostCode}` : '',
  ].filter(Boolean);
  recipientAddress.value = addressParts.join(', ');
};

const hydrateBrandFields = async (loadedOrder: ShopOrder) => {
  if (loadedOrder.billing_profile_id) {
    const { data: bp } = await supabase
      .from('billing_profiles')
      .select('name, address')
      .eq('id', loadedOrder.billing_profile_id)
      .maybeSingle();
    if (bp) {
      brandName.value = bp.name || '';
      brandAddress.value = bp.address || '';
      return;
    }
  }
  brandName.value = loadedOrder.customer_group_name || loadedOrder.shop_name || 'Dropship Reseller';
};

onMounted(async () => {
  const id = Number(route.params.id);
  const tenantId = useAuthStore().tenantId;

  try {
    if (id && tenantId) {
      const detail = await shopOrderRepository.getDropshipOrderDetailV2(tenantId, id);
      order.value = detail.order;
      items.value = detail.items;
      summaryState.value = { ...detail.summary };
      deliveredQuantities.value = Object.fromEntries(
        detail.items.map((item) => [
          item.id,
          item.confirmed_quantity != null ? item.confirmed_quantity : item.quantity,
        ]),
      );
    }

    const snapshot = loadDropshipV2CustomerInvoiceSnapshot(id);
    if (snapshot) {
      summaryState.value = snapshot.summary;
      deliveredQuantities.value = snapshot.deliveredQuantities;
    }

    if (order.value) {
      hydrateRecipientFields(order.value);
      await hydrateBrandFields(order.value);
    }
  } catch (err) {
    console.error('Failed to load customer invoice preview:', err);
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.a4-container {
  background: #fff;
  width: 100%;
  max-width: 800px;
  margin: 0 auto;
  min-height: 1120px;
  padding: 40px;
  border-radius: 4px;
}

@media print {
  .no-print {
    display: none !important;
  }

  .print-sheet-col {
    width: 100% !important;
    max-width: 100% !important;
    flex: 0 0 100% !important;
  }

  .a4-container {
    box-shadow: none !important;
    border-radius: 0;
    max-width: none;
    min-height: auto;
    padding: 0;
  }

  .recipient-preview-page {
    padding: 0 !important;
  }
}
</style>

<template>
  <q-page class="recipient-preview-page q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md no-print">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat dense icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline text-primary">Dropship Orders</div>
              <h1 class="text-h5 text-weight-bold q-my-none">Recipient Invoice Preview</h1>
              <p v-if="order?.order_no" class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Order #{{ order.order_no }}
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
            label="Print Invoice"
            @click="printInvoice"
          />
        </div>
      </section>

      <!-- Skeleton Loader -->
      <DropshipOrderRecipientInvoicePreviewSkeleton v-if="loading" />

      <!-- Loaded Content -->
      <div v-else class="row q-col-gutter-md">
        <!-- Sidebar controls - hidden on print -->
        <div class="col-12 col-md-4 no-print">
          <q-card flat bordered class="q-pa-md">
            <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">Customize Print</div>
            
            <q-input
              v-model="brandName"
              label="Brand Name"
              outlined
              dense
              class="q-mb-md"
            />

            <q-input
              v-model="brandAddress"
              label="Brand Address"
              type="textarea"
              outlined
              dense
              rows="2"
              class="q-mb-md"
            />

            <q-separator class="q-my-md" />

            <q-input
              v-model="recipientName"
              label="Recipient Name"
              outlined
              dense
              class="q-mb-md"
            />

            <q-input
              v-model="recipientPhone"
              label="Recipient Phone"
              outlined
              dense
              class="q-mb-md"
            />

            <q-input
              v-model="recipientAddress"
              label="Recipient Address"
              type="textarea"
              outlined
              dense
              rows="2"
              class="q-mb-md"
            />

            <q-input
              v-model="thankYouMessage"
              label="Thank You Message"
              outlined
              dense
              class="q-mb-md"
            />

            <q-toggle
              v-model="showItemImages"
              label="Show product images on print"
              class="q-mb-lg"
            />

            <q-btn
              color="primary"
              unelevated
              no-caps
              icon="ph ph-printer"
              label="Print Recipient Invoice"
              class="full-width text-weight-bold"
              @click="printInvoice"
            />
          </q-card>
        </div>

        <!-- Preview Sheet - centered / A4 styled -->
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

const route = useRoute();
const router = useRouter();
const loading = ref(true);

const goBack = () => {
  window.close();
  // Fallback in case window.close() is blocked by browser security (e.g. not opened via script)
  if (!window.closed) {
    if (window.history.length > 1) {
      router.back();
    } else {
      void router.push({ name: 'dropship-orders' });
    }
  }
};

const order = ref<any>(null);
const items = ref<any[]>([]);

// Customization states
const brandName = ref('');
const brandAddress = ref('');
const recipientName = ref('');
const recipientPhone = ref('');
const recipientAddress = ref('');
const thankYouMessage = ref('Thank you for shopping with us!');
const showItemImages = ref(true);

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

  // Calculate charges (excluding any that are cut/deducted from middle man's margin)
  const inlineCharges = [
    { type: 'delivery', label: 'Delivery', amount: o.deduct_delivery_from_margin ? 0 : Number(o.delivery_charge_amount || o.courier_cost_amount || 0) },
    { type: 'cod', label: 'COD', amount: o.deduct_cod_from_margin ? 0 : Number(o.cod_charge_amount || 0) },
    { type: 'print', label: 'Print', amount: o.deduct_print_from_margin ? 0 : Number(o.print_charge_amount || 0) },
    { type: 'packing', label: 'Wrapping', amount: o.deduct_packing_from_margin ? 0 : Number(o.packing_charge_amount || 0) },
  ].filter((c) => c.amount > 0);

  // Subtotal using customer sell price (face price)
  const subtotal = items.value.reduce(
    (sum, item) => sum + (item.customer_sell_price_amount ?? item.unit_sell_price_amount ?? 0) * item.quantity,
    0,
  );
  const discount = Number(o.discount_amount || 0);

  // Calculate Grand Total for Recipient
  const total = subtotal
    + inlineCharges.reduce((sum, c) => sum + c.amount, 0)
    - discount;

  // Lines
  const lines = items.value.map((item) => {
    const unitPrice = Number(item.customer_sell_price_amount ?? item.unit_sell_price_amount ?? 0);
    return {
      id: item.id,
      name: item.name || '',
      quantity: Number(item.quantity),
      unitPrice,
      lineTotal: unitPrice * item.quantity,
      imageUrl: item.image_url || null,
    };
  });

  return {
    id: o.id,
    invoiceNo: o.order_no || '-',
    invoiceDate: o.created_at ? new Date(o.created_at).toLocaleDateString() : '-',
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

const printInvoice = () => {
  window.print();
};

onMounted(async () => {
  const id = Number(route.params.id);
  const tenantId = useAuthStore().tenantId;
  if (!id || !tenantId) return;

  try {
    const orderRes = await shopOrderRepository.getShopOrderById(tenantId, id);
    order.value = orderRes.order;
    items.value = orderRes.items;

    // Load Recipient details
    recipientName.value = orderRes.order.recipient_name || '';
    recipientPhone.value = orderRes.order.recipient_phone || '';
    
    const orderWithPostCode = orderRes.order as typeof orderRes.order & {
      shipping_post_code?: string | null;
      post_code?: string | null;
    };
    const resolvedPostCode = orderWithPostCode.shipping_post_code || orderWithPostCode.post_code || '';
    const addressParts = [
      orderRes.order.shipping_address,
      orderRes.order.shipping_thana,
      orderRes.order.shipping_district,
      resolvedPostCode ? `Post Code: ${resolvedPostCode}` : '',
    ].filter(Boolean);
    recipientAddress.value = addressParts.join(', ');

    // Set initial brand
    if (orderRes.order.billing_profile_id) {
      const { data: bp } = await supabase
        .from('billing_profiles')
        .select('name, address')
        .eq('id', orderRes.order.billing_profile_id)
        .maybeSingle();
      if (bp) {
        brandName.value = bp.name || '';
        brandAddress.value = bp.address || '';
      } else {
        brandName.value = orderRes.order.customer_group_name || 'Dropship Reseller';
      }
    } else {
      brandName.value = orderRes.order.customer_group_name || 'Dropship Reseller';
    }
  } catch (err) {
    console.error('Failed to load dropship order data for print preview:', err);
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.glass-card {
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(10px);
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

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
    padding: 0 !important;
  }
  .a4-container {
    box-shadow: none !important;
    padding: 0 !important;
    border-radius: 0 !important;
    margin: 0 !important;
    min-height: auto !important;
  }
  .recipient-preview-page {
    background: transparent !important;
    padding: 0 !important;
  }
}
</style>

<script setup lang="ts">
import type { ShopOrder } from '../types';

defineProps<{
  order: ShopOrder | null;
  primaryCta: {
    label: string;
    icon: string;
    loading: boolean;
    action: () => void;
  } | null;
  isDeleting?: boolean;
}>();

const emit = defineEmits<{
  (e: 'open-recipient-invoice'): void;
  (e: 'delete-order'): void;
}>();
</script>

<template>
  <section class="row items-center justify-between q-col-gutter-md">
    <div class="col">
      <div class="row items-center q-gutter-x-sm">
        <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" :to="{ name: 'app-shop-dropship-orders-page' }" />
        <div>
          <div class="text-overline text-primary">Dropship Desk</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Process Order: {{ order?.order_no || 'ORD-DS' }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Middle Man: <strong class="text-grey-9">{{ order?.customer_group_name || order?.created_by_email || '—' }}</strong>
          </p>
        </div>
      </div>
    </div>
    <div class="col-auto row q-gutter-sm items-center">
      <q-btn
        v-if="order?.status === 'delivered'"
        color="primary"
        unelevated
        icon="ph ph-bank"
        label="Remit in Finance Hub"
        no-caps
        :to="{ name: 'app-shop-dropship-finance-hub-page', query: { orderId: order.id, step: 'courier_remittance' } }"
      />

      <q-btn
        v-if="order?.status !== 'confirmed' && order?.status !== 'submitted'"
        outline
        color="accent"
        icon="ph ph-receipt"
        label="Print Recipient Invoice"
        no-caps
        @click="emit('open-recipient-invoice')"
      />

      <q-btn
        v-if="order?.global_invoice_id"
        outline
        color="positive"
        icon="ph ph-receipt"
        label="View Accounting Invoice"
        no-caps
        :to="{ name: 'app-global-invoice-details-page', params: { id: order.global_invoice_id } }"
      />

      <q-btn
        v-if="primaryCta"
        color="primary"
        unelevated
        no-caps
        :icon="primaryCta.icon"
        :label="primaryCta.label"
        :loading="primaryCta.loading"
        @click="primaryCta.action"
      />

      <q-btn
        flat
        color="negative"
        icon="ph ph-trash"
        label="Delete Order"
        no-caps
        :loading="isDeleting"
        @click="emit('delete-order')"
      />
    </div>
  </section>
</template>

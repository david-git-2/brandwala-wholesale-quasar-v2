<script setup lang="ts">
import type { ShopOrder } from '../types';
import DropshipSettlementBadge from './DropshipSettlementBadge.vue';

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
    <div class="col-12 col-md">
      <div class="row items-center q-gutter-x-sm">
        <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" :to="{ name: 'app-shop-dropship-orders-page' }" />
        <div>
          <div class="text-overline text-primary">Dropship Desk</div>
          <div class="row items-center q-gutter-x-sm wrap">
            <h1 class="text-h5 text-weight-bold q-my-none">Process Order: {{ order?.order_no || 'ORD-DS' }}</h1>
            <DropshipSettlementBadge
              v-if="order && (order.global_invoice_id || ['delivered', 'completed', 'returned', 'payment_received'].includes(order.status))"
              :status="order.payout_settlement_status ?? null"
            />
          </div>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Merchant: <strong class="text-grey-9">{{ order?.customer_group_name || '—' }}</strong>
          </p>
        </div>
      </div>
    </div>
    <div class="col-12 col-md-auto row q-gutter-sm items-center justify-start justify-md-end wrap">
      <q-btn
        v-if="order?.status === 'delivered' && order?.collection_source !== 'billing_profile' && !order?.courier_remittance_ref"
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

      <q-btn flat round color="grey-7" icon="ph ph-dots-three-vertical">
        <q-menu auto-close anchor="bottom end" self="top end">
          <q-list style="min-width: 160px">
            <q-item clickable class="text-negative" @click="emit('delete-order')">
              <q-item-section avatar>
                <q-icon name="ph ph-trash" color="negative" />
              </q-item-section>
              <q-item-section>Delete Order</q-item-section>
            </q-item>
          </q-list>
        </q-menu>
      </q-btn>
    </div>
  </section>
</template>

<template>
  <div v-if="enabled" class="catalog-order-bills column q-gutter-y-sm">
    <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
      <q-icon name="ph ph-receipt" size="18px" color="primary" />
      <span>Bills</span>
    </div>
    <p class="text-caption text-grey-7 q-ma-none">
      Invoices and notes linked to this order (accept, condition, close, and related).
    </p>

    <q-spinner-dots v-if="isLoading && bills.length === 0" size="18px" color="primary" class="self-center q-py-sm" />

    <div v-if="!isLoading && bills.length === 0" class="text-caption text-grey-6 q-py-xs">
      No bills yet for this order.
    </div>

    <div v-if="bills.length" class="column q-gutter-y-xs full-width">
      <button
        v-for="bill in bills"
        :key="bill.id"
        type="button"
        class="catalog-order-bills__row row items-center justify-between no-wrap q-gutter-x-sm"
        :class="{ 'catalog-order-bills__row--nested': bill.parent_bill_id != null }"
        @click="emit('open-bill', bill)"
      >
        <div class="col min-width-0">
          <div class="row items-center no-wrap q-gutter-x-xs">
            <span class="font-mono text-caption text-weight-bold ellipsis">{{ bill.invoice_no }}</span>
            <q-badge
              v-if="channelLabel(bill)"
              dense
              :color="channelTone(bill)?.color ?? 'grey-2'"
              :text-color="channelTone(bill)?.textColor ?? 'grey-9'"
              class="text-weight-medium"
              :label="channelLabel(bill)!"
            />
          </div>
          <div v-if="bill.source_key" class="text-caption text-grey-6 ellipsis">
            {{ bill.source_key }}
          </div>
        </div>
        <div class="column items-end shrink-0 q-gutter-y-xs">
          <span class="text-caption text-weight-bold">{{ formatAmountBdt(bill.total_amount) }}</span>
          <span class="catalog-order-bills__status text-caption">{{ statusLabel(bill) }}</span>
        </div>
        <q-icon name="ph ph-caret-right" size="14px" color="grey-6" class="shrink-0" />
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { GlobalInvoiceRow } from 'src/modules/sales_invoice/types';
import {
  invoiceChannelLabel,
  invoiceChannelTone,
  invoiceListStatusLabel,
} from 'src/modules/sales_invoice/utils/invoiceListDisplay';
import { formatAmountBdt } from 'src/utils/currency';
import { useShopOrderBills } from '../composables/useShopOrderBills';
import type { ShopOrderBillListItem } from '../types/shopOrderBillList';

const props = defineProps<{
  parentTenantId: number | null;
  orderId: number;
  enabled: boolean;
}>();

const emit = defineEmits<{
  (e: 'open-bill', bill: ShopOrderBillListItem): void;
}>();

const enabled = computed(
  () => props.enabled && props.parentTenantId != null && props.orderId > 0,
);

const { bills, isLoading } = useShopOrderBills({
  parentTenantId: computed(() => props.parentTenantId),
  orderId: computed(() => props.orderId),
  enabled,
});

const asInvoiceRow = (bill: ShopOrderBillListItem) => bill as unknown as GlobalInvoiceRow;

const channelLabel = (bill: ShopOrderBillListItem) => invoiceChannelLabel(asInvoiceRow(bill));
const channelTone = (bill: ShopOrderBillListItem) => invoiceChannelTone(asInvoiceRow(bill));
const statusLabel = (bill: ShopOrderBillListItem) => invoiceListStatusLabel(asInvoiceRow(bill));
</script>

<style scoped>
.catalog-order-bills__row {
  width: 100%;
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
  background: var(--tf-neutral-surface);
  padding: 8px 10px;
  text-align: left;
  cursor: pointer;
}

.catalog-order-bills__row:hover {
  background: var(--tf-neutral-surface-hover, rgba(0, 0, 0, 0.03));
}

.catalog-order-bills__row--nested {
  margin-left: 12px;
  width: calc(100% - 12px);
}

.catalog-order-bills__status {
  color: var(--tf-text-muted, #64748b);
}
</style>

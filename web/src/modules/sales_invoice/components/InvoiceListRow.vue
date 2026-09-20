<script setup lang="ts">
import { computed } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import type { GlobalInvoiceRow } from '../types';
import {
  invoiceChannelLabel,
  invoiceListStatusIcon,
  invoiceListStatusLabel,
  invoiceListStatusSlug,
} from '../utils/invoiceListDisplay';

const props = defineProps<{
  row: GlobalInvoiceRow;
  showSoldBy?: boolean;
}>();

const emit = defineEmits<{
  (e: 'open', row: GlobalInvoiceRow): void;
}>();

const customerName = computed(
  () => props.row.billing_profile_name || props.row.recipient_name || 'No Customer',
);

const channelLabel = computed(() => invoiceChannelLabel(props.row));
const statusSlug = computed(() => invoiceListStatusSlug(props.row));
const statusLabel = computed(() => invoiceListStatusLabel(props.row));
const statusIcon = computed(() => invoiceListStatusIcon(props.row));

const formatAmount = (value: number) => formatAmountBdt(value);
</script>

<template>
  <div class="invoice-list-item" @click="emit('open', row)">
    <div class="invoice-info">
      <div class="invoice-title-line">
        <span class="invoice-name">{{ customerName }}</span>
      </div>
      <div class="invoice-meta-line">
        <span class="meta-item meta-id">#{{ row.invoice_no || row.id }}</span>
        <span class="meta-dot">·</span>
        <span class="meta-item meta-type">{{ channelLabel }}</span>
        <span class="meta-dot">·</span>
        <span class="meta-item meta-date">{{ row.invoice_date || '—' }}</span>
        <template v-if="showSoldBy && row.issued_by_tenant_name">
          <span class="meta-dot">·</span>
          <span class="meta-item meta-tenant">{{ row.issued_by_tenant_name }}</span>
        </template>
        <span class="meta-dot">·</span>
        <span class="meta-item meta-amount">{{ formatAmount(row.total_amount) }}</span>
        <template v-if="row.due_amount > 0">
          <span class="meta-dot">·</span>
          <span class="meta-item meta-due">Due {{ formatAmount(row.due_amount) }}</span>
        </template>
      </div>
    </div>

    <div class="invoice-aside">
      <span class="status-pill" :class="`status-pill--${statusSlug}`">
        <q-icon :name="statusIcon" size="12px" class="status-icon" />
        {{ statusLabel }}
      </span>
      <q-icon name="ph ph-caret-right" size="15px" class="invoice-chevron" />
    </div>
  </div>
</template>

<style lang="scss">
@import '../styles/invoice-list.scss';
</style>

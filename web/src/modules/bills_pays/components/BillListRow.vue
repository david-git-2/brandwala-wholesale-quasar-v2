<template>
  <div
    class="invoice-list-item"
    :class="{ 'invoice-list-item--nested': nested, 'invoice-list-item--tree-parent': treeParent }"
    @click="$emit('open', row)"
  >
    <div class="invoice-info">
      <div class="invoice-title-line">
        <span class="invoice-name">{{ row.invoice_no }}</span>
        <q-badge
          dense
          :color="channelTone.color"
          :text-color="channelTone.textColor"
          class="q-ml-xs text-weight-medium"
          :label="channelLabel"
        />
      </div>
      <div class="invoice-meta-line">
        <span class="meta-item">{{ profileName }}</span>
        <span class="meta-dot">·</span>
        <span class="meta-item meta-date">{{ row.invoice_date }}</span>
        <span v-if="row.due_amount > 0 && row.invoice_status === 'issued'" class="meta-dot">·</span>
        <span
          v-if="row.due_amount > 0 && row.invoice_status === 'issued'"
          class="meta-item meta-due"
        >
          Due {{ formatAmountBdt(row.due_amount) }}
        </span>
      </div>
    </div>
    <div class="invoice-aside">
      <span class="text-weight-bold text-slate-800" style="font-size: 12px">
        {{ formatAmountBdt(row.total_amount) }}
      </span>
      <span class="status-pill" :class="`status-pill--${statusSlug}`">
        <q-icon :name="statusIcon" size="12px" class="status-icon" />
        {{ statusLabel }}
      </span>
      <q-icon name="ph ph-caret-right" size="15px" class="invoice-chevron" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { BillListRow } from '../types/billList';
import type { GlobalInvoiceRow } from 'src/modules/sales_invoice/types';
import {
  invoiceChannelLabel,
  invoiceChannelTone,
  invoiceListStatusIcon,
  invoiceListStatusLabel,
  invoiceListStatusSlug,
} from 'src/modules/sales_invoice/utils/invoiceListDisplay';
import { formatAmountBdt } from 'src/utils/currency';

const props = withDefaults(
  defineProps<{
    row: BillListRow;
    nested?: boolean;
    /** Parent row with nested credit/debit notes on the current page. */
    treeParent?: boolean;
  }>(),
  {
    nested: false,
    treeParent: false,
  },
);

defineEmits<{
  open: [row: BillListRow];
}>();

const displayRow = computed(() => props.row as GlobalInvoiceRow);

const channelLabel = computed(() => invoiceChannelLabel(displayRow.value));
const channelTone = computed(() => invoiceChannelTone(displayRow.value));
const statusSlug = computed(() => invoiceListStatusSlug(displayRow.value));
const statusLabel = computed(() => invoiceListStatusLabel(displayRow.value));
const statusIcon = computed(() => invoiceListStatusIcon(displayRow.value));
const profileName = computed(
  () => props.row.profile_name || props.row.recipient_name || '—',
);
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
</style>

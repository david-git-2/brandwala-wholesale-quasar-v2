<template>
  <div class="invoice-list-item" @click="$emit('open', row)">
    <div class="invoice-info">
      <div class="invoice-title-line">
        <span class="invoice-name">Pay #{{ row.id }}</span>
        <q-badge dense color="blue-1" text-color="blue-9" :label="sourceLabel" class="q-ml-xs" />
        <q-badge v-if="row.voided_at" dense color="red-1" text-color="negative" label="Voided" class="q-ml-xs" />
      </div>
      <div class="text-caption text-weight-medium text-grey-9">
        {{ directionHeadline }}
      </div>
      <div class="invoice-meta-line">
        <span v-if="row.related_invoice_no" class="meta-item">{{ row.related_invoice_no }}</span>
        <span v-if="row.related_invoice_no" class="meta-dot">·</span>
        <span class="meta-item meta-date">{{ row.payment_date }}</span>
        <span v-if="row.reference" class="meta-dot">·</span>
        <span v-if="row.reference" class="meta-item">{{ row.reference }}</span>
      </div>
    </div>
    <div class="invoice-aside column items-end">
      <span class="text-weight-bold text-slate-800" style="font-size: 12px">
        {{ primaryAmountLabel }}
      </span>
      <span v-if="fxSubline" class="text-caption text-grey-7 tf-num">
        {{ fxSubline }}
      </span>
      <span v-if="row.unallocated_amount > 0" class="text-caption text-warning">
        +{{ formatAmountBdt(row.unallocated_amount) }} leftover
      </span>
      <q-icon name="ph ph-caret-right" size="15px" class="invoice-chevron" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { PayListRow } from '../repositories/paysRepository';
import { formatAmountBdt } from 'src/utils/currency';
import {
  payListDirectionHeadline,
  payListFxSubline,
  payListPrimaryAmountLabel,
} from '../utils/payListDisplay';

const props = withDefaults(
  defineProps<{
    row: PayListRow;
    perspective?: 'tenant' | 'party';
  }>(),
  { perspective: 'party' },
);

defineEmits<{ open: [row: PayListRow] }>();

const sourceLabel = computed(() => {
  const s = props.row.source;
  if (s === 'ap_payout') return 'AP pay out';
  if (s === 'courier_remittance') return 'Remittance';
  if (s === 'store_credit') return 'Store credit';
  if (s === 'bank') return 'Bank';
  return 'Pay in';
});

const directionHeadline = computed(() =>
  payListDirectionHeadline(props.row, props.perspective),
);

const primaryAmountLabel = computed(() => payListPrimaryAmountLabel(props.row));
const fxSubline = computed(() => payListFxSubline(props.row));
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
</style>

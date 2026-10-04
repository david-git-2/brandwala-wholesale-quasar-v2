<template>
  <div class="invoice-list-item" @click="$emit('open', row)">
    <div class="invoice-info">
      <div class="invoice-title-line">
        <span class="invoice-name">{{ row.name }}</span>
      </div>
      <div v-if="row.caption" class="invoice-meta-line">
        <span class="meta-item">{{ row.caption }}</span>
      </div>
    </div>
    <div class="invoice-aside">
      <span class="text-weight-bold text-slate-800" style="font-size: 12px">
        {{ formatAmountBdt(row.available_balance) }}
      </span>
      <q-icon name="ph ph-caret-right" size="15px" class="invoice-chevron" />
    </div>
  </div>
</template>

<script setup lang="ts">
import type { CashbookEntityRow } from '../repositories/cashbookRepository';
import { formatAmountBdt } from 'src/utils/currency';

defineProps<{ row: CashbookEntityRow }>();
defineEmits<{ open: [row: CashbookEntityRow] }>();
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
</style>

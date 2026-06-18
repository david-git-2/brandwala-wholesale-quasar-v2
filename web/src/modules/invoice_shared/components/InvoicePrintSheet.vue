<template>
  <div class="invoice-sheet shadow-2">
    <div class="row justify-between items-start q-mb-sm">
      <div class="col-7">
        <div class="text-subtitle1 text-weight-bold brand-title">{{ model.brandName || 'COMPANY BRAND' }}</div>
        <div class="text-caption text-grey-9 brand-address" style="white-space: pre-wrap">{{ model.brandAddress || '' }}</div>
      </div>
      <div class="col-5 text-right" style="font-size: 11px">
        <div class="text-subtitle1 text-weight-bold text-green-accent q-mb-xs">INVOICE</div>
        <div><strong>No:</strong> {{ model.invoiceNo }}</div>
        <div><strong>Date:</strong> {{ model.invoiceDate }}</div>
        <div class="text-capitalize"><strong>Type:</strong> {{ model.invoiceType }}</div>
      </div>
    </div>

    <div class="billing-profile-box border-light q-pa-sm rounded-borders bg-grey-1 q-mb-sm">
      <div class="text-weight-bold">{{ model.clientName }}</div>
      <div v-if="model.clientTr">TR: {{ model.clientTr }}</div>
      <template v-if="!model.isWholesale">
        <div class="q-mt-xs"><strong>Recipient:</strong> {{ model.recipientName }}</div>
        <div v-if="model.recipientPhone">{{ model.recipientPhone }}</div>
        <div v-if="model.recipientAddress" style="white-space: pre-wrap">{{ model.recipientAddress }}</div>
      </template>
    </div>

    <q-markup-table flat dense class="invoice-table q-mb-sm">
      <thead>
        <tr>
          <th class="text-left">SL</th>
          <th class="text-left">Item</th>
          <th class="text-right">Qty</th>
          <th class="text-right">Rate</th>
          <th class="text-right">Total</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(line, idx) in model.lines" :key="line.id">
          <td>{{ idx + 1 }}</td>
          <td>{{ line.name }}</td>
          <td class="text-right">{{ line.quantity }}</td>
          <td class="text-right">{{ formatAmount(line.unitPrice) }}</td>
          <td class="text-right">{{ formatAmount(line.lineTotal) }}</td>
        </tr>
      </tbody>
    </q-markup-table>

    <div class="row justify-end">
      <div style="min-width: 220px">
        <div class="row justify-between"><span>Subtotal</span><span>{{ formatAmount(model.subtotal) }}</span></div>
        <div v-for="charge in model.charges" :key="charge.type" class="row justify-between">
          <span>{{ charge.label }}</span><span>{{ formatAmount(charge.amount) }}</span>
        </div>
        <div v-if="model.discount > 0" class="row justify-between"><span>Discount</span><span>-{{ formatAmount(model.discount) }}</span></div>
        <div class="row justify-between text-weight-bold q-mt-xs"><span>Total</span><span>{{ formatAmount(model.total) }}</span></div>
        <div class="row justify-between"><span>Paid</span><span>{{ formatAmount(model.paid) }}</span></div>
        <div class="row justify-between"><span>Due</span><span>{{ formatAmount(model.due) }}</span></div>
      </div>
    </div>

    <div v-if="model.thankYouMessage" class="q-mt-md text-center text-caption">{{ model.thankYouMessage }}</div>
  </div>
</template>

<script setup lang="ts">
import { formatAmountBdt } from 'src/utils/currency'

import type { InvoicePrintModel } from '../types/invoicePrintModel'

defineProps<{ model: InvoicePrintModel }>()

const formatAmount = (value: number) => formatAmountBdt(value)
</script>

<style scoped>
.invoice-sheet {
  background: #fff;
  padding: 16px;
  border-radius: 8px;
}
.border-light {
  border: 1px solid rgba(0, 0, 0, 0.08);
}
</style>

<template>
  <div class="invoice-sheet shadow-2">
    <div class="row justify-between items-start q-mb-sm">
      <div class="col-7">
        <div class="text-subtitle1 text-weight-bold brand-title">{{ model.brandName || 'COMPANY BRAND' }}</div>
        <div class="text-caption text-grey-9 brand-address" style="white-space: pre-wrap">{{ model.brandAddress || '' }}</div>
      </div>
      <div class="col-5 text-right" style="font-size: 11px">
        <div class="text-subtitle1 text-weight-bold text-green-accent q-mb-xs">INVOICE</div>
        <div><strong>Invoice ID:</strong> {{ model.id }}-{{ model.invoiceDate }}</div>
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
          <th class="text-left" style="width: 40px">SL</th>
          <th v-if="hasImages" class="text-left" style="width: 50px">Image</th>
          <th class="text-left">Item</th>
          <th class="text-right">Qty</th>
          <th class="text-right">Rate</th>
          <th class="text-right">Total</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(line, idx) in model.lines" :key="line.id">
          <td>{{ idx + 1 }}</td>
          <td v-if="hasImages">
            <div v-if="line.imageUrl" class="print-item-image-box">
              <img :src="line.imageUrl" class="print-item-image" />
            </div>
            <div v-else class="print-item-image-box print-item-image-fallback">
              No Image
            </div>
          </td>
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
        <div class="row justify-between"><span>Total Qty</span><span>{{ totalQuantity }}</span></div>
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
import { computed } from 'vue'
import { formatAmountBdt } from 'src/utils/currency'

import type { InvoicePrintModel } from '../types/invoicePrintModel'

const props = defineProps<{ model: InvoicePrintModel }>()

const hasImages = computed(() => props.model.lines.some((line) => !!line.imageUrl))

const totalQuantity = computed(() => props.model.lines.reduce((sum, line) => sum + (line.quantity || 0), 0))

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
.print-item-image-box {
  width: 40px;
  height: 40px;
  border-radius: 4px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f8f9fa;
}
.print-item-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.print-item-image-fallback {
  font-size: 8px;
  color: #888;
  text-align: center;
}

@media print {
  .invoice-sheet {
    box-shadow: none !important;
    border: none !important;
    padding: 0 !important;
  }
  .billing-profile-box {
    border: 1px solid rgba(0, 0, 0, 0.15) !important;
    background-color: transparent !important;
  }
}
</style>

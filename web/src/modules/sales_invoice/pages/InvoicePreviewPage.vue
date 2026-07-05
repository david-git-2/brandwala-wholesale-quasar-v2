<template>
  <q-page class="invoice-preview-page q-pa-md">
    <PageInitialLoader v-if="loading" />
    <div v-else class="row q-col-gutter-md">
      <div class="col-12 col-md-4 no-print">
        <q-card flat class="floating-surface shadow-1 q-pa-md">
          <div class="text-subtitle1 text-weight-bold q-mb-md">Customize</div>
          <q-input v-model="brandName" label="Brand Name" outlined dense class="soft-input q-mb-sm" />
          <q-input v-model="brandAddress" label="Brand Address" type="textarea" outlined dense rows="2" class="soft-input q-mb-sm" />
          <q-input v-model="clientName" label="Client Name" outlined dense class="soft-input q-mb-sm" />
          <q-input v-model="thankYouMessage" label="Thank you message" outlined dense class="soft-input q-mb-md" />
          <q-btn color="primary" icon="print" label="Print" no-caps class="full-width pill-btn" @click="printInvoice" />
        </q-card>
      </div>
      <div class="col-12 col-md-8">
        <InvoicePrintSheet :model="printModel" />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import InvoicePrintSheet from 'src/modules/invoice_shared/components/InvoicePrintSheet.vue'
import type { InvoicePrintModel } from 'src/modules/invoice_shared/types/invoicePrintModel'

import { invoiceRepository } from '../repositories/invoiceRepository'
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from 'src/modules/global/types'

const route = useRoute()
const loading = ref(true)
const invoice = ref<GlobalInvoiceDetail | null>(null)
const items = ref<GlobalInvoiceItemRow[]>([])

const brandName = ref('')
const brandAddress = ref('')
const clientName = ref('')
const thankYouMessage = ref('Thank you for your business!')

const printModel = computed<InvoicePrintModel>(() => {
  const inv = invoice.value
  const isWholesale = inv?.invoice_type === 'wholesale'
  const isDropship = inv?.invoice_type === 'dropship'
  const subtotal = isDropship ? (inv?.face_subtotal_amount ?? inv?.subtotal_amount ?? 0) : (inv?.subtotal_amount ?? 0)

  // Construct charges array from inline header columns
  const inlineCharges = [
    { type: 'delivery', label: 'Delivery', amount: Number(inv?.shipping_charge ?? 0) },
    { type: 'cod', label: 'COD', amount: Number(inv?.cod_charge ?? 0) },
    { type: 'print', label: 'Print', amount: Number(inv?.print_charge ?? 0) },
    { type: 'packing', label: 'Wrapping', amount: Number(inv?.wrapping_charge ?? 0) },
  ].filter((c) => c.amount > 0)

  return {
    id: inv?.id ?? 0,
    invoiceNo: inv?.invoice_no ?? '-',
    invoiceDate: inv?.invoice_date ?? '-',
    invoiceType: inv?.invoice_type ?? 'wholesale',
    brandName: brandName.value,
    brandAddress: brandAddress.value,
    clientName: clientName.value || inv?.billing_profiles?.name || '-',
    recipientName: inv?.recipient_name || inv?.billing_profiles?.name || '-',
    recipientPhone: inv?.recipient_phone ?? null,
    recipientAddress: inv?.recipient_address ?? null,
    lines: items.value.map((row) => {
      const unit = isDropship
        ? Number(row.recipient_price_amount ?? row.sell_price_amount)
        : Number(row.sell_price_amount)
      const lineTotal = isDropship
        ? Number(row.line_face_total_amount ?? row.line_total_amount)
        : Number(row.line_total_amount)
      return {
        id: row.id,
        name: row.name_snapshot,
        quantity: Number(row.quantity),
        unitPrice: unit,
        lineTotal,
      }
    }),
    charges: inlineCharges,
    subtotal,
    discount: Number(inv?.discount_amount ?? 0),
    total: Number(inv?.total_amount ?? 0),
    paid: Number(inv?.paid_amount ?? 0),
    due: Number(inv?.due_amount ?? 0),
    thankYouMessage: thankYouMessage.value,
    isWholesale,
  }
})

const printInvoice = () => window.print()

onMounted(async () => {
  const id = Number(route.params.id)
  try {
    const [inv, invItems] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(id),
      invoiceRepository.listGlobalInvoiceItems(id),
    ])
    invoice.value = inv
    items.value = invItems
    brandName.value = inv.billing_profiles?.name ?? ''
    brandAddress.value = inv.billing_profiles?.address ?? ''
    clientName.value = inv.billing_profiles?.name ?? ''
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
@media print {
  .no-print {
    display: none !important;
  }
}
</style>

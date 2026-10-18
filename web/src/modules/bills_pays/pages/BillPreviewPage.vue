<template>
  <q-page class="bill-preview-page q-pa-sm">
    <div class="row items-center justify-between q-mb-md no-print">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Back" @click="goBack" />
      <div class="row items-center q-gutter-sm">
        <q-select
          v-model="selectedBrandId"
          :options="brandOptions"
          option-value="id"
          option-label="name"
          emit-value
          map-options
          outlined
          dense
          label="Letterhead brand"
          style="min-width: 200px"
        />
        <q-btn unelevated dense no-caps color="primary" icon="ph ph-printer" label="Print" @click="onPrint" />
        <q-btn flat dense no-caps label="Manage brands" @click="goBrands" />
      </div>
    </div>

    <div v-if="detailQuery.isPending.value" class="flex flex-center q-pa-xl">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="bill" class="preview-sheet q-pa-lg">
      <div class="row justify-between q-mb-lg">
        <template v-if="isApBill">
          <div class="col-grow column q-gutter-y-sm">
            <ApBillPartiesBlock :bill="bill" />
            <BillKernelSourceChips
              :source-type="bill.source_type"
              :source-id="bill.source_id"
              :source-key="bill.source_key ?? bill.ap_kind"
            />
          </div>
          <div class="col-auto text-right">
            <div v-if="documentTitle" class="text-subtitle1 text-weight-bold">{{ documentTitle }}</div>
            <div class="text-h6 text-weight-bold">{{ bill.invoice_no }}</div>
            <div v-if="parentInvoiceNo" class="text-caption text-grey-8">
              Against {{ parentInvoiceNo }}
            </div>
            <div class="text-caption text-grey-7">{{ bill.invoice_date }}</div>
            <div v-if="bill.due_date" class="text-caption">Due {{ bill.due_date }}</div>
            <div v-if="bill.currency_code" class="text-caption text-grey-7">{{ bill.currency_code }}</div>
          </div>
        </template>
        <template v-else>
          <div class="col-5">
            <div class="text-overline text-grey-7">From</div>
            <div class="text-h6 text-weight-bold">{{ selectedBrand?.name || '—' }}</div>
            <div v-if="selectedBrand?.address" class="text-body2 text-grey-8 q-mt-xs whitespace-pre-line">
              {{ selectedBrand.address }}
            </div>
          </div>
          <div class="col-4">
            <div class="text-overline text-grey-7">To</div>
            <div class="text-subtitle1 text-weight-bold">{{ profileName }}</div>
            <div v-if="bill.profiles?.address" class="text-caption text-grey-7 whitespace-pre-line">
              {{ bill.profiles.address }}
            </div>
          </div>
          <div class="col-auto text-right">
            <div v-if="documentTitle" class="text-subtitle1 text-weight-bold">{{ documentTitle }}</div>
            <div class="text-h6 text-weight-bold">{{ bill.invoice_no }}</div>
            <div v-if="parentInvoiceNo" class="text-caption text-grey-8">
              Against {{ parentInvoiceNo }}
            </div>
            <div class="text-caption text-grey-7">{{ bill.invoice_date }}</div>
            <div v-if="bill.due_date" class="text-caption">Due {{ bill.due_date }}</div>
          </div>
        </template>
      </div>

      <template v-if="isAdjustmentBill">
        <BillAdjustmentLinesTable
          :lines="adjustmentLineRows"
          :header-total-bdt="bill.total_amount"
        />
        <div class="row justify-end q-mt-md">
          <div class="totals-panel">
            <div class="total-row text-weight-bold">
              <span>Total (books)</span>
              <span>{{ formatAmountBdt(bill.total_amount) }}</span>
            </div>
            <div class="total-row">
              <span>Paid</span>
              <span>{{ formatAmountBdt(bill.paid_amount) }}</span>
            </div>
            <div class="total-row text-weight-bold">
              <span>Due</span>
              <span>{{ formatAmountBdt(bill.due_amount) }}</span>
            </div>
          </div>
        </div>
      </template>

      <template v-else-if="isApBill">
        <ApBillPaper
          :channel-meta="bill.channel_meta"
          :ap-kind="bill.source_key ?? bill.ap_kind"
          :total-amount="bill.total_amount"
        />
        <div class="row justify-end q-mt-md">
          <div class="totals-panel">
            <template v-if="apCurrencyBalances">
              <div
                v-for="(group, gIdx) in apCurrencyBalances"
                :key="group.currency_code"
                :class="{ 'ap-bill-balance-group--spaced': gIdx > 0 }"
              >
                <div
                  v-if="apCurrencyBalances.length > 1"
                  class="text-caption text-weight-bold text-grey-8 q-mb-xs text-uppercase"
                  style="letter-spacing: 0.04em"
                >
                  {{ group.currency_code }}
                </div>
                <div class="total-row">
                  <span>Total</span><span class="font-mono">{{ group.totalLabel }}</span>
                </div>
                <div v-if="group.conversionRate" class="total-row text-caption text-grey-7">
                  <span>Rate</span>
                  <span class="font-mono">{{ group.conversionRate }} BDT per 1 {{ group.currency_code }}</span>
                </div>
                <div class="total-row">
                  <span>Paid</span>
                  <div class="column items-end">
                    <span class="font-mono">{{ group.paidLabel }}</span>
                    <span v-if="group.paidBdtLabel" class="text-caption text-grey-7 font-mono">
                      {{ group.paidBdtLabel }} BDT
                    </span>
                  </div>
                </div>
                <div class="total-row text-weight-bold">
                  <span>Due</span>
                  <div class="column items-end">
                    <span class="font-mono">{{ group.dueLabel }}</span>
                    <span v-if="group.dueBdtLabel" class="text-caption text-grey-7 font-mono">
                      {{ group.dueBdtLabel }} BDT
                    </span>
                  </div>
                </div>
              </div>
            </template>
            <div v-else class="total-row text-weight-bold">
              <span>Total</span><span>{{ formatAmountBdt(bill.total_amount) }}</span>
            </div>
          </div>
        </div>
      </template>

      <template v-else>
        <q-markup-table flat dense class="preview-lines">
          <thead>
            <tr>
              <th class="text-left">Item</th>
              <th class="text-right">Qty</th>
              <th class="text-right">Sell</th>
              <th class="text-right">Disc.</th>
              <th class="text-right">Total</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="line in lines" :key="line.id">
              <td class="preview-line-item-cell">
                <BillLineItemDisplay :name="line.name_snapshot" :image-url="line.image_url" />
              </td>
              <td class="text-right">{{ line.quantity }}</td>
              <td class="text-right">{{ formatAmountBdt(line.sell_price_amount) }}</td>
              <td class="text-right">{{ formatAmountBdt(line.line_discount_amount) }}</td>
              <td class="text-right">{{ formatAmountBdt(line.line_total_amount) }}</td>
            </tr>
          </tbody>
        </q-markup-table>

        <div class="row justify-end q-mt-md">
          <div class="totals-panel">
            <div v-if="bill.discount_amount" class="total-row">
              <span>Discount</span><span>{{ formatAmountBdt(bill.discount_amount) }}</span>
            </div>
            <div v-if="bill.shipping_charge" class="total-row">
              <span>Shipping</span><span>{{ formatAmountBdt(bill.shipping_charge) }}</span>
            </div>
            <div v-if="bill.wrapping_charge" class="total-row">
              <span>Wrapping</span><span>{{ formatAmountBdt(bill.wrapping_charge) }}</span>
            </div>
            <div v-if="bill.print_charge" class="total-row">
              <span>Print</span><span>{{ formatAmountBdt(bill.print_charge) }}</span>
            </div>
            <div class="total-row text-weight-bold">
              <span>Total</span><span>{{ formatAmountBdt(bill.total_amount) }}</span>
            </div>
          </div>
        </div>
      </template>

      <div v-if="bill.note" class="q-mt-md text-caption">{{ bill.note }}</div>

      <div class="q-mt-lg flex flex-center column">
        <BarcodeRenderer :value="bill.invoice_no" :height="48" :display-value="true" />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from 'src/modules/sales_invoice/types';
import { invoiceRepository, type InvoiceBrand } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import BarcodeRenderer from 'src/modules/thrift/barcode/components/BarcodeRenderer.vue';
import BillLineItemDisplay from '../components/BillLineItemDisplay.vue';
import ApBillPaper from '../components/ApBillPaper.vue';
import BillAdjustmentLinesTable from '../components/BillAdjustmentLinesTable.vue';
import type { BillLineDisplayRow } from '../repositories/billLinesRepository';
import ApBillPartiesBlock from '../components/ApBillPartiesBlock.vue';
import BillKernelSourceChips from '../components/BillKernelSourceChips.vue';
import { useBillDetailQuery } from '../composables/useBillDetailQuery';
import { apBillCurrencyBalances } from '../utils/parseApBillPaper';

const BRAND_STORAGE_KEY = 'bills_pays_last_invoice_brand_id';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const billId = computed(() => {
  const raw = route.params.billId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const { detailQuery, itemsQuery, billLinesQuery } = useBillDetailQuery(billId);

const parentTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return null;
  return t.parent_id ?? t.id;
});

const brandsQuery = useQuery({
  queryKey: computed(() => ['invoice_brands', parentTenantId.value]),
  queryFn: () =>
    invoiceRepository.listInvoiceBrands({ parent_tenant_id: parentTenantId.value! }),
  enabled: computed(() => parentTenantId.value != null),
});

const brandOptions = computed(() => brandsQuery.data.value ?? []);
const selectedBrandId = ref<number | null>(null);

const selectedBrand = computed(() =>
  brandOptions.value.find((b) => b.id === selectedBrandId.value) ?? brandOptions.value[0],
);

watch(
  brandOptions,
  (brands) => {
    if (!brands.length) return;
    const storageKey = `${BRAND_STORAGE_KEY}_${parentTenantId.value ?? 0}`;
    const stored = localStorage.getItem(storageKey);
    const storedId = stored ? Number(stored) : NaN;
    if (Number.isFinite(storedId) && brands.some((b) => b.id === storedId)) {
      selectedBrandId.value = storedId;
    } else {
      selectedBrandId.value = brands[0].id;
    }
  },
  { immediate: true },
);

watch(selectedBrandId, (id) => {
  if (id == null || parentTenantId.value == null) return;
  localStorage.setItem(`${BRAND_STORAGE_KEY}_${parentTenantId.value}`, String(id));
});

const bill = computed(() => detailQuery.data.value as GlobalInvoiceDetail | undefined);
const isApBill = computed(() => bill.value?.invoice_type === 'ap');

const billDocumentKind = computed(() => {
  const b = bill.value as { document_kind?: string } | undefined;
  return b?.document_kind ?? 'standard';
});
const isAdjustmentBill = computed(() => billDocumentKind.value !== 'standard');
const documentTitle = computed(() => {
  if (billDocumentKind.value === 'credit_note') return 'Credit note';
  if (billDocumentKind.value === 'debit_note') return 'Debit note';
  return null;
});
const parentInvoiceNo = computed(() => {
  const meta = bill.value?.channel_meta as Record<string, unknown> | null;
  const adj = meta?.adjustment as Record<string, unknown> | undefined;
  const fromMeta = adj?.parent_invoice_no;
  if (typeof fromMeta === 'string' && fromMeta.trim()) return fromMeta.trim();
  return null;
});
const apCurrencyBalances = computed(() => {
  if (!isApBill.value || !bill.value) return null;
  return apBillCurrencyBalances(
    bill.value.channel_meta as Record<string, unknown> | null,
    bill.value.paid_amount,
    bill.value.due_amount,
  );
});
const lines = computed(() => (itemsQuery.data.value ?? []) as GlobalInvoiceItemRow[]);

const adjustmentLineRows = computed((): BillLineDisplayRow[] => {
  if (!isAdjustmentBill.value) return [];
  if (isApBill.value) {
    return billLinesQuery.data.value ?? [];
  }
  return lines.value.map((line) => ({
    id: line.id,
    name_snapshot: line.name_snapshot ?? 'Line',
    currency_code: 'BDT',
    line_total_amount: Number(line.line_total_amount ?? 0),
    books_amount: Number(line.line_total_amount ?? 0),
    quantity: Number(line.quantity ?? 1),
  }));
});

const profileName = computed(
  () => bill.value?.profiles?.name || bill.value?.recipient_name || '—',
);

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  const id = billId.value;
  if (!id) {
    router.push({ name: 'app-bills-page', params: tenantSlug ? { tenantSlug } : {} });
    return;
  }
  router.push({
    name: 'app-bill-detail-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(id),
    },
  });
};

const goBrands = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-bill-brands-page',
    params: tenantSlug ? { tenantSlug } : {},
  });
};

const onPrint = () => {
  window.print();
};
</script>

<style scoped>
.preview-sheet {
  max-width: 800px;
  margin: 0 auto;
  background: #fff;
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
}
.totals-panel {
  min-width: 200px;
  font-size: 13px;
}
.total-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 4px;
}

.ap-bill-balance-group--spaced {
  margin-top: 0.65rem;
  padding-top: 0.65rem;
  border-top: 1px solid var(--tf-neutral-border, #e2e8f0);
}
.preview-lines th {
  font-size: 11px;
  color: #64748b;
}
.preview-line-item-cell {
  vertical-align: top;
  max-width: 300px;
}
@media print {
  .no-print {
    display: none !important;
  }
  .preview-sheet {
    border: none;
    box-shadow: none;
  }
  .preview-line-item-cell img {
    print-color-adjust: exact;
    -webkit-print-color-adjust: exact;
  }
}
</style>

<style lang="scss">
@media print {
  .q-header,
  .q-drawer,
  .q-footer,
  .workspace-shell-toolbar {
    display: none !important;
  }
  .q-page-container {
    padding-top: 0 !important;
  }
}
</style>

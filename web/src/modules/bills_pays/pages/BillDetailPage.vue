<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden bill-detail-page">
    <div v-if="detailQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="detailQuery.isError.value" class="col flex flex-center text-negative">
      {{ detailErrorMessage }}
    </div>

    <div v-else-if="bill" class="col overflow-auto bill-print-root">
      <div class="bill-detail-card q-pa-md">
        <div class="bill-page-actions row items-center justify-end q-gutter-sm no-print q-mb-md">
          <q-btn
            v-if="canVoid"
            outline
            no-caps
            color="negative"
            icon="ph ph-prohibit"
            label="Void"
            :loading="voidMutation.isPending.value"
            @click="onVoid"
          />
          <q-btn
            unelevated
            no-caps
            color="primary"
            icon="ph ph-printer"
            label="Print"
            @click="onPrint"
          />
        </div>

        <div class="row items-start justify-between q-mb-md">
          <div>
            <div class="text-h6 text-weight-bold">{{ bill.invoice_no }}</div>
            <div class="text-caption text-grey-7 q-mt-xs">
              {{ channelLabel }} · {{ bill.invoice_date }}
              <span v-if="bill.due_date"> · Due {{ bill.due_date }}</span>
            </div>
          </div>
          <q-badge
            dense
            :color="channelTone.color"
            :text-color="channelTone.textColor"
            :label="statusLabel"
          />
        </div>

        <div class="q-mb-md">
          <ApBillPartiesBlock v-if="isApBill" :bill="bill" />
          <div v-else class="row q-col-gutter-md">
            <div class="col-12 col-sm-6">
              <div class="text-overline text-grey-7">To</div>
              <div class="text-subtitle2 text-weight-medium">{{ profileName }}</div>
              <div v-if="bill.billing_profiles?.email" class="text-caption text-grey-7">
                {{ bill.billing_profiles.email }}
              </div>
              <div v-if="bill.billing_profiles?.address" class="text-caption text-grey-7">
                {{ bill.billing_profiles.address }}
              </div>
            </div>
          </div>
        </div>

        <template v-if="isApBill">
          <ApBillPaper
            :channel-meta="bill.channel_meta"
            :ap-kind="bill.ap_kind"
            :total-amount="bill.total_amount"
          />
          <div class="row justify-end q-mt-md">
            <div class="bill-totals-panel">
              <div class="bill-total-row text-weight-bold">
                <span>Total</span>
                <span>{{ formatAmountBdt(bill.total_amount) }}</span>
              </div>
              <div class="bill-total-row">
                <span>Paid</span>
                <span>{{ formatAmountBdt(bill.paid_amount) }}</span>
              </div>
              <div class="bill-total-row text-weight-bold">
                <span>Due</span>
                <span>{{ formatAmountBdt(bill.due_amount) }}</span>
              </div>
            </div>
          </div>
        </template>

        <template v-else>
          <q-markup-table flat dense class="bill-lines-table">
            <thead>
              <tr>
                <th class="text-left">Item</th>
                <th class="text-right">Qty</th>
                <th class="text-right">Sell</th>
                <th class="text-right">Disc.</th>
                <th class="text-right">Line total</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="line in lines" :key="line.id">
                <td class="bill-line-item-cell">
                  <BillLineItemDisplay :name="line.name_snapshot" :image-url="line.image_url" />
                </td>
                <td class="text-right">{{ line.quantity }}</td>
                <td class="text-right">{{ formatAmountBdt(line.sell_price_amount) }}</td>
                <td class="text-right">{{ formatAmountBdt(line.line_discount_amount) }}</td>
                <td class="text-right text-weight-medium">{{ formatAmountBdt(line.line_total_amount) }}</td>
              </tr>
            </tbody>
          </q-markup-table>

          <div class="row justify-end q-mt-md">
            <div class="bill-totals-panel">
              <div v-if="bill.discount_amount" class="bill-total-row">
                <span>Discount</span>
                <span>{{ formatAmountBdt(bill.discount_amount) }}</span>
              </div>
              <div v-if="bill.shipping_charge" class="bill-total-row">
                <span>Shipping</span>
                <span>{{ formatAmountBdt(bill.shipping_charge) }}</span>
              </div>
              <div v-if="bill.wrapping_charge" class="bill-total-row">
                <span>Wrapping</span>
                <span>{{ formatAmountBdt(bill.wrapping_charge) }}</span>
              </div>
              <div v-if="bill.print_charge" class="bill-total-row">
                <span>Print</span>
                <span>{{ formatAmountBdt(bill.print_charge) }}</span>
              </div>
              <div class="bill-total-row text-weight-bold">
                <span>Total</span>
                <span>{{ formatAmountBdt(bill.total_amount) }}</span>
              </div>
              <div class="bill-total-row">
                <span>Paid</span>
                <span>{{ formatAmountBdt(bill.paid_amount) }}</span>
              </div>
              <div class="bill-total-row text-weight-bold">
                <span>Due</span>
                <span>{{ formatAmountBdt(bill.due_amount) }}</span>
              </div>
            </div>
          </div>
        </template>

        <div v-if="bill.note" class="q-mt-md">
          <div class="text-overline text-grey-7">Note</div>
          <div class="text-body2">{{ bill.note }}</div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { formatAmountBdt } from 'src/utils/currency';
import { requestConfirmation } from 'src/utils/appFeedback';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow, GlobalInvoiceRow } from 'src/modules/sales_invoice/types';
import {
  invoiceChannelLabel,
  invoiceChannelTone,
  invoiceListStatusLabel,
} from 'src/modules/sales_invoice/utils/invoiceListDisplay';
import { useBillDetailQuery } from '../composables/useBillDetailQuery';
import { useVoidBillMutation } from '../composables/useVoidBillMutation';
import BillLineItemDisplay from '../components/BillLineItemDisplay.vue';
import ApBillPaper from '../components/ApBillPaper.vue';
import ApBillPartiesBlock from '../components/ApBillPartiesBlock.vue';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

const billId = computed(() => {
  const raw = route.params.billId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const { detailQuery, itemsQuery } = useBillDetailQuery(billId);
const voidMutation = useVoidBillMutation(() => billId.value);

const bill = computed(() => detailQuery.data.value as GlobalInvoiceDetail | undefined);
const isApBill = computed(() => bill.value?.invoice_type === 'ap');
const lines = computed(() => (itemsQuery.data.value ?? []) as GlobalInvoiceItemRow[]);

const profileName = computed(
  () => bill.value?.billing_profiles?.name || bill.value?.recipient_name || '—',
);

const channelLabel = computed(() =>
  bill.value ? invoiceChannelLabel(bill.value as GlobalInvoiceRow) : '',
);
const channelTone = computed(() =>
  bill.value ? invoiceChannelTone(bill.value as GlobalInvoiceRow) : { color: 'grey-3', textColor: 'grey-9' },
);
const statusLabel = computed(() =>
  bill.value ? invoiceListStatusLabel(bill.value as GlobalInvoiceRow) : '',
);

const canVoid = computed(
  () =>
    bill.value?.invoice_status === 'issued' &&
    Number(bill.value.paid_amount ?? 0) === 0,
);

const detailErrorMessage = computed(() => {
  const err = detailQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load bill.';
});

const billLeafLabel = computed(() => {
  const no = bill.value?.invoice_no?.trim();
  if (no) return no;
  return billId.value ? `Bill #${billId.value}` : 'Bill';
});

const breadcrumbItems = computed(() => {
  const tenantSlug =
    (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null) ||
    authStore.tenantSlug ||
    undefined;
  return [
    {
      label: authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    {
      label: 'Bills',
      to: {
        name: 'app-bills-page',
        ...(tenantSlug ? { params: { tenantSlug } } : {}),
      },
    },
    { label: billLeafLabel.value },
  ];
});

watch(breadcrumbItems, (items) => setCustomBreadcrumbs(items), { immediate: true });
onBeforeUnmount(() => clearCustomBreadcrumbs());

const onPrint = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  const id = billId.value;
  if (!id) return;
  router.push({
    name: 'app-bill-preview-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(id),
    },
  });
};

const onVoid = async () => {
  if (!canVoid.value) return;
  const ok = await requestConfirmation(
    'Stock on this bill will be restored. This cannot be undone.',
    'Void this bill?',
  );
  if (!ok) return;
  await voidMutation.mutateAsync();
};
</script>

<style scoped lang="scss">
.page-fixed-layout {
  height: calc(100vh - 55px);
}

.bill-detail-card {
  max-width: 960px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: var(--bw-radius-sm, 8px);
}

.bill-totals-panel {
  min-width: 220px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 13px;
}

.bill-total-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}

.bill-lines-table th {
  font-size: 11px;
  color: var(--bw-neutral-chrome, #64748b);
  font-weight: 600;
}

.bill-line-item-cell {
  vertical-align: top;
  max-width: 320px;
}

.bill-page-actions :deep(.q-btn) {
  min-height: 36px;
  padding: 0 14px;
}

@media print {
  .no-print {
    display: none !important;
  }

  .bill-detail-page {
    height: auto !important;
    overflow: visible !important;
  }

  .bill-print-root {
    overflow: visible !important;
  }

  .bill-detail-card {
    border: none;
    box-shadow: none;
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

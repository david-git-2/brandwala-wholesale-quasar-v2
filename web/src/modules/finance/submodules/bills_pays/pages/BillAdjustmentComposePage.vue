<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="bundleQuery.isLoading.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="bundleQuery.isError.value || !bill" class="col flex flex-center column q-gutter-sm">
      <span class="text-negative">{{ loadErrorMessage }}</span>
      <TfBtn variant="secondary" label="Close" @click="closePage" />
    </div>

    <div v-else-if="!canCompose" class="col flex flex-center column q-gutter-sm">
      <span class="text-grey-7">This bill cannot take a credit or debit note right now.</span>
      <TfBtn variant="secondary" label="Back to bill" @click="goToParentBill" />
    </div>

    <template v-else>
      <div class="row items-center justify-between q-mb-sm shrink-0">
        <div class="text-h6 text-weight-bold">{{ composerPageTitle }}</div>
        <TfBtn variant="secondary" label="Cancel" @click="closePage" />
      </div>

      <div class="col overflow-auto">
        <q-card flat bordered class="q-pa-md q-mb-md">
          <div class="text-caption text-weight-bold text-uppercase" style="color: var(--tf-neutral-chrome-text)">
            Original bill (read-only)
          </div>
          <div class="text-subtitle1 text-weight-bold q-mt-xs">{{ parentBillLabel }}</div>
          <div class="text-caption text-grey-7 q-mt-xs">
            {{ bill.invoice_no }} · Due {{ formatParentDue }}
          </div>
          <div class="q-mt-md">
            <ApBillPaper
              v-if="isApBill"
              :channel-meta="bill.channel_meta as Record<string, unknown> | null"
              :ap-kind="bill.source_key ?? bill.ap_kind"
              :total-amount="bill.total_amount"
              :desk-bill-lines="bundleQuery.data.value?.billLines"
            />
            <q-markup-table v-else flat dense class="q-mt-sm">
              <thead>
                <tr>
                  <th class="text-left">Item</th>
                  <th class="text-right">Qty</th>
                  <th class="text-right">Line total</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="line in stockLines" :key="line.id">
                  <td>{{ line.name_snapshot }}</td>
                  <td class="text-right">{{ line.quantity }}</td>
                  <td class="text-right font-mono">{{ formatAmountBdt(line.line_total_amount) }}</td>
                </tr>
              </tbody>
            </q-markup-table>
          </div>
        </q-card>

        <q-card flat bordered class="q-pa-md">
          <template v-if="!isWriteOffKind">
            <div class="text-caption text-weight-bold text-uppercase q-mb-sm" style="color: var(--tf-neutral-chrome-text)">
              Note lines
            </div>
            <p class="text-caption text-grey-7 q-mb-sm">
              One row per item. Unit price uses the invoice currency ({{
                noteLineCurrencyCode
              }}). Line total is quantity × unit price.
            </p>
            <BillAdjustmentLinesComposer
              :rows="extraDraftRows"
              :currency-code="noteLineCurrencyCode"
              :currency-symbol="noteLineCurrencySymbol"
              @line-sync="onExtraLineSync"
              @remove-line="removeExtraLine"
            />
            <div class="q-mt-sm row items-center q-gutter-sm">
              <TfBtn
                variant="secondary"
                size="sm"
                icon="ph ph-plus"
                label="Add line"
                @click="addExtraRow(defaultExtraCurrency)"
              />
            </div>
          </template>

          <BillAdjustmentNoteBar
            v-model:kind="kind"
            v-model:reason="reason"
            v-model:write-off-amount="writeOffAmount"
            v-model:refund-cash-now="refundCashNow"
            v-model:refund-amount="refundAmount"
            ref="adjustmentNoteBarRef"
            :class="isWriteOffKind ? '' : 'q-mt-md'"
            :note-total-labels="noteTotalLabels"
            :balance-effect="balanceEffect"
            :submit-disabled-reason="submitDisabledReason"
            :loading="adjustmentActionLoading"
            :tenant-id="operatingTenantId"
            :parent-due-amount="parentDueAmount"
            :ar-refund-eligible="arRefundEligible"
            :excess-credit-bdt="excessCreditBdt"
            :is-ap-parent="isApBill"
            :allowed-kinds="composerAllowedKinds"
            @cancel="closePage"
            @submit="submitAdjustment"
          />
        </q-card>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import TfBtn from 'src/components/ui/TfBtn.vue';
import ApBillPaper from '../components/ApBillPaper.vue';
import BillAdjustmentNoteBar from '../components/BillAdjustmentNoteBar.vue';
import BillAdjustmentLinesComposer from '../components/BillAdjustmentLinesComposer.vue';
import { useBillDetailBundleQuery } from '../composables/useBillDetailBundleQuery';
import { useBillAdjustmentDraft } from '../composables/useBillAdjustmentDraft';
import { useCurrencySymbolMap } from '../composables/useCurrencySymbolMap';
import { useCreateBillAdjustmentMutation } from '../composables/useCreateBillAdjustmentMutation';
import { useWriteOffBillMutation } from '../composables/useWriteOffBillMutation';
import { billDetailRoute, type BillDetailAdjustmentKind } from '../utils/billRoutes';
import type { BillAdjustmentUiKind } from '../composables/useBillAdjustmentDraft';
import { formatAmountBdt } from 'src/utils/currency';
import { showErrorNotification } from 'src/utils/appFeedback';
import type { GlobalInvoiceItemRow } from 'src/modules/finance/submodules/bills_pays/types/invoice';
import type { BillAdjustmentRow } from '../types/billAdjustments';
import { kernelBillLinesToStockRows } from '../utils/kernelBillLinesToStockRows';
import { isInvWsWholesaleBill as isInvWsWholesaleBillCheck } from '../utils/wholesaleKernelBill';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

const lineEntryMode = ref<'addLinesOnly'>('addLinesOnly');
const composerActive = ref(true);
const adjustmentNoteBarRef = ref<InstanceType<typeof BillAdjustmentNoteBar> | null>(null);

const billId = computed(() => {
  const raw = route.params.billId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const tenantSlug = computed(
  () =>
    (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null) ||
    authStore.tenantSlug ||
    null,
);

const operatingTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t?.id) return 0;
  return t.parent_id ?? t.id;
});

const bundleQuery = useBillDetailBundleQuery(billId, operatingTenantId);
const bill = computed(() => bundleQuery.data.value?.bill);

const loadErrorMessage = computed(
  () => bundleQuery.error.value?.message ?? 'Could not load bill.',
);

const isStandardBill = computed(
  () => (bill.value?.document_kind ?? 'standard') === 'standard',
);

const isArStockInvoiceType = (invoiceType: string | null | undefined) =>
  invoiceType === 'wholesale' || invoiceType === 'retail' || invoiceType === 'dropship';
const isApBill = computed(() => bill.value?.invoice_type === 'ap');
const isWholesaleKernelBill = computed(() => isInvWsWholesaleBillCheck(bill.value ?? null));
const parentDueAmount = computed(() => Number(bill.value?.due_amount ?? 0));

const adjustmentRows = computed(
  () => (bundleQuery.data.value?.adjustments ?? []) as BillAdjustmentRow[],
);

const stockLines = computed((): GlobalInvoiceItemRow[] => {
  const b = bill.value;
  const bundle = bundleQuery.data.value;
  const id = billId.value;
  if (!b || !id) return [];
  if (
    bundle?.billLines?.length &&
    isStandardBill.value &&
    !isApBill.value &&
    isArStockInvoiceType(b.invoice_type)
  ) {
    return kernelBillLinesToStockRows(bundle.billLines, id);
  }
  return [];
});

const canCompose = computed(() => {
  const b = bill.value;
  if (!b || !isStandardBill.value || b.invoice_status !== 'issued') return false;
  return true;
});

const parentBillLabel = computed(() => bill.value?.invoice_no ?? `Bill #${billId.value ?? ''}`);

const formatParentDue = computed(() => {
  const due = parentDueAmount.value;
  if (isApBill.value) return formatAmountBdt(due);
  return formatAmountBdt(due);
});

const createAdjustmentMutation = useCreateBillAdjustmentMutation(() => billId.value);
const writeOffMutation = useWriteOffBillMutation(() => billId.value);

const {
  kind,
  reason,
  writeOffAmount,
  isWriteOffKind,
  onExtraLineSync,
  addExtraRow,
  extraDraftRows,
  noteTotalLabels,
  balanceEffect,
  submitDisabledReason,
  buildSubmitPayload,
  buildWriteOffPayload,
  defaultExtraCurrency,
  arRefundEligible,
  excessCreditBdt,
  refundCashNow,
  refundAmount,
  draftRows,
} = useBillAdjustmentDraft({
  bill,
  booksTenantId: operatingTenantId,
  stockLines,
  isAp: isApBill,
  parentDueAmount,
  siblingNotes: adjustmentRows,
  active: composerActive,
  lineEntryMode,
});

const { currencySymbolMap } = useCurrencySymbolMap();

const noteLineCurrencyCode = computed(() => defaultExtraCurrency.value);

const noteLineCurrencySymbol = computed(
  () => currencySymbolMap.value.get(noteLineCurrencyCode.value) ?? null,
);

const adjustmentActionLoading = computed(
  () => createAdjustmentMutation.isPending.value || writeOffMutation.isPending.value,
);

function parseAdjustmentKindQuery(raw: unknown): BillDetailAdjustmentKind | null {
  if (typeof raw !== 'string') return null;
  const k = raw.trim();
  if (k === 'credit_note' || k === 'debit_note' || k === 'write_off') return k;
  return null;
}

const routeAdjustmentKind = computed(() => parseAdjustmentKindQuery(route.query.adjustmentKind));

const composerAllowedKinds = computed((): BillAdjustmentUiKind[] | undefined => {
  const fromRoute = routeAdjustmentKind.value;
  if (fromRoute) return [fromRoute];
  if (isApBill.value) return ['credit_note', 'write_off'];
  if (isWholesaleKernelBill.value) return ['write_off'];
  return undefined;
});

const composerPageTitle = computed(() => {
  if (routeAdjustmentKind.value === 'write_off') return 'Write off';
  if (routeAdjustmentKind.value === 'credit_note') return 'Credit note';
  if (isApBill.value) return 'Credit note or write-off';
  if (isWholesaleKernelBill.value) return 'Write off';
  return 'Credit or debit note';
});

function removeExtraLine(key: string) {
  const idx = draftRows.value.findIndex((r) => r.key === key);
  if (idx < 0) return;
  draftRows.value.splice(idx, 1);
  if (!draftRows.value.some((r) => r.isExtra)) {
    addExtraRow(defaultExtraCurrency.value);
  }
}

function goToParentBill() {
  const id = billId.value;
  if (id == null) return;
  void router.push(billDetailRoute(id, tenantSlug.value));
}

function closePage() {
  if (typeof window !== 'undefined' && window.history.length > 1) {
    window.close();
  }
  goToParentBill();
}

const submitAdjustment = async () => {
  if (isWriteOffKind.value) {
    const writeOffPayload = buildWriteOffPayload();
    if (!writeOffPayload) return;
    await writeOffMutation.mutateAsync(writeOffPayload);
    goToParentBill();
    return;
  }
  const pointRef = adjustmentNoteBarRef.value?.cashbookPointId;
  const pointId =
    pointRef != null && typeof pointRef === 'object' && 'value' in pointRef
      ? (pointRef as { value: number | null }).value
      : (pointRef as number | null | undefined) ?? null;
  const payload = buildSubmitPayload(pointId);
  if (!payload) return;
  if (refundCashNow.value && !payload.cashbookPointId) {
    showErrorNotification('Choose a till or safe to pay the refund from.');
    return;
  }
  const created = await createAdjustmentMutation.mutateAsync(payload);
  const cnId = created.bill_id;
  if (cnId != null && cnId > 0) {
    void router.replace(billDetailRoute(cnId, tenantSlug.value));
    return;
  }
  goToParentBill();
};

watch(
  () => [routeAdjustmentKind.value, bundleQuery.isSuccess.value, parentDueAmount.value] as const,
  ([presetKind]) => {
    if (!presetKind) return;
    if (presetKind === 'debit_note' && isApBill.value) return;
    kind.value = presetKind;
    if (presetKind === 'write_off' && writeOffAmount.value == null && parentDueAmount.value > 0) {
      writeOffAmount.value = parentDueAmount.value;
    }
  },
  { immediate: true },
);

watch(
  () => [route.query.reason, route.query.suggestedAmount, bundleQuery.isSuccess.value] as const,
  ([qr, suggested]) => {
    if (typeof qr === 'string' && qr.trim() && !reason.value.trim()) {
      reason.value = qr.trim();
    }
    const amt = typeof suggested === 'string' ? Number(suggested) : NaN;
    if (!Number.isFinite(amt) || amt <= 0) return;
    const row = extraDraftRows.value[0];
    if (!row) return;
    if (row.amount == null && row.unitPrice == null) {
      row.amount = amt;
      row.selected = true;
    }
  },
  { immediate: true },
);

watch(
  () => [parentBillLabel.value, composerPageTitle.value] as const,
  ([label, pageTitle]) => {
    const slug = tenantSlug.value;
    const prefix = slug ? `/${slug}` : '';
    const id = billId.value;
    setCustomBreadcrumbs([
      { label: 'Bills', to: `${prefix}/app/bills` },
      { label, to: id != null ? billDetailRoute(id, slug) : undefined },
      { label: pageTitle },
    ]);
  },
  { immediate: true },
);

onMounted(() => {
  if (billId.value != null) {
    void bundleQuery.refetch();
  }
});

onUnmounted(clearCustomBreadcrumbs);
</script>

<style scoped lang="scss">
.page-fixed-layout {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
}
</style>
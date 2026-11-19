<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="bundleQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="bundleQuery.isError.value || !bill" class="col flex flex-center column q-gutter-sm">
      <span class="text-negative">{{ loadErrorMessage }}</span>
      <TfBtn variant="secondary" label="Go back" @click="goBack" />
    </div>

    <div v-else-if="!canRecordVendorRefund" class="col flex flex-center column q-gutter-sm">
      <span class="text-grey-7">This bill has no open vendor credit to refund.</span>
      <TfBtn variant="secondary" label="Back to bill" @click="goBack" />
    </div>

    <template v-else>
      <div class="bill-pay-page__toolbar row items-center justify-between q-mb-sm shrink-0">
        <div class="text-h6 text-weight-bold">Record vendor refund</div>
        <div class="row items-center q-gutter-sm">
          <TfBtn variant="secondary" label="Cancel" @click="goBack" />
          <TfBtn
            variant="primary"
            icon="ph ph-arrow-down-left"
            label="Record refund"
            :loading="vendorRefundMutation.isPending.value"
            :disable="!formRef || Boolean(submitBlockReason)"
            @click="onSubmit"
          >
            <q-tooltip v-if="submitBlockReason">{{ submitBlockReason }}</q-tooltip>
          </TfBtn>
        </div>
      </div>

      <div class="col overflow-auto bill-pay-page__body">
        <div class="bill-pay-page__stack column q-gutter-y-md">
          <MoneyPayDialogSummary
            :visible="true"
            :context="refundSummary"
            :pay-amount="payingNowAmount"
            :pay-currency-code="payingNowCurrency"
          />

          <q-card flat bordered class="q-pa-md">
            <div class="text-caption text-weight-bold text-uppercase text-grey-7">Credit</div>
            <div class="text-subtitle1 text-weight-bold q-mt-xs">{{ billLeafLabel }}</div>
            <div v-if="activeCreditNoteRow?.invoice_no" class="text-caption text-grey-7 q-mt-xs">
              Note {{ activeCreditNoteRow.invoice_no }}
            </div>
          </q-card>

          <VendorCreditRefundForm
            v-if="selectedCreditNoteId"
            ref="formRef"
            :credit-note-id="selectedCreditNoteId"
            :parent-bill-id="parentBillId"
            :open-credit="openCreditBooks"
            :books-tenant-id="operatingTenantId"
            :operating-tenant-id="staffTenantId"
            :receive-profile-id="tenantMoneyProfileId"
            :from-profile-name="fromProfileName"
            :tenant-label="tenantLabel"
            :channel-meta="channelMeta"
            :invoice-currency-code="invoiceCurrencyCode"
            :credit-note-options="openCreditNoteOptions"
            :active="pageActive"
            @update:credit-note-id="onCreditNotePicked"
            @pay-amount-change="onPayAmountChange"
            @submit="onVendorRefund"
          />
        </div>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import TfBtn from 'src/components/ui/TfBtn.vue';
import MoneyPayDialogSummary from '../components/MoneyPayDialogSummary.vue';
import VendorCreditRefundForm from '../components/VendorCreditRefundForm.vue';
import { useBillDetailBundleQuery } from '../composables/useBillDetailBundleQuery';
import { useBillVendorRefundPage } from '../composables/useBillVendorRefundPage';
import {
  usePostVendorCreditRefundMutation,
  type PostVendorCreditRefundInput,
} from '../composables/usePostVendorCreditRefundMutation';
import { billDetailRoute, billVendorRefundRoute } from '../utils/billRoutes';
import type { MoneyPaySummaryContext } from '../types/moneyPayDialog';
import { vendorRefundOpenCreditFace } from '../utils/vendorRefundDisplay';
import { useBooksCurrencyCode } from '../composables/useBooksCurrencyCode';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();
const booksCurrencyCode = useBooksCurrencyCode();

const pageActive = ref(true);
const formRef = ref<InstanceType<typeof VendorCreditRefundForm> | null>(null);
const payingNowAmount = ref<number | null>(null);
const payingNowCurrency = ref('BDT');

const billId = computed(() => {
  const raw = route.params.billId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const creditNoteIdFromQuery = computed(() => {
  const raw = route.query.creditNoteId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const operatingTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t?.id) return 0;
  return t.parent_id ?? t.id;
});

const bundleQuery = useBillDetailBundleQuery(billId, operatingTenantId);
const bill = computed(() => bundleQuery.data.value?.bill);
const bundle = computed(() => bundleQuery.data.value);

const {
  openCreditNoteOptions,
  selectedCreditNoteId,
  activeCreditNoteRow,
  parentBillId,
  openCreditBooks,
  channelMeta,
  fromProfileName,
  canRecordVendorRefund,
  tenantReceiveProfileId,
} = useBillVendorRefundPage({
  routeBillId: billId,
  creditNoteIdFromQuery,
  bill,
  bundle,
});

const vendorRefundMutation = usePostVendorCreditRefundMutation(() => billId.value);

const tenantLabel = computed(() => authStore.selectedTenant?.name ?? 'Our books');

const tenantMoneyProfileId = computed(() => {
  const fromCn = tenantReceiveProfileId.value;
  if (fromCn != null && fromCn > 0) return fromCn;
  const b = bill.value;
  if (!b) return operatingTenantId.value;
  return (
    b.from_profile_id
    ?? (b.from_profile as { id?: number } | null | undefined)?.id
    ?? operatingTenantId.value
  );
});

const staffTenantId = computed(() => authStore.selectedTenant?.id ?? 0);

const invoiceCurrencyCode = computed(() => {
  const code = String(bill.value?.currency_code ?? '').trim().toUpperCase();
  return code || booksCurrencyCode.value;
});

const openCreditFace = computed(() =>
  vendorRefundOpenCreditFace(
    openCreditBooks.value,
    channelMeta.value,
    booksCurrencyCode.value,
    invoiceCurrencyCode.value,
  ),
);

const refundSummary = computed((): MoneyPaySummaryContext => ({
  modeCaption: 'Vendor refund',
  payerName: fromProfileName.value,
  payeeName: tenantLabel.value,
  dueAmount: openCreditFace.value.amount,
  dueCurrencyCode: openCreditFace.value.currencyCode,
  headline: 'Cash from vendor against open credit note.',
}));

const loadErrorMessage = computed(
  () => bundleQuery.error.value?.message ?? 'Could not load bill.',
);

const billLeafLabel = computed(() => {
  const no = bill.value?.invoice_no?.trim();
  if (no) return no;
  return billId.value ? `Bill #${billId.value}` : 'Bill';
});

const tenantSlug = computed(
  () =>
    (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null) ||
    authStore.tenantSlug ||
    null,
);

const submitBlockReason = computed(() => {
  const reason = formRef.value?.submitDisabledReason;
  if (typeof reason === 'string' || reason == null) return reason;
  return null;
});

function onPayAmountChange(amount: number | null, currencyCode: string) {
  payingNowAmount.value = amount;
  payingNowCurrency.value = currencyCode;
}

function goBack() {
  const id = billId.value;
  if (id == null) {
    void router.back();
    return;
  }
  void router.push(billDetailRoute(id, tenantSlug.value));
}

function onCreditNotePicked(id: number) {
  selectedCreditNoteId.value = id;
  const slug = tenantSlug.value;
  if (billId.value == null) return;
  void router.replace(
    billVendorRefundRoute(billId.value, slug, { creditNoteId: String(id) }),
  );
}

async function onSubmit() {
  await formRef.value?.trySubmit();
}

async function onVendorRefund(payload: PostVendorCreditRefundInput) {
  await vendorRefundMutation.mutateAsync(payload);
  goBack();
}

watch(
  () => billLeafLabel.value,
  (label) => {
    const slug = tenantSlug.value;
    const prefix = slug ? `/${slug}` : '';
    const id = billId.value;
    setCustomBreadcrumbs([
      { label: 'Bills', to: `${prefix}/app/bills` },
      { label, to: id != null ? billDetailRoute(id, slug) : undefined },
      { label: 'Vendor refund' },
    ]);
  },
  { immediate: true },
);

onMounted(() => {
  payingNowAmount.value = openCreditFace.value.amount;
  payingNowCurrency.value = openCreditFace.value.currencyCode;
  if (billId.value != null) void bundleQuery.refetch();
});

onUnmounted(clearCustomBreadcrumbs);
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
}

.bill-pay-page__body {
  min-height: 0;
}

.bill-pay-page__stack {
  width: 100%;
  max-width: none;
}
</style>
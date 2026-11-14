<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card class="profile-pay-detail-dialog column no-wrap" style="width: min(520px, 95vw); max-height: 85vh">
      <q-card-section class="row items-center q-pb-sm">
        <div class="col text-h6">Transaction details</div>
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-separator />

      <q-card-section v-if="!row" class="text-caption text-grey-7">
        No transaction selected.
      </q-card-section>

      <q-card-section v-else-if="detailQuery.isPending.value" class="flex flex-center q-py-xl">
        <q-spinner color="primary" size="32px" />
      </q-card-section>

      <q-card-section
        v-else-if="detailQuery.isError.value"
        class="text-caption text-negative"
      >
        {{ detailErrorMessage }}
      </q-card-section>

      <q-card-section v-else class="col scroll q-pt-sm q-gutter-y-md">
        <header class="profile-pay-detail-dialog__summary">
          <div class="row items-center wrap q-gutter-xs q-mb-xs">
            <span class="profile-pay-detail-dialog__pay-id">Pay #{{ row.id }}</span>
            <span class="profile-pay-detail-dialog__kind-chip">{{ kindLabel }}</span>
            <TfStatusBadge v-if="row.reverted_at" status="cancelled" label="Reverted" />
            <TfStatusBadge v-else-if="row.is_reversal" status="cancelled" label="Reversal" />
            <TfStatusBadge v-else-if="deskPay?.voided_at" status="cancelled" label="Voided" />
          </div>
          <div class="text-body2 text-weight-medium">{{ fromToLine }}</div>
          <div class="text-caption text-grey-7 q-mt-xs">{{ summarySubtitle }}</div>
          <div
            class="profile-pay-detail-dialog__amount tf-num q-mt-sm"
            :class="amountToneClass"
          >
            {{ amountLine }}
          </div>
          <div v-if="booksAmountLine" class="text-caption text-grey-7 q-mt-xs tf-num">
            {{ booksAmountLine }}
          </div>
        </header>

        <ProfilePayDetailSection
          v-if="howTheyPaidRows.length"
          title="How they paid"
          caption="Bank, cheque, or wallet details entered when posting"
          :rows="howTheyPaidRows"
        />

        <ProfilePayDetailSection
          v-if="noteRows.length"
          title="Reference & notes"
          caption="Your reference and internal note on this pay"
          :rows="noteRows"
        />

        <section v-if="bundleRows.length">
          <ProfilePayDetailSectionTitle
            title="Cash bundles"
            caption="Which location / currency pot changed, and balance after this pay"
          />
          <q-list dense bordered separator class="rounded-borders profile-pay-detail-dialog__card">
            <q-item v-for="(b, i) in bundleRows" :key="`b-${i}`" dense>
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ b.title }}</q-item-label>
                <q-item-label caption>{{ b.location }}</q-item-label>
              </q-item-section>
              <q-item-section side class="text-right">
                <q-item-label class="tf-num text-caption text-grey-8">{{ b.balanceHint }}</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </section>

        <section v-if="deskInstrumentRows.length">
          <ProfilePayDetailSectionTitle
            title="Payment lines"
            caption="Split across methods (desk ledger)"
          />
          <q-list dense bordered separator class="rounded-borders profile-pay-detail-dialog__card">
            <q-item v-for="(inst, i) in deskInstrumentRows" :key="`inst-${i}`" dense>
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ inst.method }}</q-item-label>
                <q-item-label v-if="inst.detail" caption>{{ inst.detail }}</q-item-label>
              </q-item-section>
              <q-item-section v-if="inst.amount" side class="tf-num text-weight-medium">
                {{ inst.amount }}
              </q-item-section>
            </q-item>
          </q-list>
        </section>

        <section v-if="allocationRows.length">
          <ProfilePayDetailSectionTitle title="Applied to bills" />
          <q-list dense bordered separator class="rounded-borders profile-pay-detail-dialog__card">
            <q-item v-for="alloc in allocationRows" :key="alloc.id" dense>
              <q-item-section>{{ alloc.label }}</q-item-section>
              <q-item-section side class="tf-num text-weight-medium">{{ alloc.amount }}</q-item-section>
            </q-item>
          </q-list>
        </section>

        <ProfilePayDetailSection
          v-if="recordRows.length"
          title="Record"
          caption="System fields"
          :rows="recordRows"
          muted
        />

        <ProfilePayDetailSection
          v-if="extraMetaRows.length"
          title="Other data"
          :rows="extraMetaRows"
          mono
        />
      </q-card-section>

      <q-separator />
      <q-card-actions align="right">
        <TfBtn variant="tertiary" size="sm" label="Close" @click="close" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import ProfilePayDetailSection from './ProfilePayDetailSection.vue';
import ProfilePayDetailSectionTitle from './ProfilePayDetailSectionTitle.vue';
import { formatAmountBdt, formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';
import { cashbookRepository, type ProfileKernelPayDetail } from '../repositories/cashbookRepository';
import { paysRepository, type PayDetail, type PayListRow } from '../repositories/paysRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import {
  payFromToLine,
  payIsInflowForProfile,
  paySignedAmountParts,
  type PayAmountDisplayMode,
} from '../utils/payListDisplay';

type DetailRow = { label: string; value: string };

const props = defineProps<{
  modelValue: boolean;
  operatingTenantId: number;
  row: PayListRow | null;
  viewedProfileId: number | null;
  viewedProfileDisplayName: string;
  amountMode?: PayAmountDisplayMode;
}>();

const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>();

const row = computed(() => props.row);
const isKernel = computed(() => props.row?.spine === 'kernel');
const amountMode = computed(() => props.amountMode ?? 'original');

const detailQuery = useQuery({
  queryKey: computed(() =>
    isKernel.value
      ? cashbookQueryKeys.profilePayDetail(props.operatingTenantId, props.row?.id ?? null, 'kernel')
      : paysQueryKeys.detail(props.row?.id ?? null),
  ),
  queryFn: async () => {
    const id = props.row?.id;
    if (id == null) throw new Error('Missing pay id.');
    if (isKernel.value) {
      return cashbookRepository.getProfileKernelPayDetail(props.operatingTenantId, id);
    }
    return paysRepository.getPayById(id);
  },
  enabled: computed(() => props.modelValue && props.row != null),
});

const kernelPay = computed(() =>
  isKernel.value ? (detailQuery.data.value as ProfileKernelPayDetail | undefined) : undefined,
);
const deskPay = computed(() =>
  !isKernel.value ? (detailQuery.data.value as PayDetail | undefined) : undefined,
);

const meta = computed(() => (kernelPay.value?.meta ?? {}) as Record<string, unknown>);

const detailErrorMessage = computed(() => {
  const err = detailQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load details.';
});

const fromToLine = computed(() =>
  props.row
    ? payFromToLine(props.row, props.viewedProfileId, props.viewedProfileDisplayName)
    : '',
);

const kindLabel = computed(() => {
  const k = kernelPay.value?.kind ?? props.row?.kernel_kind ?? props.row?.description;
  if (!k) return 'Payment';
  const s = String(k).replace(/_/g, ' ');
  return s.charAt(0).toUpperCase() + s.slice(1);
});

const summarySubtitle = computed(() => {
  const parts: string[] = [];
  if (props.row?.payment_date) parts.push(props.row.payment_date);
  if (kernelPay.value?.status) {
    parts.push(titleCase(String(kernelPay.value.status)));
  }
  return parts.join(' · ') || '—';
});

const amountLine = computed(() => {
  const r = props.row;
  if (!r) return '';
  const parts = paySignedAmountParts(r, props.viewedProfileId, amountMode.value);
  return `${parts.sign}${parts.symbol} ${parts.amount}`;
});

const amountToneClass = computed(() => {
  const r = props.row;
  if (!r) return '';
  return payIsInflowForProfile(r, props.viewedProfileId) ? 'text-positive' : 'text-negative';
});

const booksAmountLine = computed(() => {
  const k = kernelPay.value;
  if (!k) {
    if (deskPay.value?.unallocated_amount && deskPay.value.unallocated_amount > 0) {
      return `Unallocated ${formatAmountBdt(deskPay.value.unallocated_amount)}`;
    }
    return null;
  }
  if (k.currency_code.toUpperCase() === 'BDT') return null;
  return `Books total ${formatBdtTaka(k.books_amount)} @ ${k.books_rate} BDT/${k.currency_code}`;
});

const howTheyPaidRows = computed((): DetailRow[] => {
  const rows: DetailRow[] = [];
  const method = String(props.row?.method ?? meta.value.method_code ?? '').trim();
  if (method) rows.push({ label: 'Method', value: titleCase(method) });

  if (kernelPay.value?.bank_name) {
    rows.push({ label: 'Bank', value: kernelPay.value.bank_name });
  }

  const chequeNumber = String(meta.value.cheque_number ?? '').trim();
  if (chequeNumber) rows.push({ label: 'Cheque number', value: chequeNumber });

  const chequeDate = String(meta.value.cheque_date ?? meta.value.instrument_date ?? '').trim();
  if (chequeDate) rows.push({ label: 'Cheque / transfer date', value: chequeDate });

  const instrumentRef = String(meta.value.instrument_reference ?? '').trim();
  if (instrumentRef) rows.push({ label: 'Cheque memo or trx ID', value: instrumentRef });

  if (!isKernel.value && !rows.length && deskPay.value?.instruments.length) {
    return [];
  }
  return rows;
});

const noteRows = computed((): DetailRow[] => {
  const rows: DetailRow[] = [];
  const paymentRef = String(props.row?.reference ?? meta.value.reference ?? '').trim();
  if (paymentRef) rows.push({ label: 'Payment reference', value: paymentRef });

  const note = String(props.row?.note ?? meta.value.note ?? '').trim();
  if (note) rows.push({ label: 'Staff note', value: note });

  if (props.row?.related_invoice_no) {
    rows.push({ label: 'Linked bill', value: props.row.related_invoice_no });
  }
  if (props.row?.cashbook_point_name) {
    rows.push({ label: 'Desk location', value: props.row.cashbook_point_name });
  }
  return rows;
});

const recordRows = computed((): DetailRow[] => {
  const rows: DetailRow[] = [];
  if (kernelPay.value?.created_at) {
    rows.push({
      label: 'Recorded at',
      value: String(kernelPay.value.created_at).slice(0, 19).replace('T', ' '),
    });
  }
  if (props.row?.revert_reason) {
    rows.push({ label: 'Revert reason', value: props.row.revert_reason });
  }
  if (props.row?.reverses_pays_id) {
    rows.push({ label: 'Reverses pay', value: `#${props.row.reverses_pays_id}` });
  }
  return rows;
});

const bundleRows = computed(() => {
  const k = kernelPay.value;
  if (!k) return [];
  type BundleRow = {
    title: string;
    location: string;
    balanceHint: string;
  };
  const out: BundleRow[] = [];
  const pushBundle = (
    direction: 'From' | 'To',
    b: typeof k.from_bundle,
    balanceAfter: number | null,
  ) => {
    if (!b?.bundle_id) return;
    const location = [b.location_name || b.location_code, b.currency_code].filter(Boolean).join(' · ');
    const currency = b.currency_code ?? 'BDT';
    const balance =
      balanceAfter != null
        ? formatSettlementCurrencyAmount(balanceAfter, currency)
        : b.amount != null
          ? formatSettlementCurrencyAmount(b.amount, currency)
          : '—';
    out.push({
      title: direction === 'From' ? 'Money out of' : 'Money into',
      location: location || 'Bundle',
      balanceHint: `Balance after · ${balance}`,
    });
  };
  pushBundle('From', k.from_bundle, k.from_balance_after);
  pushBundle('To', k.to_bundle, k.to_balance_after);
  return out;
});

const deskInstrumentRows = computed(() => {
  if (isKernel.value) return [];
  return (deskPay.value?.instruments ?? []).map((inst) => {
    const parts: string[] = [];
    if (inst.bd_bank_name) parts.push(inst.bd_bank_name);
    if (inst.cheque_number) parts.push(`Cheque ${inst.cheque_number}`);
    if (inst.cheque_date) parts.push(inst.cheque_date);
    if (inst.reference) parts.push(inst.reference);
    return {
      method: titleCase(inst.payment_method_code),
      detail: parts.join(' · ') || undefined,
      amount: formatAmountBdt(inst.amount),
    };
  });
});

const allocationRows = computed(() => {
  if (kernelPay.value?.allocations?.length) {
    return kernelPay.value.allocations.map((a) => ({
      id: `k-${a.bill_id}`,
      label: a.invoice_no || `Bill #${a.bill_id}`,
      amount: formatAmountBdt(a.amount),
    }));
  }
  return (deskPay.value?.allocations ?? []).map((a) => ({
    id: `d-${a.id}`,
    label: a.invoice_no || `Bill #${a.global_invoice_id}`,
    amount: formatAmountBdt(a.amount),
  }));
});

const META_SHOW_KEYS = new Set([
  'source',
  'method_code',
  'reference',
  'note',
  'paid_on',
  'bd_bank_id',
  'cheque_number',
  'cheque_date',
  'instrument_date',
  'instrument_reference',
  'revert_reason',
  'reverted_at',
]);

const extraMetaRows = computed((): DetailRow[] => {
  const k = kernelPay.value;
  if (!k?.meta || typeof k.meta !== 'object') return [];
  return Object.entries(k.meta)
    .filter(([key, val]) => !META_SHOW_KEYS.has(key) && val != null && String(val).trim() !== '')
    .map(([key, val]) => ({
      label: titleCase(key.replace(/_/g, ' ')),
      value: typeof val === 'object' ? JSON.stringify(val) : String(val),
    }));
});

function titleCase(raw: string): string {
  return raw
    .split(/\s+/)
    .map((w) => (w ? w.charAt(0).toUpperCase() + w.slice(1).toLowerCase() : ''))
    .join(' ');
}

const close = () => emit('update:modelValue', false);
</script>

<style scoped lang="scss">
.profile-pay-detail-dialog__summary {
  padding: 12px 14px;
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
  background: var(--tf-neutral-canvas, #faf8f5);
}

.profile-pay-detail-dialog__pay-id {
  font-size: 15px;
  font-weight: 600;
}

.profile-pay-detail-dialog__kind-chip {
  display: inline-flex;
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 6px;
  background: #fff;
  color: var(--tf-neutral-chrome-text, #5c564e);
}

.profile-pay-detail-dialog__amount {
  font-size: 1.35rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.profile-pay-detail-dialog__card {
  background: #fff;
}
</style>
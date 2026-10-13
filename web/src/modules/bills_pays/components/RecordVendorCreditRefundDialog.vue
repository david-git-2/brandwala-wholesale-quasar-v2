<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: min(480px, 92vw)">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">Record vendor refund</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>
      <q-card-section class="q-gutter-y-md q-pt-sm">
        <div class="q-pa-sm rounded-borders bg-grey-2">
          <div class="text-caption text-grey-7">From</div>
          <div class="text-body2 text-weight-medium">{{ fromProfileName }}</div>
          <div class="text-caption text-grey-7 q-mt-sm">Into our cash</div>
          <div class="text-body2">{{ tenantLabel }}</div>
        </div>
        <div class="text-caption text-grey-7">
          Open credit:
          <strong>{{ openCreditDisplay }}</strong>
        </div>
        <q-input v-model="receivedOn" outlined dense label="Date received" mask="####-##-##">
          <template #append>
            <q-icon name="ph ph-calendar" class="cursor-pointer">
              <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                <q-date v-model="receivedOn" mask="YYYY-MM-DD" />
              </q-popup-proxy>
            </q-icon>
          </template>
        </q-input>
        <q-select
          v-model="settlementCurrency"
          :options="settlementCurrencyOptions"
          emit-value
          map-options
          outlined
          dense
          label="Refund currency"
        />
        <template v-if="settlementCurrency !== 'BDT'">
          <q-input
            v-model.number="foreignAmount"
            outlined
            dense
            :label="`Amount (${settlementCurrency})`"
            type="number"
            step="0.01"
          />
          <q-input
            v-model.number="exchangeRate"
            outlined
            dense
            label="Rate (BDT per 1 unit)"
            type="number"
            step="0.0001"
          />
          <div v-if="computedBdtAmount != null" class="text-caption text-grey-8">
            Books: {{ formatAmountBdt(computedBdtAmount) }}
          </div>
        </template>
        <q-input
          v-else
          v-model.number="amountBdt"
          outlined
          dense
          label="Amount (BDT)"
          type="number"
          step="0.01"
          :max="openCredit"
        />
        <q-select
          v-model="cashbookPointId"
          :options="pointOptions"
          emit-value
          map-options
          outlined
          dense
          label="Our cash point"
          hint="Till, bank, or drawer this money goes into"
          :loading="pointsLoading"
        />
        <q-input v-model="note" outlined dense label="Note (optional)" type="textarea" autogrow />
      </q-card-section>
      <q-card-actions align="right" class="q-pa-md q-pt-none">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Record refund"
          :loading="loading"
          :disable="!!submitDisabledReason"
          @click="submit"
        >
          <q-tooltip v-if="submitDisabledReason">{{ submitDisabledReason }}</q-tooltip>
        </q-btn>
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { useCashbookPointsQuery } from '../composables/useCashbookPointsQuery';
import type { PostVendorCreditRefundInput } from '../composables/usePostVendorCreditRefundMutation';
import { apBillPaperCurrencyCode as apInvoiceCurrencyFromMeta } from '../utils/apBillBooks';
import { apBillCurrencyGroups, apBillPaperConversionRate } from '../utils/parseApBillPaper';

function defaultSettlementCurrency(channelMeta: Record<string, unknown> | null | undefined): string {
  const groups = apBillCurrencyGroups(channelMeta ?? null);
  if (groups.length === 1) {
    const c = (groups[0]?.currency_code ?? '').trim().toUpperCase();
    if (c && c !== 'BDT') return c;
  }
  const code = apInvoiceCurrencyFromMeta(channelMeta ?? null);
  return code || 'BDT';
}

function invoiceConversionRate(channelMeta: Record<string, unknown> | null | undefined): number | null {
  const fromPaper = apBillPaperConversionRate(channelMeta ?? null);
  if (fromPaper != null && fromPaper > 0) return fromPaper;
  const raw = channelMeta?.ap_paper;
  if (!raw || typeof raw !== 'object') return null;
  const direct = Number((raw as Record<string, unknown>).conversion_rate);
  if (Number.isFinite(direct) && direct > 0 && Math.abs(direct - 1) > 0.0001) return direct;
  return null;
}

const props = defineProps<{
  modelValue: boolean;
  creditNoteId: number;
  parentBillId: number | null;
  openCredit: number;
  booksTenantId: number;
  fromProfileName: string;
  tenantLabel: string;
  channelMeta?: Record<string, unknown> | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: PostVendorCreditRefundInput];
}>();

const localToday = () => {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const receivedOn = ref(localToday());
const amountBdt = ref<number | null>(null);
const foreignAmount = ref<number | null>(null);
const exchangeRate = ref<number | null>(null);
const settlementCurrency = ref('BDT');
const cashbookPointId = ref<number | null>(null);
const note = ref('');

const { data: currenciesData } = useGlobalCurrenciesQuery();
const settlementCurrencyOptions = computed(() => {
  const fromRef = (currenciesData.value ?? [])
    .filter((c) => c.is_active)
    .map((c) => ({ label: `${c.code} — ${c.name}`, value: c.code }));
  const codes = new Set(fromRef.map((o) => o.value));
  if (!codes.has('BDT')) {
    fromRef.unshift({ label: 'BDT — Bangladesh Taka', value: 'BDT' });
  }
  return fromRef.sort((a, b) =>
    a.value === 'BDT' ? -1 : b.value === 'BDT' ? 1 : a.value.localeCompare(b.value),
  );
});

const invoiceCurrency = computed(() => defaultSettlementCurrency(props.channelMeta ?? null));
const invoiceRate = computed(() => invoiceConversionRate(props.channelMeta ?? null));

const openCreditDisplay = computed(() => {
  const books = props.openCredit;
  const paper = invoiceCurrency.value;
  const rate = invoiceRate.value;
  if (paper && paper !== 'BDT' && rate && rate > 0) {
    const foreign = Math.round((books / rate) * 100) / 100;
    return `${formatAmountBdt(foreign)} ${paper}`;
  }
  return formatAmountBdt(books);
});

const computedBdtAmount = computed(() => {
  if (settlementCurrency.value === 'BDT') return amountBdt.value;
  const foreign = foreignAmount.value;
  const rate = exchangeRate.value;
  if (foreign == null || rate == null || foreign <= 0 || rate <= 0) return null;
  return Math.round(foreign * rate * 100) / 100;
});

const pointsContext = computed(() => ({
  booksTenantId: props.booksTenantId,
  entityType: 'tenant',
  entityId: props.booksTenantId,
  enabled: props.modelValue && props.booksTenantId > 0,
}));
const { pointsQuery } = useCashbookPointsQuery(pointsContext);
const pointOptions = computed(() =>
  (pointsQuery.data.value ?? [])
    .filter((p) => p.is_active)
    .map((p) => ({ label: `${p.name} (${p.kind})`, value: p.id })),
);
const pointsLoading = computed(() => pointsQuery.isPending.value);

function resetRefundForm() {
  receivedOn.value = localToday();
  note.value = '';
  cashbookPointId.value = null;
  const currency = defaultSettlementCurrency(props.channelMeta ?? null);
  const rate = invoiceConversionRate(props.channelMeta ?? null);
  settlementCurrency.value = currency;
  if (currency !== 'BDT') {
    exchangeRate.value = rate;
    if (rate && rate > 0 && props.openCredit > 0) {
      foreignAmount.value = Math.round((props.openCredit / rate) * 100) / 100;
      amountBdt.value = props.openCredit;
    } else {
      foreignAmount.value = null;
      amountBdt.value = props.openCredit > 0 ? props.openCredit : null;
    }
  } else {
    foreignAmount.value = null;
    exchangeRate.value = null;
    amountBdt.value = props.openCredit > 0 ? props.openCredit : null;
  }
}

watch(
  () => [props.modelValue, props.channelMeta, props.openCredit] as const,
  ([open]) => {
    if (open) resetRefundForm();
  },
);

watch([settlementCurrency, foreignAmount, exchangeRate], () => {
  if (settlementCurrency.value === 'BDT') return;
  if (computedBdtAmount.value != null) amountBdt.value = computedBdtAmount.value;
});

const submitDisabledReason = computed(() => {
  const books = computedBdtAmount.value ?? Number(amountBdt.value ?? 0);
  if (books <= 0) return 'Enter a refund amount.';
  if (books > props.openCredit + 0.01) {
    return `Cannot exceed ${formatAmountBdt(props.openCredit)} books.`;
  }
  if (settlementCurrency.value !== 'BDT') {
    if (foreignAmount.value == null || foreignAmount.value <= 0) {
      return `Enter the ${settlementCurrency.value} amount.`;
    }
    if (exchangeRate.value == null || exchangeRate.value <= 0) return 'Enter the exchange rate.';
  }
  if (!cashbookPointId.value) return 'Choose which cash point receives this.';
  if (!receivedOn.value) return 'Date is required.';
  return null;
});

function close() {
  emit('update:modelValue', false);
}

function submit() {
  if (submitDisabledReason.value || cashbookPointId.value == null) return;
  const books = computedBdtAmount.value ?? Number(amountBdt.value ?? 0);
  const foreign = settlementCurrency.value === 'BDT' ? null : foreignAmount.value;
  emit('submit', {
    creditNoteId: props.creditNoteId,
    parentBillId: props.parentBillId,
    amount: books,
    cashbookPointId: cashbookPointId.value,
    receivedOn: receivedOn.value,
    note: note.value.trim() || null,
    settlementCurrencyCode: settlementCurrency.value,
    foreignAmount: foreign,
    exchangeRate: settlementCurrency.value === 'BDT' ? null : exchangeRate.value,
  });
}
</script>

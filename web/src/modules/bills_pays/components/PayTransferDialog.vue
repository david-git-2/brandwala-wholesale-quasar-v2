<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="pay-transfer-card">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">{{ heading }}</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-card-section class="q-gutter-y-md q-pt-sm">
        <div v-if="loadingParties" class="flex flex-center q-py-md">
          <q-spinner color="primary" size="28px" />
        </div>

        <template v-else>
          <q-select
            v-model="fromKey"
            :options="partySelectOptions"
            emit-value
            map-options
            outlined
            dense
            label="From"
            :loading="loadingPartyMeta"
          >
            <template #option="scope">
              <q-item v-bind="scope.itemProps">
                <q-item-section>
                  <q-item-label>{{ scope.opt.label }}</q-item-label>
                  <q-item-label caption>{{ scope.opt.caption }}</q-item-label>
                </q-item-section>
              </q-item>
            </template>
          </q-select>

          <q-select
            v-model="toKey"
            :options="partySelectOptions"
            emit-value
            map-options
            outlined
            dense
            label="To"
            :loading="loadingPartyMeta"
          >
            <template #option="scope">
              <q-item v-bind="scope.itemProps">
                <q-item-section>
                  <q-item-label>{{ scope.opt.label }}</q-item-label>
                  <q-item-label caption>{{ scope.opt.caption }}</q-item-label>
                </q-item-section>
              </q-item>
            </template>
          </q-select>

          <q-select
            v-if="showPotSelector"
            v-model="potId"
            :options="payFromOptions"
            emit-value
            map-options
            outlined
            dense
            label="From till (pot)"
            hint="Till, safe, or bank"
            :loading="payFromLoading"
          />

          <q-input
            v-model.number="amount"
            outlined
            dense
            type="number"
            label="Amount"
          />

          <q-select
            v-model="methodCode"
            :options="methodOptions"
            emit-value
            map-options
            outlined
            dense
            label="Method"
            :loading="loadingPaymentMeta"
          />

          <PaymentInstrumentExtrasFields
            :method-code="methodCode"
            :method-options="methodOptions"
            :bd-bank-options="bdBankOptions"
            :loading="loadingPaymentMeta"
            :bd-bank-id="bdBankId"
            :cheque-number="chequeNumber"
            :instrument-date="instrumentDate"
            :instrument-reference="instrumentReference"
            @update:bd-bank-id="bdBankId = $event"
            @update:cheque-number="chequeNumber = $event"
            @update:instrument-date="instrumentDate = $event"
            @update:instrument-reference="instrumentReference = $event"
          />

          <q-input v-model="note" outlined dense label="Notes" type="textarea" autogrow />
        </template>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md q-pt-none">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          :label="submitLabel"
          :loading="submitting"
          :disable="!!submitDisabledReason || loadingParties"
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
import PaymentInstrumentExtrasFields from './PaymentInstrumentExtrasFields.vue';
import { useWholesalePaymentMethodMeta } from '../composables/useWholesalePaymentMethodMeta';
import { useCashbookPayFromPotSelect } from '../composables/useCashbookPayFromPotSelect';
import { useCashbookPointsQuery } from '../composables/useCashbookPointsQuery';
import { useCollectPayMutation } from '../composables/useCollectPayMutation';
import { cashbookRepository } from '../repositories/cashbookRepository';
import { paysRepository } from '../repositories/paysRepository';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import {
  buildWholesalePaymentInstrument,
  paymentInstrumentExtrasBlockReason,
  paymentMethodFieldFlags,
} from '../utils/paymentInstrumentFields';
import {
  type PayTransferParty,
  payTransferPartyKey,
} from '../types/payTransferParty';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    tenantId: number;
    booksTenantId: number;
    tenantName: string;
    initialFromKey?: string | null;
    initialToKey?: string | null;
    parties?: PayTransferParty[];
    seedParties?: PayTransferParty[];
    loadPartiesOnOpen?: boolean;
  }>(),
  { loadPartiesOnOpen: true },
);

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  posted: [];
}>();

const partyList = ref<PayTransferParty[]>([]);
const loadingParties = ref(false);
const loadingPartyMeta = ref(false);
const fromKey = ref<string | null>(null);
const toKey = ref<string | null>(null);
const amount = ref<number | null>(null);
const methodCode = ref('cash');
const note = ref('');
const bdBankId = ref<number | null>(null);
const chequeNumber = ref('');
const instrumentDate = ref('');
const instrumentReference = ref('');
const submitting = ref(false);
const collectMutation = useCollectPayMutation();
const { loadingPaymentMeta, methodOptions, bdBankOptions, loadPaymentMeta } =
  useWholesalePaymentMethodMeta('cash');

const tenantKey = computed(() =>
  payTransferPartyKey('tenant', props.booksTenantId),
);

const partyByKey = computed(() => {
  const map = new Map<string, PayTransferParty>();
  for (const p of partyList.value) map.set(p.key, p);
  return map;
});

const fromParty = computed(() => (fromKey.value ? partyByKey.value.get(fromKey.value) : null));
const toParty = computed(() => (toKey.value ? partyByKey.value.get(toKey.value) : null));

const isPayIn = computed(
  () => fromParty.value?.entityType !== 'tenant' && toParty.value?.entityType === 'tenant',
);
const isPayOut = computed(
  () => fromParty.value?.entityType === 'tenant' && toParty.value?.entityType !== 'tenant',
);

const heading = computed(() => {
  if (isPayOut.value) return 'Pay out';
  if (isPayIn.value) return 'Pay in';
  return 'Transfer';
});

const submitLabel = computed(() => {
  if (isPayOut.value) return 'Cash out';
  if (isPayIn.value) return 'Post receipt';
  return 'Post payment';
});

const showPotSelector = computed(() => fromParty.value?.entityType === 'tenant');

const needsTenantPot = computed(() => isPayIn.value || isPayOut.value);

const pointsContext = computed(() => ({
  booksTenantId: props.booksTenantId,
  entityType: 'tenant',
  entityId: props.booksTenantId,
  enabled: props.modelValue && props.booksTenantId > 0 && needsTenantPot.value,
}));
const { pointsQuery } = useCashbookPointsQuery(pointsContext);
const points = computed(() => pointsQuery.data.value);
const payFromEnabled = computed(
  () => props.modelValue && props.booksTenantId > 0 && needsTenantPot.value,
);
const {
  selectedPotId: potId,
  payFromOptions,
  cashbookPointId,
  loading: payFromLoading,
} = useCashbookPayFromPotSelect(points, payFromEnabled);

const partyCaption = (p: PayTransferParty) => {
  const parts = [`Have ${formatAmountBdt(p.availableBalance)}`];
  if (p.entityType !== 'tenant' && p.dueTotal > 0) {
    parts.push(`Owe ${formatAmountBdt(p.dueTotal)}`);
  }
  return parts.join(' · ');
};

const partySelectOptions = computed(() =>
  partyList.value.map((p) => ({
    label: p.name,
    value: p.key,
    caption: partyCaption(p),
  })),
);

const profilePartyForRpc = computed(() => {
  if (isPayIn.value && fromParty.value?.entityType === 'customer') return fromParty.value;
  if (isPayOut.value && toParty.value?.entityType === 'customer') return toParty.value;
  return null;
});

const loadDueForProfile = async (profileId: number) => {
  const { data } = await invoiceRepository.listGlobalInvoices({
    parentTenantId: props.booksTenantId,
    profileId,
    invoiceStatus: 'issued',
    quickFilter: 'unpaid',
    pageSize: 100,
  });
  return data.reduce((sum, bill) => sum + (Number(bill.due_amount) || 0), 0);
};

const refreshPartyBalances = async (keys: string[]) => {
  if (!props.tenantId) return;
  loadingPartyMeta.value = true;
  try {
    for (const key of keys) {
      const p = partyByKey.value.get(key);
      if (!p) continue;
      const detail = await cashbookRepository.getPartyDetail(
        props.tenantId,
        p.entityType,
        p.entityId,
      );
      p.availableBalance = detail.available_balance;
      if (p.entityType === 'tenant') {
        p.dueTotal = 0;
      } else {
        p.dueTotal = await loadDueForProfile(p.entityId);
      }
    }
  } finally {
    loadingPartyMeta.value = false;
  }
};

const mergeSeedParties = () => {
  for (const seed of props.seedParties ?? []) {
    if (!partyList.value.some((p) => p.key === seed.key)) {
      partyList.value.push({ ...seed });
    }
  }
};

const loadPartyList = async () => {
  if (!props.tenantId || !props.booksTenantId) return;
  loadingParties.value = true;
  try {
    if (props.parties?.length) {
      partyList.value = props.parties.map((p) => ({ ...p }));
      mergeSeedParties();
    } else if (props.loadPartiesOnOpen) {
      const tenantRow = await cashbookRepository.getTenantCashRow(
        props.tenantId,
        props.booksTenantId,
      );
      const customers = await cashbookRepository.listEntities({
        tenantId: props.tenantId,
        entityType: 'customer',
        limit: 200,
      });
      const tenantParty: PayTransferParty = {
        key: payTransferPartyKey('tenant', tenantRow.entity_id),
        entityType: 'tenant',
        entityId: tenantRow.entity_id,
        name: tenantRow.name || props.tenantName,
        availableBalance: tenantRow.available_balance,
        dueTotal: 0,
      };
      partyList.value = [
        tenantParty,
        ...customers.map((row) => ({
          key: payTransferPartyKey('customer', row.entity_id),
          entityType: 'customer' as const,
          entityId: row.entity_id,
          name: row.name,
          availableBalance: row.available_balance,
          dueTotal: 0,
        })),
      ];
    } else {
      partyList.value = [];
    }
    mergeSeedParties();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Could not load parties.');
    partyList.value = [];
  } finally {
    loadingParties.value = false;
  }
};

const applyInitialSelection = () => {
  const keys = new Set(partyList.value.map((p) => p.key));
  const from = props.initialFromKey && keys.has(props.initialFromKey) ? props.initialFromKey : null;
  const to = props.initialToKey && keys.has(props.initialToKey) ? props.initialToKey : null;
  if (from && to) {
    fromKey.value = from;
    toKey.value = to;
  } else if (from) {
    fromKey.value = from;
    toKey.value = from === tenantKey.value ? null : tenantKey.value;
  } else if (to) {
    toKey.value = to;
    fromKey.value = to === tenantKey.value ? null : tenantKey.value;
  } else {
    fromKey.value = partyList.value[0]?.key ?? null;
    toKey.value = partyList.value[1]?.key ?? null;
  }
  if (fromKey.value === toKey.value) {
    toKey.value = partyList.value.find((p) => p.key !== fromKey.value)?.key ?? null;
  }
};

const suggestAmount = () => {
  if (isPayOut.value && toParty.value) {
    amount.value = toParty.value.availableBalance;
  } else if (isPayIn.value && fromParty.value) {
    amount.value = fromParty.value.dueTotal > 0 ? fromParty.value.dueTotal : null;
  }
};

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return;
    note.value = '';
    await loadPartyList();
    applyInitialSelection();
    void loadPaymentMeta((code) => {
      methodCode.value = code;
    });
    const keys = [fromKey.value, toKey.value].filter((k): k is string => !!k);
    await refreshPartyBalances(keys);
    suggestAmount();
  },
);

watch([fromKey, toKey], async ([from, to], [prevFrom, prevTo]) => {
  if (from === to && from) {
    toKey.value = partyList.value.find((p) => p.key !== from)?.key ?? null;
    return;
  }
  const toRefresh: string[] = [];
  if (from && from !== prevFrom) toRefresh.push(from);
  if (to && to !== prevTo) toRefresh.push(to);
  if (toRefresh.length) await refreshPartyBalances(toRefresh);
  suggestAmount();
});

const methodFlags = computed(() => {
  const row = methodOptions.value.find((m) => m.value === methodCode.value);
  return paymentMethodFieldFlags(
    row ? { code: row.code, category: row.category } : { code: methodCode.value.toUpperCase(), category: '' },
  );
});

const submitDisabledReason = computed((): string | null => {
  if (!fromParty.value || !toParty.value) return 'Choose from and to';
  if (fromKey.value === toKey.value) return 'From and to must differ';
  if (!isPayIn.value && !isPayOut.value) {
    return 'One side must be company (tenant), the other a profile';
  }
  if (!profilePartyForRpc.value) return 'Pay in/out needs a customer profile on the other side';
  if (needsTenantPot.value && (payFromLoading.value || !potId.value || !cashbookPointId.value)) {
    return showPotSelector.value ? 'Choose a till (pot)' : 'Loading till…';
  }
  if ((amount.value ?? 0) <= 0) return 'Enter an amount';
  return paymentInstrumentExtrasBlockReason(methodFlags.value, {
    bdBankId: bdBankId.value,
    chequeNumber: chequeNumber.value,
    instrumentDate: instrumentDate.value,
    instrumentReference: instrumentReference.value,
  });
});

const close = () => emit('update:modelValue', false);

const submit = async () => {
  if (submitDisabledReason.value || !profilePartyForRpc.value) return;
  if (!cashbookPointId.value || !potId.value) return;
  submitting.value = true;
  try {
    const localToday = () => new Date().toISOString().slice(0, 10);
    const profileId = profilePartyForRpc.value.entityId;
    if (isPayOut.value) {
      await paysRepository.dispenseMiddlemanPayout({
        tenant_id: props.tenantId,
        profile_id: profileId,
        amount: Number(amount.value),
        payout_method: methodCode.value,
        reference_notes: note.value || null,
        cashbook_point_id: cashbookPointId.value,
        cashbook_point_pot_id: potId.value,
      });
      showSuccessNotification('Cash out recorded.');
    } else {
      await collectMutation.mutateAsync({
        tenantId: props.tenantId,
        profileId,
        receivedOn: localToday(),
        note: note.value || null,
        instruments: [
          buildWholesalePaymentInstrument({
            payment_method_code: methodCode.value,
            amount: Number(amount.value),
            instrument_reference: instrumentReference.value,
            bd_bank_id: bdBankId.value,
            cheque_number: chequeNumber.value,
            instrument_date: instrumentDate.value,
            cashbook_point_id: cashbookPointId.value,
          }),
        ],
        allocations: [],
      });
    }
    emit('posted');
    close();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Payment failed.');
  } finally {
    submitting.value = false;
  }
};
</script>

<style scoped>
.pay-transfer-card {
  width: min(520px, 92vw);
}
</style>

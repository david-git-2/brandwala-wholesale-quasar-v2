<template>
  <div class="bill-adjustment-note-bar q-mt-md q-pa-md rounded-borders bg-grey-1 no-print">
    <div class="row items-center q-col-gutter-md q-mb-sm">
      <div v-if="kindOptions.length > 1" class="col-12 col-sm-auto">
        <q-btn-toggle
          v-model="kind"
          spread
          no-caps
          unelevated
          dense
          toggle-color="primary"
          :options="kindOptions"
        />
      </div>
      <div v-else class="col-12 col-sm-auto text-body2 text-weight-medium">
        {{ kindOptions[0]?.label ?? 'Adjustment' }}
      </div>
      <div v-if="kind !== 'write_off'" class="col-12 col-sm-auto text-body2">
        <template v-if="noteTotalLabels.length">
          <span v-for="(item, idx) in noteTotalLabels" :key="item.code">
            <template v-if="idx > 0"> · </template>
            Note total ({{ item.code }}):
            <strong class="font-mono">{{ item.label }}</strong>
          </span>
        </template>
        <template v-else>
          Note total:
          <strong class="font-mono">—</strong>
        </template>
      </div>
    </div>

    <q-input
      v-if="kind === 'write_off'"
      v-model.number="writeOffAmount"
      outlined
      dense
      class="q-mb-sm"
      type="number"
      step="0.01"
      min="0"
      :max="parentDueAmount"
      label="Write-off amount (BDT)"
    />

    <q-banner
      v-if="balanceEffect.title"
      dense
      rounded
      class="q-mb-sm"
      :class="{
        'bg-positive-1 text-positive-10': balanceEffect.direction === 'decrease',
        'bg-orange-1 text-orange-10': balanceEffect.direction === 'increase',
        'bg-grey-2': balanceEffect.direction === 'neutral',
      }"
    >
      <div class="text-weight-medium">{{ balanceEffect.title }}</div>
      <div v-if="balanceEffect.detail" class="text-caption q-mt-xs">{{ balanceEffect.detail }}</div>
    </q-banner>

    <q-input
      v-model="reason"
      outlined
      dense
      class="q-mb-sm"
      label="Reason"
      type="textarea"
      autogrow
    />

    <template v-if="arRefundEligible">
      <q-checkbox
        v-model="refundCashNow"
        dense
        label="Refund cash to customer now"
        class="q-mb-xs"
      />
      <div v-if="refundCashNow" class="column q-gutter-y-sm q-mb-sm">
        <div class="text-caption text-grey-7">
          Open on credit note after issue: up to {{ formatAmountBdt(excessCreditBdt) }}
        </div>
        <q-input
          v-model.number="refundAmount"
          outlined
          dense
          type="number"
          step="0.01"
          min="0"
          :max="excessCreditBdt"
          label="Refund amount (BDT)"
        />
        <q-select
          v-model="selectedPotId"
          :options="payFromOptions"
          emit-value
          map-options
          outlined
          dense
          label="Pay from (till / safe)"
          :loading="payFromLoading"
        />
      </div>
    </template>

    <div class="row justify-end q-gutter-sm">
      <q-btn flat no-caps label="Cancel" @click="emit('cancel')" />
      <q-btn
        unelevated
        no-caps
        color="primary"
        :label="submitLabel"
        :loading="loading"
        :disable="!!submitDisabledReason"
        @click="emit('submit')"
      >
        <q-tooltip v-if="submitDisabledReason">{{ submitDisabledReason }}</q-tooltip>
      </q-btn>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import { useCashbookPointsQuery } from '../composables/useCashbookPointsQuery';
import { useCashbookPayFromPotSelect } from '../composables/useCashbookPayFromPotSelect';
import type { BillAdjustmentUiKind } from '../composables/useBillAdjustmentDraft';

type BalanceEffect = {
  direction: 'increase' | 'decrease' | 'neutral';
  title: string;
  detail: string;
};

type NoteTotalLabel = { code: string; label: string };

const props = defineProps<{
  noteTotalLabels: NoteTotalLabel[];
  balanceEffect: BalanceEffect;
  submitDisabledReason: string | null;
  loading?: boolean;
  tenantId?: number | null;
  arRefundEligible?: boolean;
  excessCreditBdt?: number;
  parentDueAmount?: number;
  /** AP bills: no debit note — credit note and write-off only. */
  isApParent?: boolean;
  /** When set, only these kinds are offered (e.g. opened from AP detail buttons). */
  allowedKinds?: BillAdjustmentUiKind[];
}>();

const refundCashNow = defineModel<boolean>('refundCashNow', { default: false });
const refundAmount = defineModel<number | null>('refundAmount', { default: null });

const arRefundEligible = computed(() => props.arRefundEligible === true);
const excessCreditBdt = computed(() => Number(props.excessCreditBdt) || 0);

const parentId = computed(() => Number(props.tenantId ?? 0) || 0);

const cashbookPointsContext = computed(() => {
  const enabled =
    arRefundEligible.value && refundCashNow.value && parentId.value > 0;
  return {
    booksTenantId: parentId.value,
    entityType: 'tenant',
    entityId: parentId.value,
    enabled,
  };
});

const { pointsQuery } = useCashbookPointsQuery(cashbookPointsContext);

const cashbookPoints = computed(() => pointsQuery.data.value ?? []);

const payFromEnabled = computed(() => cashbookPointsContext.value.enabled);

const { selectedPotId, payFromOptions, cashbookPointId, loading: payFromLoading } =
  useCashbookPayFromPotSelect(cashbookPoints, payFromEnabled);

defineExpose({ cashbookPointId });

const emit = defineEmits<{
  cancel: [];
  submit: [];
}>();

const kind = defineModel<BillAdjustmentUiKind>('kind', { required: true });
const reason = defineModel<string>('reason', { required: true });
const writeOffAmount = defineModel<number | null>('writeOffAmount', { default: null });

const parentDueAmount = computed(() => Math.max(0, Number(props.parentDueAmount ?? 0)));

const kindOptions = computed(() => {
  const all: Array<{ label: string; value: BillAdjustmentUiKind }> = [
    { label: 'Credit note', value: 'credit_note' },
    { label: 'Debit note', value: 'debit_note' },
    { label: 'Write-off', value: 'write_off' },
  ];
  let filtered = all;
  if (props.isApParent) {
    filtered = all.filter((o) => o.value !== 'debit_note');
  }
  if (props.allowedKinds?.length) {
    const allowed = new Set(props.allowedKinds);
    filtered = filtered.filter((o) => allowed.has(o.value));
  }
  if (parentDueAmount.value <= 0) {
    filtered = filtered.filter((o) => o.value !== 'write_off');
  }
  return filtered;
});

const submitLabel = computed(() => (kind.value === 'write_off' ? 'Write off' : 'Issue note'));
</script>

<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: min(520px, 96vw); max-width: 560px">
      <q-card-section class="text-h6">Apply credit to another bill</q-card-section>
      <q-card-section class="q-pt-none">
        <q-select
          v-if="creditNoteOptions.length > 1"
          v-model="selectedCreditNoteId"
          :options="creditNoteOptions"
          option-value="id"
          option-label="label"
          emit-value
          map-options
          outlined
          dense
          label="Credit note"
          class="q-mb-md"
        />
        <div v-else-if="selectedCreditNote" class="text-body2 q-mb-md">
          From {{ selectedCreditNote.invoice_no }} · open
          {{ formatAmountBdt(selectedCreditNote.due_amount) }}
        </div>

        <div class="row items-center justify-between q-mb-sm">
          <div class="text-weight-medium">Target bills</div>
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            label="Fill oldest first"
            :disable="!openRows.length"
            @click="fillOldestFirst"
          />
        </div>
        <div v-if="loadingBills" class="text-grey-7 q-py-sm">Loading bills…</div>
        <div v-else-if="!openRows.length" class="text-grey-7 q-py-sm">
          No other open bills for this profile.
        </div>
        <q-list v-else bordered separator class="rounded-borders">
          <q-item v-for="row in openRows" :key="row.id">
            <q-item-section side top>
              <q-checkbox
                :model-value="row.selected"
                dense
                @update:model-value="(v) => onRowSelected(row, !!v)"
              />
            </q-item-section>
            <q-item-section>
              <q-item-label>{{ row.invoice_no }}</q-item-label>
              <q-item-label caption>Due {{ formatAmountBdt(row.due_amount) }}</q-item-label>
            </q-item-section>
            <q-item-section side top>
              <q-input
                v-model.number="row.allocAmount"
                type="number"
                outlined
                dense
                label="Amount"
                style="width: 112px"
                :disable="!row.selected"
              />
            </q-item-section>
          </q-item>
        </q-list>

        <q-banner
          v-if="allocOverPool"
          dense
          rounded
          class="bg-orange-1 text-orange-10 q-mt-sm"
        >
          Total exceeds open credit {{ formatAmountBdt(creditPool) }}.
        </q-banner>
      </q-card-section>
      <q-card-actions align="right">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Apply credit"
          :loading="submitting"
          :disable="!canSubmit"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import { billsRepository } from '../repositories/billsRepository';
import { fifoFillByOldest } from '../utils/fifoBillAlloc';
import { useApplySettlementMutation } from '../composables/useApplySettlementMutation';

export type OpenCreditNoteOption = {
  id: number;
  invoice_no: string;
  due_amount: number;
};

type TargetRow = {
  id: number;
  invoice_no: string;
  due_amount: number;
  selected: boolean;
  allocAmount: number;
};

const props = defineProps<{
  modelValue: boolean;
  tenantId: number;
  booksTenantId: number;
  profileId: number;
  isAp: boolean;
  excludeBillId: number;
  openCreditNotes: OpenCreditNoteOption[];
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  applied: [];
}>();

const applyMutation = useApplySettlementMutation({ successMessage: 'Credit applied to bill(s).' });

const selectedCreditNoteId = ref<number | null>(null);
const openRows = ref<TargetRow[]>([]);
const loadingBills = ref(false);

const creditNoteOptions = computed(() =>
  props.openCreditNotes.map((n) => ({
    id: n.id,
    label: `${n.invoice_no} · ${formatAmountBdt(n.due_amount)} open`,
  })),
);

const selectedCreditNote = computed(() =>
  props.openCreditNotes.find((n) => n.id === selectedCreditNoteId.value) ?? null,
);

const creditPool = computed(() => Math.max(0, Number(selectedCreditNote.value?.due_amount ?? 0)));

watch(
  () => [props.modelValue, props.openCreditNotes] as const,
  () => {
    if (!props.modelValue) return;
    const first = props.openCreditNotes.find((n) => n.due_amount > 0);
    selectedCreditNoteId.value = first?.id ?? null;
    openRows.value = [];
    void loadTargets();
  },
);

watch(selectedCreditNoteId, () => {
  for (const row of openRows.value) {
    row.selected = false;
    row.allocAmount = row.due_amount;
  }
});

const loadTargets = async () => {
  if (!props.profileId || !props.booksTenantId) {
    openRows.value = [];
    return;
  }
  loadingBills.value = true;
  try {
    const { data } = await billsRepository.listBills({
      parentTenantId: props.booksTenantId,
      profileId: props.profileId,
      invoiceStatus: 'issued',
      quickFilter: 'unpaid',
      pageSize: 100,
      invoiceType: props.isAp ? 'ap' : undefined,
      arSide: props.isAp ? 'we_owe' : 'they_owe',
    });
    openRows.value = data
      .filter((b) => b.id !== props.excludeBillId)
      .map((b) => ({
        id: b.id,
        invoice_no: b.invoice_no ?? `#${b.id}`,
        due_amount: Number(b.due_amount) || 0,
        selected: false,
        allocAmount: Number(b.due_amount) || 0,
      }));
  } finally {
    loadingBills.value = false;
  }
};

const selectedLines = computed(() =>
  openRows.value
    .filter((r) => r.selected && r.allocAmount > 0)
    .map((r) => ({ bill_id: r.id, amount: Number(r.allocAmount) || 0 })),
);

const allocTotal = computed(() => selectedLines.value.reduce((s, r) => s + r.amount, 0));

const allocOverPool = computed(() => allocTotal.value > creditPool.value);

const canSubmit = computed(
  () =>
    !!selectedCreditNoteId.value &&
    selectedLines.value.length > 0 &&
    allocTotal.value > 0 &&
    !allocOverPool.value &&
    !applyMutation.isPending.value,
);

const submitting = computed(() => applyMutation.isPending.value);

const remainingPoolExcluding = (billId: number) => {
  const used = openRows.value
    .filter((r) => r.selected && r.id !== billId)
    .reduce((sum, r) => sum + (Number(r.allocAmount) || 0), 0);
  return Math.max(0, creditPool.value - used);
};

const onRowSelected = (row: TargetRow, selected: boolean) => {
  if (!selected) {
    row.selected = false;
    row.allocAmount = row.due_amount;
    return;
  }
  const take = Math.min(row.due_amount, remainingPoolExcluding(row.id));
  if (take <= 0) {
    row.selected = false;
    return;
  }
  row.selected = true;
  row.allocAmount = take;
};

const fillOldestFirst = () => {
  const filled = fifoFillByOldest(openRows.value, creditPool.value);
  openRows.value = openRows.value.map((row) => {
    const take = filled.get(row.id);
    if (take == null) {
      return { ...row, selected: false, allocAmount: row.due_amount };
    }
    return { ...row, selected: true, allocAmount: take };
  });
};

const onSubmit = async () => {
  if (!canSubmit.value || !selectedCreditNoteId.value) return;
  await applyMutation.mutateAsync({
    tenantId: props.tenantId,
    lines: selectedLines.value.map((line) => ({
      bill_id: line.bill_id,
      amount: line.amount,
      allocator_kind: 'credit_note' as const,
      allocator_id: selectedCreditNoteId.value!,
    })),
  });
  emit('applied');
  emit('update:modelValue', false);
};
</script>

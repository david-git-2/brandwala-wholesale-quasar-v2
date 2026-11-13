import { computed, ref, watch, type Ref } from 'vue';
import type { OpenBillAllocRow } from './useOpenBillAllocations';
import { fifoFillByOldest } from '../utils/fifoBillAlloc';
import {
  paymentInstrumentExtrasBlockReason,
  paymentMethodFieldFlags,
} from '../utils/paymentInstrumentFields';
import type { WholesaleMethodOption } from './useWholesalePaymentMethodMeta';
import type {
  MoneyPayKind,
  MoneyPayDialogFieldFlags,
  MoneyPayDialogPrefill,
  MoneyPayInstrumentFields,
  MoneyPaySubmitPayload,
} from '../types/moneyPayDialog';

const localToday = () => {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const cloneAllocRows = (rows: OpenBillAllocRow[]): OpenBillAllocRow[] =>
  rows.map((r) => ({
    ...r,
    selected: r.selected,
    allocAmount: r.allocAmount,
  }));

function defaultFromLegVisible(kind: MoneyPayKind, flags: MoneyPayDialogFieldFlags): boolean {
  if (flags.showFromLeg != null) return flags.showFromLeg;
  return kind === 'payment' || kind === 'withdrawal' || kind === 'transfer';
}

function defaultToLegVisible(kind: MoneyPayKind, flags: MoneyPayDialogFieldFlags): boolean {
  if (flags.showToLeg != null) return flags.showToLeg;
  return kind === 'payment' || kind === 'deposit' || kind === 'transfer';
}

export function useMoneyPayDialogForm(options: {
  kind: Ref<MoneyPayKind>;
  dialogOpen: Ref<boolean>;
  fieldFlags: Ref<MoneyPayDialogFieldFlags>;
  prefill: Ref<MoneyPayDialogPrefill | null | undefined>;
  initialAllocationRows: Ref<OpenBillAllocRow[]>;
  methodOptions: Ref<WholesaleMethodOption[]>;
  defaultMethodCode?: string;
  lockBillId: Ref<number | null>;
}) {
  const amount = ref<number | null>(null);
  const paymentDate = ref(localToday());
  const methodCode = ref(options.defaultMethodCode ?? 'bank_transfer');
  const fromPotId = ref<number | null>(null);
  const toPotId = ref<number | null>(null);
  const reference = ref('');
  const note = ref('');
  const bdBankId = ref<number | null>(null);
  const chequeNumber = ref('');
  const instrumentDate = ref('');
  const instrumentReference = ref('');
  const allocationRows = ref<OpenBillAllocRow[]>([]);

  const showFromLeg = computed(() => defaultFromLegVisible(options.kind.value, options.fieldFlags.value));
  const showToLeg = computed(() => defaultToLegVisible(options.kind.value, options.fieldFlags.value));
  const showAllocations = computed(() => {
    if (options.kind.value !== 'payment') return false;
    return options.fieldFlags.value.showAllocations !== false;
  });
  const showInstrument = computed(() => options.fieldFlags.value.showInstrument !== false);
  const showDate = computed(() => options.fieldFlags.value.showDate !== false);
  const showReferenceNote = computed(() => options.fieldFlags.value.showReferenceNote !== false);

  const showSummary = computed(() => options.kind.value === 'payment');

  const paymentOverAlloc = computed(() => {
    const pay = Number(amount.value) || 0;
  const allocSum = selectedAllocations.value.reduce((s, a) => s + a.amount, 0);
    return pay > 0 && allocSum > 0 && pay > allocSum + 0.009;
  });

  const unallocatedAmount = computed(() => {
    const pay = Number(amount.value) || 0;
    const allocSum = selectedAllocations.value.reduce((s, a) => s + a.amount, 0);
    return Math.max(0, pay - allocSum);
  });

  const selectedAllocations = computed(() =>
    allocationRows.value
      .filter((b) => b.selected && (Number(b.allocAmount) || 0) > 0)
      .map((b) => ({ bill_id: b.id, amount: Number(b.allocAmount) || 0 })),
  );

  const selectedMethodMeta = computed(() => {
    const code = methodCode.value?.toLowerCase();
    const opt = options.methodOptions.value.find((m) => m.value === code);
    if (!opt) return { code: methodCode.value, category: '' };
    return { code: opt.code, category: opt.category };
  });

  const methodFieldFlags = computed(() => paymentMethodFieldFlags(selectedMethodMeta.value));

  const resolvePayAmount = (): number => {
    const pay = Number(amount.value);
    if (Number.isFinite(pay) && pay > 0) return pay;
    const pre = Number(options.prefill.value?.amount);
    if (Number.isFinite(pre) && pre > 0) return pre;
    const lockId = options.lockBillId.value;
    if (lockId != null) {
      const row =
        allocationRows.value.find((r) => r.id === lockId)
        ?? options.initialAllocationRows.value.find((r) => r.id === lockId);
      const due = Number(row?.allocAmount ?? row?.due_amount);
      if (Number.isFinite(due) && due > 0) return due;
    }
    return 0;
  };

  const resetForm = () => {
    const p = options.prefill.value;
    amount.value = p?.amount ?? null;
    paymentDate.value = p?.paymentDate?.trim() || localToday();
    methodCode.value = p?.methodCode?.trim() || options.defaultMethodCode || 'bank_transfer';
    fromPotId.value = p?.fromPotId ?? null;
    toPotId.value = p?.toPotId ?? null;
    reference.value = p?.reference ?? '';
    note.value = p?.note ?? '';
    bdBankId.value = null;
    chequeNumber.value = '';
    instrumentDate.value = '';
    instrumentReference.value = '';

    const seed = p?.allocationRows?.length
      ? cloneAllocRows(p.allocationRows)
      : cloneAllocRows(options.initialAllocationRows.value);
    if (options.lockBillId.value != null && seed.length) {
      for (const row of seed) {
        if (row.id === options.lockBillId.value) {
          row.selected = true;
        }
      }
    }
    allocationRows.value = seed;
  };

  watch(
    () => options.dialogOpen.value,
    (open) => {
      if (open) resetForm();
    },
    { immediate: true },
  );

  watch(
    () => options.prefill.value?.fromPotId,
    (potId) => {
      if (!options.dialogOpen.value || options.kind.value !== 'payment') return;
      if (potId != null && potId > 0) {
        fromPotId.value = potId;
      }
    },
  );

  const instrumentFields = (): MoneyPayInstrumentFields => ({
    bdBankId: bdBankId.value,
    chequeNumber: chequeNumber.value,
    instrumentDate: instrumentDate.value,
    instrumentReference: instrumentReference.value,
  });

  const submitDisabledReason = computed((): string | null => {
    const pay = resolvePayAmount();
    if (pay <= 0) return 'Next: enter an amount greater than zero.';

    if (showFromLeg.value && (fromPotId.value == null || fromPotId.value <= 0)) {
      return 'Next: choose which bundle cash leaves from.';
    }
    if (showToLeg.value && (toPotId.value == null || toPotId.value <= 0)) {
      return 'Next: choose which bundle receives cash.';
    }
    if (showFromLeg.value && showToLeg.value && fromPotId.value === toPotId.value) {
      return 'From and to pot must differ.';
    }

    if (showAllocations.value) {
      const lockId = options.lockBillId.value;
      if (lockId != null) {
        const locked = allocationRows.value.find((r) => r.id === lockId);
        const alloc = locked?.selected ? Number(locked.allocAmount) || 0 : 0;
        if (alloc <= 0) return 'Allocate some amount to this bill.';
        if (locked && alloc > locked.due_amount + 0.009) return 'Allocation exceeds bill due.';
      }
      for (const row of allocationRows.value) {
        if (!row.selected) continue;
        const a = Number(row.allocAmount) || 0;
        if (a <= 0) continue;
        if (a > row.due_amount + 0.009) {
          return `Allocation exceeds due on ${row.invoice_no}.`;
        }
      }
      const sum = selectedAllocations.value.reduce((s, x) => s + x.amount, 0);
      if (sum > pay + 0.009) return 'Sum of bill allocations exceeds payment amount.';
      if (options.kind.value === 'payment' && lockId != null && sum <= 0) {
        return 'Allocate some amount to this bill.';
      }
    }

    if (showInstrument.value) {
      const extrasReason = paymentInstrumentExtrasBlockReason(methodFieldFlags.value, instrumentFields());
      if (extrasReason) return extrasReason;
    }

    if (showDate.value && !paymentDate.value.trim()) return 'Next: enter payment date.';

    return null;
  });

  const buildPayload = (): MoneyPaySubmitPayload => {
    const pay = resolvePayAmount();
    let allocations = selectedAllocations.value;
    const lockId = options.lockBillId.value;
    if (options.kind.value === 'payment' && lockId != null && allocations.length === 0) {
      const dueRow = allocationRows.value.find((r) => r.id === lockId);
      const due = dueRow?.due_amount ?? pay;
      allocations = [{ bill_id: lockId, amount: Math.min(pay, due) }];
    }
    return {
      kind: options.kind.value,
      amount: pay,
      paymentDate: paymentDate.value.trim(),
      fromPotId: showFromLeg.value ? fromPotId.value : null,
      toPotId: showToLeg.value ? toPotId.value : null,
      allocations,
      methodCode: methodCode.value,
      reference: reference.value.trim() || null,
      note: note.value.trim() || null,
      instrumentFields: instrumentFields(),
    };
  };

  const fillOldestAllocations = () => {
    const pay = resolvePayAmount();
    if (pay <= 0) return;
    const filled = fifoFillByOldest(
      allocationRows.value.map((r) => ({ id: r.id, due_amount: r.due_amount })),
      pay,
    );
    for (const row of allocationRows.value) {
      const take = filled.get(row.id);
      if (take != null && take > 0) {
        row.selected = true;
        row.allocAmount = take;
      } else {
        row.selected = false;
        row.allocAmount = 0;
      }
    }
  };

  return {
    amount,
    paymentDate,
    methodCode,
    fromPotId,
    toPotId,
    reference,
    note,
    bdBankId,
    chequeNumber,
    instrumentDate,
    instrumentReference,
    allocationRows,
    showFromLeg,
    showToLeg,
    showAllocations,
    showInstrument,
    showDate,
    showReferenceNote,
    showSummary,
    paymentOverAlloc,
    unallocatedAmount,
    methodFieldFlags,
    submitDisabledReason,
    buildPayload,
    fillOldestAllocations,
    resetForm,
  };
}

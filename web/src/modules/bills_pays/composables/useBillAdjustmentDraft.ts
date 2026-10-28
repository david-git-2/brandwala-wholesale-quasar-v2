import { computed, ref, watch, type Ref } from 'vue';
import type { Database } from 'src/types/database.types';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from 'src/modules/sales_invoice/types';
import { formatAmountBdt } from 'src/utils/currency';
import type { CreateBillAdjustmentInput } from './useCreateBillAdjustmentMutation';
import {
  type BillAdjustmentDraftRow,
  booksAmountForAdjustmentLine,
  buildAdjustmentDraftRowsFromBill,
  defaultFxRateForBill,
  draftRowsToRpcLines,
  noteAmountFromRevised,
  noteLineMatchKey,
  parseNoteInputAmount,
  parseRevisedInputAmount,
  remainingAfterNotes,
} from '../utils/billAdjustmentParentLines';
import type { BillAdjustmentRow } from '../types/billAdjustments';
import { listBillLinesForInvoices } from '../repositories/billLinesRepository';

type BillDocumentKind = Database['public']['Enums']['bill_document_kind'];

function formatForeignAmount(amount: number): string {
  return Number(amount).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

export function useBillAdjustmentDraft(params: {
  bill: Ref<GlobalInvoiceDetail | undefined>;
  stockLines: Ref<GlobalInvoiceItemRow[]>;
  isAp: Ref<boolean>;
  parentDueAmount: Ref<number>;
  siblingNotes: Ref<BillAdjustmentRow[]>;
  active: Ref<boolean>;
}) {
  const kind = ref<BillDocumentKind>('credit_note');
  const reason = ref('');
  const draftRows = ref<BillAdjustmentDraftRow[]>([]);
  const remainingByKey = ref<Map<string, number>>(new Map());

  const fxRate = computed(() =>
    defaultFxRateForBill(
      (params.bill.value?.channel_meta ?? null) as Record<string, unknown> | null,
    ),
  );

  async function loadRemainingByKey() {
    const notes = params.siblingNotes.value.filter(
      (n) =>
        n.invoice_status === 'issued' &&
        (n.document_kind === 'credit_note' || n.document_kind === 'debit_note'),
    );
    const map = new Map<string, number>();
    if (!notes.length) {
      remainingByKey.value = map;
      return;
    }
    const lines = await listBillLinesForInvoices(notes.map((n) => n.id));
    const noteById = new Map(notes.map((n) => [n.id, n]));
    for (const line of lines) {
      const note = noteById.get(line.invoice_id);
      if (!note) continue;
      const key = noteLineMatchKey(line.name_snapshot, line.currency_code);
      const signed =
        note.document_kind === 'debit_note' ? -line.line_total_amount : line.line_total_amount;
      map.set(key, (map.get(key) ?? 0) + signed);
    }
    remainingByKey.value = map;
  }

  function applyRemainingToRows(rows: BillAdjustmentDraftRow[]) {
    const credited = remainingByKey.value;
    return rows.map((r) => {
      if (r.isExtra || r.originalAmount == null) return r;
      const net = credited.get(noteLineMatchKey(r.name, r.currencyCode)) ?? 0;
      const remaining = remainingAfterNotes(r.originalAmount, net);
      return { ...r, maxAmount: remaining };
    });
  }

  async function resetDraftRows() {
    const b = params.bill.value;
    if (!b) {
      draftRows.value = [];
      return;
    }
    await loadRemainingByKey();
    draftRows.value = applyRemainingToRows(
      buildAdjustmentDraftRowsFromBill({
        isAp: params.isAp.value,
        bill: b,
        stockLines: params.stockLines.value,
      }).map((r) => ({ ...r })),
    );
  }

  watch(
    () => params.active.value,
    (open) => {
      if (!open) return;
      kind.value = 'credit_note';
      reason.value = '';
      void resetDraftRows();
    },
  );

  function draftByKey(key: string) {
    return draftRows.value.find((r) => r.key === key);
  }

  function applyRevisedToRow(row: BillAdjustmentDraftRow) {
    if (row.isExtra || row.maxAmount == null) return;
    const noteAmt = noteAmountFromRevised({
      original: row.maxAmount,
      revised: row.revisedAmount,
      kind: kind.value,
    });
    row.amount = noteAmt;
    row.selected = noteAmt != null;
  }

  function onNoteAmountInput(row: BillAdjustmentDraftRow, value: number | null) {
    if (row.isExtra || row.maxAmount == null) {
      row.amount = parseNoteInputAmount(value);
      row.revisedAmount = row.amount;
      row.selected = row.amount != null;
      return;
    }
    row.revisedAmount = parseRevisedInputAmount(value);
    applyRevisedToRow(row);
  }

  watch(kind, () => {
    for (const row of draftRows.value) {
      applyRevisedToRow(row);
    }
  });

  function addExtraRow(currencyCode = 'BDT') {
    draftRows.value.push({
      key: `extra-${Date.now()}`,
      selected: true,
      lineKind: 'description',
      name: 'Extra adjustment',
      currencyCode: currencyCode.toUpperCase(),
      amount: null,
      revisedAmount: null,
      isExtra: true,
    });
  }

  const extraDraftRows = computed(() => draftRows.value.filter((r) => r.isExtra));

  const arChargeDraftRows = computed(() =>
    draftRows.value.filter((r) => !r.isExtra && ['shipping', 'wrapping', 'print'].includes(r.key)),
  );

  const noteTotalBdt = computed(() =>
    draftRows.value.reduce((sum, r) => {
      const amt = parseNoteInputAmount(r.amount);
      if (!r.selected || amt == null) return sum;
      return sum + booksAmountForAdjustmentLine(r.currencyCode, amt, fxRate.value);
    }, 0),
  );

  const noteTotalsByCurrency = computed(() => {
    const map = new Map<string, number>();
    for (const r of draftRows.value) {
      const amt = parseNoteInputAmount(r.amount);
      if (!r.selected || amt == null) continue;
      const code = r.currencyCode.trim().toUpperCase() || 'BDT';
      map.set(code, (map.get(code) ?? 0) + amt);
    }
    return [...map.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([code, amount]) => ({ code, amount }));
  });

  const noteTotalLabels = computed(() =>
    noteTotalsByCurrency.value.map(({ code, amount }) => ({
      code,
      label: code === 'BDT' ? formatAmountBdt(amount) : formatForeignAmount(amount),
    })),
  );

  const amountReducesDue = computed(() => {
    const due = Math.max(0, params.parentDueAmount.value);
    return Math.min(noteTotalBdt.value, due);
  });

  const balanceEffect = computed(() => {
    const total = noteTotalBdt.value;
    if (total <= 0) {
      return {
        direction: 'neutral' as const,
        title: 'Enter amounts on the lines above',
        detail: '',
      };
    }
    if (kind.value === 'debit_note') {
      return {
        direction: 'increase' as const,
        title: `Amount due will increase by ${formatAmountBdt(total)}`,
        detail: 'Collect the extra from the party when they pay.',
      };
    }
    const reduces = amountReducesDue.value;
    if (reduces < total) {
      const excess = total - reduces;
      return {
        direction: 'decrease' as const,
        title: `Due down ${formatAmountBdt(reduces)} · ${formatAmountBdt(excess)} open on the credit note`,
        detail: 'Cash refund is recorded separately when you pay out.',
      };
    }
    return {
      direction: 'decrease' as const,
      title: `Amount due will decrease by ${formatAmountBdt(total)}`,
      detail: '',
    };
  });

  const submitDisabledReason = computed(() => {
    if (noteTotalBdt.value <= 0) return 'Enter a note amount on at least one line.';
    if (!reason.value.trim()) return 'Reason is required.';
    return null;
  });

  function buildSubmitPayload(): CreateBillAdjustmentInput | null {
    if (submitDisabledReason.value || !params.bill.value) return null;
    const lines = draftRowsToRpcLines(draftRows.value, fxRate.value);

    return {
      parentBillId: params.bill.value.id,
      kind: kind.value,
      amount: noteTotalBdt.value,
      reason: reason.value.trim(),
      lines,
      refundAmount: null,
      cashbookPointId: null,
    };
  }

  const defaultExtraCurrency = computed(() => {
    const first = draftRows.value.find((r) => !r.isExtra);
    return first?.currencyCode ?? 'BDT';
  });

  const kindHint = computed(() =>
    kind.value === 'credit_note'
      ? 'Credit lowers what is owed on this bill.'
      : 'Debit adds to what is owed.',
  );

  return {
    kind,
    reason,
    draftRows,
    draftByKey,
    onNoteAmountInput,
    addExtraRow,
    extraDraftRows,
    arChargeDraftRows,
    noteTotalBdt,
    noteTotalLabels,
    amountReducesDue,
    balanceEffect,
    submitDisabledReason,
    buildSubmitPayload,
    defaultExtraCurrency,
    kindHint,
  };
}

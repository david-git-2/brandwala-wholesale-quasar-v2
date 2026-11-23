import { computed, ref, watch, type Ref } from 'vue';
import type { Database } from 'src/types/database.types';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from 'src/modules/bills_pays/types/invoice';
import { formatAmountBdt, formatCurrencyAmount } from 'src/utils/currency';
import type { CreateBillAdjustmentInput } from './useCreateBillAdjustmentMutation';
import type { WriteOffBillInput } from './useWriteOffBillMutation';
import {
  type BillAdjustmentDraftRow,
  booksAmountForAdjustmentLine,
  buildAdjustmentDraftRowsFromBill,
  defaultFxRateForBill,
  draftRowsToRpcLines,
  extraLineTotalFromDraftRow,
  noteAmountFromRevised,
  noteLineMatchKey,
  parseNoteInputAmount,
  parseRevisedInputAmount,
  remainingAfterNotes,
} from '../utils/billAdjustmentParentLines';
import type { BillAdjustmentRow } from '../types/billAdjustments';
import { listBillLinesForInvoices } from '../repositories/billLinesRepository';

type BillDocumentKind = Database['public']['Enums']['bill_document_kind'];

export type BillAdjustmentUiKind = BillDocumentKind | 'write_off';

export function useBillAdjustmentDraft(params: {
  bill: Ref<GlobalInvoiceDetail | undefined>;
  booksTenantId: Ref<number>;
  stockLines: Ref<GlobalInvoiceItemRow[]>;
  isAp: Ref<boolean>;
  parentDueAmount: Ref<number>;
  siblingNotes: Ref<BillAdjustmentRow[]>;
  active: Ref<boolean>;
  /** full = revise parent lines on bill detail; addLinesOnly = new tab, user-added lines only */
  lineEntryMode?: Ref<'full' | 'addLinesOnly'>;
}) {
  const kind = ref<BillAdjustmentUiKind>('credit_note');
  const reason = ref('');
  const writeOffAmount = ref<number | null>(null);
  const draftRows = ref<BillAdjustmentDraftRow[]>([]);
  const remainingByKey = ref<Map<string, number>>(new Map());
  const parentLineCaps = ref<Map<string, number>>(new Map());
  const lineEntryMode = computed(() => params.lineEntryMode?.value ?? 'full');

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
    const built = applyRemainingToRows(
      buildAdjustmentDraftRowsFromBill({
        isAp: params.isAp.value,
        bill: b,
        stockLines: params.stockLines.value,
      }).map((r) => ({ ...r })),
    );
    const caps = new Map<string, number>();
    for (const r of built) {
      if (r.isExtra || r.maxAmount == null) continue;
      caps.set(noteLineMatchKey(r.name, r.currencyCode), r.maxAmount);
    }
    parentLineCaps.value = caps;
    if (lineEntryMode.value === 'addLinesOnly') {
      const code = String(b.currency_code ?? 'BDT').trim().toUpperCase();
      draftRows.value = [
        {
          key: `extra-${Date.now()}`,
          selected: true,
          lineKind: 'description',
          name: '',
          currencyCode: code,
          amount: null,
          revisedAmount: null,
          isExtra: true,
          quantity: 1,
          unitPrice: null,
          reason: '',
        },
      ];
      return;
    }
    draftRows.value = built;
  }

  watch(
    () => params.active.value,
    (open) => {
      if (!open) return;
      kind.value = 'credit_note';
      reason.value = '';
      writeOffAmount.value = null;
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

  function syncExtraLineAmount(row: BillAdjustmentDraftRow) {
    const total = extraLineTotalFromDraftRow(row);
    row.amount = total;
    row.revisedAmount = total;
    row.selected = total != null;
  }

  function onNoteAmountInput(row: BillAdjustmentDraftRow, value: number | null) {
    if (row.isExtra) {
      row.unitPrice = null;
      row.amount = parseNoteInputAmount(value);
      row.revisedAmount = row.amount;
      row.selected = row.amount != null;
      return;
    }
    if (row.maxAmount == null) {
      row.amount = parseNoteInputAmount(value);
      row.revisedAmount = row.amount;
      row.selected = row.amount != null;
      return;
    }
    row.revisedAmount = parseRevisedInputAmount(value);
    applyRevisedToRow(row);
  }

  function onExtraLineSync(row: BillAdjustmentDraftRow) {
    syncExtraLineAmount(row);
  }

  watch(kind, (k) => {
    if (k === 'write_off') {
      refundCashNow.value = false;
      refundAmount.value = null;
      const due = Math.max(0, params.parentDueAmount.value);
      if (writeOffAmount.value == null || writeOffAmount.value <= 0) {
        writeOffAmount.value = due > 0 ? due : null;
      }
      return;
    }
    for (const row of draftRows.value) {
      applyRevisedToRow(row);
    }
  });

  function addExtraRow(currencyCode = 'BDT') {
    const code = (
      currencyCode ||
      String(params.bill.value?.currency_code ?? 'BDT')
    )
      .trim()
      .toUpperCase();
    draftRows.value.push({
      key: `extra-${Date.now()}`,
      selected: true,
      lineKind: 'description',
      name: '',
      currencyCode: code,
      amount: null,
      revisedAmount: null,
      isExtra: true,
      quantity: 1,
      unitPrice: null,
      reason: '',
    });
  }

  function lineFaceAmount(row: BillAdjustmentDraftRow): number | null {
    if (!row.selected) return null;
    if (row.isExtra) return extraLineTotalFromDraftRow(row);
    return parseNoteInputAmount(row.amount);
  }

  const extraDraftRows = computed(() => draftRows.value.filter((r) => r.isExtra));

  const arChargeDraftRows = computed(() =>
    draftRows.value.filter((r) => !r.isExtra && ['shipping', 'wrapping', 'print'].includes(r.key)),
  );

  const noteTotalBdt = computed(() =>
    draftRows.value.reduce((sum, r) => {
      const amt = lineFaceAmount(r);
      if (amt == null) return sum;
      return sum + booksAmountForAdjustmentLine(r.currencyCode, amt, fxRate.value);
    }, 0),
  );

  const noteTotalsByCurrency = computed(() => {
    const map = new Map<string, number>();
    for (const r of draftRows.value) {
      const amt = lineFaceAmount(r);
      if (amt == null) continue;
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
      label: formatCurrencyAmount(amount, code),
    })),
  );

  const amountReducesDue = computed(() => {
    const due = Math.max(0, params.parentDueAmount.value);
    return Math.min(noteTotalBdt.value, due);
  });

  const isWriteOffKind = computed(() => kind.value === 'write_off');

  const balanceEffect = computed(() => {
    if (kind.value === 'write_off') {
      const amt = Number(writeOffAmount.value) || 0;
      const due = Math.max(0, params.parentDueAmount.value);
      if (amt <= 0) {
        return {
          direction: 'neutral' as const,
          title: 'Enter the amount to forgive',
          detail: due > 0 ? `Due now: ${formatAmountBdt(due)}` : '',
        };
      }
      const remainder = Math.max(0, due - amt);
      return {
        direction: 'decrease' as const,
        title: `Forgive ${formatAmountBdt(amt)} of due`,
        detail:
          remainder > 0
            ? `${formatAmountBdt(remainder)} will remain due.`
            : 'Bill due can go to zero.',
      };
    }
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

  const excessCreditBdt = computed(() => {
    if (params.isAp.value || kind.value !== 'credit_note') return 0;
    const total = noteTotalBdt.value;
    if (total <= 0) return 0;
    const reduces = amountReducesDue.value;
    return Math.max(0, Math.round((total - reduces) * 100) / 100);
  });

  const arRefundEligible = computed(
    () => !params.isAp.value && kind.value === 'credit_note' && excessCreditBdt.value > 0,
  );

  const refundCashNow = ref(false);
  const refundAmount = ref<number | null>(null);

  watch(
    () => [arRefundEligible.value, excessCreditBdt.value] as const,
    ([eligible, excess]) => {
      if (!eligible) {
        refundCashNow.value = false;
        refundAmount.value = null;
        return;
      }
      if (refundCashNow.value && (refundAmount.value == null || refundAmount.value <= 0)) {
        refundAmount.value = excess;
      }
    },
  );

  watch(refundCashNow, (on) => {
    if (on && excessCreditBdt.value > 0) {
      refundAmount.value = excessCreditBdt.value;
    }
    if (!on) {
      refundAmount.value = null;
    }
  });

  const submitDisabledReason = computed(() => {
    if (kind.value === 'write_off') {
      const due = Math.max(0, params.parentDueAmount.value);
      const amt = Number(writeOffAmount.value) || 0;
      if (due <= 0) return 'Nothing due to write off.';
      if (amt <= 0) return 'Enter a write-off amount.';
      if (amt > due + 0.001) return `Cannot exceed due ${formatAmountBdt(due)}.`;
      if (!reason.value.trim()) return 'Reason is required.';
      return null;
    }
    if (noteTotalBdt.value <= 0) {
      return 'Add at least one line with description, quantity, and unit price.';
    }
    if (!reason.value.trim()) return 'Reason is required.';
    for (const row of draftRows.value) {
      const amt = lineFaceAmount(row);
      if (amt == null) continue;
      if (!row.name.trim()) return 'Each line needs a description.';
      if (!row.reason.trim()) return 'Each line needs a reason.';
      if (row.isExtra && row.quantity <= 0) return 'Line quantity must be greater than zero.';
      if (row.isExtra && (row.unitPrice == null || row.unitPrice <= 0)) {
        return 'Each line needs a unit price.';
      }
    }
    if (kind.value === 'credit_note') {
      const draftByKey = new Map<string, number>();
      for (const row of draftRows.value) {
        const amt = lineFaceAmount(row);
        if (amt == null) continue;
        const matchKey = noteLineMatchKey(row.name, row.currencyCode);
        draftByKey.set(matchKey, (draftByKey.get(matchKey) ?? 0) + amt);
      }
      for (const [matchKey, draftSum] of draftByKey) {
        const cap = parentLineCaps.value.get(matchKey);
        if (cap == null) continue;
        if (draftSum > cap + 0.001) {
          const row = draftRows.value.find(
            (r) => noteLineMatchKey(r.name, r.currencyCode) === matchKey,
          );
          const code = row?.currencyCode ?? 'BDT';
          const label = formatCurrencyAmount(cap, code);
          const labelName = row?.name?.trim() || 'line';
          return `Credit for "${labelName}" cannot exceed ${label} remaining.`;
        }
      }
    }
    if (refundCashNow.value) {
      const amt = Number(refundAmount.value) || 0;
      if (amt <= 0) return 'Enter a refund amount.';
      if (amt > excessCreditBdt.value + 0.001) {
        return `Refund cannot exceed ${formatAmountBdt(excessCreditBdt.value)} open on the note.`;
      }
    }
    return null;
  });

  function buildWriteOffPayload(): WriteOffBillInput | null {
    if (kind.value !== 'write_off' || submitDisabledReason.value || !params.bill.value) {
      return null;
    }
    const amt = Math.round((Number(writeOffAmount.value) || 0) * 100) / 100;
    return {
      billId: params.bill.value.id,
      tenantId: params.booksTenantId.value,
      amount: amt,
      reason: reason.value.trim(),
    };
  }

  function buildSubmitPayload(
    cashbookPointId?: number | null,
  ): CreateBillAdjustmentInput | null {
    if (kind.value === 'write_off') return null;
    if (submitDisabledReason.value || !params.bill.value) return null;
    const lines = draftRowsToRpcLines(draftRows.value, fxRate.value);
    const refund =
      refundCashNow.value && (Number(refundAmount.value) || 0) > 0
        ? Math.round(Number(refundAmount.value) * 100) / 100
        : null;

    return {
      parentBillId: params.bill.value.id,
      tenantId: params.booksTenantId.value,
      kind: kind.value,
      amount: noteTotalBdt.value,
      reason: reason.value.trim(),
      lines,
      refundAmount: refund,
      cashbookPointId:
        refund != null && cashbookPointId != null && cashbookPointId > 0
          ? cashbookPointId
          : null,
    };
  }

  const defaultExtraCurrency = computed(() => {
    const fromBill = params.bill.value?.currency_code;
    if (fromBill) return String(fromBill).trim().toUpperCase();
    const first = draftRows.value.find((r) => r.currencyCode);
    return first?.currencyCode ?? 'BDT';
  });

  const kindHint = computed(() => {
    if (kind.value === 'write_off') {
      return 'Write-off forgives due without a credit note.';
    }
    return kind.value === 'credit_note'
      ? 'Credit lowers what is owed on this bill.'
      : 'Debit adds to what is owed.';
  });

  return {
    kind,
    reason,
    writeOffAmount,
    isWriteOffKind,
    draftRows,
    draftByKey,
    onNoteAmountInput,
    onExtraLineSync,
    addExtraRow,
    extraDraftRows,
    arChargeDraftRows,
    noteTotalBdt,
    noteTotalLabels,
    amountReducesDue,
    balanceEffect,
    submitDisabledReason,
    buildSubmitPayload,
    buildWriteOffPayload,
    defaultExtraCurrency,
    kindHint,
    arRefundEligible,
    excessCreditBdt,
    refundCashNow,
    refundAmount,
  };
}

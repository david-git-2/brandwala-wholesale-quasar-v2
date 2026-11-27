import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from 'src/modules/finance/submodules/bills_pays/types/invoice';
import { apBillCurrencyGroups, apBillPaperConversionRate, parseApBillPaper } from './parseApBillPaper';

export type BillAdjustmentDraftRow = {
  key: string;
  selected: boolean;
  lineKind: 'stock' | 'description' | 'charge';
  name: string;
  currencyCode: string;
  /** Amount sent on the note (delta vs original, or typed extra). */
  amount: number | null;
  /** What the user typed as the new line total. Extra lines leave this unused. */
  revisedAmount: number | null;
  parentLineId?: number;
  globalStockId?: number;
  isExtra: boolean;
  originalAmount?: number;
  maxAmount?: number;
  /** Own lines and display for revised lines (default 1). */
  quantity: number;
  /** Own lines: unit price in line currency. */
  unitPrice: number | null;
  /** Per-line reason stored on note line meta. */
  reason: string;
};

export function apLineDraftKey(groupIdx: number, lineIdx: number) {
  return `ap-${groupIdx}-${lineIdx}`;
}

/** Normalize q-input number values (strings) for note line amounts. */
export function parseNoteInputAmount(value: unknown): number | null {
  if (value == null || value === '') return null;
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

/** Revised line total: 0 is allowed (full credit). */
export function parseRevisedInputAmount(value: unknown): number | null {
  if (value == null || value === '') return null;
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n) || n < 0) return null;
  return n;
}

export function noteAmountFromRevised(params: {
  original: number;
  revised: number | null;
  kind: 'credit_note' | 'debit_note' | string;
}): number | null {
  if (params.revised == null) return null;
  const delta =
    params.kind === 'debit_note'
      ? params.revised - params.original
      : params.original - params.revised;
  if (!Number.isFinite(delta) || delta <= 0) return null;
  return Math.round(delta * 100) / 100;
}

export function noteLineMatchKey(name: string, currencyCode: string): string {
  return `${(name || '').trim().toLowerCase()}|${(currencyCode || 'BDT').trim().toUpperCase()}`;
}

/** Remaining face after issued notes: original − credits + debits (never below 0). */
export function remainingAfterNotes(original: number, netCredited: number): number {
  return Math.max(0, Math.round((original - netCredited) * 100) / 100);
}

export function booksAmountForAdjustmentLine(
  currencyCode: string,
  lineTotal: number,
  fxRateBdtPerUnit: number | null,
): number {
  const code = currencyCode.trim().toUpperCase();
  if (code === 'BDT' || !code) {
    return Math.round(lineTotal * 100) / 100;
  }
  const rate = fxRateBdtPerUnit != null && fxRateBdtPerUnit > 0 ? fxRateBdtPerUnit : 1;
  return Math.round(lineTotal * rate * 100) / 100;
}

export function buildAdjustmentDraftRowsFromBill(params: {
  isAp: boolean;
  bill: GlobalInvoiceDetail;
  stockLines: GlobalInvoiceItemRow[];
}): BillAdjustmentDraftRow[] {
  const { isAp, bill, stockLines } = params;
  const rows: BillAdjustmentDraftRow[] = [];

  if (isAp) {
    const meta = (bill.channel_meta ?? null) as Record<string, unknown> | null;
    const groups = apBillCurrencyGroups(meta);
    if (groups.length) {
      for (let gIdx = 0; gIdx < groups.length; gIdx++) {
        const group = groups[gIdx];
        const code = (group.currency_code || 'BDT').toUpperCase();
        const groupLines = group.lines ?? [];
        for (let lineIdx = 0; lineIdx < groupLines.length; lineIdx++) {
          const line = groupLines[lineIdx];
          const amt = Number(line.amount ?? 0);
          if (amt <= 0) continue;
          rows.push({
            key: apLineDraftKey(gIdx, lineIdx),
            selected: false,
            lineKind: 'description',
            name: line.description?.trim() || 'Cost line',
            currencyCode: (line.currency_code || code || 'BDT').toUpperCase(),
            amount: null,
            revisedAmount: null,
            isExtra: false,
            originalAmount: amt,
            maxAmount: amt,
            quantity: 1,
            unitPrice: null,
            reason: '',
          });
        }
      }
    } else {
      const paper = parseApBillPaper(meta, bill.ap_kind);
      const bdt =
        paper && 'bdt_amount' in paper ? Number((paper as { bdt_amount?: number }).bdt_amount ?? 0) : Number(bill.total_amount ?? 0);
      if (bdt > 0) {
        rows.push({
          key: 'ap-total',
          selected: false,
          lineKind: 'description',
          name: 'Bill total',
          currencyCode: 'BDT',
          amount: null,
          revisedAmount: null,
          isExtra: false,
          originalAmount: bdt,
          maxAmount: bdt,
          quantity: 1,
          unitPrice: null,
          reason: '',
        });
      }
    }
    return rows;
  }

  for (const line of stockLines) {
    const lineTotal = Number(line.line_total_amount ?? 0);
    rows.push({
      key: `stock-${line.id}`,
      selected: false,
      lineKind: 'stock',
      name: line.name_snapshot?.trim() || 'Line item',
      currencyCode: 'BDT',
      amount: null,
      revisedAmount: null,
      parentLineId: line.id,
      globalStockId: line.global_stock_id > 0 ? line.global_stock_id : undefined,
      isExtra: false,
      originalAmount: lineTotal > 0 ? lineTotal : undefined,
      maxAmount: lineTotal > 0 ? lineTotal : undefined,
      quantity: 1,
      unitPrice: null,
      reason: '',
    });
  }

  const pushCharge = (key: string, label: string, value: number | undefined | null) => {
    const amt = Number(value ?? 0);
    if (amt <= 0) return;
    rows.push({
      key,
      selected: false,
      lineKind: 'charge',
      name: label,
      currencyCode: 'BDT',
      amount: null,
      revisedAmount: null,
      isExtra: false,
      originalAmount: amt,
      maxAmount: amt,
      quantity: 1,
      unitPrice: null,
      reason: '',
    });
  };

  pushCharge('shipping', 'Shipping', bill.shipping_charge);
  pushCharge('wrapping', 'Wrapping', bill.wrapping_charge);
  pushCharge('print', 'Print', bill.print_charge);

  return rows;
}

export function defaultFxRateForBill(channelMeta: Record<string, unknown> | null | undefined): number | null {
  return apBillPaperConversionRate(channelMeta ?? null);
}

export type BillAdjustmentRpcLine = {
  line_kind: 'stock' | 'description' | 'charge';
  name_snapshot: string;
  quantity: number;
  unit_price: number;
  currency_code: string;
  line_total_amount: number;
  books_amount: number;
  reason: string;
  parent_line_id?: number;
  global_stock_id?: number;
};

/** Own line amount from qty × unit price when both set; else typed amount. */
export function extraLineTotalFromDraftRow(row: BillAdjustmentDraftRow): number | null {
  const qty = Number(row.quantity);
  const unit = row.unitPrice;
  if (row.isExtra && Number.isFinite(qty) && qty > 0 && unit != null && Number.isFinite(unit) && unit > 0) {
    return Math.round(qty * unit * 100) / 100;
  }
  return parseNoteInputAmount(row.amount);
}

export function draftRowsToRpcLines(
  rows: BillAdjustmentDraftRow[],
  fxRateBdtPerUnit: number | null,
): BillAdjustmentRpcLine[] {
  return rows
    .map((r) => {
      const lineTotal = r.isExtra ? extraLineTotalFromDraftRow(r) : parseNoteInputAmount(r.amount);
      if (!r.selected || lineTotal == null) return null;
      const qty = Math.max(Number(r.quantity) || 1, 0.001);
      const unitPrice =
        r.isExtra && r.unitPrice != null && r.unitPrice > 0
          ? Math.round(r.unitPrice * 10000) / 10000
          : Math.round((lineTotal / qty) * 10000) / 10000;
      const reason = r.reason.trim();
      return {
        line_kind: r.lineKind,
        name_snapshot: r.name,
        quantity: qty,
        unit_price: unitPrice,
        currency_code: r.currencyCode,
        line_total_amount: lineTotal,
        books_amount: booksAmountForAdjustmentLine(r.currencyCode, lineTotal, fxRateBdtPerUnit),
        reason,
        ...(r.parentLineId != null ? { parent_line_id: r.parentLineId } : {}),
        ...(r.globalStockId != null ? { global_stock_id: r.globalStockId } : {}),
      };
    })
    .filter((line): line is BillAdjustmentRpcLine => line != null);
}

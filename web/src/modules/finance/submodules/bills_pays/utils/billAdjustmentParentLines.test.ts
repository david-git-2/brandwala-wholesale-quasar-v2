import { describe, expect, it } from 'vitest';
import {
  draftRowsToRpcLines,
  extraLineTotalFromDraftRow,
  type BillAdjustmentDraftRow,
} from './billAdjustmentParentLines';

function extraRow(overrides: Partial<BillAdjustmentDraftRow> = {}): BillAdjustmentDraftRow {
  return {
    key: 'extra-1',
    selected: true,
    lineKind: 'description',
    name: 'Head & Shoulders Menthol 400ML',
    currencyCode: 'GBP',
    amount: null,
    revisedAmount: null,
    isExtra: true,
    quantity: 6,
    unitPrice: 2.49,
    reason: 'Not brought — vendor refunded',
    ...overrides,
  };
}

describe('extraLineTotalFromDraftRow', () => {
  it('uses qty × unit price for own lines', () => {
    expect(extraLineTotalFromDraftRow(extraRow())).toBe(14.94);
  });

  it('falls back to typed amount when unit price missing', () => {
    expect(extraLineTotalFromDraftRow(extraRow({ unitPrice: null, amount: 9.9 }))).toBe(9.9);
  });
});

describe('draftRowsToRpcLines', () => {
  it('maps quantity, unit_price, and reason', () => {
    const lines = draftRowsToRpcLines([extraRow()], 150);
    expect(lines).toHaveLength(1);
    expect(lines[0]?.quantity).toBe(6);
    expect(lines[0]?.unit_price).toBe(2.49);
    expect(lines[0]?.line_total_amount).toBe(14.94);
    expect(lines[0]?.reason).toBe('Not brought — vendor refunded');
  });
});
import { describe, expect, test } from 'vitest';
import {
  matchBatchItemsForShipmentLine,
  summarizeBatchMatches,
} from './batchCodeShipmentMatch';
import type { BatchCodeItem } from '../repositories/batchCodeRepository';

const item = (partial: Partial<BatchCodeItem>): BatchCodeItem =>
  ({
    id: 1,
    list_id: 1,
    barcode: null,
    product_code: null,
    batch_id: null,
    manufacturing_date: null,
    expire_date: null,
    is_arrived: false,
    created_at: '',
    updated_at: '',
    ...partial,
  }) as BatchCodeItem;

describe('batchCodeShipmentMatch', () => {
  test('matches by barcode or product code', () => {
    const batchItems = [
      item({ id: 1, barcode: 'ABC', batch_id: 'B1' }),
      item({ id: 2, product_code: 'SKU-9', batch_id: 'B2' }),
      item({ id: 3, barcode: 'OTHER', batch_id: 'B3' }),
    ];

    expect(
      matchBatchItemsForShipmentLine({ barcode: 'abc', product_code: null }, batchItems).map(
        (r) => r.id,
      ),
    ).toEqual([1]);

    expect(
      matchBatchItemsForShipmentLine({ barcode: null, product_code: 'sku-9' }, batchItems).map(
        (r) => r.id,
      ),
    ).toEqual([2]);
  });

  test('compact batch count matches dialog line count', () => {
    const matches = [
      item({ batch_id: 'A1', expire_date: '2030-01-01' }),
      item({ batch_id: 'A1', expire_date: '2030-02-01' }),
      item({ batch_id: 'A2', expire_date: '2030-03-01' }),
    ];
    const summary = summarizeBatchMatches(matches);
    expect(summary.compactLabel).toBe('3');
    expect(summary.summaryLabel).toBe('A1 · A2');
    expect(summary.lineCount).toBe(3);
  });
});

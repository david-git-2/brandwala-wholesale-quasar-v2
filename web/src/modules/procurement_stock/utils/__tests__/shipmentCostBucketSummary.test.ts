import { describe, expect, test } from 'vitest';
import {
  aggregateCostEntriesByBucket,
  aggregateSectionLines,
  applyMaterialLineListFallback,
  freightPerKgFromBucketSummary,
  sumBucketBdtPreview,
  sumBucketBuyInPurchase,
} from '../shipmentCostBucketSummary';
import type { GlobalShipmentItem } from '../../repositories/globalShipmentRepository';

describe('shipmentCostBucketSummary', () => {
  const preview = {
    type: 'international' as const,
    product_conversion_rate: 120,
    cargo_conversion_rate: 130,
    cargo_rate: 2.5,
    received_weight: 10,
    transaction_rate: null,
  };

  const currency = {
    purchaseCurrencyId: 1,
    costCurrencyId: 2,
    codeById: (id: number | null | undefined) => (id === 2 ? 'BDT' : 'GBP'),
  };

  test('aggregateCostEntriesByBucket groups freight and material', () => {
    const rows = aggregateCostEntriesByBucket(
      [
        { cost_bucket: 'material', amount: 100, currency_id: 1, is_capitalizable: true },
        { cost_bucket: 'freight', amount: 50, currency_id: 1, is_capitalizable: true },
        { cost_bucket: 'customs', amount: 200, currency_id: 2, is_capitalizable: true },
      ],
      preview,
      currency,
    );
    const material = rows.find((r) => r.bucket === 'material')!;
    const freight = rows.find((r) => r.bucket === 'freight')!;
    const customs = rows.find((r) => r.bucket === 'customs')!;
    expect(material.buyInPurchaseCurrency).toBe(100);
    expect(material.bdtPreview).toBe(12000);
    expect(freight.bdtPreview).toBe(6500);
    expect(customs.bdtPreview).toBe(200);
    expect(sumBucketBuyInPurchase(rows)).toBe(150);
    expect(sumBucketBdtPreview(rows)).toBe(18700);
  });

  test('applyMaterialLineListFallback fills material from line goods', () => {
    const empty = aggregateCostEntriesByBucket([], preview, currency);
    const filled = applyMaterialLineListFallback(empty, 250, preview, 'GBP');
    const material = filled.find((r) => r.bucket === 'material')!;
    expect(material.buyInPurchaseCurrency).toBe(250);
    expect(material.bdtPreview).toBe(30000);
    expect(material.foreignLegs).toEqual([{ currency_code: 'GBP', amount: 250 }]);
  });

  test('aggregateSectionLines splits freight by weight across sections', () => {
    const itemA: GlobalShipmentItem = {
      id: 1,
      shipment_id: 1,
      product_id: null,
      vendor_id: null,
      name: 'A',
      ordered_quantity: 10,
      image_url: null,
      add_method: 'manual',
      purchase_price: 5,
      product_weight: 1000,
      package_weight: 0,
      barcode: null,
      product_code: null,
      source_child_tenant_id: null,
      source_type: null,
      source_id: null,
      section_id: 1,
      created_at: '',
      updated_at: '',
    };
    const itemB: GlobalShipmentItem = {
      ...itemA,
      id: 2,
      name: 'B',
      ordered_quantity: 10,
      product_weight: 3000,
      section_id: 2,
    };
    const all = [itemA, itemB];
    const secA = aggregateSectionLines([itemA], preview, all);
    const secB = aggregateSectionLines([itemB], preview, all);
    expect(secA.goodsPurchase).toBe(50);
    expect(secB.goodsPurchase).toBe(50);
    expect(secA.weightKg).toBe(10);
    expect(secB.weightKg).toBe(30);
    expect(secA.freightPurchase + secB.freightPurchase).toBeCloseTo(25, 2);
  });

  test('freightPerKgFromBucketSummary divides freight buy total by weight', () => {
    const rows = aggregateCostEntriesByBucket(
      [{ cost_bucket: 'freight', amount: 500, currency_id: 1, is_capitalizable: true }],
      preview,
      currency,
    );
    expect(freightPerKgFromBucketSummary(rows, 145)).toBeCloseTo(500 / 145, 4);
    expect(freightPerKgFromBucketSummary(rows, 0)).toBeNull();
  });
});
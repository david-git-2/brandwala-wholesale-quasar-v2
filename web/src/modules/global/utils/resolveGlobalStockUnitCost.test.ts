import { describe, test, expect } from 'vitest';
import { resolveGlobalStockUnitCostSync } from './resolveGlobalStockUnitCost';
import type { GlobalStockCostingInput } from '../types';

const baseLine: GlobalStockCostingInput = {
  shipment_id: 1,
  shipment_item_id: 10,
  purchase_price: 10,
  product_weight: 800,
  package_weight: 200,
  ordered_quantity: 5,
  shipment_type: 'international',
  product_conversion_rate: 124.5,
  cargo_conversion_rate: 165.2,
  cargo_rate: 6.5,
  received_weight: 15,
  transaction_rate: null,
};

describe('resolveGlobalStockUnitCostSync', () => {
  test('returns domestic cost without conversion', () => {
    const line: GlobalStockCostingInput = {
      ...baseLine,
      shipment_type: 'domestic',
      product_conversion_rate: 1,
      cargo_conversion_rate: 1,
      cargo_rate: 0,
      received_weight: null,
    };

    const cost = resolveGlobalStockUnitCostSync(line, []);
    expect(cost).toBe(10);
  });

  test('allocates cargo proportionally when shipment items provided', () => {
    const shipmentItems = [
      {
        purchase_price: 10,
        product_weight: 800,
        package_weight: 200,
        ordered_quantity: 5,
      },
      {
        purchase_price: 20,
        product_weight: 1500,
        package_weight: 500,
        ordered_quantity: 10,
      },
    ];

    const cost = resolveGlobalStockUnitCostSync(baseLine, shipmentItems);
    expect(cost).toBeCloseTo(1889.28, 2);
  });

  test('overrides transaction_rate in line input with live calculated rate when shipment items provided', () => {
    const lineWithCustomTxRate: GlobalStockCostingInput = {
      ...baseLine,
      transaction_rate: 999.0, // Stored transaction rate that should be overridden
    };

    const shipmentItems = [
      {
        purchase_price: 10,
        product_weight: 800,
        package_weight: 200,
        ordered_quantity: 5,
      },
      {
        purchase_price: 20,
        product_weight: 1500,
        package_weight: 500,
        ordered_quantity: 10,
      },
    ];

    const cost = resolveGlobalStockUnitCostSync(lineWithCustomTxRate, shipmentItems);
    // If it did not override, the unit cost would be ~13.9 * 999 = ~13886.1
    // With override, it matches the live calculated rate, resulting in ~1889.28
    expect(cost).toBeCloseTo(1889.28, 2);
  });
});

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
  received_weight: 15,
};

describe('resolveGlobalStockUnitCostSync', () => {
  test('prefers landed_cost_bdt stamp on the line over live recompute', () => {
    const line: GlobalStockCostingInput = {
      ...baseLine,
      landed_cost_bdt: 42.5,
    };
    const cost = resolveGlobalStockUnitCostSync(line, []);
    expect(cost).toBe(42.5);
  });

  test('prefers stamp from shipment item cache when line has no stamp', () => {
    const shipmentItems = [
      {
        id: 10,
        purchase_price: 10,
        product_weight: 800,
        package_weight: 200,
        ordered_quantity: 5,
        landed_cost_bdt: 99.25,
      },
    ];
    const cost = resolveGlobalStockUnitCostSync(baseLine, shipmentItems);
    expect(cost).toBe(99.25);
  });

  test('returns domestic cost without conversion when unstamped', () => {
    const line: GlobalStockCostingInput = {
      ...baseLine,
      shipment_type: 'local',
      received_weight: null,
    };

    const cost = resolveGlobalStockUnitCostSync(line, []);
    expect(cost).toBe(10);
  });

  test('uses default conversion when unstamped and shipment items provided', () => {
    const shipmentItems = [
      {
        id: 10,
        purchase_price: 10,
        product_weight: 800,
        package_weight: 200,
        ordered_quantity: 5,
        landed_cost_bdt: null,
      },
      {
        id: 11,
        purchase_price: 20,
        product_weight: 1500,
        package_weight: 500,
        ordered_quantity: 10,
        landed_cost_bdt: null,
      },
    ];

    const cost = resolveGlobalStockUnitCostSync(baseLine, shipmentItems);
    expect(cost).toBe(10);
  });
});

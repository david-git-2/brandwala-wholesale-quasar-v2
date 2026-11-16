import { describe, test, expect } from 'vitest';
import { buildShipmentLandedPlan } from '../landedCostBdtEngine';
import type { CostingLineItemInput, CostingShipmentInput } from '../types';

describe('landedCostBdtEngine', () => {
  const shipment: CostingShipmentInput = {
    type: 'international',
    received_weight: 145,
    total_weight_kg: 145,
    product_conversion_rate: 168,
    cargo_conversion_rate: 166,
    cargo_rate: 0,
    transaction_rate: null,
    freight_bdt_per_kg: 1125.97,
  };

  const aveeno: CostingLineItemInput = {
    purchase_price: 5.21,
    product_weight: 500,
    package_weight: 95.785,
    ordered_quantity: 12,
  };

  const pools = {
    materialBdt: 262_382.4,
    freightBdt: 163_265,
    customsBdt: 5_000,
    handlingBdt: 3_400,
    financeBdt: 0,
    otherBdt: 300,
  };

  test('buildShipmentLandedPlan includes freight customs handling other on unit landed', () => {
    const plan = buildShipmentLandedPlan([aveeno], shipment, pools, 1_561.8, 168);
    const parts = plan.lines.get(0);
    expect(parts).toBeDefined();
    expect(parts!.freightBdtPerUnit).toBeGreaterThan(600);
    expect(parts!.customsBdtPerUnit).toBeGreaterThan(0);
    expect(parts!.handlingBdtPerUnit).toBeGreaterThan(0);
    expect(parts!.unitLanded).toBeGreaterThan(parts!.goodsBdtPerUnit + parts!.freightBdtPerUnit);
  });
});
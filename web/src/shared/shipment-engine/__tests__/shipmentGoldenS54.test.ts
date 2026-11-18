import { describe, expect, test } from 'vitest';
import golden from '../fixtures/shipment_golden_s54.json';
import { buildShipmentLandedPlan } from '../landedCostBdtEngine';
import type { CostingLineItemInput, CostingShipmentInput } from '../types';

describe('shipmentGoldenS54', () => {
  test('web landed engine matches SQL golden per-unit and line sum', () => {
    const shipment = golden.shipment as CostingShipmentInput;
    const items = golden.items as CostingLineItemInput[];
    const plan = buildShipmentLandedPlan(
      items,
      shipment,
      golden.pools,
      golden.materialForeign,
      golden.shipment.product_conversion_rate,
    );

    golden.expected.landedPerUnit.forEach((expected, index) => {
      const parts = plan.lines.get(index);
      expect(parts).toBeDefined();
      expect(parts!.unitLanded).toBeCloseTo(expected, 4);
    });

    let lineSum = 0;
    items.forEach((item, index) => {
      const parts = plan.lines.get(index);
      lineSum += (parts?.unitLanded ?? 0) * item.ordered_quantity;
    });

    expect(lineSum).toBeCloseTo(golden.expected.lineLandedSum, 1);
    expect(Math.abs(lineSum - golden.expected.apBooksGrandTotal)).toBeLessThanOrEqual(
      golden.expected.toleranceLineSum,
    );
  });
});
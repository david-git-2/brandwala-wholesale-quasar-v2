import { describe, expect, test } from 'vitest';
import { ref } from 'vue';
import golden from '../../fixtures/shipment_report_golden_s54.json';
import type { ShipmentReportDetailPayload } from '../../types/shipmentReportDetailTypes';
import { useShipmentReportView } from '../useShipmentReportView';

const tol = golden.tolerance_bdt as number;
const payload = golden.payload as ShipmentReportDetailPayload;

function near(actual: number, expected: number) {
  expect(Math.abs(actual - expected)).toBeLessThanOrEqual(tol);
}

describe('shipment report golden S54 (tenant 15 / shipment 54)', () => {
  test('profit matrix matches canonical batch P&L', () => {
    const { matrix } = useShipmentReportView(ref(payload));
    const pm = golden.profit_matrix as Record<string, number>;
    near(matrix.value.total_cost_bdt, pm.total_cost_bdt);
    near(matrix.value.total_sell_bdt, pm.total_sell_bdt);
    near(matrix.value.profit_loss_bdt, pm.profit_loss_bdt);
    near(matrix.value.receive_loss_bdt, pm.receive_loss_bdt);
    expect(matrix.value.profit_loss_pct).toBeCloseTo(pm.profit_loss_pct, 2);
    expect(matrix.value.unpaid_total_bdt).toBe(pm.unpaid_total_bdt);
  });

  test('quantity summary: 1500 ordered, 3 lost, 1497 sold, 0 warehouse value', () => {
    const { qty, warehouseValueBdt, soldPct } = useShipmentReportView(ref(payload));
    const q = golden.qty_summary as Record<string, number>;
    expect(qty.value.should_arrive).toBe(q.should_arrive);
    expect(qty.value.loss_at_shipment).toBe(q.loss_at_shipment);
    expect(qty.value.sold).toBe(q.sold);
    expect(qty.value.warehouse_value_bdt).toBe(q.warehouse_value_bdt);
    expect(warehouseValueBdt.value).toBe(0);
    expect(soldPct.value).toBeCloseTo(99.8, 1);
  });

  test('donut slices sum to total cost and match bucket golden', () => {
    const { donutSlices, bridgeSteps } = useShipmentReportView(ref(payload));
    const buckets = golden.cost_buckets_bdt as Record<string, number>;
    const sum = donutSlices.value.reduce((a, s) => a + s.amount, 0);
    near(sum, golden.profit_matrix.total_cost_bdt as number);
    for (const slice of donutSlices.value) {
      const exp = buckets[slice.key];
      if (exp != null) near(slice.amount, exp);
    }
    const profitStep = bridgeSteps.value.find((s) => s.key === 'profit');
    expect(profitStep).toBeDefined();
    near(profitStep?.amount ?? 0, golden.profit_matrix.profit_loss_bdt as number);
  });

  test('realized gross profit on sold units (higher than batch profit by loss)', () => {
    const { realizedGrossProfit } = useShipmentReportView(ref(payload));
    near(realizedGrossProfit.value, golden.pnl.realized_gross_profit as number);
    near(
      realizedGrossProfit.value - (golden.profit_matrix.profit_loss_bdt as number),
      golden.profit_matrix.receive_loss_bdt as number,
    );
  });
});
/**
 * Golden fixtures: SQL compute_thrift_landed_unit_cost ≡ TS computeThriftUnitCosts.
 * SQL side is mirrored from 20270802000036_thrift_money_path_guards.sql
 * (qty-stable SOLD qty=0). If SQL migrations change the formula, update the mirror + fixtures together.
 */
import { describe, test, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  computeShipmentUnitCount,
  costingQuantity,
  computeThriftUnitCosts,
  type ThriftSettingsCostInput,
  type ThriftShipmentCostInput,
  type ThriftStockCostInput,
  type ThriftStockPricingInput,
} from './computeThriftUnitCosts';
import { ceilThriftRetailPrice } from './ceilThriftRetailPrice';

const __dirname = dirname(fileURLToPath(import.meta.url));
const fixturePath = resolve(
  __dirname,
  '../../../../../../doc/v2/thrift/stock/fixtures/compute_thrift_landed_unit_cost.golden.json',
);

interface GoldenExpect {
  landed_unit_cost: number;
  uses_weight_based_cargo: boolean;
  cargo_share_per_unit: number;
  suggested_sell_unit_price: number;
}

interface GoldenCase {
  id: string;
  description: string;
  settings: ThriftSettingsCostInput;
  shipment: ThriftShipmentCostInput;
  stocks: (ThriftStockCostInput & { id: number })[];
  pricing_by_stock_id: Record<string, ThriftStockPricingInput>;
  expect_by_stock_id: Record<string, GoldenExpect>;
}

interface GoldenFixtureFile {
  cases: GoldenCase[];
}

/** Pure mirror of public.compute_thrift_landed_unit_cost (landed cost only). */
function computeThriftLandedUnitCostSqlMirror(
  stock: ThriftStockCostInput,
  shipment: ThriftShipmentCostInput,
  settings: ThriftSettingsCostInput,
  allStocks: ThriftStockCostInput[],
): number {
  const v_costing_qty = costingQuantity(stock);
  const v_u = Math.max(
    allStocks.reduce((acc, s) => acc + costingQuantity(s), 0),
    1,
  );

  const v_total_weight_kg = allStocks.reduce((acc, s) => {
    const grams = (s.product_weight ?? 0) + (s.extra_weight ?? 0);
    return acc + (grams / 1000) * costingQuantity(s);
  }, 0);

  const v_line_weight_kg =
    ((stock.product_weight ?? 0) + (stock.extra_weight ?? 0)) / 1000 * v_costing_qty;

  const v_product_unit_cost =
    ((stock.origin_unit_price ?? 0) + (stock.extra_origin_unit_price ?? 0)) *
    (shipment.product_conversion_rate ?? 1);

  const v_shipment_cargo_cost =
    (shipment.total_cargo_weight_kg ?? 0) *
    (shipment.cargo_rate ?? 0) *
    (shipment.cargo_conversion_rate ?? 0);

  const v_shipment_ops_cost =
    (settings.hand_tag_unit_cost ?? 0) * v_u +
    (settings.sticker_unit_cost ?? 0) * v_u +
    (shipment.labor_total_cost ?? 0) +
    (shipment.transportation_total_cost ?? 0) +
    (shipment.washing_total_cost ?? 0);

  let v_cargo_share_per_unit: number;
  if (v_total_weight_kg > 0 && v_costing_qty > 0) {
    v_cargo_share_per_unit =
      ((v_line_weight_kg / v_total_weight_kg) * v_shipment_cargo_cost) / v_costing_qty;
  } else {
    v_cargo_share_per_unit = v_shipment_cargo_cost / v_u;
  }

  const v_ops_share_per_unit = v_shipment_ops_cost / v_u;

  return (
    v_product_unit_cost +
    v_cargo_share_per_unit +
    v_ops_share_per_unit +
    (stock.additional_charges_cost ?? 0)
  );
}

const fixture = JSON.parse(readFileSync(fixturePath, 'utf8')) as GoldenFixtureFile;

describe('Thrift costing golden fixtures (SQL ≡ TS)', () => {
  for (const c of fixture.cases) {
    test(`${c.id}: ${c.description}`, () => {
      const U = computeShipmentUnitCount(c.stocks);

      for (const stock of c.stocks) {
        const expected = c.expect_by_stock_id[String(stock.id)];
        expect(expected, `missing expect for stock ${stock.id}`).toBeDefined();

        const pricing = c.pricing_by_stock_id[String(stock.id)];
        const ts = computeThriftUnitCosts(stock, c.shipment, c.settings, U, pricing, c.stocks);
        const sqlLanded = computeThriftLandedUnitCostSqlMirror(
          stock,
          c.shipment,
          c.settings,
          c.stocks,
        );

        expect(sqlLanded).toBeCloseTo(expected!.landed_unit_cost, 10);
        expect(ts.landed_unit_cost).toBeCloseTo(expected!.landed_unit_cost, 10);
        expect(ts.landed_unit_cost).toBeCloseTo(sqlLanded, 10);

        expect(ts.uses_weight_based_cargo).toBe(expected!.uses_weight_based_cargo);
        expect(ts.cargo_share_per_unit).toBeCloseTo(expected!.cargo_share_per_unit, 10);
        expect(ts.suggested_sell_unit_price).toBe(expected!.suggested_sell_unit_price);

        // Markup ceil is UI-side; SQL RPC returns landed only — still pin suggested from engine.
        const rate =
          pricing?.markup_rate_override != null
            ? pricing.markup_rate_override
            : (c.shipment.default_markup_rate ?? 0);
        expect(ts.suggested_sell_unit_price).toBe(
          ceilThriftRetailPrice(ts.landed_unit_cost * (1 + rate)),
        );
      }
    });
  }
});

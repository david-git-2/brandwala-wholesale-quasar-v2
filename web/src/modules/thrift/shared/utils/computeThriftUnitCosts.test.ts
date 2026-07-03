import { describe, test, expect } from 'vitest';
import {
  computeShipmentUnitCount,
  computeShipmentCargoCost,
  computeShipmentOpsCost,
  computeCargoSharePerUnit,
  computeThriftUnitCosts,
  computeThriftUnitCostsForShipment,
  buildThriftCostBreakdownByStockId,
} from './computeThriftUnitCosts';
import { ceilThriftRetailPrice } from './ceilThriftRetailPrice';

describe('Thrift P2 Cost Engine', () => {
  const mockShipment = {
    product_conversion_rate: 1.2,
    cargo_conversion_rate: 1.5,
    cargo_rate: 4.0,
    total_cargo_weight_kg: 50.0,
    labor_total_cost: 200.0,
    transportation_total_cost: 100.0,
    default_markup_rate: 0.5, // 50% markup
  };

  const mockSettings = {
    hand_tag_unit_cost: 2.0,
    sticker_unit_cost: 0.5,
  };

  test('computeShipmentUnitCount returns at least 1', () => {
    expect(computeShipmentUnitCount([])).toBe(1);
    expect(computeShipmentUnitCount([{ quantity: 0 }])).toBe(1);
    expect(computeShipmentUnitCount([{ quantity: 10 }, { quantity: 15 }])).toBe(25);
  });

  test('computeShipmentCargoCost computes cargo total weight * rate * conversion_rate', () => {
    // 50.0 * 4.0 * 1.5 = 300.0
    expect(computeShipmentCargoCost(mockShipment)).toBe(300.0);
  });

  test('computeShipmentOpsCost computes tags/stickers ops total', () => {
    // U = 100
    // (2.0 * 100) + (0.5 * 100) + 200 + 100 = 200 + 50 + 200 + 100 = 550
    expect(computeShipmentOpsCost(mockShipment, mockSettings, 100)).toBe(550.0);
  });

  test('computeThriftUnitCosts returns landed cost and suggested price for single stock item', () => {
    const stock = {
      id: 1,
      quantity: 10,
      origin_unit_price: 100.0,
      extra_origin_unit_price: 20.0,
      additional_charges_cost: 15.0,
    };

    const U = 50; // Total shipment units

    // product_unit_cost = (100 + 20) * 1.2 = 144
    // cargo_share_per_unit = 300 / 50 = 6
    // shipment_ops_cost = (2.0 * 50) + (0.5 * 50) + 200 + 100 = 100 + 25 + 200 + 100 = 425
    // ops_share_per_unit = 425 / 50 = 8.5
    // landed_unit_cost = 144 + 6 + 8.5 + 15 = 173.5
    // suggested_sell_unit_price = 173.5 * 1.5 = 260.25

    const result = computeThriftUnitCosts(stock, mockShipment, mockSettings, U, undefined, [stock]);

    expect(result.product_unit_cost).toBe(144.0);
    expect(result.cargo_share_per_unit).toBe(6.0);
    expect(result.ops_share_per_unit).toBe(8.5);
    expect(result.landed_unit_cost).toBe(173.5);
    expect(result.suggested_sell_unit_price).toBe(290.0); // rounded from 260.25
  });

  test('manual listed price overrides suggested price', () => {
    const stock = {
      quantity: 5,
      origin_unit_price: 50.0,
    };
    const U = 10;

    const pricingManual = {
      listed_unit_price: 150.0,
      is_listed_price_manual: true,
    };

    const pricingAuto = {
      listed_unit_price: 150.0,
      is_listed_price_manual: false,
    };

    const resManual = computeThriftUnitCosts(stock, mockShipment, mockSettings, U, pricingManual);
    expect(resManual.display_listed_unit_price).toBe(150.0);

    const resAuto = computeThriftUnitCosts(stock, mockShipment, mockSettings, U, pricingAuto);
    expect(resAuto.display_listed_unit_price).toBe(resAuto.suggested_sell_unit_price);
  });

  test('null/undefined coalescing treats null as 0', () => {
    const stock = {
      quantity: 1,
      origin_unit_price: null,
      extra_origin_unit_price: null,
      additional_charges_cost: null,
    };
    const shipmentNulls = {
      product_conversion_rate: null,
      cargo_conversion_rate: null,
      cargo_rate: null,
      total_cargo_weight_kg: null,
      labor_total_cost: null,
      transportation_total_cost: null,
      default_markup_rate: null,
    };
    const settingsNulls = {
      hand_tag_unit_cost: null,
      sticker_unit_cost: null,
    };

    const result = computeThriftUnitCosts(stock, shipmentNulls, settingsNulls, 1);
    expect(result.product_unit_cost).toBe(0);
    expect(result.landed_unit_cost).toBe(0);
    expect(result.suggested_sell_unit_price).toBe(50); // min price for <= 0 is 50
  });

  test('computeCargoSharePerUnit allocates cargo by weight when weights are set', () => {
    const stocks = [
      { id: 1, quantity: 1, product_weight: 500, origin_unit_price: 10 },
      { id: 2, quantity: 1, product_weight: 1500, origin_unit_price: 20 },
    ];
    const U = 2;
    const cargoTotal = computeShipmentCargoCost(mockShipment); // 300

    const lightShare = computeCargoSharePerUnit(stocks[0]!, mockShipment, stocks, U);
    const heavyShare = computeCargoSharePerUnit(stocks[1]!, mockShipment, stocks, U);

    expect(lightShare).toBe(75);
    expect(heavyShare).toBe(225);
    expect(lightShare + heavyShare).toBe(cargoTotal);
  });

  test('item markup_rate_override beats shipment default', () => {
    const stock = {
      quantity: 1,
      origin_unit_price: 100.0,
    };
    const pricing = {
      listed_unit_price: 0,
      is_listed_price_manual: false,
      markup_rate_override: 0.8,
    };

    const result = computeThriftUnitCosts(stock, mockShipment, mockSettings, 1, pricing);
    expect(result.markup_source).toBe('item_override');
    expect(result.applied_markup_rate).toBe(0.8);
    expect(result.suggested_sell_unit_price).toBe(ceilThriftRetailPrice(result.landed_unit_cost * 1.8));
  });

  test('effective markup pct reflects manual listed price', () => {
    const stock = {
      quantity: 1,
      origin_unit_price: 100.0,
    };
    const pricing = {
      listed_unit_price: 300.0,
      is_listed_price_manual: true,
    };

    const result = computeThriftUnitCosts(stock, mockShipment, mockSettings, 1, pricing);
    expect(result.display_listed_unit_price).toBe(300.0);
    expect(result.effective_markup_pct).not.toBeNull();
    expect(result.suggested_sell_unit_price).toBe(ceilThriftRetailPrice(result.landed_unit_cost * 1.5));
  });

  test('computeThriftUnitCostsForShipment batches calculation correctly', () => {
    const stocks = [
      { id: 101, quantity: 20, origin_unit_price: 10 },
      { id: 102, quantity: 30, origin_unit_price: 20 },
    ];
    // Total U = 50

    const results = computeThriftUnitCostsForShipment(stocks, mockShipment, mockSettings);
    expect(Object.keys(results).length).toBe(2);
    expect(results[101]).toBeDefined();
    expect(results[102]).toBeDefined();
    expect(results[101]!.shipment_unit_count).toBe(50);
  });

  test('buildThriftCostBreakdownByStockId groups and builds breakdowns', () => {
    const stocks = [
      { id: 101, shipment_id: 1, quantity: 20, origin_unit_price: 10 },
      { id: 102, shipment_id: 1, quantity: 30, origin_unit_price: 20 },
      { id: 103, shipment_id: 2, quantity: 10, origin_unit_price: 15 },
    ];
    const shipmentMap = new Map([
      [1, mockShipment],
      [2, { ...mockShipment, labor_total_cost: 0, transportation_total_cost: 0 }],
    ]);

    const results = buildThriftCostBreakdownByStockId(stocks, shipmentMap, mockSettings);
    expect(Object.keys(results).length).toBe(3);
    expect(results[101]!.shipment_unit_count).toBe(50); // shipment 1 total qty
    expect(results[103]!.shipment_unit_count).toBe(10); // shipment 2 total qty
  });
});


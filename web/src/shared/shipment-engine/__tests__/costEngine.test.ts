import { describe, test, expect } from 'vitest';
import {
  calculateLineLandedCostBdt,
  calculateTransactionRate,
  getCalculatedTransactionRate,
  calculateShipmentCostSummary,
  type CostingLineItemInput,
} from '../costEngine';

describe('shipment-engine costEngine', () => {
  const sampleInternationalShipment = {
    type: 'international' as const,
    product_conversion_rate: 124.5,
    cargo_conversion_rate: 165.2,
    cargo_rate: 6.5,
    received_weight: 15.0,
    transaction_rate: null,
  };

  const sampleDomesticShipment = {
    type: 'local' as const,
    product_conversion_rate: 1.0,
    cargo_conversion_rate: 1.0,
    cargo_rate: 0.0,
    received_weight: null,
    transaction_rate: null,
  };

  const item1: CostingLineItemInput = {
    purchase_price: 10.0,
    product_weight: 800,
    package_weight: 200,
    ordered_quantity: 5,
  };

  const item2: CostingLineItemInput = {
    purchase_price: 20.0,
    product_weight: 1500,
    package_weight: 500,
    ordered_quantity: 10,
  };

  const sampleItems = [item1, item2];

  test('calculateTransactionRate uses cargo invoice weight when received_weight is set', () => {
    const rate = calculateTransactionRate(sampleInternationalShipment, sampleItems);
    expect(rate).toBe(135.92);
  });

  test('calculateTransactionRate returns null for domestic shipment', () => {
    const rate = calculateTransactionRate(sampleDomesticShipment, sampleItems);
    expect(rate).toBeNull();
  });

  test('getCalculatedTransactionRate works identical to calculateTransactionRate', () => {
    const rate1 = calculateTransactionRate(sampleInternationalShipment, sampleItems);
    const rate2 = getCalculatedTransactionRate(sampleInternationalShipment, sampleItems);
    expect(rate1).toEqual(rate2);
  });

  test('calculateLineLandedCostBdt allocates cargo by line weight share when invoice weight differs', () => {
    const cost = calculateLineLandedCostBdt(item1, sampleInternationalShipment, sampleItems);
    expect(cost).toBeCloseTo(1889.28, 1);

    const costWithFallback = calculateLineLandedCostBdt(item1, sampleInternationalShipment);
    expect(costWithFallback).toBeCloseTo(2390.025, 2);
  });

  test('lineLandedCostTotal matches totalCost when invoice weight differs from packaging', () => {
    const summary = calculateShipmentCostSummary(sampleInternationalShipment, sampleItems);
    expect(summary.lineLandedCostTotal).toBeCloseTo(summary.totalCost, 2);
  });

  test('calculateShipmentCostSummary uses received_weight for cargo costing when set', () => {
    const summary = calculateShipmentCostSummary(sampleInternationalShipment, sampleItems);

    expect(summary.quantity).toBe(15);
    expect(summary.packagingWeightKg).toBe(25.0);
    expect(summary.cargoWeightKg).toBe(15.0);

    expect(summary.goodsPurchase).toBe(250.0);
    expect(summary.cargoPurchase).toBe(97.5);
    expect(summary.totalPurchase).toBe(347.5);

    expect(summary.goodsCost).toBe(31125.0);
    expect(summary.cargoCost).toBeCloseTo(16107.0, 0);
    expect(summary.totalCost).toBeCloseTo(47232.0, 0);

    expect(summary.transactionRate).toBe(135.92);
    expect(summary.lineLandedCostTotal).toBeCloseTo(summary.totalCost, 2);
  });

  test('calculateShipmentCostSummary falls back to packaging weight when received_weight is null', () => {
    const shipmentNoInvoice = { ...sampleInternationalShipment, received_weight: null };
    const summary = calculateShipmentCostSummary(shipmentNoInvoice, sampleItems);

    expect(summary.packagingWeightKg).toBe(25.0);
    expect(summary.cargoWeightKg).toBe(25.0);
    expect(summary.cargoPurchase).toBe(162.5);
    expect(summary.transactionRate).toBe(140.53);
    expect(summary.lineLandedCostTotal).toBeCloseTo(summary.totalCost, 2);
  });

  test('after weight balance adjustment, estimated weight matches actual', () => {
    const adjustedItem1: CostingLineItemInput = {
      ...item1,
      package_weight: 1200,
    };
    const adjustedItem2: CostingLineItemInput = {
      ...item2,
      package_weight: 500,
    };

    const adjustedShipment = {
      ...sampleInternationalShipment,
      received_weight: 30.0,
    };

    const summary = calculateShipmentCostSummary(adjustedShipment, [adjustedItem1, adjustedItem2]);
    expect(summary.packagingWeightKg).toBe(30.0);
    expect(summary.cargoWeightKg).toBe(30.0);
    expect(summary.cargoWeightKg).toEqual(adjustedShipment.received_weight);
    expect(summary.lineLandedCostTotal).toBeCloseTo(summary.totalCost, 2);
  });

  test('calculateShipmentCostSummary handles domestic shipment correctly', () => {
    const summary = calculateShipmentCostSummary(sampleDomesticShipment, sampleItems);

    expect(summary.quantity).toBe(15);
    expect(summary.goodsPurchase).toBe(250.0);
    expect(summary.cargoPurchase).toBe(0.0);
    expect(summary.totalPurchase).toBe(250.0);
    expect(summary.goodsCost).toBe(250.0);
    expect(summary.cargoCost).toBe(0.0);
    expect(summary.totalCost).toBe(250.0);
    expect(summary.transactionRate).toBeNull();
    expect(summary.lineLandedCostTotal).toBe(250.0);
  });
});

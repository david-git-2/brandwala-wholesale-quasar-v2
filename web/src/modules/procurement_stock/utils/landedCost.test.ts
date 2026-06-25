import { describe, test, expect } from 'vitest'
import {
  calculateLineLandedCostBdt,
  calculateTransactionRate,
  getCalculatedTransactionRate,
  calculateShipmentCostSummary,
  type CostingLineItemInput,
} from './landedCost'

describe('Landed Cost Utility', () => {
  const sampleInternationalShipment = {
    type: 'international' as const,
    product_conversion_rate: 124.5,
    cargo_conversion_rate: 165.2,
    cargo_rate: 6.5,
    received_weight: 15.0, // Should be ignored in favor of packaging weight (25.0)
    transaction_rate: null,
  }

  const sampleDomesticShipment = {
    type: 'domestic' as const,
    product_conversion_rate: 1.0,
    cargo_conversion_rate: 1.0,
    cargo_rate: 0.0,
    received_weight: null,
    transaction_rate: null,
  }

  const item1: CostingLineItemInput = {
    purchase_price: 10.0,
    product_weight: 800, // 0.8kg
    package_weight: 200, // 0.2kg
    ordered_quantity: 5,
  }

  const item2: CostingLineItemInput = {
    purchase_price: 20.0,
    product_weight: 1500, // 1.5kg
    package_weight: 500,  // 0.5kg
    ordered_quantity: 10,
  }

  const sampleItems = [item1, item2]

  test('calculateTransactionRate returns correct blended rate based on estimated packaging weight', () => {
    // goods_purchase = (10 * 5) + (20 * 10) = 250
    // cargo_purchase = 25.0 (packaging weight) * 6.5 (cargo_rate) = 162.5
    // goods_cost = 250 * 124.5 = 31125
    // cargo_cost = 162.5 * 165.2 = 26845
    // expected blended rate = (31125 + 26845) / (250 + 162.5) = 57970 / 412.5 = 140.5333...
    const rate = calculateTransactionRate(sampleInternationalShipment, sampleItems)
    expect(rate).toBeCloseTo(140.5333, 4)
  })

  test('calculateTransactionRate returns null for domestic shipment', () => {
    const rate = calculateTransactionRate(sampleDomesticShipment, sampleItems)
    expect(rate).toBeNull()
  })

  test('getCalculatedTransactionRate works identical to calculateTransactionRate', () => {
    const rate1 = calculateTransactionRate(sampleInternationalShipment, sampleItems)
    const rate2 = getCalculatedTransactionRate(sampleInternationalShipment, sampleItems)
    expect(rate1).toEqual(rate2)
  })

  test('calculateLineLandedCostBdt uses calculated rate when items array is provided', () => {
    // Item 1 base: 10 + (1.0 kg * 6.5) = 16.5
    // Effective Rate = 140.5333...
    // Landed Cost = 16.5 * 140.5333... = 2318.8
    const cost = calculateLineLandedCostBdt(item1, sampleInternationalShipment, sampleItems)
    expect(cost).toBeCloseTo(2318.8, 1)

    // Verify it differs from using a fallback when no items array is provided
    const costWithFallback = calculateLineLandedCostBdt(item1, sampleInternationalShipment)
    expect(costWithFallback).toBeCloseTo(2390.025, 2)
  })

  test('calculateShipmentCostSummary calculates all summary values correctly using estimated weight', () => {
    const summary = calculateShipmentCostSummary(sampleInternationalShipment, sampleItems)
    
    expect(summary.quantity).toBe(15)
    expect(summary.packagingWeightKg).toBe(25.0)
    expect(summary.cargoWeightKg).toBe(25.0) // Must match packaging weight

    expect(summary.goodsPurchase).toBe(250.0)
    expect(summary.cargoPurchase).toBe(162.5)
    expect(summary.totalPurchase).toBe(412.5)

    expect(summary.goodsCost).toBe(31125.0)
    expect(summary.cargoCost).toBeCloseTo(26845.0, 2)
    expect(summary.totalCost).toBeCloseTo(57970.0, 2)

    expect(summary.transactionRate).toBeCloseTo(140.5333, 4)

    // lineLandedCostTotal = Σ(unit cost * qty)
    // Since transactionRate is used for all lines, total should match exactly base * transactionRate
    // total base = 412.5, total cost BDT = 412.5 * 140.5333... = 57970.0
    expect(summary.lineLandedCostTotal).toBeCloseTo(57970.0, 2)
  })

  test('after weight balance adjustment, estimated weight matches actual', () => {
    // Simulate weight balance being applied:
    // Actual boxes weight = 30.0 kg
    // Adjust package weight on item 1 from 200g to 1200g (adds 1.0kg * 5 = 5.0kg)
    // Adjust package weight on item 2 from 500g to 0g (dummy change, or adjust item2 to add remaining weight)
    // Let's just adjust items to match actual weight of 30.0 kg:
    const adjustedItem1: CostingLineItemInput = {
      ...item1,
      package_weight: 1200, // gross: 800 + 1200 = 2000g * 5 = 10kg
    }
    const adjustedItem2: CostingLineItemInput = {
      ...item2,
      package_weight: 500, // gross: 1500 + 500 = 2000g * 10 = 20kg
    }
    // Total adjusted packaging weight = 10 + 20 = 30.0 kg
    
    const adjustedShipment = {
      ...sampleInternationalShipment,
      received_weight: 30.0, // actual boxes weight matches
    }
    
    const summary = calculateShipmentCostSummary(adjustedShipment, [adjustedItem1, adjustedItem2])
    expect(summary.packagingWeightKg).toBe(30.0)
    expect(summary.cargoWeightKg).toBe(30.0)
    expect(summary.cargoWeightKg).toEqual(adjustedShipment.received_weight)
  })

  test('calculateShipmentCostSummary handles domestic shipment correctly', () => {
    const summary = calculateShipmentCostSummary(sampleDomesticShipment, sampleItems)

    expect(summary.quantity).toBe(15)
    expect(summary.goodsPurchase).toBe(250.0)
    expect(summary.cargoPurchase).toBe(0.0)
    expect(summary.totalPurchase).toBe(250.0)
    expect(summary.goodsCost).toBe(250.0)
    expect(summary.cargoCost).toBe(0.0)
    expect(summary.totalCost).toBe(250.0)
    expect(summary.transactionRate).toBeNull()
    expect(summary.lineLandedCostTotal).toBe(250.0)
  })
})

import { describe, test, expect } from 'vitest'
import {
  calculateEstimatedWeightKg,
  calculateActualWeightKg,
  computePackageWeightAdjustments,
} from './weightBalance'

describe('Weight Balance Utility', () => {
  const sampleItems = [
    { id: 1, name: 'Item A', product_weight: 100, package_weight: 10, ordered_quantity: 10 }, // Gross: 1100g
    { id: 2, name: 'Item B', product_weight: 200, package_weight: 20, ordered_quantity: 5 },  // Gross: 1100g
  ]

  test('calculateEstimatedWeightKg correctly calculates weight', () => {
    const est = calculateEstimatedWeightKg(sampleItems)
    expect(est).toBe(2.2) // (110 * 10 + 220 * 5) / 1000 = (1100 + 1100) / 1000 = 2.2 kg
  })

  test('calculateActualWeightKg correctly sums boxes', () => {
    const boxes = [{ weight_kg: 1.5 }, { weight_kg: 2.5 }]
    const actual = calculateActualWeightKg(boxes)
    expect(actual).toBe(4.0)
  })

  test('computePackageWeightAdjustments distributes delta proportionally', () => {
    // Est: 2.2 kg, Act: 3.2 kg. Delta: 1.0 kg (1000g)
    // Both lines have gross weight of 1100g. So share is 50% each.
    // Line 1 gets 500g delta / 10 qty = 50g per unit increase. New package weight: 10 + 50 = 60g.
    // Line 2 gets 500g delta / 5 qty = 100g per unit increase. New package weight: 20 + 100 = 120g.
    const result = computePackageWeightAdjustments(sampleItems, 3.2)
    expect(result).toHaveLength(2)
    expect(result[0]?.newPackageWeight).toBe(60)
    expect(result[1]?.newPackageWeight).toBe(120)
  })

  test('computePackageWeightAdjustments throws error if adjustment makes package weight negative', () => {
    // Est: 2.2 kg, Act: 1.0 kg. Delta: -1.2 kg (-1200g)
    // Line 1 gets -600g / 10 qty = -60g per unit change.
    // New package weight for Line 1: 10 - 60 = -50g (negative!)
    expect(() => computePackageWeightAdjustments(sampleItems, 1.0)).toThrow(
      /would go below 0 after adjustment/,
    )
  })

  test('computePackageWeightAdjustments guards against zero estimated weight basis', () => {
    const zeroBasis = [
      { id: 1, name: 'Zero Item', product_weight: 0, package_weight: 0, ordered_quantity: 10 },
    ]
    expect(() => computePackageWeightAdjustments(zeroBasis, 2.0)).toThrow(
      'no weight basis to distribute',
    )
  })

  test('computePackageWeightAdjustments distributes rounding remainder to largest gross weight item', () => {
    // Items with unequal gross weights
    const unequalItems = [
      { id: 1, name: 'Item Large', product_weight: 200, package_weight: 20, ordered_quantity: 10 }, // 2200g
      { id: 2, name: 'Item Small', product_weight: 100, package_weight: 10, ordered_quantity: 5 },  // 550g
    ]
    // Total est: 2.75 kg (2750g)
    // Actual: 3.0 kg (3000g) -> Delta: 250g
    // Item 1 share: 2200 / 2750 = 0.8 -> 200g -> per unit: 200 / 10 = 20g. New weight: 40g
    // Item 2 share: 550 / 2750 = 0.2 -> 50g -> per unit: 50 / 5 = 10g. New weight: 20g
    const result = computePackageWeightAdjustments(unequalItems, 3.0)
    expect(result[0]?.newPackageWeight).toBe(40)
    expect(result[1]?.newPackageWeight).toBe(20)
  })
})

import assert from 'assert'
import {
  calculateEstimatedWeightKg,
  calculateActualWeightKg,
  computePackageWeightAdjustments,
} from '../src/modules/procurement_stock/utils/weightBalance.ts'

console.log('Running weightBalance.ts tests...')

// Test case 1: Basic calculation
const items = [
  { id: 1, name: 'Item A', product_weight: 100, package_weight: 10, ordered_quantity: 10 }, // 1100g
  { id: 2, name: 'Item B', product_weight: 200, package_weight: 20, ordered_quantity: 5 },  // 1100g
]

assert.strictEqual(calculateEstimatedWeightKg(items), 2.2)
assert.strictEqual(calculateActualWeightKg([{ weight_kg: 1.5 }, { weight_kg: 2.5 }]), 4.0)

const res1 = computePackageWeightAdjustments(items, 3.2) // Est: 2.2kg, Act: 3.2kg (Delta: 1000g)
assert.strictEqual(res1[0].newPackageWeight, 60)
assert.strictEqual(res1[1].newPackageWeight, 120)

// Test case 2: Error when negative package weight
try {
  computePackageWeightAdjustments(items, 1.0)
  assert.fail('Should have failed for negative weight')
} catch (e) {
  assert.match(e.message, /would go below 0 after adjustment/)
}

// Test case 3: Zero estimated weight basis
const zeroBasis = [
  { id: 1, name: 'Zero Item', product_weight: 0, package_weight: 0, ordered_quantity: 10 },
]
try {
  computePackageWeightAdjustments(zeroBasis, 2.0)
  assert.fail('Should have failed for zero basis')
} catch (e) {
  assert.match(e.message, /no weight basis to distribute/)
}

console.log('All tests passed successfully!')

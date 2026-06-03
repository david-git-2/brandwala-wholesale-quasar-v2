import type { ShipmentItem } from '../types'

export const getSplitQuantities = (item: ShipmentItem) => {
  if (!item.receiving_splits) {
    return {
      standard: item.quantity,
      box_damage: 0,
      expired: 0,
      boxless: 0,
      stolen: 0,
    }
  }

  const splits = item.receiving_splits
  return {
    standard: splits.standard?.qty ?? 0,
    box_damage: splits.box_damage?.qty ?? 0,
    expired: splits.expired?.qty ?? 0,
    boxless: splits.boxless?.qty ?? 0,
    stolen: splits.stolen?.qty ?? 0,
  }
}

export const getReceivedQty = (item: ShipmentItem): number => {
  const q = getSplitQuantities(item)
  return q.standard + q.box_damage + q.boxless
}

export const getDamagedQty = (item: ShipmentItem): number => {
  const q = getSplitQuantities(item)
  return q.expired
}

export const getStolenQty = (item: ShipmentItem): number => {
  const q = getSplitQuantities(item)
  return q.stolen
}

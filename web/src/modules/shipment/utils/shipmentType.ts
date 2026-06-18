import type { ShipmentType } from '../types'

export function normalizeShipmentType(value?: string | null): ShipmentType {
  return value === 'local' ? 'local' : 'international'
}

export function isInternationalShipment(
  shipment?: { shipment_type?: string | null } | null,
): boolean {
  return normalizeShipmentType(shipment?.shipment_type) === 'international'
}

export function isLocalShipment(shipment?: { shipment_type?: string | null } | null): boolean {
  return normalizeShipmentType(shipment?.shipment_type) === 'local'
}

export function shipmentTypeFromIsGbp(isGbp: boolean): ShipmentType {
  return isGbp ? 'international' : 'local'
}

export function isGbpFromShipmentType(shipmentType?: string | null): boolean {
  return normalizeShipmentType(shipmentType) === 'international'
}

import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';

export type ShipmentItemIdentity = {
  product_id?: number | null;
  barcode?: string | null;
  product_code?: string | null;
  section_id?: number | null;
};

const norm = (value: string | null | undefined) => {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
};

export const shipmentItemIdentityMatches = (
  existing: GlobalShipmentItem,
  candidate: ShipmentItemIdentity,
): boolean => {
  if (candidate.product_id != null && existing.product_id === candidate.product_id) {
    return true;
  }
  const barcode = norm(candidate.barcode);
  if (barcode && norm(existing.barcode) === barcode) return true;
  const productCode = norm(candidate.product_code);
  if (productCode && norm(existing.product_code) === productCode) return true;
  return false;
};

/** Same product/code may repeat on another section; not within the target section. */
export const shipmentItemExistsInSection = (
  items: GlobalShipmentItem[],
  candidate: ShipmentItemIdentity,
  targetSectionId: number | null,
  shipmentHasSections: boolean,
): boolean => {
  return items.some((item) => {
    if (shipmentHasSections && item.section_id !== targetSectionId) return false;
    return shipmentItemIdentityMatches(item, candidate);
  });
};

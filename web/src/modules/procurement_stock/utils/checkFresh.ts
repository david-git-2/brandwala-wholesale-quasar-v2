import type { BatchCodeItem } from '../repositories/batchCodeRepository';
import {
  matchBatchItemsForShipmentLine,
  normalizeBatchMatchKey,
  type ShipmentLineCodes,
} from './batchCodeShipmentMatch';

export type CatalogBrandHint = {
  id: number;
  brand: string | null;
  barcode: string | null;
  product_code: string | null;
};

export const CHECKFRESH_HOME = 'https://www.checkfresh.com/';

export const checkFreshBrandSlug = (brand: string | null | undefined): string =>
  (brand ?? '')
    .trim()
    .toLowerCase()
    .replace(/['’]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

export const checkFreshPageUrl = (brand?: string | null): string => {
  const slug = checkFreshBrandSlug(brand);
  if (!slug) return CHECKFRESH_HOME;
  return `https://www.checkfresh.com/${slug}.html`;
};

export const openCheckFreshTab = (brand?: string | null): void => {
  window.open(checkFreshPageUrl(brand), '_blank', 'noopener,noreferrer');
};

const hintBrand = (hint: CatalogBrandHint | undefined): string | null => {
  const brand = hint?.brand?.trim() ?? '';
  return brand.length > 0 ? brand : null;
};

export const resolveCheckFreshBrand = (
  item: Pick<BatchCodeItem, 'barcode' | 'product_code'>,
  shipmentLines: Array<ShipmentLineCodes & { product_id?: number | null }>,
  hints: CatalogBrandHint[],
): string | null => {
  const matchedLine = shipmentLines.find(
    (line) => matchBatchItemsForShipmentLine(line, [item as BatchCodeItem]).length > 0,
  );
  if (matchedLine?.product_id != null) {
    const byId = hintBrand(hints.find((hint) => hint.id === matchedLine.product_id));
    if (byId) return byId;
  }

  const bar = normalizeBatchMatchKey(item.barcode);
  const code = normalizeBatchMatchKey(item.product_code);
  for (const hint of hints) {
    if (bar && normalizeBatchMatchKey(hint.barcode) === bar) {
      const brand = hintBrand(hint);
      if (brand) return brand;
    }
    if (code && normalizeBatchMatchKey(hint.product_code) === code) {
      const brand = hintBrand(hint);
      if (brand) return brand;
    }
  }
  return null;
};

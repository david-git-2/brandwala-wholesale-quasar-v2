import type { ProcurementDemandItem } from '../repositories/procurementDemandRepository';

export type DemandBuyBulkPasteRow = {
  barcode: string;
  product_code: string;
  quantity: string;
  unit_price: string;
};

export const normalizeProductKey = (value: string | null | undefined): string =>
  (value || '').trim().replace(/^['`]+/, '').replace(/\s+/g, '').toLowerCase();

export const parsePasteQuantity = (raw: string): number | null => {
  if (!raw.trim()) return null;
  const val = Number(raw.replace(/[^0-9.-]/g, ''));
  if (Number.isNaN(val)) return null;
  return Math.max(1, Math.round(val));
};

export const parsePasteUnitPrice = (raw: string): number | null => {
  if (!raw.trim()) return null;
  const val = Number(raw.replace(/[^0-9.-]/g, ''));
  if (Number.isNaN(val)) return null;
  return Math.max(0, Number(val.toFixed(2)));
};

export const demandItemProductKeys = (item: ProcurementDemandItem) => ({
  barcode: normalizeProductKey(item.barcode ?? ''),
  product_code: normalizeProductKey(item.product_code ?? ''),
});

export const findDemandItemsByKeys = (
  items: ProcurementDemandItem[],
  barcode: string,
  productCode: string,
): ProcurementDemandItem[] =>
  items.filter((item) => {
    const codes = demandItemProductKeys(item);
    if (barcode && productCode) {
      return codes.barcode === barcode && codes.product_code === productCode;
    }
    if (barcode) return codes.barcode === barcode;
    if (productCode) return codes.product_code === productCode;
    return false;
  });

export const findUniqueDemandItemByKeys = (
  items: ProcurementDemandItem[],
  barcode: string,
  productCode: string,
): ProcurementDemandItem | null => {
  const hits = findDemandItemsByKeys(items, barcode, productCode);
  return hits.length === 1 ? hits[0]! : null;
};

export const bulkPasteRowHasValues = (row: DemandBuyBulkPasteRow): boolean =>
  parsePasteQuantity(row.quantity) !== null || parsePasteUnitPrice(row.unit_price) !== null;
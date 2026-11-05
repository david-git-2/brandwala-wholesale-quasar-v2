import type {
  PreorderVendorPlacement,
  ProcurementDemandItem,
} from '../repositories/procurementDemandRepository';

export type VendorPlacementDraft = {
  vendorCode: string;
  quantity: number | null;
};

export type DemandBuyLineDraft = {
  placements: VendorPlacementDraft[];
};

export const itemDraftKey = (item: ProcurementDemandItem): string =>
  `${item.source_type}-${item.source_id}`;

export const placementsFromItem = (item: ProcurementDemandItem): VendorPlacementDraft[] => {
  const fromApi = item.vendor_placements ?? [];
  if (fromApi.length > 0) {
    return fromApi.map((p) => ({
      vendorCode: p.vendor_code?.trim() ?? '',
      quantity: p.quantity > 0 ? p.quantity : null,
    }));
  }
  if ((item.placed_quantity ?? 0) > 0) {
    return [{ vendorCode: item.vendor_code?.trim() ?? '', quantity: item.placed_quantity ?? null }];
  }
  return [{ vendorCode: '', quantity: null }];
};

export const normalizePlacementsForSave = (
  drafts: VendorPlacementDraft[],
): PreorderVendorPlacement[] =>
  drafts
    .map((row) => ({
      vendor_code: row.vendorCode.trim(),
      quantity: Math.max(0, Math.floor(Number(row.quantity) || 0)),
    }))
    .filter((row) => row.vendor_code.length > 0 && row.quantity > 0);

export const serializePlacements = (drafts: VendorPlacementDraft[]): string =>
  JSON.stringify(
    drafts.map((d) => ({
      vendorCode: d.vendorCode.trim(),
      quantity: d.quantity == null ? null : Math.floor(Number(d.quantity) || 0),
    })),
  );

export const sumPlacementDraftQty = (drafts: VendorPlacementDraft[]): number =>
  normalizePlacementsForSave(drafts).reduce((acc, row) => acc + row.quantity, 0);

export const validatePlacementDrafts = (
  needQty: number,
  drafts: VendorPlacementDraft[],
): string | null => {
  const rows = normalizePlacementsForSave(drafts);
  if (rows.length === 0) return null;
  for (const row of rows) {
    if (!row.vendor_code) return 'Each row needs a vendor code.';
    if (row.quantity <= 0) return 'Quantity must be greater than zero.';
  }
  const total = rows.reduce((acc, row) => acc + row.quantity, 0);
  if (total > needQty) return `Placed total (${total}) cannot exceed need (${needQty}).`;
  return null;
};

export const cloneLineDraft = (draft: DemandBuyLineDraft): DemandBuyLineDraft => ({
  placements: draft.placements.map((p) => ({ ...p })),
});

import type {
  PreorderVendorPlacement,
  ProcurementDemandItem,
} from '../repositories/procurementDemandRepository';

export type VendorPlacementDraft = {
  vendorCode: string;
  quantity: number | null;
  unitPrice: number | null;
};

export type DemandBuyLineDraft = {
  placements: VendorPlacementDraft[];
};

export const itemDraftKey = (item: ProcurementDemandItem): string =>
  `${item.source_type}-${item.source_id}`;

export const orderLineUnitPrice = (item: ProcurementDemandItem): number | null => {
  const raw = item.unit_demand_buy_price_amount ?? item.unit_sell_price_amount;
  const amount = Number(raw ?? NaN);
  return Number.isFinite(amount) ? amount : null;
};

export const defaultVendorCodeForItem = (item: ProcurementDemandItem): string =>
  item.vendor_code?.trim() ?? '';

export const coalescePlacementUnitPrice = (
  item: ProcurementDemandItem,
  placement: VendorPlacementDraft,
): number | null => placement.unitPrice ?? orderLineUnitPrice(item);

export const backfillPlacementUnitPrices = (
  item: ProcurementDemandItem,
  placements: VendorPlacementDraft[],
): void => {
  const orderPrice = orderLineUnitPrice(item);
  if (orderPrice == null) return;
  for (const pl of placements) {
    if (pl.unitPrice == null) pl.unitPrice = orderPrice;
  }
};

/** When qty is set but vendor was cleared (e.g. bulk paste), use line vendor_code (often PC). */
export const backfillPlacementVendorCodes = (
  item: ProcurementDemandItem,
  placements: VendorPlacementDraft[],
): void => {
  const fallback = defaultVendorCodeForItem(item);
  if (!fallback) return;
  for (const pl of placements) {
    const qty = Math.max(0, Math.floor(Number(pl.quantity) || 0));
    if (qty > 0 && !pl.vendorCode.trim()) pl.vendorCode = fallback;
  }
};

const draftUnitPriceFromPlacement = (
  item: ProcurementDemandItem,
  placement?: PreorderVendorPlacement,
): number | null => {
  if (placement?.unit_price != null) {
    const saved = Number(placement.unit_price);
    if (Number.isFinite(saved)) return saved;
  }
  return orderLineUnitPrice(item);
};

export const placementsFromItem = (item: ProcurementDemandItem): VendorPlacementDraft[] => {
  const fromApi = item.vendor_placements ?? [];
  if (fromApi.length > 0) {
    const mapped = fromApi.map((p) => ({
      vendorCode: p.vendor_code?.trim() ?? '',
      quantity: p.quantity > 0 ? p.quantity : null,
      unitPrice: draftUnitPriceFromPlacement(item, p),
    }));
    backfillPlacementUnitPrices(item, mapped);
    return mapped;
  }
  if ((item.placed_quantity ?? 0) > 0) {
    return [
      {
        vendorCode: item.vendor_code?.trim() ?? '',
        quantity: item.placed_quantity ?? null,
        unitPrice: orderLineUnitPrice(item),
      },
    ];
  }
  return [
    {
      vendorCode: defaultVendorCodeForItem(item),
      quantity: null,
      unitPrice: orderLineUnitPrice(item),
    },
  ];
};

export const emptyPlacementForItem = (item: ProcurementDemandItem): VendorPlacementDraft => ({
  vendorCode: defaultVendorCodeForItem(item),
  quantity: null,
  unitPrice: orderLineUnitPrice(item),
});

/** Cleared vendor row for bulk paste / bulk update when a line is not in the paste list. */
export const clearedVendorPlacementDraft = (): VendorPlacementDraft => ({
  vendorCode: '',
  quantity: 0,
  unitPrice: 0,
});

export const clearedLineDraft = (): DemandBuyLineDraft => ({
  placements: [clearedVendorPlacementDraft()],
});

export const normalizePlacementsForSave = (
  drafts: VendorPlacementDraft[],
  item?: ProcurementDemandItem,
): PreorderVendorPlacement[] =>
  drafts
    .map((row) => {
      const resolved = item ? coalescePlacementUnitPrice(item, row) : row.unitPrice;
      const vendorCode =
        row.vendorCode.trim() || (item ? defaultVendorCodeForItem(item) : '');
      return {
        vendor_code: vendorCode,
        quantity: Math.max(0, Math.floor(Number(row.quantity) || 0)),
        unit_price: Math.max(0, Number(resolved) || 0),
      };
    })
    .filter((row) => row.vendor_code.length > 0 && row.quantity > 0);

export const serializePlacements = (drafts: VendorPlacementDraft[]): string =>
  JSON.stringify(
    drafts.map((d) => ({
      vendorCode: d.vendorCode.trim(),
      quantity: d.quantity == null ? null : Math.floor(Number(d.quantity) || 0),
      unitPrice: d.unitPrice == null ? null : Number(d.unitPrice),
    })),
  );

export const placementsFromBaseline = (json: string | undefined): VendorPlacementDraft[] | null => {
  if (!json?.trim()) return null;
  try {
    const parsed = JSON.parse(json) as Array<{
      vendorCode?: string;
      quantity?: number | null;
      unitPrice?: number | null;
    }>;
    if (!Array.isArray(parsed)) return null;
    return parsed.map((d) => ({
      vendorCode: String(d.vendorCode ?? '').trim(),
      quantity: d.quantity == null ? null : Math.floor(Number(d.quantity) || 0),
      unitPrice: d.unitPrice == null ? null : Number(d.unitPrice),
    }));
  } catch {
    return null;
  }
};

export const sumPlacementDraftQty = (drafts: VendorPlacementDraft[]): number =>
  normalizePlacementsForSave(drafts).reduce((acc, row) => acc + row.quantity, 0);

export const sumVendorPlacementDrafts = (
  item: ProcurementDemandItem,
  drafts: VendorPlacementDraft[],
): { quantity: number; amount: number } => {
  let quantity = 0;
  let amount = 0;
  for (const pl of drafts) {
    const code = pl.vendorCode.trim();
    const q = Math.max(0, Math.floor(Number(pl.quantity) || 0));
    if (!code || q <= 0) continue;
    const price = coalescePlacementUnitPrice(item, pl);
    const unit = price != null && Number.isFinite(Number(price)) ? Number(price) : 0;
    quantity += q;
    amount += q * unit;
  }
  return { quantity, amount };
};

export const validatePlacementDrafts = (
  _needQty: number,
  drafts: VendorPlacementDraft[],
  item?: ProcurementDemandItem,
): string | null => {
  for (const draft of drafts) {
    const code = draft.vendorCode.trim();
    const qty = Math.max(0, Math.floor(Number(draft.quantity) || 0));
    if (!code || qty <= 0) continue;
    const price = item ? coalescePlacementUnitPrice(item, draft) : draft.unitPrice;
    if (price === null || !Number.isFinite(Number(price)) || Number(price) < 0) {
      return 'Each placed row needs a unit price of 0 or greater.';
    }
  }
  const rows = normalizePlacementsForSave(drafts, item);
  if (rows.length === 0) return null;
  for (const row of rows) {
    if (!row.vendor_code) return 'Each row needs a vendor code.';
    if (row.quantity <= 0) return 'Quantity must be greater than zero.';
  }
  return null;
};

/** Before RPC: block rows with qty but no vendor (would save as empty and look like a failed save). */
export const validatePlacementDraftsForPersist = (
  drafts: VendorPlacementDraft[],
  item?: ProcurementDemandItem,
): string | null => {
  const structural = validatePlacementDrafts(0, drafts, item);
  if (structural) return structural;

  for (const pl of drafts) {
    const code = pl.vendorCode.trim() || (item ? defaultVendorCodeForItem(item) : '');
    const qty = Math.max(0, Math.floor(Number(pl.quantity) || 0));
    const hasVendor = code.length > 0;
    const hasQty = qty > 0;
    if (hasQty && !hasVendor) {
      return 'Choose a vendor for each row that has quantity.';
    }
    if (hasVendor && !hasQty) {
      return 'Enter quantity for each vendor row.';
    }
  }
  return null;
};

export const cloneLineDraft = (draft: DemandBuyLineDraft): DemandBuyLineDraft => ({
  placements: draft.placements.map((p) => ({ ...p })),
});

export const upsertVendorPlacementDraft = (
  item: ProcurementDemandItem,
  drafts: VendorPlacementDraft[],
  vendorCode: string,
  patch: { quantity?: number; unitPrice?: number },
): VendorPlacementDraft[] => {
  const code = vendorCode.trim();
  if (!code) return drafts.map((p) => ({ ...p }));

  const next = drafts.map((p) => ({ ...p }));
  const idx = next.findIndex((p) => p.vendorCode.trim() === code);
  if (idx >= 0) {
    const row = { ...next[idx]! };
    if (patch.quantity !== undefined) row.quantity = patch.quantity;
    if (patch.unitPrice !== undefined) row.unitPrice = patch.unitPrice;
    next[idx] = row;
    return next;
  }

  next.push({
    vendorCode: code,
    quantity: patch.quantity ?? null,
    unitPrice: patch.unitPrice ?? orderLineUnitPrice(item),
  });
  return next;
};

export type VendorPlacementTotalsBucket = {
  vendorCode: string;
  quantity: number;
  amount: number;
};

export const aggregateVendorPlacementTotals = (
  items: ProcurementDemandItem[],
  resolveDraft: (item: ProcurementDemandItem) => VendorPlacementDraft[],
): {
  grand: { quantity: number; amount: number };
  byVendor: VendorPlacementTotalsBucket[];
} => {
  const byCode = new Map<string, { quantity: number; amount: number }>();
  let grandQty = 0;
  let grandAmt = 0;

  for (const item of items) {
    const placements = resolveDraft(item);
    for (const pl of placements) {
      const code = pl.vendorCode.trim();
      const q = Math.max(0, Math.floor(Number(pl.quantity) || 0));
      if (!code || q <= 0) continue;
      const price = coalescePlacementUnitPrice(item, pl);
      const unit = price != null && Number.isFinite(Number(price)) ? Number(price) : 0;
      const amt = q * unit;
      grandQty += q;
      grandAmt += amt;
      const cur = byCode.get(code) ?? { quantity: 0, amount: 0 };
      cur.quantity += q;
      cur.amount += amt;
      byCode.set(code, cur);
    }
  }

  const byVendor = [...byCode.entries()]
    .map(([vendorCode, v]) => ({ vendorCode, quantity: v.quantity, amount: v.amount }))
    .sort((a, b) => a.vendorCode.localeCompare(b.vendorCode));

  return { grand: { quantity: grandQty, amount: grandAmt }, byVendor };
};
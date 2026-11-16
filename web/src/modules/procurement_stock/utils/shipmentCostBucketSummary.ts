import {
  calculateLineCargoPurchaseShare,
  calculateLineGrossWeightKg,
  calculateLineLandedCostBdt,
  calculateLineLandedCostBreakdown,
  type CostingShipmentInput,
} from 'src/shared/shipment-engine';
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';
import { SHIPMENT_AP_COST_BUCKETS } from '../constants/shipmentApBuckets';
import type { GlobalShipmentCostBucket } from '../types/shipmentCostEntry';
import { PRODUCT_COST_BUCKET } from '../types/shipmentCostEntry';

export type CostEntryForBucketSummary = {
  cost_bucket: GlobalShipmentCostBucket;
  amount: number;
  currency_id?: number | null;
  is_capitalizable?: boolean | null;
};

export type ShipmentCostForeignLeg = {
  currency_code: string;
  amount: number;
};

export type ShipmentBucketSummaryRow = {
  bucket: GlobalShipmentCostBucket;
  foreignLegs: ShipmentCostForeignLeg[];
  /** Sum of entry amounts in the shipment purchase currency (for Buy / file display). */
  buyInPurchaseCurrency: number;
  /** Preview landed total in cost (BDT) currency for capitalizable rows. */
  bdtPreview: number;
};

export type ShipmentSectionLineMetrics = {
  itemCount: number;
  quantity: number;
  weightKg: number;
  goodsPurchase: number;
  freightPurchase: number;
  freightLanded: number;
  goodsLanded: number;
};

type CurrencyResolver = {
  codeById: (currencyId: number | null | undefined) => string;
  purchaseCurrencyId: number | null | undefined;
  costCurrencyId: number | null | undefined;
};

const round2 = (n: number) => Math.round(n * 100) / 100;

const isCostCurrency = (
  currencyId: number | null | undefined,
  resolver: CurrencyResolver,
): boolean => {
  if (resolver.costCurrencyId == null) return false;
  return currencyId === resolver.costCurrencyId;
};

const fxRateForBucketBdt = (
  bucket: GlobalShipmentCostBucket,
  preview: CostingShipmentInput,
  entryIsCostCurrency: boolean,
): number => {
  if (entryIsCostCurrency) return 1;
  if (bucket === 'material') return preview.product_conversion_rate ?? 1;
  if (bucket === 'freight') return preview.cargo_conversion_rate ?? 1;
  return preview.product_conversion_rate ?? 1;
};

function addForeignLeg(
  legs: Map<string, number>,
  currencyCode: string,
  amount: number,
) {
  if (amount <= 0) return;
  const code = currencyCode.toUpperCase();
  legs.set(code, round2((legs.get(code) ?? 0) + amount));
}

/**
 * Group cost worksheet rows by bucket with foreign legs and preview BDT.
 */
export function aggregateCostEntriesByBucket(
  entries: CostEntryForBucketSummary[],
  preview: CostingShipmentInput,
  currency: CurrencyResolver,
): ShipmentBucketSummaryRow[] {
  const byBucket = new Map<GlobalShipmentCostBucket, ShipmentBucketSummaryRow>();

  for (const bucket of SHIPMENT_AP_COST_BUCKETS) {
    byBucket.set(bucket, {
      bucket,
      foreignLegs: [],
      buyInPurchaseCurrency: 0,
      bdtPreview: 0,
    });
  }

  for (const entry of entries) {
    const amt = Number(entry.amount) || 0;
    if (amt <= 0) continue;
    const bucket = entry.cost_bucket;
    const row = byBucket.get(bucket);
    if (!row) continue;

    const currencyId = entry.currency_id ?? currency.purchaseCurrencyId ?? null;
    const code = currency.codeById(currencyId);
    const legMap = new Map<string, number>();
    for (const leg of row.foreignLegs) {
      legMap.set(leg.currency_code, leg.amount);
    }
    addForeignLeg(legMap, code, amt);
    row.foreignLegs = [...legMap.entries()]
      .map(([currency_code, amount]) => ({ currency_code, amount }))
      .sort((a, b) => a.currency_code.localeCompare(b.currency_code));

    if (currencyId === currency.purchaseCurrencyId) {
      row.buyInPurchaseCurrency = round2(row.buyInPurchaseCurrency + amt);
    }

    const capitalizable = entry.is_capitalizable !== false;
    if (capitalizable) {
      const entryIsCostCurrency = isCostCurrency(currencyId, currency);
      const rate = fxRateForBucketBdt(bucket, preview, entryIsCostCurrency);
      row.bdtPreview = round2(row.bdtPreview + amt * rate);
    }
  }

  return SHIPMENT_AP_COST_BUCKETS.map((b) => byBucket.get(b)!);
}

/** When material bucket has no entries, show line-list goods in Buy column. */
export function applyMaterialLineListFallback(
  rows: ShipmentBucketSummaryRow[],
  lineGoodsPurchase: number,
  preview: CostingShipmentInput,
  purchaseCurrencyCode?: string,
): ShipmentBucketSummaryRow[] {
  if (lineGoodsPurchase <= 0) return rows;
  return rows.map((row) => {
    if (row.bucket !== PRODUCT_COST_BUCKET) return row;
    if (row.buyInPurchaseCurrency > 0 || row.bdtPreview > 0) return row;
    const rate = preview.product_conversion_rate ?? 1;
    const buy = round2(lineGoodsPurchase);
    const code = purchaseCurrencyCode?.toUpperCase() ?? 'GBP';
    return {
      ...row,
      foreignLegs: [{ currency_code: code, amount: buy }],
      buyInPurchaseCurrency: buy,
      bdtPreview: round2(lineGoodsPurchase * rate),
    };
  });
}

export function sumBucketBuyInPurchase(rows: ShipmentBucketSummaryRow[]): number {
  return round2(rows.reduce((s, r) => s + r.buyInPurchaseCurrency, 0));
}

export function sumBucketBdtPreview(rows: ShipmentBucketSummaryRow[]): number {
  return round2(rows.reduce((s, r) => s + r.bdtPreview, 0));
}

/** Freight worksheet buy total ÷ cargo kg (purchase currency per kg). */
export function freightPerKgFromBucketSummary(
  rows: ShipmentBucketSummaryRow[],
  weightKg: number,
): number | null {
  if (!Number.isFinite(weightKg) || weightKg <= 0) return null;
  const freight = rows.find((r) => r.bucket === 'freight');
  const total = freight?.buyInPurchaseCurrency ?? 0;
  if (total <= 0) return null;
  return Math.round((total / weightKg) * 10_000) / 10_000;
}

export function aggregateSectionLines(
  matchedItems: GlobalShipmentItem[],
  forCosting: CostingShipmentInput,
  allItems: GlobalShipmentItem[],
  getUnitLandedBdt?: (item: GlobalShipmentItem, allItems: GlobalShipmentItem[]) => number,
): ShipmentSectionLineMetrics {
  let quantity = 0;
  let weightKg = 0;
  let goodsPurchase = 0;
  let freightPurchase = 0;
  let freightLanded = 0;
  let goodsLanded = 0;

  const cargoConv = forCosting.cargo_conversion_rate ?? 1;

  for (const it of matchedItems) {
    const qty = Number(it.ordered_quantity) || 0;
    quantity += qty;
    weightKg += calculateLineGrossWeightKg(it);
    goodsPurchase += (Number(it.purchase_price) || 0) * qty;

    const freightShare = calculateLineCargoPurchaseShare(it, forCosting, allItems);
    freightPurchase += freightShare;

    const breakdown = calculateLineLandedCostBreakdown(it, forCosting, allItems);
    freightLanded += breakdown.cargoSharePerUnit * qty * cargoConv;

    const unitLanded =
      getUnitLandedBdt?.(it, allItems)
      ?? calculateLineLandedCostBdt(it, forCosting, allItems);
    goodsLanded += unitLanded * qty;
  }

  return {
    itemCount: matchedItems.length,
    quantity,
    weightKg: Math.round(weightKg * 100) / 100,
    goodsPurchase: round2(goodsPurchase),
    freightPurchase: round2(freightPurchase),
    freightLanded: round2(freightLanded),
    goodsLanded: round2(goodsLanded),
  };
}
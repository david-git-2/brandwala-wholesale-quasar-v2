/**
 * Pure shipment cost preview engine.
 * No Supabase, no Pinia, no writes to `landed_cost_bdt`.
 */
import type {
  CostEntryInput,
  CostingLineItemInput,
  CostingShipmentInput,
  ShipmentCostSummary,
} from './types';

export type {
  CostEntryInput,
  CostingLineItemInput,
  CostingShipmentInput,
  ShipmentCostSummary,
} from './types';

export const calculateLineGrossWeightKg = (item: CostingLineItemInput): number => {
  return (
    (((item.product_weight || 0) + (item.package_weight || 0)) * (item.ordered_quantity || 0)) /
    1000
  );
};

export const calculatePackagingWeightKg = (items: CostingLineItemInput[]): number => {
  let weight = 0;
  for (const item of items) {
    weight += calculateLineGrossWeightKg(item);
  }
  return weight;
};

/**
 * Cargo weight for costing: cargo invoice weight when set, else packaging estimate.
 */
export const getCargoWeightKg = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number => {
  const headerKg =
    shipment.total_weight_kg ??
    shipment.received_weight ??
    null;
  if (headerKg != null && headerKg > 0) {
    return Math.round(headerKg * 100) / 100;
  }
  return calculatePackagingWeightKg(items);
};

const sumGoodsPurchase = (items: CostingLineItemInput[]): number => {
  let goodsPurchase = 0;
  for (const item of items) {
    goodsPurchase += (item.purchase_price || 0) * (item.ordered_quantity || 0);
  }
  return goodsPurchase;
};

const sumQuantity = (items: CostingLineItemInput[]): number => {
  let quantity = 0;
  for (const item of items) {
    quantity += item.ordered_quantity || 0;
  }
  return quantity;
};

export type MoneyWeightedFxLeg = { foreign: number; rate: number };

/**
 * Bucket-style FX: Σ(foreign × rate) / Σ foreign — same as total BDT ÷ total foreign.
 * Never uses arithmetic mean of rates.
 */
export const moneyWeightedBlendRate = (
  legs: MoneyWeightedFxLeg[],
  fallbackRate = 1,
): number => {
  let foreignSum = 0;
  let bdtSum = 0;
  for (const leg of legs) {
    const foreign = Number(leg.foreign) || 0;
    const rate = Number(leg.rate) || 0;
    if (foreign <= 0 || rate <= 0) continue;
    foreignSum += foreign;
    bdtSum += foreign * rate;
  }
  if (foreignSum > 0) return bdtSum / foreignSum;
  return fallbackRate > 0 ? fallbackRate : 1;
};

export const calculateLineCargoPurchaseShare = (
  item: CostingLineItemInput,
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number => {
  const qty = item.ordered_quantity || 0;
  if (qty === 0) return 0;

  const cargoPurchaseTotal = getCargoWeightKg(shipment, items) * (shipment.cargo_rate || 0);
  if (cargoPurchaseTotal <= 0) return 0;

  const packagingKg = calculatePackagingWeightKg(items);
  if (packagingKg > 0) {
    return (calculateLineGrossWeightKg(item) / packagingKg) * cargoPurchaseTotal;
  }

  const totalQty = sumQuantity(items);
  if (totalQty <= 0) return 0;
  return (qty / totalQty) * cargoPurchaseTotal;
};

export const calculateLinePurchaseBase = (
  item: CostingLineItemInput,
  shipment?: CostingShipmentInput | null,
  items?: CostingLineItemInput[],
): number => {
  if (!item) return 0;
  const purchasePrice = item.purchase_price || 0;
  const qty = item.ordered_quantity || 0;

  if (items && items.length > 0 && shipment) {
    const lineCargoPurchase = calculateLineCargoPurchaseShare(item, shipment, items);
    return purchasePrice + (qty > 0 ? lineCargoPurchase / qty : 0);
  }

  const weightKg = ((item.product_weight || 0) + (item.package_weight || 0)) / 1000;
  return purchasePrice + weightKg * (shipment?.cargo_rate || 0);
};

export const calculateRawTransactionRate = (
  shipment?: CostingShipmentInput | null,
  items?: CostingLineItemInput[],
): number | null => {
  if (!shipment || shipment.type === 'local') {
    return null;
  }

  const productConv = shipment.product_conversion_rate || 1.0;
  const cargoConv = shipment.cargo_conversion_rate || 1.0;
  const cargoRate = shipment.cargo_rate || 0;
  const cargoWeight = items ? getCargoWeightKg(shipment, items) : 0;
  const goodsPurchase = items ? sumGoodsPurchase(items) : 0;
  const cargoPurchase = cargoWeight * cargoRate;

  return moneyWeightedBlendRate(
    [
      { foreign: goodsPurchase, rate: productConv },
      { foreign: cargoPurchase, rate: cargoConv },
    ],
    shipment.transaction_rate && shipment.transaction_rate > 0
      ? shipment.transaction_rate
      : productConv,
  );
};

export const calculateTransactionRate = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number | null => {
  const raw = calculateRawTransactionRate(shipment, items);
  if (raw === null) return null;
  return Math.round(raw * 100) / 100;
};

export const getCalculatedTransactionRate = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number | null => {
  if (shipment.type === 'local') return null;
  const fromPays = shipment.transaction_rate;
  if (fromPays != null && fromPays > 0) {
    return Math.round(fromPays * 100) / 100;
  }
  return calculateTransactionRate(shipment, items);
};

/** Blended FX used to convert purchase-currency base → BDT (international only). */
export const getEffectiveTransactionRateForLandedCost = (
  shipment: CostingShipmentInput,
  items?: CostingLineItemInput[],
): number | null => {
  if (shipment.type === 'local') return null;

  const rawTxRate = items && items.length > 0 ? calculateRawTransactionRate(shipment, items) : null;
  const storedTxRate = shipment.transaction_rate;

  if (rawTxRate !== null && rawTxRate > 0) return rawTxRate;
  if (storedTxRate !== null && storedTxRate !== undefined && storedTxRate > 0) return storedTxRate;

  const productConv = shipment.product_conversion_rate || 1;
  const cargoConv = shipment.cargo_conversion_rate || 1;
  const cargoRate = shipment.cargo_rate || 0;
  const cargoWeight = items && items.length > 0 ? getCargoWeightKg(shipment, items) : 0;
  const goodsPurchase = items && items.length > 0 ? sumGoodsPurchase(items) : 0;
  const cargoPurchase = cargoWeight * cargoRate;

  return moneyWeightedBlendRate(
    [
      { foreign: goodsPurchase, rate: productConv },
      { foreign: cargoPurchase, rate: cargoConv },
    ],
    productConv,
  );
};

export type LineLandedCostBreakdown = {
  purchasePricePerUnit: number;
  cargoSharePerUnit: number;
  basePerUnit: number;
  /** Pay-weighted material + freight blend — shown for context; line uses split rates below. */
  transactionRate: number | null;
  productConversionRate: number | null;
  cargoConversionRate: number | null;
  landedCostBdt: number;
};

export const calculateLineLandedCostBreakdown = (
  item: CostingLineItemInput,
  shipment?: CostingShipmentInput | null,
  items?: CostingLineItemInput[],
): LineLandedCostBreakdown => {
  const purchasePricePerUnit = Number(item.purchase_price) || 0;
  const qty = item.ordered_quantity || 0;
  const lineCargoTotal =
    shipment && items && items.length > 0
      ? calculateLineCargoPurchaseShare(item, shipment, items)
      : 0;
  const cargoSharePerUnit =
    items && items.length > 0 && qty > 0
      ? lineCargoTotal / qty
      : (((item.product_weight || 0) + (item.package_weight || 0)) / 1000) *
        (shipment?.cargo_rate || 0);
  const basePerUnit = calculateLinePurchaseBase(item, shipment, items);

  if (!shipment) {
    return {
      purchasePricePerUnit,
      cargoSharePerUnit,
      basePerUnit: purchasePricePerUnit,
      transactionRate: null,
      productConversionRate: null,
      cargoConversionRate: null,
      landedCostBdt: purchasePricePerUnit,
    };
  }

  if (shipment.type === 'local') {
    return {
      purchasePricePerUnit,
      cargoSharePerUnit,
      basePerUnit,
      transactionRate: null,
      productConversionRate: null,
      cargoConversionRate: null,
      landedCostBdt: basePerUnit,
    };
  }

  const productConv = shipment.product_conversion_rate || 1.0;
  const cargoConv = shipment.cargo_conversion_rate || 1.0;
  const transactionRate = getCalculatedTransactionRate(shipment, items ?? []);
  const landedCostBdt = purchasePricePerUnit * productConv + cargoSharePerUnit * cargoConv;

  return {
    purchasePricePerUnit,
    cargoSharePerUnit,
    basePerUnit,
    transactionRate,
    productConversionRate: productConv,
    cargoConversionRate: cargoConv,
    landedCostBdt,
  };
};

/** Preview unit landed cost in BDT — does not write `landed_cost_bdt`. */
export const calculateLineLandedCostBdt = (
  item: CostingLineItemInput,
  shipment?: CostingShipmentInput | null,
  items?: CostingLineItemInput[],
): number => {
  if (!item) return 0;
  return calculateLineLandedCostBreakdown(item, shipment, items).landedCostBdt;
};

export function buildShipmentForLiveCosting(
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): CostingShipmentInput {
  return {
    ...shipment,
    transaction_rate: calculateTransactionRate(shipment, items),
  };
}

export function calculateShipmentCostSummary(
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): ShipmentCostSummary {
  const quantity = sumQuantity(items);
  const packagingWeightKg = calculatePackagingWeightKg(items);
  const cargoWeightKg = getCargoWeightKg(shipment, items);
  const goodsPurchase = sumGoodsPurchase(items);
  const cargoPurchase = cargoWeightKg * (shipment.cargo_rate || 0);
  const totalPurchase = goodsPurchase + cargoPurchase;

  const goodsCost =
    shipment.type === 'local'
      ? goodsPurchase
      : goodsPurchase * (shipment.product_conversion_rate || 1);
  const cargoCost =
    shipment.type === 'local'
      ? cargoPurchase
      : cargoPurchase * (shipment.cargo_conversion_rate || 1);
  const totalCost = goodsCost + cargoCost;

  const transactionRate = getCalculatedTransactionRate(shipment, items);

  let lineLandedCostTotal = 0;
  for (const item of items) {
    const qty = item.ordered_quantity || 0;
    lineLandedCostTotal += calculateLineLandedCostBdt(item, shipment, items) * qty;
  }

  return {
    quantity,
    packagingWeightKg,
    cargoWeightKg,
    goodsPurchase,
    cargoPurchase,
    totalPurchase,
    goodsCost,
    cargoCost,
    totalCost,
    transactionRate,
    lineLandedCostTotal,
  };
}

// --- Cost-entry helpers (entry → header-shaped preview input) ---

const LEGACY_COST_TYPE_BY_BUCKET: Record<string, string> = {
  material: 'product',
  freight: 'cargo',
};

export const entryCostType = (entry: CostEntryInput): string | null => {
  if (entry.cost_type) return entry.cost_type;
  if (entry.cost_bucket) {
    return LEGACY_COST_TYPE_BY_BUCKET[entry.cost_bucket] ?? entry.cost_bucket;
  }
  return null;
};

const sumByType = (entries: CostEntryInput[], costType: string): number => {
  let total = 0;
  for (const e of entries) {
    if (entryCostType(e) === costType) total += Number(e.amount) || 0;
  }
  return total;
};

/** Money-weighted average FX for a cost_type (total BDT ÷ total foreign on matching rows). */
export const effectiveRateForType = (
  entries: CostEntryInput[],
  costType: string,
  fallbackRate = 1,
): number => {
  const legs: MoneyWeightedFxLeg[] = [];
  for (const e of entries) {
    if (entryCostType(e) !== costType) continue;
    const amount = Number(e.amount) || 0;
    const rawRate = Number(e.exchange_rate);
    const rate = Number.isFinite(rawRate) && rawRate > 0 ? rawRate : fallbackRate;
    if (amount > 0) legs.push({ foreign: amount, rate });
  }
  return moneyWeightedBlendRate(legs, fallbackRate);
};

/**
 * Maps cost entries → header-shaped CostingShipmentInput for live preview.
 * Blended / transaction rate stays computed — never written as an input.
 */
export function costingShipmentFromEntries(
  shipment: CostingShipmentInput,
  entries: CostEntryInput[],
  items: CostingLineItemInput[],
): CostingShipmentInput {
  const hasEntries = entries && entries.length > 0;
  const headerProductRate = shipment.product_conversion_rate ?? 1.0;
  const headerCargoRate = shipment.cargo_conversion_rate ?? 1.0;
  const productAmount = hasEntries ? sumByType(entries, 'product') : 0;
  const cargoAmount = hasEntries ? sumByType(entries, 'cargo') : 0;
  const productRate =
    productAmount > 0
      ? effectiveRateForType(entries, 'product', headerProductRate)
      : headerProductRate;
  const cargoFxRate =
    cargoAmount > 0
      ? effectiveRateForType(entries, 'cargo', headerCargoRate)
      : headerCargoRate;
  const cargoKg = getCargoWeightKg(shipment, items);
  const cargoRatePerKg = cargoKg > 0 ? cargoAmount / cargoKg : (shipment.cargo_rate ?? 0);

  const merged: CostingShipmentInput = {
    ...shipment,
    product_conversion_rate: productRate,
    cargo_conversion_rate: cargoFxRate,
    cargo_rate: cargoRatePerKg,
    transaction_rate: shipment.transaction_rate ?? null,
  };

  if (shipment.type === 'local') {
    return { ...merged, transaction_rate: null };
  }

  const fromPays = shipment.transaction_rate;
  const fromPreview =
    fromPays != null && fromPays > 0
      ? fromPays
      : calculateTransactionRate(merged, items);

  return {
    ...merged,
    transaction_rate: fromPreview,
  };
}

export function sumEntryAmount(entries: CostEntryInput[], costType: string): number {
  return sumByType(entries, costType);
}

export function sumProductEntryAmount(entries: CostEntryInput[]): number {
  return sumByType(entries, 'product');
}

export function productCostEntries(entries: CostEntryInput[]): CostEntryInput[] {
  return entries.filter((e) => entryCostType(e) === 'product');
}

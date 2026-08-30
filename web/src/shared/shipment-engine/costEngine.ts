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
  shipment: CostingShipmentInput,
  items?: CostingLineItemInput[],
): number => {
  const purchasePrice = item.purchase_price || 0;
  const qty = item.ordered_quantity || 0;

  if (items && items.length > 0) {
    const lineCargoPurchase = calculateLineCargoPurchaseShare(item, shipment, items);
    return purchasePrice + (qty > 0 ? lineCargoPurchase / qty : 0);
  }

  const weightKg = ((item.product_weight || 0) + (item.package_weight || 0)) / 1000;
  return purchasePrice + weightKg * (shipment.cargo_rate || 0);
};

export const calculateRawTransactionRate = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number | null => {
  if (shipment.type === 'local') {
    return null;
  }

  const productConv = shipment.product_conversion_rate || 1.0;
  const cargoConv = shipment.cargo_conversion_rate || 1.0;
  const cargoRate = shipment.cargo_rate || 0;
  const cargoWeight = getCargoWeightKg(shipment, items);
  const goodsPurchase = sumGoodsPurchase(items);
  const cargoPurchase = cargoWeight * cargoRate;

  const goodsBdt = goodsPurchase * productConv;
  const cargoBdt = cargoPurchase * cargoConv;
  const denominator = goodsPurchase + cargoPurchase;

  if (denominator > 0) {
    return (goodsBdt + cargoBdt) / denominator;
  }

  return (productConv + cargoConv) / 2;
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
  return calculateTransactionRate(shipment, items);
};

/** Preview unit landed cost in BDT — does not write `landed_cost_bdt`. */
export const calculateLineLandedCostBdt = (
  item: CostingLineItemInput,
  shipment: CostingShipmentInput,
  items?: CostingLineItemInput[],
): number => {
  const base = calculateLinePurchaseBase(item, shipment, items);

  if (shipment.type === 'local') {
    return base;
  }

  const rawTxRate = items && items.length > 0 ? calculateRawTransactionRate(shipment, items) : null;

  const storedTxRate = shipment.transaction_rate;

  const effectiveRate =
    rawTxRate !== null && rawTxRate > 0
      ? rawTxRate
      : storedTxRate !== null && storedTxRate !== undefined && storedTxRate > 0
        ? storedTxRate
        : ((shipment.product_conversion_rate || 1) + (shipment.cargo_conversion_rate || 1)) / 2;

  return base * effectiveRate;
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

const sumByType = (entries: CostEntryInput[], costType: string): number => {
  let total = 0;
  for (const e of entries) {
    if (e.cost_type === costType) total += Number(e.amount) || 0;
  }
  return total;
};

/** Money-weighted average exchange rate for a cost_type. */
export const effectiveRateForType = (entries: CostEntryInput[], costType: string): number => {
  let weighted = 0;
  let amountSum = 0;
  for (const e of entries) {
    if (e.cost_type !== costType) continue;
    const amount = Number(e.amount) || 0;
    const rate = Number(e.exchange_rate) || 1;
    weighted += amount * rate;
    amountSum += amount;
  }
  if (amountSum <= 0) return 1;
  return weighted / amountSum;
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
  const productRate = hasEntries ? effectiveRateForType(entries, 'product') : (shipment.product_conversion_rate ?? 1.0);
  const cargoFxRate = hasEntries ? effectiveRateForType(entries, 'cargo') : (shipment.cargo_conversion_rate ?? 1.0);
  const cargoAmount = hasEntries ? sumByType(entries, 'cargo') : 0;
  const cargoKg = getCargoWeightKg(shipment, items);
  const cargoRatePerKg = cargoKg > 0 ? cargoAmount / cargoKg : (shipment.cargo_rate ?? 0);

  return {
    ...shipment,
    product_conversion_rate: productRate,
    cargo_conversion_rate: cargoFxRate,
    cargo_rate: cargoRatePerKg,
    transaction_rate: null,
  };
}

export function sumEntryAmount(entries: CostEntryInput[], costType: string): number {
  return sumByType(entries, costType);
}

export function sumProductEntryAmount(entries: CostEntryInput[]): number {
  return sumByType(entries, 'product');
}

export function productCostEntries(entries: CostEntryInput[]): CostEntryInput[] {
  return entries.filter((e) => e.cost_type === 'product');
}

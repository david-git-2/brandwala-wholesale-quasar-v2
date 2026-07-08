export interface CostingShipmentInput {
  type: 'domestic' | 'international';
  product_conversion_rate: number;
  cargo_conversion_rate: number;
  cargo_rate: number;
  received_weight: number | null;
  transaction_rate: number | null;
}

export interface CostingLineItemInput {
  purchase_price: number;
  product_weight: number; // in grams
  package_weight: number; // in grams
  ordered_quantity: number;
}

/**
 * Gross weight in kg for one line (all units).
 */
export const calculateLineGrossWeightKg = (item: CostingLineItemInput): number => {
  return (
    (((item.product_weight || 0) + (item.package_weight || 0)) * (item.ordered_quantity || 0)) /
    1000
  );
};

/**
 * Calculates total packaging weight in kg from item list.
 */
export const calculatePackagingWeightKg = (items: CostingLineItemInput[]): number => {
  let weight = 0;
  for (const item of items) {
    weight += calculateLineGrossWeightKg(item);
  }
  return weight;
};

/**
 * Cargo weight for costing: uses cargo invoice weight (received_weight) when set,
 * otherwise falls back to estimated packaging weight from line items.
 */
export const getCargoWeightKg = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number => {
  if (shipment.received_weight != null && shipment.received_weight > 0) {
    return Math.round(shipment.received_weight * 100) / 100;
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

/**
 * Allocates total shipment cargo purchase to a line proportionally by gross weight
 * (or evenly by quantity when there is no weight basis).
 */
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

/**
 * Purchase-currency unit base: price + allocated cargo per unit.
 */
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

/**
 * Full-precision blended rate used for line costing so line totals match header costs.
 */
export const calculateRawTransactionRate = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number | null => {
  if (shipment.type === 'domestic') {
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

/**
 * Computes the transaction rate for an international shipment (rounded for display/storage).
 */
export const calculateTransactionRate = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number | null => {
  const raw = calculateRawTransactionRate(shipment, items);
  if (raw === null) return null;
  return Math.round(raw * 100) / 100;
};

/**
 * Thin alias to get calculated transaction rate.
 */
export const getCalculatedTransactionRate = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number | null => {
  return calculateTransactionRate(shipment, items);
};

/**
 * Calculates the BDT landed cost for a single line item.
 */
export const calculateLineLandedCostBdt = (
  item: CostingLineItemInput,
  shipment: CostingShipmentInput,
  items?: CostingLineItemInput[],
): number => {
  const base = calculateLinePurchaseBase(item, shipment, items);

  if (shipment.type === 'domestic') {
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

export interface ShipmentCostSummary {
  quantity: number;
  packagingWeightKg: number;
  cargoWeightKg: number;
  goodsPurchase: number;
  cargoPurchase: number;
  totalPurchase: number;
  goodsCost: number;
  cargoCost: number;
  totalCost: number;
  transactionRate: number | null;
  lineLandedCostTotal: number; // Σ(unit cost × qty) using live rate
}

/**
 * Calculates the complete shipment costing summary.
 */
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
    shipment.type === 'domestic'
      ? goodsPurchase
      : goodsPurchase * (shipment.product_conversion_rate || 1);
  const cargoCost =
    shipment.type === 'domestic'
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

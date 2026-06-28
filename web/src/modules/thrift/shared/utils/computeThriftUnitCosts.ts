export interface ThriftShipmentCostInput {
  product_conversion_rate?: number | null | undefined;
  cargo_conversion_rate?: number | null | undefined;
  cargo_rate?: number | null | undefined;
  total_cargo_weight_kg?: number | null | undefined;
  labor_total_cost?: number | null | undefined;
  transportation_total_cost?: number | null | undefined;
  default_markup_rate?: number | null | undefined;
}

export interface ThriftSettingsCostInput {
  hand_tag_unit_cost?: number | null | undefined;
  sticker_unit_cost?: number | null | undefined;
}

export interface ThriftStockCostInput {
  id?: number;
  quantity: number;
  origin_unit_price?: number | null | undefined;
  extra_origin_unit_price?: number | null | undefined;
  additional_charges_cost?: number | null | undefined;
}

export interface ThriftStockPricingInput {
  listed_unit_price: number;
  is_listed_price_manual?: boolean | null | undefined;
}

export interface ThriftUnitCostBreakdown {
  shipment_unit_count: number;
  product_unit_cost: number;
  shipment_cargo_cost: number;
  shipment_ops_cost: number;
  cargo_share_per_unit: number;
  ops_share_per_unit: number;
  landed_unit_cost: number;
  suggested_sell_unit_price: number;
  display_listed_unit_price?: number;
}

export function computeShipmentUnitCount(stocks: ThriftStockCostInput[]): number {
  const sum = stocks.reduce((acc, stock) => acc + (stock.quantity || 0), 0);
  return Math.max(sum, 1);
}

export function computeShipmentCargoCost(shipment: ThriftShipmentCostInput): number {
  const weight = shipment.total_cargo_weight_kg ?? 0;
  const rate = shipment.cargo_rate ?? 0;
  const conv = shipment.cargo_conversion_rate ?? 0;
  return weight * rate * conv;
}

export function computeShipmentOpsCost(
  shipment: ThriftShipmentCostInput,
  settings: ThriftSettingsCostInput,
  U: number,
): number {
  const handTagCost = settings.hand_tag_unit_cost ?? 0;
  const stickerCost = settings.sticker_unit_cost ?? 0;
  const labor = shipment.labor_total_cost ?? 0;
  const transport = shipment.transportation_total_cost ?? 0;

  return (handTagCost * U) + (stickerCost * U) + labor + transport;
}

export function computeThriftUnitCosts(
  stock: ThriftStockCostInput,
  shipment: ThriftShipmentCostInput,
  settings: ThriftSettingsCostInput,
  U: number,
  pricing?: ThriftStockPricingInput,
): ThriftUnitCostBreakdown {
  const originPrice = stock.origin_unit_price ?? 0;
  const extraOriginPrice = stock.extra_origin_unit_price ?? 0;
  const prodConv = shipment.product_conversion_rate ?? 1.0;

  const product_unit_cost = (originPrice + extraOriginPrice) * prodConv;

  const shipment_cargo_cost = computeShipmentCargoCost(shipment);
  const shipment_ops_cost = computeShipmentOpsCost(shipment, settings, U);

  const cargo_share_per_unit = shipment_cargo_cost / U;
  const ops_share_per_unit = shipment_ops_cost / U;

  const additionalCharges = stock.additional_charges_cost ?? 0;
  const landed_unit_cost = product_unit_cost + cargo_share_per_unit + ops_share_per_unit + additionalCharges;

  const markup = shipment.default_markup_rate ?? 0;
  const suggested_sell_unit_price = landed_unit_cost * (1 + markup);

  const breakdown: ThriftUnitCostBreakdown = {
    shipment_unit_count: U,
    product_unit_cost,
    shipment_cargo_cost,
    shipment_ops_cost,
    cargo_share_per_unit,
    ops_share_per_unit,
    landed_unit_cost,
    suggested_sell_unit_price,
  };

  if (pricing) {
    breakdown.display_listed_unit_price = pricing.is_listed_price_manual
      ? pricing.listed_unit_price
      : suggested_sell_unit_price;
  }

  return breakdown;
}

export function computeThriftUnitCostsForShipment(
  stocks: ThriftStockCostInput[],
  shipment: ThriftShipmentCostInput,
  settings: ThriftSettingsCostInput,
  pricingByStockId?: Record<number, ThriftStockPricingInput>,
): Record<number, ThriftUnitCostBreakdown> {
  const U = computeShipmentUnitCount(stocks);
  const results: Record<number, ThriftUnitCostBreakdown> = {};

  for (const stock of stocks) {
    if (stock.id !== undefined) {
      const pricing = pricingByStockId?.[stock.id];
      results[stock.id] = computeThriftUnitCosts(stock, shipment, settings, U, pricing);
    }
  }

  return results;
}

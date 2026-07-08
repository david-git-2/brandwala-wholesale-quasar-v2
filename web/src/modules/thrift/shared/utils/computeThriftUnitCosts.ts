import { ceilThriftRetailPrice } from './ceilThriftRetailPrice';

export interface ThriftShipmentCostInput {
  product_conversion_rate?: number | null | undefined;
  cargo_conversion_rate?: number | null | undefined;
  cargo_rate?: number | null | undefined;
  total_cargo_weight_kg?: number | null | undefined;
  labor_total_cost?: number | null | undefined;
  transportation_total_cost?: number | null | undefined;
  washing_total_cost?: number | null | undefined;
  default_markup_rate?: number | null | undefined;
}

export interface ThriftSettingsCostInput {
  hand_tag_unit_cost?: number | null | undefined;
  sticker_unit_cost?: number | null | undefined;
}

export interface ThriftStockCostInput {
  id?: number;
  quantity: number;
  product_weight?: number | null | undefined;
  extra_weight?: number | null | undefined;
  origin_unit_price?: number | null | undefined;
  extra_origin_unit_price?: number | null | undefined;
  additional_charges_cost?: number | null | undefined;
}

export interface ThriftStockPricingInput {
  listed_unit_price: number;
  is_listed_price_manual?: boolean | null | undefined;
  markup_rate_override?: number | null | undefined;
}

export type MarkupSource = 'shipment' | 'item_override';

export interface ThriftUnitCostBreakdownDetails {
  origin_unit_price: number;
  extra_origin_unit_price: number;
  product_conversion_rate: number;
  product_weight_g: number;
  extra_weight_g: number;
  quantity: number;
  unit_weight_kg: number;
  total_cargo_weight_kg: number;
  cargo_rate: number;
  cargo_conversion_rate: number;
  cargo_weight_share_pct: number | null;
  cargo_line_allocation: number;
  hand_tag_unit_cost: number;
  sticker_unit_cost: number;
  hand_tags_total: number;
  stickers_total: number;
  labor_total_cost: number;
  transportation_total_cost: number;
  washing_total_cost: number;
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
  additional_charges_cost: number;
  line_weight_kg: number;
  shipment_total_weight_kg: number;
  uses_weight_based_cargo: boolean;
  applied_markup_rate: number;
  markup_source: MarkupSource;
  effective_markup_pct: number | null;
  details: ThriftUnitCostBreakdownDetails;
}

export function computeShipmentUnitCount(stocks: ThriftStockCostInput[]): number {
  const sum = stocks.reduce((acc, stock) => acc + (stock.quantity || 0), 0);
  return Math.max(sum, 1);
}

export function computeStockLineWeightKg(stock: ThriftStockCostInput): number {
  const grams = (stock.product_weight ?? 0) + (stock.extra_weight ?? 0);
  return (grams / 1000) * Math.max(stock.quantity || 0, 0);
}

export function computeShipmentTotalWeightKg(stocks: ThriftStockCostInput[]): number {
  return stocks.reduce((acc, stock) => acc + computeStockLineWeightKg(stock), 0);
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
  const washing = shipment.washing_total_cost ?? 0;

  return handTagCost * U + stickerCost * U + labor + transport + washing;
}

export function resolveAppliedMarkupRate(
  pricing: ThriftStockPricingInput | undefined,
  shipment: ThriftShipmentCostInput,
): { rate: number; source: MarkupSource } {
  if (pricing?.markup_rate_override != null) {
    return { rate: pricing.markup_rate_override, source: 'item_override' };
  }
  return { rate: shipment.default_markup_rate ?? 0, source: 'shipment' };
}

export function computeEffectiveMarkupPct(landed: number, listedPrice: number): number | null {
  if (landed <= 0) return null;
  return ((listedPrice - landed) / landed) * 100;
}

export function computeCargoSharePerUnit(
  stock: ThriftStockCostInput,
  shipment: ThriftShipmentCostInput,
  allStocks: ThriftStockCostInput[],
  U: number,
): number {
  const cargoTotal = computeShipmentCargoCost(shipment);
  const qty = stock.quantity || 0;
  if (qty <= 0) return 0;

  const totalWeightKg = computeShipmentTotalWeightKg(allStocks);
  if (totalWeightKg > 0) {
    const lineWeightKg = computeStockLineWeightKg(stock);
    return ((lineWeightKg / totalWeightKg) * cargoTotal) / qty;
  }

  return cargoTotal / U;
}

export function computeThriftUnitCosts(
  stock: ThriftStockCostInput,
  shipment: ThriftShipmentCostInput,
  settings: ThriftSettingsCostInput,
  U: number,
  pricing?: ThriftStockPricingInput,
  allStocks?: ThriftStockCostInput[],
): ThriftUnitCostBreakdown {
  const originPrice = stock.origin_unit_price ?? 0;
  const extraOriginPrice = stock.extra_origin_unit_price ?? 0;
  const prodConv = shipment.product_conversion_rate ?? 1.0;

  const product_unit_cost = (originPrice + extraOriginPrice) * prodConv;

  const shipment_cargo_cost = computeShipmentCargoCost(shipment);
  const shipment_ops_cost = computeShipmentOpsCost(shipment, settings, U);

  const stocksForCargo = allStocks && allStocks.length > 0 ? allStocks : [stock];
  const shipment_total_weight_kg = computeShipmentTotalWeightKg(stocksForCargo);
  const line_weight_kg = computeStockLineWeightKg(stock);
  const uses_weight_based_cargo = shipment_total_weight_kg > 0;

  const cargo_share_per_unit = computeCargoSharePerUnit(stock, shipment, stocksForCargo, U);
  const ops_share_per_unit = shipment_ops_cost / U;

  const qty = stock.quantity || 0;
  const productWeightG = stock.product_weight ?? 0;
  const extraWeightG = stock.extra_weight ?? 0;
  const unitWeightKg = (productWeightG + extraWeightG) / 1000;
  const cargoLineAllocation = qty > 0 ? cargo_share_per_unit * qty : 0;
  const cargoWeightSharePct =
    uses_weight_based_cargo && shipment_total_weight_kg > 0
      ? (line_weight_kg / shipment_total_weight_kg) * 100
      : null;

  const handTagUnitCost = settings.hand_tag_unit_cost ?? 0;
  const stickerUnitCost = settings.sticker_unit_cost ?? 0;
  const laborTotal = shipment.labor_total_cost ?? 0;
  const transportTotal = shipment.transportation_total_cost ?? 0;
  const washingTotal = shipment.washing_total_cost ?? 0;

  const additionalCharges = stock.additional_charges_cost ?? 0;
  const landed_unit_cost =
    product_unit_cost + cargo_share_per_unit + ops_share_per_unit + additionalCharges;

  const { rate: applied_markup_rate, source: markup_source } = resolveAppliedMarkupRate(
    pricing,
    shipment,
  );
  const suggested_sell_unit_price = ceilThriftRetailPrice(
    landed_unit_cost * (1 + applied_markup_rate),
  );

  const isManual = !!pricing?.is_listed_price_manual;
  const listedPrice = isManual && pricing ? pricing.listed_unit_price : suggested_sell_unit_price;
  const effective_markup_pct = computeEffectiveMarkupPct(landed_unit_cost, listedPrice);

  const breakdown: ThriftUnitCostBreakdown = {
    shipment_unit_count: U,
    product_unit_cost,
    shipment_cargo_cost,
    shipment_ops_cost,
    cargo_share_per_unit,
    ops_share_per_unit,
    landed_unit_cost,
    suggested_sell_unit_price,
    additional_charges_cost: additionalCharges,
    line_weight_kg,
    shipment_total_weight_kg,
    uses_weight_based_cargo,
    applied_markup_rate,
    markup_source,
    effective_markup_pct,
    details: {
      origin_unit_price: originPrice,
      extra_origin_unit_price: extraOriginPrice,
      product_conversion_rate: prodConv,
      product_weight_g: productWeightG,
      extra_weight_g: extraWeightG,
      quantity: qty,
      unit_weight_kg: unitWeightKg,
      total_cargo_weight_kg: shipment.total_cargo_weight_kg ?? 0,
      cargo_rate: shipment.cargo_rate ?? 0,
      cargo_conversion_rate: shipment.cargo_conversion_rate ?? 0,
      cargo_weight_share_pct: cargoWeightSharePct,
      cargo_line_allocation: cargoLineAllocation,
      hand_tag_unit_cost: handTagUnitCost,
      sticker_unit_cost: stickerUnitCost,
      hand_tags_total: handTagUnitCost * U,
      stickers_total: stickerUnitCost * U,
      labor_total_cost: laborTotal,
      transportation_total_cost: transportTotal,
      washing_total_cost: washingTotal,
    },
  };

  if (pricing) {
    breakdown.display_listed_unit_price = isManual
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
      results[stock.id] = computeThriftUnitCosts(stock, shipment, settings, U, pricing, stocks);
    }
  }

  return results;
}

export function buildThriftCostBreakdownByStockId(
  stocks: (ThriftStockCostInput & {
    id: number;
    shipment_id: number;
    pricing?: ThriftStockPricingInput | null;
  })[],
  shipmentById: Map<number, ThriftShipmentCostInput>,
  settings: ThriftSettingsCostInput,
): Record<number, ThriftUnitCostBreakdown> {
  const byShipment = new Map<
    number,
    (ThriftStockCostInput & { id: number; pricing?: ThriftStockPricingInput | null })[]
  >();
  for (const stock of stocks) {
    const list = byShipment.get(stock.shipment_id) ?? [];
    list.push(stock);
    byShipment.set(stock.shipment_id, list);
  }

  const breakdowns: Record<number, ThriftUnitCostBreakdown> = {};
  for (const [shipmentId, shipmentStocks] of byShipment) {
    const shipment = shipmentById.get(shipmentId);
    if (!shipment) continue;

    const pricingMap: Record<number, ThriftStockPricingInput> = {};
    for (const stock of shipmentStocks) {
      if (stock.pricing) {
        pricingMap[stock.id] = {
          listed_unit_price: stock.pricing.listed_unit_price,
          is_listed_price_manual: stock.pricing.is_listed_price_manual,
          markup_rate_override: stock.pricing.markup_rate_override ?? null,
        };
      }
    }

    const shipmentBreakdowns = computeThriftUnitCostsForShipment(
      shipmentStocks,
      shipment,
      settings,
      pricingMap,
    );
    Object.assign(breakdowns, shipmentBreakdowns);
  }
  return breakdowns;
}

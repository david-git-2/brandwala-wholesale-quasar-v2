import type { ShopOrderItem } from '../types';

export interface CatalogRatesParams {
  conversion_rate?: number | null | undefined;
  cargo_rate?: number | null | undefined;
  first_offer_rate?: number | null | undefined;
  final_offer_rate?: number | null | undefined;
  profit_rate?: number | null | undefined;
  profit_basis?: 'purchase' | 'total_cost' | 'sale_price' | null | undefined;
}

export function roundUpToNearest5(val: number): number {
  if (val <= 0) return 0;
  return Math.ceil(val / 5) * 5;
}

export function getProductWeightGm(item: Partial<ShopOrderItem>): number {
  if (item.product_weight_gm != null && Number(item.product_weight_gm) > 0) {
    return Number(item.product_weight_gm);
  }
  if (item.weight_kg != null) {
    return Number(item.weight_kg) * 1000;
  }
  return 0;
}

export function getPackageWeightGm(
  item: Partial<ShopOrderItem>,
  orderPackageWeightKg?: number | null,
): number {
  if (item.package_weight_gm != null && Number(item.package_weight_gm) > 0) {
    return Number(item.package_weight_gm);
  }
  if (orderPackageWeightKg != null) {
    return Number(orderPackageWeightKg) * 1000;
  }
  return 0;
}

export function getTotalWeightGm(
  item: Partial<ShopOrderItem>,
  orderPackageWeightKg?: number | null,
): number {
  return getProductWeightGm(item) + getPackageWeightGm(item, orderPackageWeightKg);
}

export function getCargoCostUnitPurchase(
  item: Partial<ShopOrderItem>,
  cargoRate: number,
  orderPackageWeightKg?: number | null,
): number {
  const weightKg = getTotalWeightGm(item, orderPackageWeightKg) / 1000;
  return weightKg * cargoRate;
}

export function getLandedCostUnitPurchase(
  item: Partial<ShopOrderItem>,
  cargoRate: number,
  orderPackageWeightKg?: number | null,
): number {
  const purchasePrice = Number(item.cost_price_amount ?? item.unit_list_price_amount ?? 0);
  return purchasePrice + getCargoCostUnitPurchase(item, cargoRate, orderPackageWeightKg);
}

export function getLandedCostRowPurchase(
  item: Partial<ShopOrderItem>,
  cargoRate: number,
  orderPackageWeightKg?: number | null,
): number {
  const quantity = Number(item.quantity || 0);
  return getLandedCostUnitPurchase(item, cargoRate, orderPackageWeightKg) * quantity;
}

export function getLandedCostUnitSell(
  item: Partial<ShopOrderItem>,
  cargoRate: number,
  conversionRate: number,
  orderPackageWeightKg?: number | null,
): number {
  return getLandedCostUnitPurchase(item, cargoRate, orderPackageWeightKg) * conversionRate;
}

export function getLandedCostRowSell(
  item: Partial<ShopOrderItem>,
  cargoRate: number,
  conversionRate: number,
  orderPackageWeightKg?: number | null,
): number {
  const quantity = Number(item.quantity || 0);
  return getLandedCostUnitSell(item, cargoRate, conversionRate, orderPackageWeightKg) * quantity;
}

export function calculateItemFirstOfferPrice(
  item: Partial<ShopOrderItem>,
  rates: CatalogRatesParams,
  orderPackageWeightKg?: number | null,
): number {
  const purchasePrice = Number(item.cost_price_amount ?? item.unit_list_price_amount ?? 0);
  const prodGm = getProductWeightGm(item);
  const pkgGm = getPackageWeightGm(item, orderPackageWeightKg);
  const weightKg = prodGm + pkgGm > 0 ? (prodGm + pkgGm) / 1000 : Number(item.weight_kg || 0);

  const fx = rates.conversion_rate ?? 140;
  const cRate = rates.cargo_rate ?? 0;
  const pRate = rates.first_offer_rate ?? rates.profit_rate ?? 25;
  const pBasis = rates.profit_basis ?? 'total_cost';
  const markup = pRate / 100;
  const cargoCostBuy = weightKg * cRate;

  if (pBasis === 'purchase') {
    const purchaseCostSell = purchasePrice * fx;
    const cargoCostSell = cargoCostBuy * fx;
    return roundUpToNearest5(purchaseCostSell * (1 + markup) + cargoCostSell);
  }
  const landedCostSell = (purchasePrice + cargoCostBuy) * fx;
  return roundUpToNearest5(landedCostSell * (1 + markup));
}

export function getFirstOfferUnitAmount(
  item: Partial<ShopOrderItem>,
  rates: CatalogRatesParams,
  orderPackageWeightKg?: number | null,
): number {
  if (item.is_first_offer_manual) {
    return Number(item.staff_offer_amount || 0);
  }
  const calc = calculateItemFirstOfferPrice(item, rates, orderPackageWeightKg);
  if (calc > 0 && item.staff_offer_amount === undefined) {
    item.staff_offer_amount = calc;
  }
  return Number(item.staff_offer_amount || calc || 0);
}

export function getFirstOfferMargin(
  item: Partial<ShopOrderItem>,
  rates: CatalogRatesParams,
  orderPackageWeightKg?: number | null,
): number {
  const offer = getFirstOfferUnitAmount(item, rates, orderPackageWeightKg);
  const cost = getLandedCostUnitSell(
    item,
    rates.cargo_rate ?? 0,
    rates.conversion_rate ?? 140,
    orderPackageWeightKg,
  );
  if (cost <= 0) return 0;
  return ((offer - cost) / cost) * 100;
}

export function getCounterOfferMargin(
  item: Partial<ShopOrderItem>,
  rates: CatalogRatesParams,
  orderPackageWeightKg?: number | null,
): number {
  const offer = Number(item.customer_offer_amount || 0);
  const cost = getLandedCostUnitSell(
    item,
    rates.cargo_rate ?? 0,
    rates.conversion_rate ?? 140,
    orderPackageWeightKg,
  );
  if (cost <= 0) return 0;
  return ((offer - cost) / cost) * 100;
}

export function calculateItemFinalOfferPrice(
  item: Partial<ShopOrderItem>,
  rates: CatalogRatesParams,
  orderPackageWeightKg?: number | null,
): number {
  const effectiveFinalRate = rates.final_offer_rate ?? rates.first_offer_rate ?? rates.profit_rate ?? 25;
  return calculateItemFirstOfferPrice(
    item,
    {
      ...rates,
      first_offer_rate: effectiveFinalRate,
    },
    orderPackageWeightKg,
  );
}

export function getFinalOfferUnitAmount(
  item: Partial<ShopOrderItem>,
  rates: CatalogRatesParams,
  orderPackageWeightKg?: number | null,
): number {
  if (item.is_final_offer_manual && item.final_price_amount != null) {
    return Number(item.final_price_amount);
  }
  if (rates.final_offer_rate != null && rates.final_offer_rate > 0) {
    return calculateItemFinalOfferPrice(item, rates, orderPackageWeightKg);
  }
  if (item.final_price_amount != null && Number(item.final_price_amount) > 0) {
    return Number(item.final_price_amount);
  }
  if (item.final_offer_amount != null && Number(item.final_offer_amount) > 0) {
    return Number(item.final_offer_amount);
  }
  return getFirstOfferUnitAmount(item, rates, orderPackageWeightKg);
}

export function getFinalOfferMargin(
  item: Partial<ShopOrderItem>,
  rates: CatalogRatesParams,
  orderPackageWeightKg?: number | null,
): number {
  const offer = getFinalOfferUnitAmount(item, rates, orderPackageWeightKg);
  const cost = getLandedCostUnitSell(
    item,
    rates.cargo_rate ?? 0,
    rates.conversion_rate ?? 140,
    orderPackageWeightKg,
  );
  if (cost <= 0) return 0;
  return ((offer - cost) / cost) * 100;
}

/**
 * Target landed-cost algorithm — see docs/features/procurement_stock/shipment-rate-calculations.md
 */
import type { CostingLineItemInput, CostingShipmentInput } from './types';

const lineGrossWeightKg = (item: CostingLineItemInput): number =>
  (((item.product_weight || 0) + (item.package_weight || 0)) * (item.ordered_quantity || 0)) /
  1000;

const headerKg = (shipment: CostingShipmentInput): number =>
  shipment.total_weight_kg ?? shipment.received_weight ?? 0;

export type LandedCostPools = {
  materialBdt: number;
  freightBdt: number;
  customsBdt: number;
  handlingBdt: number;
  financeBdt: number;
  otherBdt: number;
};

export type LineLandedBdtParts = {
  goodsBdtPerUnit: number;
  surplusBdtPerUnit: number;
  freightBdtPerUnit: number;
  customsBdtPerUnit: number;
  handlingBdtPerUnit: number;
  financeBdtPerUnit: number;
  otherBdtPerUnit: number;
  unitCif: number;
  unitLanded: number;
};

export type ShipmentLandedPlan = {
  materialRate: number;
  freightBdtPerKg: number;
  kgBasis: number;
  totalQty: number;
  materialSurplusBdt: number;
  totalGoodsBdt: number;
  totalCif: number;
  lines: Map<number, LineLandedBdtParts>;
};

const round4 = (n: number) => Math.round(n * 10000) / 10000;
const round2 = (n: number) => Math.round(n * 100) / 100;

const sumQty = (items: CostingLineItemInput[]) =>
  items.reduce((s, i) => s + (i.ordered_quantity || 0), 0);

const unitKg = (item: CostingLineItemInput) =>
  ((item.product_weight || 0) + (item.package_weight || 0)) / 1000;

const lineKey = (item: CostingLineItemInput, index: number) => index;

export function materialRateFromPools(
  pools: LandedCostPools,
  materialForeign: number,
  fallbackRate = 1,
): number {
  if (materialForeign > 0 && pools.materialBdt > 0) {
    return pools.materialBdt / materialForeign;
  }
  return fallbackRate > 0 ? fallbackRate : 1;
}

/** Full shipment plan: run once, then read per-line parts by index. */
export function buildShipmentLandedPlan(
  items: CostingLineItemInput[],
  shipment: CostingShipmentInput,
  pools: LandedCostPools,
  materialForeign: number,
  materialRateOverride?: number | null,
): ShipmentLandedPlan {
  const materialRate =
    materialRateOverride != null && materialRateOverride > 0
      ? materialRateOverride
      : materialRateFromPools(pools, materialForeign, shipment.product_conversion_rate ?? 1);

  const packagingKg = items.reduce((s, i) => s + lineGrossWeightKg(i), 0);
  const header = headerKg(shipment);
  const kgBasis = packagingKg > 0 ? packagingKg : Math.max(0, header);
  const freightBdtPerKg =
    shipment.freight_bdt_per_kg != null && shipment.freight_bdt_per_kg > 0
      ? shipment.freight_bdt_per_kg
      : kgBasis > 0 && pools.freightBdt > 0
        ? pools.freightBdt / kgBasis
        : 0;

  const totalQty = sumQty(items);
  const indexed = items.map((item, index) => ({ item, index }));

  let totalLineGoodsBdt = 0;
  const lineGoodsBdt = new Map<number, number>();
  const lineGoodsPerUnit = new Map<number, number>();

  for (const { item, index } of indexed) {
    const qty = item.ordered_quantity || 0;
    const goodsPerUnit = (item.purchase_price || 0) * materialRate;
    const goodsLine = goodsPerUnit * qty;
    lineGoodsPerUnit.set(index, goodsPerUnit);
    lineGoodsBdt.set(index, goodsLine);
    totalLineGoodsBdt += goodsLine;
  }

  const materialSurplusBdt = Math.max(0, pools.materialBdt - totalLineGoodsBdt);

  const surplusPerUnit = new Map<number, number>();
  for (const { item, index } of indexed) {
    const qty = item.ordered_quantity || 0;
    const lineGoods = lineGoodsBdt.get(index) ?? 0;
  const share =
      totalLineGoodsBdt > 0 && materialSurplusBdt > 0
        ? (lineGoods / totalLineGoodsBdt) * materialSurplusBdt
        : 0;
    surplusPerUnit.set(index, qty > 0 ? share / qty : 0);
  }

  let freightAssigned = 0;
  const freightPerUnit = new Map<number, number>();
  for (const { item, index } of indexed) {
    const qty = item.ordered_quantity || 0;
    const ukg = unitKg(item);
    const lineFreight =
      ukg > 0 && qty > 0 ? round2(ukg * freightBdtPerKg * qty) : 0;
    freightAssigned += lineFreight;
    freightPerUnit.set(index, qty > 0 ? lineFreight / qty : 0);
  }

  const freightRemainder = Math.max(0, pools.freightBdt - freightAssigned);
  const zeroWeightLines = indexed.filter(({ item }) => unitKg(item) <= 0);
  const zeroWeightQty = zeroWeightLines.reduce(
    (s, { item }) => s + (item.ordered_quantity || 0),
    0,
  );
  if (freightRemainder > 0 && zeroWeightQty > 0) {
    for (const { item, index } of zeroWeightLines) {
      const qty = item.ordered_quantity || 0;
      const extra = (qty / zeroWeightQty) * freightRemainder;
      const prev = freightPerUnit.get(index) ?? 0;
      freightPerUnit.set(index, qty > 0 ? prev + extra / qty : prev);
    }
  }

  let totalGoodsBdt = 0;
  let totalCif = 0;
  const unitCifMap = new Map<number, number>();

  for (const { item, index } of indexed) {
    const qty = item.ordered_quantity || 0;
    const goods = lineGoodsPerUnit.get(index) ?? 0;
    const surplus = surplusPerUnit.get(index) ?? 0;
    const freight = freightPerUnit.get(index) ?? 0;
    const goodsInclSurplus = goods + surplus;
    const unitCif = goodsInclSurplus + freight;
    unitCifMap.set(index, unitCif);
    totalGoodsBdt += goodsInclSurplus * qty;
    totalCif += unitCif * qty;
  }

  const lines = new Map<number, LineLandedBdtParts>();
  for (const { item, index } of indexed) {
    const qty = item.ordered_quantity || 0;
    const goods = lineGoodsPerUnit.get(index) ?? 0;
    const surplus = surplusPerUnit.get(index) ?? 0;
    const freight = freightPerUnit.get(index) ?? 0;
    const unitCif = unitCifMap.get(index) ?? 0;

    const customsPerUnit =
      totalCif > 0 && qty > 0
        ? round4((unitCif / totalCif) * pools.customsBdt)
        : 0;
    const handlingPerUnit = totalQty > 0 ? round4(pools.handlingBdt / totalQty) : 0;
    const otherPerUnit = totalQty > 0 ? round4(pools.otherBdt / totalQty) : 0;
    const goodsInclSurplus = goods + surplus;
    const financePerUnit =
      totalGoodsBdt > 0 && qty > 0
        ? round4(((goodsInclSurplus * qty) / totalGoodsBdt) * pools.financeBdt / qty)
        : 0;

    const unitLanded =
      goodsInclSurplus +
      freight +
      customsPerUnit +
      handlingPerUnit +
      financePerUnit +
      otherPerUnit;

    lines.set(lineKey(item, index), {
      goodsBdtPerUnit: round4(goods),
      surplusBdtPerUnit: round4(surplus),
      freightBdtPerUnit: round4(freight),
      customsBdtPerUnit: customsPerUnit,
      handlingBdtPerUnit: handlingPerUnit,
      financeBdtPerUnit: financePerUnit,
      otherBdtPerUnit: otherPerUnit,
      unitCif: round4(unitCif),
      unitLanded: round4(unitLanded),
    });
  }

  return {
    materialRate,
    freightBdtPerKg,
    kgBasis,
    totalQty,
    materialSurplusBdt: round2(materialSurplusBdt),
    totalGoodsBdt: round2(totalGoodsBdt),
    totalCif: round2(totalCif),
    lines,
  };
}

export function lineLandedFromPlan(
  plan: ShipmentLandedPlan,
  itemIndex: number,
): LineLandedBdtParts | null {
  return plan.lines.get(itemIndex) ?? null;
}

export function unitLandedBdtForLine(
  items: CostingLineItemInput[],
  item: CostingLineItemInput,
  shipment: CostingShipmentInput,
  pools: LandedCostPools,
  materialForeign: number,
  itemIndex?: number,
): number {
  const idx =
    itemIndex ??
    items.findIndex(
      (i) =>
        i.purchase_price === item.purchase_price &&
        i.ordered_quantity === item.ordered_quantity &&
        i.product_weight === item.product_weight &&
        i.package_weight === item.package_weight,
    );
  const plan = buildShipmentLandedPlan(items, shipment, pools, materialForeign);
  const parts = lineLandedFromPlan(plan, idx >= 0 ? idx : 0);
  return parts?.unitLanded ?? 0;
}
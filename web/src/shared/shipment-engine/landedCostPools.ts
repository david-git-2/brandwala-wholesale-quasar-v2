import type { LandedCostPools } from './landedCostBdtEngine';
import type { CostingShipmentInput } from './types';

export type ApFxLandedPoolsInput = {
  material: { bdt_paid: number };
  freight: { bdt_paid: number };
  freight_bdt?: number;
  product_conversion_rate?: number;
  cargo_conversion_rate?: number;
  cargo_rate?: number;
  transaction_rate?: number;
  product_foreign?: number;
  freight_bdt_per_kg?: number | null;
  customs?: { bdt_paid: number };
  handling?: { bdt_paid: number };
  finance?: { bdt_paid: number };
  other?: { bdt_paid: number };
};

export function landedPoolsFromApFx(apFx: ApFxLandedPoolsInput): LandedCostPools {
  return {
    materialBdt: apFx.material.bdt_paid,
    freightBdt: apFx.freight_bdt > 0 ? apFx.freight_bdt : apFx.freight.bdt_paid,
    customsBdt: apFx.customs?.bdt_paid ?? 0,
    handlingBdt: apFx.handling?.bdt_paid ?? 0,
    financeBdt: apFx.finance?.bdt_paid ?? 0,
    otherBdt: apFx.other?.bdt_paid ?? 0,
  };
}

export function costingShipmentWithLandedPools(
  shipment: CostingShipmentInput,
  apFx: ApFxLandedPoolsInput | null | undefined,
): CostingShipmentInput {
  if (!apFx || shipment.type === 'local') return shipment;
  const pools = landedPoolsFromApFx(apFx);
  const hasPoolSignal =
    pools.materialBdt > 0 ||
    pools.freightBdt > 0 ||
    pools.customsBdt > 0 ||
    pools.handlingBdt > 0 ||
    pools.financeBdt > 0 ||
    pools.otherBdt > 0;
  if (!hasPoolSignal) return shipment;
  return {
    ...shipment,
    product_conversion_rate: apFx.product_conversion_rate,
    cargo_conversion_rate: apFx.cargo_conversion_rate,
    cargo_rate: apFx.cargo_rate,
    transaction_rate: apFx.transaction_rate,
    landed_pools: pools,
    material_foreign: apFx.product_foreign,
    freight_bdt_per_kg: apFx.freight_bdt_per_kg ?? null,
  };
}
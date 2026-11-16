import {
  calculateRawTransactionRate,
  type CostingLineItemInput,
  type CostingShipmentInput,
  type ShipmentCostSummary,
} from 'src/shared/shipment-engine';

import type { ShipmentApFxSnapshot } from '../repositories/shipmentApBillsRepository';

export type PaymentLegRow = {
  label: string;
  bdt: number;
  foreign: number;
  rate: number | null;
  active: boolean;
};

export type LinePreviewRateBreakdown =
  | {
      kind: 'ap_payments';
      rate: number;
      purchaseSymbol: string;
      costSymbol: string;
      material: PaymentLegRow;
      freight: PaymentLegRow;
      blendBdt: number;
      blendForeign: number;
      blendRate: number;
    }
  | {
      kind: 'cost_preview';
      rate: number;
      purchaseSymbol: string;
      costSymbol: string;
      goodsPurchase: number;
      cargoPurchase: number;
      productRate: number;
      cargoRate: number;
      cargoWeightKg: number;
      cargoRatePerKg: number;
      bdtOnMaterial: number;
      bdtOnFreight: number;
      totalForeign: number;
      totalBdt: number;
      blendRate: number;
      weightNote: string;
    };

const round4 = (n: number) => Math.round(n * 10_000) / 10_000;
const round2 = (n: number) => Math.round(n * 100) / 100;

/** Matches `getCalculatedTransactionRate`: stored pay rate wins over line-list blend. */
function usesApPaymentTransactionRate(
  forCosting: CostingShipmentInput,
  items: CostingLineItemInput[],
  displayedRate: number,
): boolean {
  const stored = forCosting.transaction_rate;
  if (stored == null || stored <= 0) return false;
  const previewRate = calculateRawTransactionRate(
    { ...forCosting, transaction_rate: null },
    items,
  );
  if (previewRate != null && Math.abs(stored - previewRate) < 0.000_5) {
    return false;
  }
  return Math.abs(displayedRate - stored) < 0.05;
}

function legRow(
  label: string,
  bdt: number,
  foreign: number,
  fallbackRate: number,
  active: boolean,
): PaymentLegRow {
  const rate = foreign > 0.000_5 ? round4(bdt / foreign) : null;
  return {
    label,
    bdt: round2(bdt),
    foreign: round2(foreign),
    rate: rate ?? (active && fallbackRate > 0 ? round4(fallbackRate) : null),
    active,
  };
}

export function buildLinePreviewRateBreakdown(input: {
  rate: number;
  totals: ShipmentCostSummary;
  forCosting: CostingShipmentInput;
  items: CostingLineItemInput[];
  apFx: ShipmentApFxSnapshot | null;
  weightNote: string;
  purchaseSymbol: string;
  costSymbol: string;
}): LinePreviewRateBreakdown {
  const { rate, totals, forCosting, items, apFx, weightNote, purchaseSymbol, costSymbol } = input;

  if (usesApPaymentTransactionRate(forCosting, items, rate) && apFx) {
    const blendBdt = round2(apFx.goods_bdt + apFx.freight_bdt);
    const blendForeign = round2(apFx.product_foreign + apFx.cargo_foreign);
    const blendRate =
      blendForeign > 0 ? round4(blendBdt / blendForeign) : round4(apFx.transaction_rate || rate);

    return {
      kind: 'ap_payments',
      rate,
      purchaseSymbol,
      costSymbol,
      material: legRow(
        'Material',
        apFx.material.bdt_paid,
        apFx.material.foreign_paid,
        apFx.product_conversion_rate,
        (apFx.material.payment_count ?? 0) > 0 || apFx.product_foreign > 0,
      ),
      freight: legRow(
        'Freight',
        apFx.freight.bdt_paid,
        apFx.freight.foreign_paid,
        apFx.cargo_conversion_rate,
        (apFx.freight.payment_count ?? 0) > 0 || apFx.cargo_foreign > 0,
      ),
      blendBdt,
      blendForeign,
      blendRate,
    };
  }

  const productRate = Number(forCosting.product_conversion_rate) || 1;
  const cargoRate = Number(forCosting.cargo_conversion_rate) || 1;
  const cargoRatePerKg = Number(forCosting.cargo_rate) || 0;
  const goodsPurchase = round2(totals.goodsPurchase);
  const cargoPurchase = round2(totals.cargoPurchase);
  const totalForeign = round2(goodsPurchase + cargoPurchase);
  const bdtOnMaterial = round2(goodsPurchase * productRate);
  const bdtOnFreight = round2(cargoPurchase * cargoRate);
  const totalBdt = round2(bdtOnMaterial + bdtOnFreight);
  const fromEngine = calculateRawTransactionRate(forCosting, items);
  const blendRate = fromEngine != null && fromEngine > 0 ? round4(fromEngine) : round4(rate);

  return {
    kind: 'cost_preview',
    rate,
    purchaseSymbol,
    costSymbol,
    goodsPurchase,
    cargoPurchase,
    productRate,
    cargoRate,
    cargoWeightKg: round2(totals.cargoWeightKg),
    cargoRatePerKg: round4(cargoRatePerKg),
    bdtOnMaterial,
    bdtOnFreight,
    totalForeign,
    totalBdt,
    blendRate,
    weightNote,
  };
}
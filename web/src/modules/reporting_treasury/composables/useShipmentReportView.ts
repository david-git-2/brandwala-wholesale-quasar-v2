import { computed, type ComputedRef, type Ref, unref } from 'vue';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { ShipmentReportDetailPayload } from '../types/shipmentReportDetailTypes';

export type ShipmentReportVerdictChipTone = 'positive' | 'negative' | 'attention' | 'default';

export interface ShipmentReportVerdictChip {
  key: string;
  label: string;
  tone: ShipmentReportVerdictChipTone;
}

export interface ShipmentReportVerdictModel {
  sentence: string;
  chips: ShipmentReportVerdictChip[];
}

export interface ShipmentReportKpiTile {
  key: string;
  label: string;
  value: string;
  hint?: string;
  emphasis?: 'default' | 'hero' | 'positive' | 'negative';
  tone?: 'positive' | 'negative';
}

export interface ShipmentReportBridgeStep {
  key: string;
  label: string;
  amount: number;
  kind: 'total' | 'cost' | 'credit' | 'profit';
}

export interface ShipmentReportDonutSlice {
  key: string;
  label: string;
  amount: number;
  sharePct: number;
}

export interface ShipmentReportPieceSegment {
  key: string;
  label: string;
  qty: number;
  sharePct: number;
}

const EMPTY_MATRIX = {
  total_cost_bdt: 0,
  total_cost_by_currency: [],
  total_sell_bdt: 0,
  receive_loss_bdt: 0,
  unpaid_total_bdt: 0,
  profit_loss_bdt: 0,
  profit_loss_pct: 0,
  vendor_credit_bdt: 0,
  vendor_credit_count: 0,
  net_cost_bdt: 0,
  net_profit_loss_bdt: 0,
  net_profit_loss_pct: 0,
};

const EMPTY_QTY = {
  should_arrive: 0,
  arrived: 0,
  loss_at_shipment: 0,
  warehouse_stalled: 0,
  warehouse_remaining: 0,
  sold: 0,
  warehouse_value_bdt: 0,
};

function moneyBdt(amount: number) {
  return formatSettlementCurrencyAmount(amount, 'BDT');
}

function foreignCostSubline(
  legs: { currency_code: string; amount: number }[] | undefined,
): string | undefined {
  if (!legs?.length) return undefined;
  return legs.map((l) => formatSettlementCurrencyAmount(l.amount, l.currency_code)).join(' · ');
}

export function useShipmentReportView(detail: Ref<ShipmentReportDetailPayload | null | undefined>) {
  const matrix = computed(() => unref(detail)?.profit_matrix ?? EMPTY_MATRIX);
  const qty = computed(() => unref(detail)?.qty_summary ?? EMPTY_QTY);
  const pnl = computed(() => unref(detail)?.pnl ?? null);
  const costBuckets = computed(() => unref(detail)?.cost_buckets ?? []);

  const vendorCreditBdt = computed(() => matrix.value.vendor_credit_bdt ?? 0);
  const hasVendorCredits = computed(() => vendorCreditBdt.value > 0.009);

  const netCostBdt = computed(() =>
    hasVendorCredits.value
      ? (matrix.value.net_cost_bdt ?? matrix.value.total_cost_bdt - vendorCreditBdt.value)
      : matrix.value.total_cost_bdt,
  );

  const displayProfitBdt = computed(() =>
    hasVendorCredits.value
      ? (matrix.value.net_profit_loss_bdt ?? matrix.value.total_sell_bdt - netCostBdt.value)
      : matrix.value.profit_loss_bdt,
  );

  const displayProfitPct = computed(() =>
    hasVendorCredits.value
      ? (matrix.value.net_profit_loss_pct ?? matrix.value.profit_loss_pct)
      : matrix.value.profit_loss_pct,
  );

  const warehouseLeft = computed(
    () => qty.value.warehouse_remaining + qty.value.warehouse_stalled,
  );

  const warehouseValueBdt = computed(() => {
    if (warehouseLeft.value <= 0) {
      return qty.value.warehouse_value_bdt;
    }
    const onHand = qty.value.warehouse_value_bdt;
    if (onHand > 0.009) return onHand;
    const fromPnl = pnl.value?.unsold_stock_value;
    if (fromPnl != null && fromPnl >= 0) return fromPnl;
    return 0;
  });

  const soldPct = computed(() => {
    if (qty.value.should_arrive <= 0) return 0;
    return (qty.value.sold / qty.value.should_arrive) * 100;
  });

  const foreignSubline = computed(() => {
    const legs = matrix.value.total_cost_by_currency?.filter(
      (c) => c.currency_code && c.currency_code.toUpperCase() !== 'BDT' && c.amount > 0,
    );
    return foreignCostSubline(legs);
  });

  const verdict = computed((): ShipmentReportVerdictModel => {
    const m = matrix.value;
    const q = qty.value;
    const profit = displayProfitBdt.value;
    const isProfit = profit >= -0.009;
    const profitWord = isProfit ? 'made a profit' : 'lost money';
    const profitAmt = moneyBdt(Math.abs(profit));
    const margin = displayProfitPct.value.toFixed(2);

    const parts: string[] = [
      `This batch ${profitWord} of ${profitAmt} (${margin}% margin on sales).`,
      `${soldPct.value.toFixed(1)}% of pieces sold.`,
    ];

    if (hasVendorCredits.value) {
      parts.push(
        `Vendor credits of ${moneyBdt(vendorCreditBdt.value)} reduced true batch cost.`,
      );
    }

    if (m.unpaid_total_bdt > 0.009) {
      parts.push(`Customers still owe ${moneyBdt(m.unpaid_total_bdt)}.`);
    } else {
      parts.push('Customers owe nothing on this batch.');
    }

    if (q.loss_at_shipment > 0) {
      parts.push(
        `${q.loss_at_shipment} piece${q.loss_at_shipment === 1 ? '' : 's'} lost at receive (${moneyBdt(m.receive_loss_bdt)}).`,
      );
    }

    const chips: ShipmentReportVerdictChip[] = [
      {
        key: 'pl',
        label: isProfit ? 'Profit' : 'Loss',
        tone: isProfit ? 'positive' : 'negative',
      },
      {
        key: 'ar',
        label: m.unpaid_total_bdt > 0.009 ? 'Money owed' : 'Fully collected',
        tone: m.unpaid_total_bdt > 0.009 ? 'attention' : 'default',
      },
      {
        key: 'stock',
        label:
          warehouseLeft.value <= 0 && q.loss_at_shipment <= 0
            ? 'Sold through'
            : warehouseLeft.value > 0
              ? 'Stock in warehouse'
              : 'Sold out (loss only)',
        tone: warehouseLeft.value > 0 ? 'attention' : 'default',
      },
    ];

    if (hasVendorCredits.value) {
      chips.push({ key: 'vcredit', label: 'Vendor credit', tone: 'default' });
    }

    return { sentence: parts.join(' '), chips };
  });

  const primaryKpis = computed((): ShipmentReportKpiTile[] => {
    const m = matrix.value;
    const profitTone: ShipmentReportKpiTile['tone'] =
      displayProfitBdt.value >= 0 ? 'positive' : 'negative';

    const tiles: ShipmentReportKpiTile[] = [
      {
        key: 'spent',
        label: 'Money spent (gross)',
        value: moneyBdt(m.total_cost_bdt),
        hint: foreignSubline.value,
      },
    ];

    if (hasVendorCredits.value) {
      tiles.push({
        key: 'vcredit',
        label: 'Vendor credits',
        value: moneyBdt(vendorCreditBdt.value),
        tone: 'positive',
      });
    }

    tiles.push(
      {
        key: 'earned',
        label: 'Money earned',
        value: moneyBdt(m.total_sell_bdt),
      },
      {
        key: 'profit',
        label: hasVendorCredits.value ? 'Net profit' : 'Profit',
        value: moneyBdt(displayProfitBdt.value),
        hint: hasVendorCredits.value
          ? `${displayProfitPct.value.toFixed(2)}% margin · Before credits: ${moneyBdt(m.profit_loss_bdt)}`
          : `${displayProfitPct.value.toFixed(2)}% margin`,
        emphasis: 'hero',
        tone: profitTone,
      },
      {
        key: 'collect',
        label: 'Still to collect',
        value: moneyBdt(m.unpaid_total_bdt),
        tone: m.unpaid_total_bdt > 0.009 ? 'negative' : undefined,
      },
    );

    return tiles;
  });

  const secondaryKpis = computed((): ShipmentReportKpiTile[] => {
    const q = qty.value;
    const m = matrix.value;
    return [
      {
        key: 'soldpct',
        label: 'Sold',
        value: `${soldPct.value.toFixed(1)}%`,
        hint: `${q.sold} of ${q.should_arrive} pieces`,
      },
      {
        key: 'lost',
        label: 'Lost at receive',
        value: String(q.loss_at_shipment),
        hint: q.loss_at_shipment > 0 ? moneyBdt(m.receive_loss_bdt) : undefined,
        emphasis: q.loss_at_shipment > 0 ? 'negative' : 'default',
      },
      {
        key: 'warehouse',
        label: 'Warehouse value',
        value: moneyBdt(warehouseValueBdt.value),
        hint:
          warehouseLeft.value > 0 ? `${warehouseLeft.value} pieces in stock` : 'No stock on hand',
      },
    ];
  });

  const bridgeSteps = computed((): ShipmentReportBridgeStep[] => {
    const sell = matrix.value.total_sell_bdt;
    const buckets = costBuckets.value.filter((b) => b.bdt_amount > 0.009);
    const steps: ShipmentReportBridgeStep[] = [
      { key: 'sell', label: 'Earned', amount: sell, kind: 'total' },
    ];
    for (const b of buckets) {
      steps.push({
        key: b.ap_kind,
        label: b.label,
        amount: b.bdt_amount,
        kind: 'cost',
      });
    }
    if (hasVendorCredits.value) {
      steps.push({
        key: 'vendor_credit',
        label: 'Vendor credit',
        amount: vendorCreditBdt.value,
        kind: 'credit',
      });
    }
    steps.push({
      key: 'profit',
      label: hasVendorCredits.value ? 'Net profit' : 'Profit',
      amount: displayProfitBdt.value,
      kind: 'profit',
    });
    return steps;
  });

  const bridgeTotalCost = computed(() =>
    hasVendorCredits.value ? netCostBdt.value : matrix.value.total_cost_bdt,
  );

  const donutSlices = computed((): ShipmentReportDonutSlice[] => {
    const total = matrix.value.total_cost_bdt;
    const buckets = costBuckets.value.filter((b) => b.bdt_amount > 0.009);
    if (total <= 0 || !buckets.length) return [];
    return buckets.map((b) => ({
      key: b.ap_kind,
      label: b.label,
      amount: b.bdt_amount,
      sharePct: Math.round((b.bdt_amount / total) * 1000) / 10,
    }));
  });

  const pieceSegments = computed((): ShipmentReportPieceSegment[] => {
    const ordered = qty.value.should_arrive;
    if (ordered <= 0) return [];
    const sold = qty.value.sold;
    const lost = qty.value.loss_at_shipment;
    const left = warehouseLeft.value;
    const pct = (n: number) => (ordered > 0 ? Math.round((n / ordered) * 1000) / 10 : 0);
    return [
      { key: 'sold', label: 'Sold', qty: sold, sharePct: pct(sold) },
      { key: 'lost', label: 'Lost', qty: lost, sharePct: pct(lost) },
      { key: 'left', label: 'In warehouse', qty: left, sharePct: pct(left) },
    ].filter((s) => s.qty > 0 || s.key === 'sold');
  });

  const realizedGrossProfit = computed(() => pnl.value?.realized_gross_profit ?? 0);

  return {
    matrix,
    qty,
    pnl,
    vendorCreditBdt,
    hasVendorCredits,
    netCostBdt,
    displayProfitBdt,
    displayProfitPct,
    bridgeTotalCost,
    warehouseValueBdt,
    soldPct,
    verdict,
    primaryKpis,
    secondaryKpis,
    bridgeSteps,
    donutSlices,
    pieceSegments,
    realizedGrossProfit,
  };
}

export type UseShipmentReportViewReturn = {
  matrix: ComputedRef<typeof EMPTY_MATRIX>;
  qty: ComputedRef<typeof EMPTY_QTY>;
  verdict: ComputedRef<ShipmentReportVerdictModel>;
  primaryKpis: ComputedRef<ShipmentReportKpiTile[]>;
  secondaryKpis: ComputedRef<ShipmentReportKpiTile[]>;
  bridgeSteps: ComputedRef<ShipmentReportBridgeStep[]>;
  donutSlices: ComputedRef<ShipmentReportDonutSlice[]>;
  pieceSegments: ComputedRef<ShipmentReportPieceSegment[]>;
  realizedGrossProfit: ComputedRef<number>;
  warehouseValueBdt: ComputedRef<number>;
  soldPct: ComputedRef<number>;
  pnl: ComputedRef<import('../types/shipmentProfitTypes').ShipmentProfitReportRow | null>;
  vendorCreditBdt: ComputedRef<number>;
  hasVendorCredits: ComputedRef<boolean>;
  netCostBdt: ComputedRef<number>;
  displayProfitBdt: ComputedRef<number>;
  displayProfitPct: ComputedRef<number>;
  bridgeTotalCost: ComputedRef<number>;
};
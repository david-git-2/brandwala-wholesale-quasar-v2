import type { ShopOrder } from '../types';

export type DropshipInvoiceSummaryState = {
  delivery_charge_amount: number;
  deduct_delivery_from_margin: boolean;
  cod_charge_amount: number;
  deduct_cod_from_margin: boolean;
  print_charge_amount: number;
  deduct_print_from_margin: boolean;
  packing_charge_amount: number;
  deduct_packing_from_margin: boolean;
  discount_amount: number;
  cod_collect_amount: number;
};

export function createDropshipInvoiceSummaryFromOrder(
  order: Pick<
    ShopOrder,
    | 'delivery_charge_amount'
    | 'deduct_delivery_from_margin'
    | 'cod_charge_amount'
    | 'deduct_cod_from_margin'
    | 'print_charge_amount'
    | 'deduct_print_from_margin'
    | 'packing_charge_amount'
    | 'deduct_packing_from_margin'
    | 'discount_amount'
    | 'cod_collect_amount'
  >,
): DropshipInvoiceSummaryState {
  return {
    delivery_charge_amount: Number(order.delivery_charge_amount ?? 0),
    deduct_delivery_from_margin: !!order.deduct_delivery_from_margin,
    cod_charge_amount: Number(order.cod_charge_amount ?? 0),
    deduct_cod_from_margin: !!order.deduct_cod_from_margin,
    print_charge_amount: Number(order.print_charge_amount ?? 0),
    deduct_print_from_margin: !!order.deduct_print_from_margin,
    packing_charge_amount: Number(order.packing_charge_amount ?? 0),
    deduct_packing_from_margin: !!order.deduct_packing_from_margin,
    discount_amount: Number(order.discount_amount ?? 0),
    cod_collect_amount: Number(order.cod_collect_amount ?? 0),
  };
}

export function createEmptyDropshipInvoiceSummary(): DropshipInvoiceSummaryState {
  return createDropshipInvoiceSummaryFromOrder({
    delivery_charge_amount: 0,
    deduct_delivery_from_margin: false,
    cod_charge_amount: 0,
    deduct_cod_from_margin: false,
    print_charge_amount: 0,
    deduct_print_from_margin: false,
    packing_charge_amount: 0,
    deduct_packing_from_margin: false,
    discount_amount: 0,
    cod_collect_amount: 0,
  });
}

export type ChargePayer = 'recipient' | 'merchant';

export const chargePayer = (deductFromMargin: boolean | undefined): ChargePayer =>
  deductFromMargin ? 'merchant' : 'recipient';

export const chargePayerLabel = (deductFromMargin: boolean | undefined): string =>
  chargePayer(deductFromMargin) === 'recipient' ? 'Recipient pays' : 'Merchant pays';

export const chargeCountsTowardRecipientTotal = (deductFromMargin: boolean | undefined): boolean =>
  !deductFromMargin;

export type SummaryChargeRow = {
  key: 'delivery' | 'cod' | 'print' | 'packing';
  label: string;
  amount: number;
  payer: ChargePayer;
  payerLabel: string;
  countsTowardRecipientTotal: boolean;
};

export function buildSummaryChargeRows(
  summary: DropshipInvoiceSummaryState,
  options?: { includeZeroAmounts?: boolean },
): SummaryChargeRow[] {
  const includeZero = options?.includeZeroAmounts ?? false;
  const defs: Array<{
    key: SummaryChargeRow['key'];
    label: string;
    amount: number;
    deduct: boolean;
  }> = [
    {
      key: 'delivery',
      label: 'Delivery',
      amount: summary.delivery_charge_amount,
      deduct: summary.deduct_delivery_from_margin,
    },
    {
      key: 'cod',
      label: 'COD charge',
      amount: summary.cod_charge_amount,
      deduct: summary.deduct_cod_from_margin,
    },
    {
      key: 'print',
      label: 'Print',
      amount: summary.print_charge_amount,
      deduct: summary.deduct_print_from_margin,
    },
    {
      key: 'packing',
      label: 'Packing',
      amount: summary.packing_charge_amount,
      deduct: summary.deduct_packing_from_margin,
    },
  ];

  return defs
    .filter((row) => includeZero || row.amount > 0)
    .map((row) => ({
      key: row.key,
      label: row.label,
      amount: row.amount,
      payer: chargePayer(row.deduct),
      payerLabel: chargePayerLabel(row.deduct),
      countsTowardRecipientTotal: chargeCountsTowardRecipientTotal(row.deduct),
    }));
}

export function computeRecipientGrandTotal(
  itemsResellTotal: number,
  summary: DropshipInvoiceSummaryState,
): number {
  const chargeTotal = buildSummaryChargeRows(summary)
    .filter((row) => row.countsTowardRecipientTotal)
    .reduce((sum, row) => sum + row.amount, 0);

  return itemsResellTotal + chargeTotal - summary.discount_amount;
}

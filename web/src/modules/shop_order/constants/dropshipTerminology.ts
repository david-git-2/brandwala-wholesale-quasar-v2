/**
 * Dropship roles in UI copy (see docs/features/shop_order/spec.md — Terminology).
 * DB/RPC names (merchant_bill, reseller_*, middleman_*) are unchanged.
 */
export const DROPSHIP_TERM = {
  supplier: 'Supplier',
  dropshipper: 'Dropshipper',
  endCustomer: 'End customer',
  customerInvoice: 'Customer invoice',
  dropshipperProfit: 'Dropshipper profit',
  dropshipperPayout: 'Dropshipper payout',
  dropshipperBalance: 'Dropshipper balance',
} as const;

export type DropshipSettlementChargePayerUi = 'recipient' | 'merchant' | 'company';

export function dropshipChargePayerLabel(payer: DropshipSettlementChargePayerUi): string {
  switch (payer) {
    case 'recipient':
      return 'End customer pays';
    case 'merchant':
      return 'Dropshipper pays';
    case 'company':
      return 'Supplier pays';
    default:
      return payer;
  }
}

export function dropshipGiftCostChargedToLabel(chargedTo: 'reseller' | 'tenant'): string {
  return chargedTo === 'tenant' ? 'Supplier pays' : 'Dropshipper pays';
}

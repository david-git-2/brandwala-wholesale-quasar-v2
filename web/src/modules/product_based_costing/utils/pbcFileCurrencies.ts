export const PBC_FALLBACK_BUY_CURRENCY_CODE = 'GBP';
export const PBC_FALLBACK_SELL_CURRENCY_CODE = 'BDT';

export type PbcFileCurrencyFields = {
  buy_currency_id?: number | null;
  buy_currency_code?: string | null;
  sell_currency_id?: number | null;
  sell_currency_code?: string | null;
};

export function pbcFileBuyCurrencyCode(file: PbcFileCurrencyFields | null | undefined): string {
  const code = file?.buy_currency_code?.trim();
  return code ? code.toUpperCase() : PBC_FALLBACK_BUY_CURRENCY_CODE;
}

export function pbcFileSellCurrencyCode(file: PbcFileCurrencyFields | null | undefined): string {
  const code = file?.sell_currency_code?.trim();
  return code ? code.toUpperCase() : PBC_FALLBACK_SELL_CURRENCY_CODE;
}

export function pbcCurrencyMark(code: string): string {
  const upper = code.trim().toUpperCase();
  if (upper === 'GBP') return '£';
  if (upper === 'BDT') return '৳';
  return `${upper} `;
}

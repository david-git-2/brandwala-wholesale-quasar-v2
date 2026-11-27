export type BdtFormatOptions = {
  minimumFractionDigits?: number;
  maximumFractionDigits?: number;
};

export type CurrencyFormatOptions = BdtFormatOptions;

const DEFAULT_OPTIONS: Required<BdtFormatOptions> = {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
};

const toSafeAmount = (value: number | string | null | undefined): number => {
  const amount = Number(value ?? 0);
  return Number.isFinite(amount) ? amount : 0;
};

const normalizeFractionOptions = (options: BdtFormatOptions = {}): Required<BdtFormatOptions> => ({
  ...DEFAULT_OPTIONS,
  ...options,
});

const formatIndianGrouping = (value: number): string => {
  const parts = Math.abs(value).toFixed(2).split('.');
  const integerPart = parts[0] || '0';
  const fractionPart = parts[1] || '00';
  const lastThree = integerPart.slice(-3);
  const leading = integerPart.slice(0, -3);
  const groupedLeading = leading.replace(/\B(?=(\d{2})+(?!\d))/g, ',');
  const grouped = leading ? `${groupedLeading},${lastThree}` : lastThree;
  return `${value < 0 ? '-' : ''}${grouped}.${fractionPart}`;
};

export const formatAmountBdt = (
  value: number | string | null | undefined,
  options: BdtFormatOptions = {},
): string => {
  const safeAmount = toSafeAmount(value);
  const normalizedOptions = normalizeFractionOptions(options);

  if (
    normalizedOptions.minimumFractionDigits === 2 &&
    normalizedOptions.maximumFractionDigits === 2
  ) {
    return formatIndianGrouping(safeAmount);
  }

  return new Intl.NumberFormat('en-IN', {
    minimumFractionDigits: normalizedOptions.minimumFractionDigits,
    maximumFractionDigits: normalizedOptions.maximumFractionDigits,
  }).format(safeAmount);
};

/** Grouped BDT with ৳ prefix (cashbook / bill paid & due). */
export const formatBdtTaka = (value: number | string | null | undefined): string =>
  `৳${formatAmountBdt(value)}`;

export const SETTLEMENT_CURRENCY_SYMBOL: Record<string, string> = {
  BDT: '৳',
  GBP: '£',
  USD: '$',
  EUR: '€',
  CNY: '¥',
};

/** Symbol for UI labels — ignores `currency_symbol` when it is the ISO code. */
export const resolveSettlementCurrencySymbol = (
  currencyCode: string,
  currencySymbol?: string | null,
): string | null => {
  const code = (currencyCode || 'BDT').trim().toUpperCase();
  const sym = currencySymbol?.trim();
  if (sym && sym.toUpperCase() !== code) return sym;
  return SETTLEMENT_CURRENCY_SYMBOL[code] ?? null;
};

export const settlementCurrencyDisplayLabel = (
  currencyCode: string,
  currencySymbol?: string | null,
): string => resolveSettlementCurrencySymbol(currencyCode, currencySymbol) ?? (currencyCode || 'BDT').trim().toUpperCase();

/**
 * Format an amount in any currency.
 * Uses Indian digit grouping for BDT and standard grouping for foreign currencies;
 * never uses ৳ unless the resolved currency is BDT.
 */
export const formatCurrencyAmount = (
  value: number | string | null | undefined,
  currencyCode?: string | null,
  currencySymbol?: string | null,
  options: CurrencyFormatOptions = {},
): string => {
  const rawCode = currencyCode?.trim().toUpperCase() || '';
  const symOverride = currencySymbol?.trim() || null;
  const isSymbolOnlyForeign =
    !rawCode && symOverride !== null && symOverride !== '৳' && symOverride.toUpperCase() !== 'BDT';

  if (isSymbolOnlyForeign) {
    const normalizedOptions = normalizeFractionOptions(options);
    const formatted = new Intl.NumberFormat('en-US', normalizedOptions).format(toSafeAmount(value));
    return `${symOverride}${formatted}`;
  }

  const code = rawCode || 'BDT';
  const formatted =
    code === 'BDT'
      ? formatAmountBdt(value, options)
      : new Intl.NumberFormat('en-US', normalizeFractionOptions(options)).format(toSafeAmount(value));

  const sym = resolveSettlementCurrencySymbol(code, symOverride);
  if (sym) return `${sym}${formatted}`;
  return `${formatted} ${code}`;
};

/** Foreign or BDT settlement leg — never uses ৳ unless currency is BDT. */
export const formatSettlementCurrencyAmount = (
  value: number | string | null | undefined,
  currencyCode: string,
  currencySymbol?: string | null,
  options?: CurrencyFormatOptions,
): string => formatCurrencyAmount(value, currencyCode, currencySymbol, options);

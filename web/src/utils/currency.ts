export type BdtFormatOptions = {
  minimumFractionDigits?: number;
  maximumFractionDigits?: number;
};

const DEFAULT_OPTIONS: Required<BdtFormatOptions> = {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
};

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
  const amount = Number(value ?? 0);
  const safeAmount = Number.isFinite(amount) ? amount : 0;
  const normalizedOptions = {
    ...DEFAULT_OPTIONS,
    ...options,
  };

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

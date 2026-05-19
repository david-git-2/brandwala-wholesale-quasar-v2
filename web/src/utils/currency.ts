export type BdtFormatOptions = {
  minimumFractionDigits?: number
  maximumFractionDigits?: number
}

const DEFAULT_OPTIONS: Required<BdtFormatOptions> = {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
}

export const formatAmountBdt = (
  value: number | string | null | undefined,
  options: BdtFormatOptions = {},
): string => {
  const amount = Number(value ?? 0)
  const safeAmount = Number.isFinite(amount) ? amount : 0
  const normalizedOptions = {
    ...DEFAULT_OPTIONS,
    ...options,
  }

  return new Intl.NumberFormat('en-BD', {
    minimumFractionDigits: normalizedOptions.minimumFractionDigits,
    maximumFractionDigits: normalizedOptions.maximumFractionDigits,
  }).format(safeAmount)
}


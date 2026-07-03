export function isListedPriceLocked(pricing?: {
  is_listed_price_manual?: boolean | null;
} | null): boolean {
  return !!pricing?.is_listed_price_manual;
}

export function isItemMarkupLocked(pricing?: {
  markup_rate_override?: number | null;
} | null): boolean {
  return pricing?.markup_rate_override != null;
}

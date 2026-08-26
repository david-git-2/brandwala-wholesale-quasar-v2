/** Round up to the next 50-step price (50, 100, 150, 200, …). */
export function roundUpToNearest50or100(val: number): number {
  if (!val || val <= 0) return 0;
  return Math.ceil(val / 50) * 50;
}

/** Round to the nearest 5-step price (5, 10, 15, …). */
export function roundNearest5or0(val: number): number {
  if (!val || val <= 0) return 0;
  return Math.round(val / 5) * 5;
}

/** @deprecated Use {@link roundUpToNearest50or100} for floor/resell pricing. */
export function roundNearest50or100(val: number): number {
  return roundUpToNearest50or100(val);
}

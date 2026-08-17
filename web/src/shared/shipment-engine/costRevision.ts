/**
 * Optional UI helper: old→new stamp delta after cost revision preview.
 * Does not post wallet / ledger — display / stub only.
 */
import type { StampRevisionDelta } from './types';

export type { StampRevisionDelta } from './types';

export function computeStampRevisionDelta(
  oldLandedCostBdt: number,
  newLandedCostBdt: number,
): StampRevisionDelta {
  const oldV = Number(oldLandedCostBdt) || 0;
  const newV = Number(newLandedCostBdt) || 0;
  return {
    old_landed_cost_bdt: oldV,
    new_landed_cost_bdt: newV,
    delta_bdt: newV - oldV,
  };
}

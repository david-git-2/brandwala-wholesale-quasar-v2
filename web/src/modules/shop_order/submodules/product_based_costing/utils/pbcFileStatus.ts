/** PBC costing file status helpers — see doc/product_based_costing/PBC_COSTING.md */

import { normalizePbcFileStatus, workflowStatuses } from '../composables/useProductBasedCostingFileDetailsState';

export const PBC_PROGRESS_STEP_KEYS = [...workflowStatuses] as const;

export type PbcProgressStepKey = (typeof PBC_PROGRESS_STEP_KEYS)[number];

export type StaffPbcPrimaryAction =
  | 'send_offer'
  | 'confirm_order'
  | 'start_procurement'
  | 'mark_dispatch'
  | 'mark_delivered'
  | 'mark_closed';

export function mapPbcStatusToProgressKey(status: string | null | undefined): PbcProgressStepKey {
  const st = normalizePbcFileStatus(status || 'pending');
  if (st === 'cancelled') return 'pending';
  if (PBC_PROGRESS_STEP_KEYS.includes(st as PbcProgressStepKey)) {
    return st as PbcProgressStepKey;
  }
  return 'pending';
}

export function getPbcProgressSteps(): PbcProgressStepKey[] {
  return [...PBC_PROGRESS_STEP_KEYS];
}

export function isPbcProgressStepCurrent(
  stepKey: PbcProgressStepKey,
  currentStepKey: PbcProgressStepKey,
): boolean {
  return stepKey === currentStepKey;
}

export function getPbcProgressStepIndex(currentStepKey: PbcProgressStepKey): {
  current: number;
  total: number;
} {
  const steps = getPbcProgressSteps();
  const idx = Math.max(0, steps.indexOf(currentStepKey));
  return { current: idx + 1, total: steps.length };
}

export function getStaffPbcPrimaryAction(
  status: string | null | undefined,
): StaffPbcPrimaryAction | null {
  const st = normalizePbcFileStatus(status);
  switch (st) {
    case 'pending':
      return 'send_offer';
    case 'offered':
      return 'confirm_order';
    case 'confirmed':
      return 'start_procurement';
    case 'procuring':
      return 'mark_dispatch';
    case 'dispatch':
      return 'mark_delivered';
    case 'delivered':
      return 'mark_closed';
    default:
      return null;
  }
}

export function getStaffPbcPrimaryActionTargetStatus(action: StaffPbcPrimaryAction): string {
  switch (action) {
    case 'send_offer':
      return 'offered';
    case 'confirm_order':
      return 'confirmed';
    case 'start_procurement':
      return 'procuring';
    case 'mark_dispatch':
      return 'dispatch';
    case 'mark_delivered':
      return 'delivered';
    case 'mark_closed':
      return 'closed';
    default:
      return 'pending';
  }
}

export function isPbcTerminalStatus(status: string | null | undefined): boolean {
  const st = normalizePbcFileStatus(status);
  return st === 'closed' || st === 'cancelled';
}

export function isPbcRatesEditable(status: string | null | undefined): boolean {
  const st = normalizePbcFileStatus(status);
  return st === 'pending';
}

/** Quasar button color token for header workflow chips */
export function pbcFileStatusWorkflowColor(status: string): string {
  switch (normalizePbcFileStatus(status)) {
    case 'pending':
      return 'orange-8';
    case 'offered':
      return 'blue-7';
    case 'confirmed':
      return 'teal-7';
    case 'procuring':
      return 'indigo-7';
    case 'dispatch':
      return 'purple-7';
    case 'delivered':
      return 'green-7';
    case 'closed':
      return 'grey-8';
    case 'cancelled':
      return 'negative';
    default:
      return 'grey-7';
  }
}

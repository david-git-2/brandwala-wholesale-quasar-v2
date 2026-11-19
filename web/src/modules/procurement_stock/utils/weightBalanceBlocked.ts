import { Dialog } from 'quasar';

import type { WeightBalanceItemInput } from './weightBalance';

export type WeightBalanceBlockReason =
  | 'cargo_below_packaging_capacity'
  | 'line_package_below_zero'
  | 'cannot_distribute'
  | 'no_weight_basis';

export interface WeightBalanceAffectedLine {
  id: number;
  name: string;
  packageWeightG: number;
  productWeightG: number;
  orderedQty: number;
  hint: string;
}

export interface WeightBalanceBlockDetails {
  reason: WeightBalanceBlockReason;
  estimatedKg: number;
  actualKg: number;
  deltaKg: number;
  shortfallKg?: number;
  packagingCapacityKg?: number;
  affectedLines: WeightBalanceAffectedLine[];
}

export class WeightBalanceBlockedError extends Error {
  readonly details: WeightBalanceBlockDetails;

  constructor(message: string, details: WeightBalanceBlockDetails) {
    super(message);
    this.name = 'WeightBalanceBlockedError';
    this.details = details;
  }
}

export function isWeightBalanceBlockedError(error: unknown): error is WeightBalanceBlockedError {
  return error instanceof WeightBalanceBlockedError;
}

function estimatedTotalGm(items: WeightBalanceItemInput[]): number {
  return items.reduce(
    (sum, item) =>
      sum +
      ((item.product_weight || 0) + (item.package_weight || 0)) * (item.ordered_quantity || 0),
    0,
  );
}

function packagingCapacityGm(items: WeightBalanceItemInput[]): number {
  return items.reduce((sum, item) => {
    const qty = item.ordered_quantity || 0;
    if (qty <= 0) return sum;
    return sum + (item.package_weight || 0) * qty;
  }, 0);
}

export function collectAffectedLinesForCargoShortfall(
  items: WeightBalanceItemInput[],
  estimatedTotalGm: number,
  requiredReductionGm: number,
): WeightBalanceAffectedLine[] {
  if (estimatedTotalGm <= 0 || requiredReductionGm <= 0) return [];

  const affected: Array<WeightBalanceAffectedLine & { excessGm: number }> = [];
  for (const item of items) {
    const qty = item.ordered_quantity || 0;
    if (qty <= 0) continue;

    const productG = item.product_weight || 0;
    const packageG = item.package_weight || 0;
    const grossGm = (productG + packageG) * qty;
    const share = grossGm / estimatedTotalGm;
    const lineReductionGm = requiredReductionGm * share;
    const lineCapacityGm = packageG * qty;

    if (lineReductionGm <= lineCapacityGm + 1e-9) continue;

    const excessGm = lineReductionGm - lineCapacityGm;
    const excessKg = excessGm / 1000;
    affected.push({
      id: item.id,
      name: item.name,
      packageWeightG: packageG,
      productWeightG: productG,
      orderedQty: qty,
      excessGm,
      hint: `Would need ~${(lineReductionGm / 1000).toFixed(3)} kg cut from packaging but only ${(lineCapacityGm / 1000).toFixed(3)} kg is available (${excessKg.toFixed(3)} kg short). Product weight (${productG} g/unit) is not changed by balance.`,
    });
  }

  return affected
    .sort((a, b) => b.excessGm - a.excessGm)
    .slice(0, 12)
    .map(({ excessGm: _excessGm, ...line }) => line);
}

export function collectAffectedLinesFromNaivePass(
  items: WeightBalanceItemInput[],
  deltaGm: number,
  estimatedTotalGm: number,
): WeightBalanceAffectedLine[] {
  const affected: WeightBalanceAffectedLine[] = [];
  for (const item of items) {
    const qty = item.ordered_quantity || 0;
    if (qty <= 0) continue;

    const productG = item.product_weight || 0;
    const packageG = item.package_weight || 0;
    const grossGm = (productG + packageG) * qty;
    const share = grossGm / estimatedTotalGm;
    const lineDeltaGm = deltaGm * share;
    const perUnitDelta = lineDeltaGm / qty;
    const newPackageG = packageG + perUnitDelta;

    if (newPackageG >= -1e-9) continue;

    affected.push({
      id: item.id,
      name: item.name,
      packageWeightG: packageG,
      productWeightG: productG,
      orderedQty: qty,
      hint: `Packaging would become ${newPackageG.toFixed(2)} g/unit (now ${packageG} g/unit). Most of this line's weight is product (${productG} g/unit).`,
    });
  }

  return affected.slice(0, 12);
}

export function throwWeightBalanceBlocked(
  reason: WeightBalanceBlockReason,
  items: WeightBalanceItemInput[],
  actualTotalKg: number,
  message: string,
  options?: {
    shortfallKg?: number;
    lineName?: string;
    affectedLines?: WeightBalanceAffectedLine[];
  },
): never {
  const estimatedGm = estimatedTotalGm(items);
  const estimatedKg = estimatedGm / 1000;
  const deltaKg = actualTotalKg - estimatedKg;
  const deltaGm = deltaKg * 1000;

  let affectedLines = options?.affectedLines ?? [];
  if (!affectedLines.length && reason === 'cargo_below_packaging_capacity') {
    affectedLines = collectAffectedLinesForCargoShortfall(items, estimatedGm, -deltaGm);
  }
  if (!affectedLines.length && reason === 'line_package_below_zero' && deltaGm !== 0) {
    affectedLines = collectAffectedLinesFromNaivePass(items, deltaGm, estimatedGm);
  }
  if (!affectedLines.length && options?.lineName) {
    const line = items.find((item) => item.name === options.lineName);
    if (line) {
      affectedLines = [
        {
          id: line.id,
          name: line.name,
          packageWeightG: line.package_weight || 0,
          productWeightG: line.product_weight || 0,
          orderedQty: line.ordered_quantity || 0,
          hint: 'This line cannot absorb more packaging reduction.',
        },
      ];
    }
  }

  throw new WeightBalanceBlockedError(message, {
    reason,
    estimatedKg,
    actualKg: actualTotalKg,
    deltaKg,
    shortfallKg: options?.shortfallKg,
    packagingCapacityKg: packagingCapacityGm(items) / 1000,
    affectedLines,
  });
}

function reasonLeadCopy(reason: WeightBalanceBlockReason, details: WeightBalanceBlockDetails): string {
  switch (reason) {
    case 'cargo_below_packaging_capacity':
      return `Cargo weight (${details.actualKg.toFixed(3)} kg) is below the total from line items (${details.estimatedKg.toFixed(3)} kg). The gap is ${Math.abs(details.deltaKg).toFixed(3)} kg, but only ${(details.packagingCapacityKg ?? 0).toFixed(3)} kg can be removed by lowering packaging weights alone.`;
    case 'line_package_below_zero':
      return `Cargo weight (${details.actualKg.toFixed(3)} kg) does not match line totals (${details.estimatedKg.toFixed(3)} kg). At least one line would need packaging below zero before other lines can take the rest.`;
    case 'no_weight_basis':
      return 'Line items have no weight to use as a distribution basis. Set product or packaging weight on lines first.';
    default:
      return 'Weight could not be balanced across packaging weights. Check cargo weight and line weights.';
  }
}

export function showWeightBalanceBlockedDialog(error: WeightBalanceBlockedError): void {
  const { details } = error;
  const lead = reasonLeadCopy(details.reason, details);

  const productList =
    details.affectedLines.length > 0
      ? `<p class="q-mb-xs text-weight-medium">Lines most likely causing the block:</p><ul style="margin: 0 0 12px 18px; padding: 0;">${details.affectedLines
          .map(
            (line) =>
              `<li style="margin-bottom: 6px;"><strong>${escapeHtml(line.name)}</strong><br/><span style="opacity: 0.85;">${escapeHtml(line.hint)}</span></li>`,
          )
          .join('')}</ul>`
      : '';

  const shortfallNote =
    details.shortfallKg != null && details.shortfallKg > 0
      ? `<p>Remaining gap after using all packaging: <strong>${details.shortfallKg.toFixed(3)} kg</strong> — lower <strong>product weight</strong> on lines or fix cargo invoice weight.</p>`
      : '';

  const actions =
    '<p class="q-mb-none text-caption" style="opacity: 0.9;">What you can do: correct cargo invoice weight, reduce product weight on heavy lines, or edit packaging weight manually on the shipment lines.</p>';

  Dialog.create({
    title: 'Cannot balance weight',
    message: `<p>${escapeHtml(lead)}</p><p>Weight balance only changes <strong>packaging weight</strong>, not product weight.</p>${shortfallNote}${productList}${actions}`,
    html: true,
    ok: {
      label: 'Close',
      flat: true,
      color: 'primary',
      noCaps: true,
    },
    persistent: false,
  });
}

function escapeHtml(text: string): string {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}
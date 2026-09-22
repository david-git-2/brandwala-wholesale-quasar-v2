export type BoxWeightVarianceStatus = 'match' | 'weight_loss' | 'minor_over';

const MATCH_TOLERANCE_KG = 0.01;

/** shipping − received (kg), rounded to 2 decimals */
export function boxWeightDiffKg(received: number, shipping: number): number {
  const diff = (Number(shipping) || 0) - (Number(received) || 0);
  return Math.round(diff * 100) / 100;
}

export function boxWeightVarianceStatus(
  received: number,
  shipping: number,
): BoxWeightVarianceStatus {
  const diff = boxWeightDiffKg(received, shipping);
  if (Math.abs(diff) <= MATCH_TOLERANCE_KG) return 'match';
  if (diff > MATCH_TOLERANCE_KG) return 'weight_loss';
  return 'minor_over';
}

export function formatBoxWeightDiffKg(received: number, shipping: number): string {
  const diff = boxWeightDiffKg(received, shipping);
  if (diff > 0) return `+${diff.toFixed(2)}`;
  return diff.toFixed(2);
}

export function boxWeightsAreValid(received: number | null, shipping: number | null): boolean {
  const r = received ?? 0;
  const s = shipping ?? 0;
  if (r < 0 || s < 0) return false;
  return r > 0 || s > 0;
}

export const BOX_WEIGHT_VARIANCE_LABEL: Record<BoxWeightVarianceStatus, string> = {
  match: 'Match',
  weight_loss: 'Weight loss',
  minor_over: 'Minor over',
};

/** Human-readable totals: shipping minus received across all boxes */
export function describeBoxTotalsNetDiff(
  receivedTotalKg: number,
  shippingTotalKg: number,
): {
  formulaLabel: string;
  signedKgLabel: string;
  explanation: string;
} {
  const diff = boxWeightDiffKg(receivedTotalKg, shippingTotalKg);
  const signedKgLabel = `${formatBoxWeightDiffKg(receivedTotalKg, shippingTotalKg)} kg`;
  const status = boxWeightVarianceStatus(receivedTotalKg, shippingTotalKg);
  const gap = Math.abs(diff).toFixed(2);

  let explanation = 'Box shipping and received totals match.';
  if (status === 'weight_loss') {
    explanation = `Shipping is ${gap} kg heavier than received across all boxes.`;
  } else if (status === 'minor_over') {
    explanation = `Received is ${gap} kg heavier than shipping across all boxes.`;
  }

  return {
    formulaLabel: 'Shipping − received',
    signedKgLabel,
    explanation,
  };
}

export type BoxVsInvoiceCargoLabel = 'Box shipping' | 'Box received';

/** box total − invoice cargo (kg) */
export function boxVsInvoiceCargoDiffKg(boxKg: number, invoiceCargoKg: number): number {
  return Math.round(((Number(boxKg) || 0) - (Number(invoiceCargoKg) || 0)) * 100) / 100;
}

export function formatSignedDiffKg(diffKg: number): string {
  if (diffKg > 0) return `+${diffKg.toFixed(2)} kg`;
  return `${diffKg.toFixed(2)} kg`;
}

export function describeBoxVsInvoiceCargo(
  label: BoxVsInvoiceCargoLabel,
  boxKg: number,
  invoiceCargoKg: number,
): { formulaLabel: string; signedKgLabel: string; explanation: string } {
  const diff = boxVsInvoiceCargoDiffKg(boxKg, invoiceCargoKg);
  const signedKgLabel = formatSignedDiffKg(diff);
  const gap = Math.abs(diff).toFixed(2);
  const short = label === 'Box shipping' ? 'Box shipping' : 'Box received';

  let explanation = `${short} matches invoice cargo (${invoiceCargoKg.toFixed(2)} kg).`;
  if (Math.abs(diff) > MATCH_TOLERANCE_KG) {
    explanation =
      diff > 0
        ? `${short} is ${gap} kg above invoice cargo (${invoiceCargoKg.toFixed(2)} kg).`
        : `${short} is ${gap} kg below invoice cargo (${invoiceCargoKg.toFixed(2)} kg).`;
  }

  return {
    formulaLabel: `${short} − invoice cargo`,
    signedKgLabel,
    explanation,
  };
}

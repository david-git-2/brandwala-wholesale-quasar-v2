export type LandSplitGuardLine = {
  id: number;
  name?: string | null;
  product_code?: string | null;
  ordered_quantity?: number | null;
};

export type LandSplitGuardOutcome = {
  shipment_item_id: number;
  reason: string;
  quantity: number;
};

export type LandSplitQtyIssue = {
  itemId: number;
  name: string;
  productCode: string | null;
  orderedQty: number;
  splitQty: number;
};

const isLandSplit = (row: LandSplitGuardOutcome) =>
  row.reason !== 'ordered' && row.reason !== 'vendor_discount';

export const landSplitQtyForItem = (
  itemId: number,
  outcomes: LandSplitGuardOutcome[],
): number =>
  outcomes
    .filter((row) => row.shipment_item_id === itemId && isLandSplit(row))
    .reduce((sum, row) => sum + (Number(row.quantity) || 0), 0);

/** Lines with ordered qty > 0 that have no land split, or split qty ≠ ordered. */
export const findLandSplitQtyMismatches = (
  items: LandSplitGuardLine[],
  outcomes: LandSplitGuardOutcome[],
): LandSplitQtyIssue[] => {
  const issues: LandSplitQtyIssue[] = [];
  for (const item of items) {
    const orderedQty = Number(item.ordered_quantity) || 0;
    if (orderedQty <= 0) continue;
    const splitQty = landSplitQtyForItem(item.id, outcomes);
    if (splitQty === orderedQty) continue;
    issues.push({
      itemId: item.id,
      name: item.name?.trim() || `Line #${item.id}`,
      productCode: item.product_code?.trim() || null,
      orderedQty,
      splitQty,
    });
  }
  return issues;
};

const issueLabel = (issue: LandSplitQtyIssue): string => {
  if (issue.productCode) return `${issue.productCode} — ${issue.name}`;
  return issue.name;
};

/** One line for dialogs / banners. */
export const describeLandSplitIssue = (issue: LandSplitQtyIssue): string => {
  const label = issueLabel(issue);
  if (issue.splitQty === 0) {
    return `${label}: no land splits yet (ordered ${issue.orderedQty})`;
  }
  if (issue.splitQty < issue.orderedQty) {
    const gap = issue.orderedQty - issue.splitQty;
    return `${label}: split ${issue.splitQty} / ordered ${issue.orderedQty} (add ${gap} — e.g. Missing)`;
  }
  const over = issue.splitQty - issue.orderedQty;
  return `${label}: split ${issue.splitQty} / ordered ${issue.orderedQty} (reduce by ${over})`;
};

/** Short hint on the line card. */
export const describeLandSplitIssueShort = (issue: LandSplitQtyIssue): string => {
  if (issue.splitQty === 0) return `Needs land splits for ${issue.orderedQty} ordered`;
  if (issue.splitQty < issue.orderedQty) {
    return `Split ${issue.splitQty} / ${issue.orderedQty} — add ${issue.orderedQty - issue.splitQty}`;
  }
  return `Split ${issue.splitQty} / ${issue.orderedQty} — reduce by ${issue.splitQty - issue.orderedQty}`;
};

export const formatLandSplitQtyGuardMessage = (issues: LandSplitQtyIssue[]): string => {
  const lines = issues.map((issue) => `• ${describeLandSplitIssue(issue)}`);
  const max = 12;
  const shown = lines.slice(0, max);
  const extra = lines.length > max ? `\n• …and ${lines.length - max} more product(s)` : '';
  return (
    'These products need land splits before receive:\n\n' +
    shown.join('\n') +
    extra +
    '\n\nAdd splits on each line (Missing/damaged for leftover). The app will not auto-fill.'
  );
};

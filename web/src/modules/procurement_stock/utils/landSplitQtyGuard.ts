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

/** One line for plain-text banners (matches row chip: "Split X of Y"). */
export const describeLandSplitIssue = (issue: LandSplitQtyIssue): string => {
  const label = issueLabel(issue);
  return `${label}: ${issue.splitQty} of ${issue.orderedQty}`;
};

/** Short hint on the line card. */
export const describeLandSplitIssueShort = (issue: LandSplitQtyIssue): string => {
  return `Split ${issue.splitQty} of ${issue.orderedQty}`;
};

const escapeLandSplitHtml = (raw: string): string =>
  raw
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

export const landSplitQtyGuardDialogTitle = (issueCount: number): string => {
  if (issueCount === 1) return 'One product still needs quantities';
  return `${issueCount} products still need quantities`;
};

export const formatLandSplitQtyGuardMessage = (issues: LandSplitQtyIssue[]): string => {
  const max = 12;
  const shown = issues
    .slice(0, max)
    .map((issue) => `• ${describeLandSplitIssue(issue)}`);
  const extra =
    issues.length > max ? `• …and ${issues.length - max} more` : '';
  return [
    'On each product, enter how many units you received. Good + missing + damaged must add up to the order qty.',
    '',
    'Still to fix:',
    ...shown,
    extra,
    '',
    'Open each line → Add split. Short count? use Missing or Damaged for the rest.',
  ]
    .filter((line) => line !== '')
    .join('\n');
};

/** Structured copy for Quasar dialog (`html: true`). */
export const formatLandSplitQtyGuardDialogHtml = (issues: LandSplitQtyIssue[]): string => {
  const max = 12;
  const listItems = issues.slice(0, max).map((issue) => {
    const label = escapeLandSplitHtml(issueLabel(issue));
    return `<li><strong>${label}</strong> — ${issue.splitQty} of ${issue.orderedQty}</li>`;
  });
  const extra =
    issues.length > max
      ? `<li class="text-grey-7">…and ${issues.length - max} more</li>`
      : '';
  return [
    '<p class="q-mb-sm">You can’t receive until each product shows how many units arrived.',
    'The numbers must add up to what you ordered (use <strong>Missing</strong> or <strong>Damaged</strong> if you got less).</p>',
    '<p class="text-weight-medium q-mb-xs q-mt-md">These lines:</p>',
    `<ul class="q-pl-md q-my-sm">${listItems.join('')}${extra}</ul>`,
    '<p class="q-mb-none text-grey-8">Go back to the list → open the product → <strong>Add split</strong>.</p>',
  ].join('');
};

/**
 * Single source of truth: any status string -> color group.
 * Pages pass the raw status to <TfStatusBadge>; they never pick colors.
 * Groups map to --tf-status-<group> tokens in css/app.scss.
 */
export type TfStatusGroup = 'wait' | 'attention' | 'progress' | 'done' | 'bad';

const GROUPS: Record<TfStatusGroup, string[]> = {
  wait: ['draft', 'on_hold', 'inactive', 'closed', 'open', 'abandoned', 'popped'],
  attention: [
    'pending', 'offered', 'low_stock', 'submitted', 'costing_pending', 'negotiating',
    'countered', 'priced', 'final_offered', 'partial', 'unpaid',
  ],
  progress: ['confirmed', 'placed', 'procuring', 'processing', 'packed', 'shipped', 'active', 'accepted', 'converted'],
  done: ['delivered', 'completed', 'fulfilled', 'payment_received', 'paid', 'in_stock', 'received'],
  bad: ['cancelled', 'rejected', 'returned', 'overdue', 'failed', 'out_of_stock'],
};

const LOOKUP = new Map<string, TfStatusGroup>();
for (const [group, keys] of Object.entries(GROUPS) as [TfStatusGroup, string[]][]) {
  for (const k of keys) LOOKUP.set(k, group);
}

/** Step icons inside a group (label + icon show the step; hue stays the group's). */
const ICONS: Record<string, string> = {
  confirmed: 'ph ph-check',
  placed: 'ph ph-receipt',
  procuring: 'ph ph-shopping-cart',
  processing: 'ph ph-arrows-clockwise',
  packed: 'ph ph-package',
  shipped: 'ph ph-truck',
  offered: 'ph ph-tag',
  pending: 'ph ph-clock',
  draft: 'ph ph-note-pencil',
  on_hold: 'ph ph-pause-circle',
  cancelled: 'ph ph-x-circle',
  overdue: 'ph ph-warning-circle',
  low_stock: 'ph ph-warning',
};

const GROUP_ICONS: Record<TfStatusGroup, string> = {
  wait: 'ph ph-circle-dashed',
  attention: 'ph ph-clock',
  progress: 'ph ph-arrows-clockwise',
  done: 'ph ph-check-circle',
  bad: 'ph ph-warning-circle',
};

export function normalizeStatus(status: string | null | undefined): string {
  return (status ?? '').trim().toLowerCase().replace(/[\s-]+/g, '_');
}

export function statusGroup(status: string | null | undefined): TfStatusGroup {
  return LOOKUP.get(normalizeStatus(status)) ?? 'wait';
}

export function statusIcon(status: string | null | undefined): string {
  return ICONS[normalizeStatus(status)] ?? GROUP_ICONS[statusGroup(status)];
}

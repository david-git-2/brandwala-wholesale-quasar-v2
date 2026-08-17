export const WAITING_STATUSES = new Set([
  'priced',
  'negotiating',
  'countered',
  'final_offered',
]);

export const DONE_STATUSES = new Set([
  'fulfilled',
  'delivered',
  'payment_received',
  'cancelled',
  'returned',
]);

export type OrderGlanceBucket = 'needs_you' | 'in_progress' | 'done';

export const ORDER_GLANCE_BUCKETS: readonly OrderGlanceBucket[] = [
  'needs_you',
  'in_progress',
  'done',
];

export const parseOrderGlanceBucket = (raw: unknown): OrderGlanceBucket | null => {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (value === 'needs_you' || value === 'in_progress' || value === 'done') return value;
  return null;
};

export const isWaitingStatus = (status: string) => WAITING_STATUSES.has(status);

export const orderGlanceBucket = (status: string): OrderGlanceBucket | null => {
  if (status === 'draft') return null;
  if (WAITING_STATUSES.has(status)) return 'needs_you';
  if (DONE_STATUSES.has(status)) return 'done';
  return 'in_progress';
};

export const countOrderGlance = (orders: Array<{ status: string }>) => {
  const counts = { needs_you: 0, in_progress: 0, done: 0, total: 0 };
  orders.forEach((order) => {
    const bucket = orderGlanceBucket(order.status);
    if (!bucket) return;
    counts[bucket] += 1;
    counts.total += 1;
  });
  return counts;
};

export const waitingActionI18nKey = (status: string) => {
  if (status === 'priced' || status === 'final_offered') {
    return 'customer_dashboard.action_confirm_price';
  }
  if (status === 'negotiating' || status === 'countered') {
    return 'customer_dashboard.action_reply';
  }
  return null;
};

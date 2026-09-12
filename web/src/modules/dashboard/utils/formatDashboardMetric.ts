export function asDashboardNumber(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

export function formatDashboardCount(value: unknown): string {
  return Math.round(asDashboardNumber(value)).toLocaleString();
}

export function formatDashboardMoney(value: unknown): string {
  const amount = asDashboardNumber(value);
  const sign = amount < 0 ? '-' : '';
  const abs = Math.abs(amount);
  if (abs >= 1_000_000) {
    const m = abs / 1_000_000;
    const digits = m >= 10 ? 1 : 2;
    return `${sign}৳${m.toFixed(digits).replace(/\.0+$/, '')}M`;
  }
  if (abs >= 10_000) {
    const k = abs / 1000;
    const digits = k >= 100 ? 0 : 1;
    return `${sign}৳${k.toFixed(digits).replace(/\.0+$/, '')}K`;
  }
  return `${sign}৳${Math.round(abs).toLocaleString()}`;
}

export function formatDashboardMoneyFull(value: unknown): string {
  return `৳${Math.round(asDashboardNumber(value)).toLocaleString()}`;
}

/** True when a formatted metric display string represents zero (0, ৳0, 0 batches, etc.). */
export function isDashboardMetricZero(value: string): boolean {
  const digits = value.replace(/[^\d.]/g, '');
  if (!digits) return false;
  const n = Number(digits);
  return Number.isFinite(n) && n === 0;
}

export function dashboardSharePct(part: number, total: number): number {
  if (total <= 0) {
    return 0;
  }
  return Math.round((part / total) * 100);
}

const MINUTE_MS = 60_000;
const HOUR_MS = 3_600_000;
const DAY_MS = 86_400_000;

export const formatRelativeTime = (isoDate: string): string => {
  const parsed = new Date(isoDate);
  if (Number.isNaN(parsed.getTime())) {
    return '';
  }

  const diffMs = parsed.getTime() - Date.now();
  const absMs = Math.abs(diffMs);

  if (absMs < MINUTE_MS) {
    return 'Just now';
  }

  if (absMs < HOUR_MS) {
    const minutes = Math.round(absMs / MINUTE_MS);
    return diffMs < 0 ? `${minutes}m ago` : `in ${minutes}m`;
  }

  if (absMs < DAY_MS) {
    const hours = Math.round(absMs / HOUR_MS);
    return diffMs < 0 ? `${hours}h ago` : `in ${hours}h`;
  }

  const days = Math.round(absMs / DAY_MS);
  return diffMs < 0 ? `${days}d ago` : `in ${days}d`;
};

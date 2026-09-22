export const DEFAULT_BATCH_EXPIRE_MONTHS = 36;
/** Matches 30-day month blocks used in Expires in display. */
export const BATCH_EXPIRE_WARN_MONTHS = 14;
export const BATCH_EXPIRE_DAYS_PER_MONTH = 30;
export const BATCH_EXPIRE_WARN_DAYS = BATCH_EXPIRE_WARN_MONTHS * BATCH_EXPIRE_DAYS_PER_MONTH;

const pad2 = (n: number) => String(n).padStart(2, '0');

const isValidYmd = (year: number, month: number, day: number): boolean => {
  if (!year || month < 1 || month > 12 || day < 1 || day > 31) return false;
  const date = new Date(year, month - 1, day);
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day;
};

export const formatDateOnly = (date: Date): string =>
  `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;

/** Store as YYYY-MM-DD. Accepts ISO, DD-MM-YYYY (dashes), and Excel M/D/YYYY (slashes). */
export const toIsoDate = (value: string | null | undefined): string | null => {
  const raw = value?.trim();
  if (!raw) return null;

  const iso = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (iso) {
    const year = Number(iso[1]);
    const month = Number(iso[2]);
    const day = Number(iso[3]);
    return isValidYmd(year, month, day) ? raw : null;
  }

  const parts = raw.match(/^(\d{1,2})([/\-.])(\d{1,2})\2(\d{4})$/);
  if (!parts) return null;

  const first = Number(parts[1]);
  const second = Number(parts[3]);
  const year = Number(parts[4]);
  const separator = parts[2];

  let month: number;
  let day: number;

  if (first > 12) {
    day = first;
    month = second;
  } else if (second > 12) {
    month = first;
    day = second;
  } else if (separator === '/') {
    month = first;
    day = second;
  } else {
    day = first;
    month = second;
  }

  if (!isValidYmd(year, month, day)) return null;
  return `${year}-${pad2(month)}-${pad2(day)}`;
};

export const toDisplayDate = (value: string | null | undefined): string => {
  const iso = toIsoDate(value);
  if (!iso) return '';
  const [year, month, day] = iso.split('-');
  return `${day}-${month}-${year}`;
};

export const defaultExpireFromManufacturing = (mfgDate: string): string => {
  const iso = toIsoDate(mfgDate);
  if (!iso) return '';
  const [year, month, day] = iso.split('-').map((part) => Number(part));
  const date = new Date(year, month - 1, day);
  date.setMonth(date.getMonth() + DEFAULT_BATCH_EXPIRE_MONTHS);
  return formatDateOnly(date);
};

export const daysUntilExpire = (expireDate: string | null | undefined): number | null => {
  const iso = toIsoDate(expireDate);
  if (!iso) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const expire = new Date(`${iso}T00:00:00`);
  expire.setHours(0, 0, 0, 0);
  const diffMs = expire.getTime() - today.getTime();
  return Math.round(diffMs / 86_400_000);
};

/** Whole days from today; display as months (30-day blocks) + days. */
export const formatDaysAsMonthsAndDays = (days: number | null): string => {
  if (days === null) return '—';
  if (days <= 0) return 'Expired';

  const months = Math.floor(days / 30);
  const remainder = days % 30;
  const parts: string[] = [];
  if (months > 0) parts.push(`${months}mo`);
  if (remainder > 0) parts.push(`${remainder}d`);
  return parts.length > 0 ? parts.join(' ') : '0d';
};

export const formatExpiresIn = (expireDate: string | null | undefined): string =>
  formatDaysAsMonthsAndDays(daysUntilExpire(expireDate));

export type BatchExpiryTone = 'unset' | 'ok' | 'warn';

export const batchExpiryTone = (expireDate: string | null | undefined): BatchExpiryTone => {
  const days = daysUntilExpire(expireDate);
  if (days === null) return 'unset';
  if (days < BATCH_EXPIRE_WARN_DAYS) return 'warn';
  return 'ok';
};

/** Row class: warn = under 14mo or expired; ok = safe; unset = no expire date. */
export const batchExpiryRowClass = (expireDate: string | null | undefined): string => {
  const tone = batchExpiryTone(expireDate);
  if (tone === 'warn') return 'batch-row--warn';
  if (tone === 'ok') return 'batch-row--ok';
  return 'batch-row--unset';
};

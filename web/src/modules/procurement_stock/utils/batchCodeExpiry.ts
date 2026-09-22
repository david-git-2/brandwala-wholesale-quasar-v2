export const DEFAULT_BATCH_EXPIRE_MONTHS = 36;

const pad2 = (n: number) => String(n).padStart(2, '0');

export const formatDateOnly = (date: Date): string =>
  `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;

export const defaultExpireFromManufacturing = (mfgDate: string): string => {
  const [year, month, day] = mfgDate.split('-').map((part) => Number(part));
  const date = new Date(year, month - 1, day);
  date.setMonth(date.getMonth() + DEFAULT_BATCH_EXPIRE_MONTHS);
  return formatDateOnly(date);
};

export const daysUntilExpire = (expireDate: string | null | undefined): number | null => {
  if (!expireDate) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const expire = new Date(`${expireDate}T00:00:00`);
  expire.setHours(0, 0, 0, 0);
  const diffMs = expire.getTime() - today.getTime();
  return Math.round(diffMs / 86_400_000);
};

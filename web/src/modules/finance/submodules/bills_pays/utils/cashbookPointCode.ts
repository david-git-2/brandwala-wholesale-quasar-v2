/** Stable short id for cashbook_points.code (unique per cashbook account). */
export const cashbookPointCodeFromName = (name: string): string => {
  const base = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  return base.length > 0 ? base : 'point';
};

export const uniqueCashbookPointCode = (baseCode: string, taken: Set<string>): string => {
  if (!taken.has(baseCode)) return baseCode;
  let n = 2;
  while (taken.has(`${baseCode}-${n}`)) n += 1;
  return `${baseCode}-${n}`;
};

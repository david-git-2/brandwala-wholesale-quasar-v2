import { ppOrderLineHostLabel } from './ppOrderLineUrl';

export type PpOrderLineGroupBlock<T extends { url: string }> = {
  key: string;
  label: string;
  lines: T[];
};

/** Group order lines by store URL host (supplier batching / staff store_url view). */
export function groupPpOrderLinesByStoreHost<T extends { url: string }>(
  lines: T[],
): PpOrderLineGroupBlock<T>[] {
  const map = new Map<string, T[]>();
  for (const line of lines) {
    const label = ppOrderLineHostLabel(line.url) || 'Unknown store';
    const bucket = map.get(label) ?? [];
    bucket.push(line);
    map.set(label, bucket);
  }
  return [...map.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([label, groupedLines]) => ({
      key: label,
      label,
      lines: groupedLines,
    }));
}
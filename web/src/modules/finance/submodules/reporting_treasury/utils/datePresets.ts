export type DatePreset = 'today' | 'week' | 'month' | 'quarter' | 'year' | 'all' | 'custom';

export function applyDatePreset(preset: DatePreset): { startDate: string | null; endDate: string | null } {
  const now = new Date();
  const end = now.toISOString().slice(0, 10);

  if (preset === 'all') return { startDate: null, endDate: null };
  if (preset === 'today') return { startDate: end, endDate: end };
  if (preset === 'week') {
    const start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    return { startDate: start.toISOString().slice(0, 10), endDate: end };
  }
  if (preset === 'month') {
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    return { startDate: start.toISOString().slice(0, 10), endDate: end };
  }
  if (preset === 'quarter') {
    const start = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
    return { startDate: start.toISOString().slice(0, 10), endDate: end };
  }
  const start = new Date(now.getFullYear(), 0, 1);
  return { startDate: start.toISOString().slice(0, 10), endDate: end };
}

export function monthFirstDay(d = new Date()): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

export function shiftMonth(monthFirst: string, delta: number): string {
  const d = new Date(`${monthFirst}T00:00:00`);
  d.setMonth(d.getMonth() + delta);
  return monthFirstDay(d);
}

export function formatMonthLabel(monthFirst: string): string {
  const d = new Date(`${monthFirst}T00:00:00`);
  return d.toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
}

export function ppOrderLineUrlLabel(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  if (trimmed.length <= 56) return trimmed;
  return `${trimmed.slice(0, 53)}…`;
}

/** Host for display when product name is not set (e.g. cultbeauty.co.uk). */
export function ppOrderLineHostLabel(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  if (!trimmed) return '';
  try {
    const href = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
    const host = new URL(href).hostname.replace(/^www\./i, '');
    return host || trimmed;
  } catch {
    return trimmed.length <= 48 ? trimmed : `${trimmed.slice(0, 45)}…`;
  }
}

export function openPpOrderLineUrl(rawUrl: string): void {
  const href = rawUrl.trim();
  if (!href) return;
  const withScheme = /^https?:\/\//i.test(href) ? href : `https://${href}`;
  window.open(withScheme, '_blank', 'noopener,noreferrer');
}
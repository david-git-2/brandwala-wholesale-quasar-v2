export function ppOrderLineUrlLabel(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  if (trimmed.length <= 56) return trimmed;
  return `${trimmed.slice(0, 53)}…`;
}

export function openPpOrderLineUrl(rawUrl: string): void {
  const href = rawUrl.trim();
  if (!href) return;
  const withScheme = /^https?:\/\//i.test(href) ? href : `https://${href}`;
  window.open(withScheme, '_blank', 'noopener,noreferrer');
}
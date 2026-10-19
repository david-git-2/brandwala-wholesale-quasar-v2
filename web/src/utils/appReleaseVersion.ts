const SEMVER_RE = /^v?(\d+\.\d+\.\d+)(?:[-+].*)?$/i;

/** Staff-facing semver label (always vX.Y.Z when parseable). */
export function formatReleaseVersionLabel(raw: string | null | undefined): string {
  const value = (raw ?? '').trim();
  if (!value || value === 'unknown') {
    return '—';
  }

  const semver = value.match(SEMVER_RE);
  if (semver) {
    return `v${semver[1]}`;
  }

  return value;
}

export function formatReleaseDeployedDate(iso: string | null | undefined): string | null {
  if (!iso) return null;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  const now = new Date();
  const opts: Intl.DateTimeFormatOptions =
    date.getFullYear() === now.getFullYear()
      ? { month: 'short', day: 'numeric' }
      : { month: 'short', day: 'numeric', year: '2-digit' };
  return date.toLocaleDateString(undefined, opts);
}

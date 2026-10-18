const APP_VERSION = (import.meta.env.VITE_APP_VERSION as string | undefined)?.trim() || '1.0.0';

const SEMVER_RE = /^v?(\d+\.\d+\.\d+)(?:[-+].*)?$/i;
const GIT_SHA_RE = /^[0-9a-f]{7,40}$/i;

/** Staff-facing label (semver), e.g. v1.0.0 */
export function formatReleaseVersionLabel(raw: string | null | undefined): string {
  const value = (raw ?? '').trim();
  if (!value || value === 'unknown') {
    return `v${APP_VERSION}`;
  }

  const semver = value.match(SEMVER_RE);
  if (semver) {
    return `v${semver[1]}`;
  }

  if (GIT_SHA_RE.test(value)) {
    return `v${APP_VERSION}`;
  }

  return value.startsWith('v') ? value : `v${value}`;
}

/** Tooltip when stored value is a git build id, not semver */
export function releaseVersionBuildHint(raw: string | null | undefined): string | undefined {
  const value = (raw ?? '').trim();
  if (!value || value === 'unknown') {
    return undefined;
  }
  if (SEMVER_RE.test(value)) {
    return undefined;
  }
  if (GIT_SHA_RE.test(value)) {
    return `Build ${value}`;
  }
  return value;
}

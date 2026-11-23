/**
 * Rewrite legacy scoped URLs to canonical shapes (query/hash preserved elsewhere).
 */

const RESERVED_FIRST_SEGMENTS = new Set([
  'app',
  'shop',
  'investor',
  'platform',
  'auth',
  'dev',
  'docs',
  'help',
  'operating-manual',
]);

export function rewriteLegacyRedirectQuery(redirect: string): string {
  return rewriteLegacyShopPath(rewriteLegacyAppInvestorPath(redirect));
}

export function rewriteLegacyAppInvestorPath(path: string): string {
  const withoutQuery = path.split('?')[0] ?? path;
  const match = withoutQuery.match(/^\/([^/]+)\/(app|investor)(\/.*)?$/);
  if (!match?.[1] || RESERVED_FIRST_SEGMENTS.has(match[1])) {
    return path;
  }
  const rest = match[3] ?? '';
  const query = path.includes('?') ? path.slice(path.indexOf('?')) : '';
  return `/${match[2]}${rest}${query}`;
}

export function rewriteLegacyShopPath(path: string): string {
  const withoutQuery = path.split('?')[0] ?? path;
  const legacyPrefix = withoutQuery.match(/^\/([^/]+)\/shop(\/.*)?$/);
  if (!legacyPrefix?.[1] || RESERVED_FIRST_SEGMENTS.has(legacyPrefix[1])) {
    return path;
  }
  const tenant = legacyPrefix[1];
  const rest = legacyPrefix[2] ?? '';
  const query = path.includes('?') ? path.slice(path.indexOf('?')) : '';
  return `/shop/${tenant}${rest}${query}`;
}

export function stripLeadingTenantAppPath(fullPath: string): string {
  const [pathPart, ...queryParts] = fullPath.split('?');
  const hashSplit = pathPart?.split('#') ?? [fullPath];
  const pathOnly = hashSplit[0] ?? fullPath;
  const hash = hashSplit.length > 1 ? `#${hashSplit.slice(1).join('#')}` : '';
  const match = pathOnly.match(/^\/([^/]+)\/app(\/.*)?$/);
  if (!match?.[1] || RESERVED_FIRST_SEGMENTS.has(match[1])) {
    return fullPath;
  }
  const rest = match[2] ?? '';
  const query = queryParts.length ? `?${queryParts.join('?')}` : '';
  return `/app${rest}${query}${hash}`;
}

export function stripLeadingTenantInvestorPath(fullPath: string): string {
  const [pathPart, ...queryParts] = fullPath.split('?');
  const hashSplit = pathPart?.split('#') ?? [fullPath];
  const pathOnly = hashSplit[0] ?? fullPath;
  const hash = hashSplit.length > 1 ? `#${hashSplit.slice(1).join('#')}` : '';
  const match = pathOnly.match(/^\/([^/]+)\/investor(\/.*)?$/);
  if (!match?.[1] || RESERVED_FIRST_SEGMENTS.has(match[1])) {
    return fullPath;
  }
  const rest = match[2] ?? '';
  const query = queryParts.length ? `?${queryParts.join('?')}` : '';
  return `/investor${rest}${query}${hash}`;
}